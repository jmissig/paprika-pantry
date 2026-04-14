import Foundation

public enum PantrySourceKind: String, Codable, Equatable, Sendable {
    case paprikaToken = "paprika-token"
    case kappari
}

public struct PaprikaTokenSourceConfiguration: Codable, Equatable, Sendable {
    public let token: String?
    public let tokenEnvironmentVariable: String?
    public let baseURL: String?

    public init(
        token: String? = nil,
        tokenEnvironmentVariable: String? = nil,
        baseURL: String? = nil
    ) {
        self.token = token
        self.tokenEnvironmentVariable = tokenEnvironmentVariable
        self.baseURL = baseURL
    }
}

public struct KappariSourceConfiguration: Codable, Equatable, Sendable {
    public let executable: String?
    public let arguments: [String]
    public let account: String?

    public init(
        executable: String? = nil,
        arguments: [String] = [],
        account: String? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.account = account
    }
}

public struct PantrySourceConfiguration: Codable, Equatable, Sendable {
    public let kind: PantrySourceKind
    public let displayName: String?
    public let paprikaToken: PaprikaTokenSourceConfiguration?
    public let kappari: KappariSourceConfiguration?

    public init(
        kind: PantrySourceKind,
        displayName: String? = nil,
        paprikaToken: PaprikaTokenSourceConfiguration? = nil,
        kappari: KappariSourceConfiguration? = nil
    ) {
        self.kind = kind
        self.displayName = displayName
        self.paprikaToken = paprikaToken
        self.kappari = kappari
    }
}

public enum PantrySourceProviderError: Error, LocalizedError, Equatable {
    case notConfigured
    case missingPaprikaToken
    case invalidBaseURL(String)
    case unsupportedSource(PantrySourceKind)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No pantry source is configured. Set PAPRIKA_PANTRY_SOURCE_TOKEN or add a source block to config.json."
        case .missingPaprikaToken:
            return "The paprika-token source needs a token. Set PAPRIKA_PANTRY_SOURCE_TOKEN or configure source.paprikaToken."
        case .invalidBaseURL(let rawValue):
            return "The configured source base URL is invalid: \(rawValue)"
        case .unsupportedSource(let kind):
            return "The \(kind.rawValue) source is described in config but not wired yet."
        }
    }
}

public enum PantrySourceDoctorStatus: String, Codable, Equatable, Sendable {
    case ready
    case notConfigured = "not-configured"
    case invalid
    case unsupported
}

public struct PantrySourceDoctorSnapshot: Codable, Equatable, Sendable {
    public let status: PantrySourceDoctorStatus
    public let message: String
    public let sourceKind: PantrySourceKind?
    public let displayName: String?
    public let implementation: String?
    public let credentialSource: String?

    public init(
        status: PantrySourceDoctorStatus,
        message: String,
        sourceKind: PantrySourceKind?,
        displayName: String?,
        implementation: String?,
        credentialSource: String?
    ) {
        self.status = status
        self.message = message
        self.sourceKind = sourceKind
        self.displayName = displayName
        self.implementation = implementation
        self.credentialSource = credentialSource
    }
}

public protocol PantrySourceProvider: Sendable {
    func makeSource() throws -> any PantrySource
    func diagnose() throws -> PantrySourceDoctorSnapshot
}

public struct ConfiguredPantrySourceProvider: PantrySourceProvider {
    public static let defaultTokenEnvironmentVariable = "PAPRIKA_PANTRY_SOURCE_TOKEN"

    private let configStore: PantryConfigStore
    private let environment: [String: String]

    public init(
        paths: PantryPaths,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.configStore = PantryConfigStore(paths: paths)
        self.environment = environment
    }

    public func makeSource() throws -> any PantrySource {
        switch try resolvedSourceReference() {
        case .paprikaToken(let token, let baseURL, _, _):
            return PaprikaTokenSource(token: token, baseURL: baseURL)
        case .kappari:
            throw PantrySourceProviderError.unsupportedSource(.kappari)
        case .invalid(_, _, let error):
            throw error
        case .none:
            throw PantrySourceProviderError.notConfigured
        }
    }

    public func diagnose() throws -> PantrySourceDoctorSnapshot {
        switch try resolvedSourceReference() {
        case .paprikaToken(_, _, let displayName, let credentialSource):
            return PantrySourceDoctorSnapshot(
                status: .ready,
                message: "The configured pantry source is ready.",
                sourceKind: .paprikaToken,
                displayName: displayName,
                implementation: "direct Paprika token source",
                credentialSource: credentialSource
            )
        case .kappari(let displayName):
            return PantrySourceDoctorSnapshot(
                status: .unsupported,
                message: "A kappari source is configured, but this build does not wire it yet.",
                sourceKind: .kappari,
                displayName: displayName,
                implementation: "planned kappari-backed source",
                credentialSource: nil
            )
        case .none:
            return PantrySourceDoctorSnapshot(
                status: .notConfigured,
                message: "No pantry source is configured.",
                sourceKind: nil,
                displayName: nil,
                implementation: nil,
                credentialSource: nil
            )
        case .invalid(let kind, let displayName, let error):
            return PantrySourceDoctorSnapshot(
                status: kind == .kappari ? .unsupported : .invalid,
                message: error.localizedDescription,
                sourceKind: kind,
                displayName: displayName,
                implementation: kind == .kappari ? "planned kappari-backed source" : "direct Paprika token source",
                credentialSource: nil
            )
        }
    }

    private func resolvedSourceReference() throws -> ResolvedSourceReference {
        if let token = environment[Self.defaultTokenEnvironmentVariable]?.trimmedNonEmpty {
            let baseURL = try resolvedBaseURL(rawValue: environment["PAPRIKA_PANTRY_SOURCE_BASE_URL"])
            return .paprikaToken(
                token: token,
                baseURL: baseURL,
                displayName: "environment",
                credentialSource: "env:\(Self.defaultTokenEnvironmentVariable)"
            )
        }

        guard let source = try configStore.loadConfig()?.source else {
            return .none
        }

        switch source.kind {
        case .paprikaToken:
            let sourceConfig = source.paprikaToken ?? PaprikaTokenSourceConfiguration()
            if let token = sourceConfig.token?.trimmedNonEmpty {
                return .paprikaToken(
                    token: token,
                    baseURL: try resolvedBaseURL(rawValue: sourceConfig.baseURL),
                    displayName: source.displayName,
                    credentialSource: "config:inline"
                )
            }

            let tokenEnvironmentVariable = sourceConfig.tokenEnvironmentVariable?.trimmedNonEmpty
                ?? Self.defaultTokenEnvironmentVariable
            guard let token = environment[tokenEnvironmentVariable]?.trimmedNonEmpty else {
                return .invalid(
                    kind: .paprikaToken,
                    displayName: source.displayName,
                    error: PantrySourceProviderError.missingPaprikaToken
                )
            }

            return .paprikaToken(
                token: token,
                baseURL: try resolvedBaseURL(rawValue: sourceConfig.baseURL),
                displayName: source.displayName,
                credentialSource: "env:\(tokenEnvironmentVariable)"
            )
        case .kappari:
            return .kappari(displayName: source.displayName)
        }
    }

    private func resolvedBaseURL(rawValue: String?) throws -> URL {
        guard let rawValue = rawValue?.trimmedNonEmpty else {
            return PaprikaTokenSource.defaultBaseURL
        }

        guard let baseURL = URL(string: rawValue) else {
            throw PantrySourceProviderError.invalidBaseURL(rawValue)
        }

        return baseURL
    }
}

private enum ResolvedSourceReference {
    case paprikaToken(token: String, baseURL: URL, displayName: String?, credentialSource: String)
    case kappari(displayName: String?)
    case invalid(kind: PantrySourceKind, displayName: String?, error: PantrySourceProviderError)
    case none
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
