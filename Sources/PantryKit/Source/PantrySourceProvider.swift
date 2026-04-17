import Foundation

public enum PantrySourceKind: String, Codable, Equatable, Sendable {
    case paprikaSQLite = "paprika-sqlite"
    case paprikaToken = "paprika-token"
    case kappari
}

public struct PaprikaSQLiteSourceConfiguration: Codable, Equatable, Sendable {
    public let databasePath: String?
    public let databasePathEnvironmentVariable: String?

    public init(
        databasePath: String? = nil,
        databasePathEnvironmentVariable: String? = nil
    ) {
        self.databasePath = databasePath
        self.databasePathEnvironmentVariable = databasePathEnvironmentVariable
    }
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
    public let paprikaSQLite: PaprikaSQLiteSourceConfiguration?
    public let paprikaToken: PaprikaTokenSourceConfiguration?
    public let kappari: KappariSourceConfiguration?

    public init(
        kind: PantrySourceKind,
        displayName: String? = nil,
        paprikaSQLite: PaprikaSQLiteSourceConfiguration? = nil,
        paprikaToken: PaprikaTokenSourceConfiguration? = nil,
        kappari: KappariSourceConfiguration? = nil
    ) {
        self.kind = kind
        self.displayName = displayName
        self.paprikaSQLite = paprikaSQLite
        self.paprikaToken = paprikaToken
        self.kappari = kappari
    }
}

public enum PantrySourceProviderError: Error, LocalizedError, Equatable {
    case notConfigured
    case missingPaprikaSQLiteDatabase
    case paprikaSQLiteDatabaseNotFound(String)
    case invalidPaprikaSQLiteDatabase(String)
    case missingPaprikaToken
    case invalidBaseURL(String)
    case unsupportedSource(PantrySourceKind)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No pantry source is configured. Add a source block to config.json, set PAPRIKA_PANTRY_SOURCE_PAPRIKA_DB, or set PAPRIKA_PANTRY_SOURCE_TOKEN."
        case .missingPaprikaSQLiteDatabase:
            return "The paprika-sqlite source needs a Paprika.sqlite path. Configure source.paprikaSQLite.databasePath, set PAPRIKA_PANTRY_SOURCE_PAPRIKA_DB, or install Paprika in its default path."
        case .paprikaSQLiteDatabaseNotFound(let rawValue):
            return "The configured Paprika.sqlite database was not found: \(rawValue)"
        case .invalidPaprikaSQLiteDatabase(let message):
            return "The configured Paprika.sqlite database is not readable: \(message)"
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
    public let sourceLocation: String?
    public let schemaFlavor: String?
    public let accessMode: String?
    public let queryOnly: Bool?
    public let journalMode: String?
    public let hasWriteAheadLogFiles: Bool?

    public init(
        status: PantrySourceDoctorStatus,
        message: String,
        sourceKind: PantrySourceKind?,
        displayName: String?,
        implementation: String?,
        credentialSource: String?,
        sourceLocation: String?,
        schemaFlavor: String? = nil,
        accessMode: String? = nil,
        queryOnly: Bool? = nil,
        journalMode: String? = nil,
        hasWriteAheadLogFiles: Bool? = nil
    ) {
        self.status = status
        self.message = message
        self.sourceKind = sourceKind
        self.displayName = displayName
        self.implementation = implementation
        self.credentialSource = credentialSource
        self.sourceLocation = sourceLocation
        self.schemaFlavor = schemaFlavor
        self.accessMode = accessMode
        self.queryOnly = queryOnly
        self.journalMode = journalMode
        self.hasWriteAheadLogFiles = hasWriteAheadLogFiles
    }
}

public protocol PantrySourceProvider: Sendable {
    func makeSource() throws -> any PantrySource
    func diagnose() throws -> PantrySourceDoctorSnapshot
}

public struct ConfiguredPantrySourceProvider: PantrySourceProvider, @unchecked Sendable {
    public static let defaultPaprikaSQLiteEnvironmentVariable = "PAPRIKA_PANTRY_SOURCE_PAPRIKA_DB"
    public static let defaultTokenEnvironmentVariable = "PAPRIKA_PANTRY_SOURCE_TOKEN"

    private let configStore: PantryConfigStore
    private let environment: [String: String]
    private let fileManager: FileManager

    public init(
        paths: PantryPaths,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.configStore = PantryConfigStore(paths: paths)
        self.environment = environment
        self.fileManager = fileManager
    }

    public func makeSource() throws -> any PantrySource {
        switch try resolvedSourceReference() {
        case .paprikaSQLite(let databaseURL, _, _):
            do {
                return try PaprikaSQLiteSource(databaseURL: databaseURL, fileManager: fileManager)
            } catch let error as PaprikaSQLiteSourceError {
                throw PantrySourceProviderError.invalidPaprikaSQLiteDatabase(error.localizedDescription)
            }
        case .paprikaToken(let token, let baseURL, _, _):
            return PaprikaTokenSource(token: token, baseURL: baseURL)
        case .kappari:
            throw PantrySourceProviderError.unsupportedSource(.kappari)
        case .invalid(_, _, _, let error):
            throw error
        case .none:
            throw PantrySourceProviderError.notConfigured
        }
    }

    public func diagnose() throws -> PantrySourceDoctorSnapshot {
        switch try resolvedSourceReference() {
        case .paprikaSQLite(let databaseURL, let displayName, _):
            do {
                let source = try PaprikaSQLiteSource(databaseURL: databaseURL, fileManager: fileManager)
                return PantrySourceDoctorSnapshot(
                    status: .ready,
                    message: "The configured pantry source is ready for direct read-only Paprika access.",
                    sourceKind: .paprikaSQLite,
                    displayName: displayName,
                    implementation: "direct Paprika SQLite source",
                    credentialSource: nil,
                    sourceLocation: databaseURL.path,
                    schemaFlavor: source.inspection.schemaFlavor,
                    accessMode: source.inspection.accessMode,
                    queryOnly: source.inspection.queryOnly,
                    journalMode: source.inspection.journalMode,
                    hasWriteAheadLogFiles: source.inspection.hasWriteAheadLogFiles
                )
            } catch let error as PaprikaSQLiteSourceError {
                return PantrySourceDoctorSnapshot(
                    status: .invalid,
                    message: PantrySourceProviderError.invalidPaprikaSQLiteDatabase(error.localizedDescription).localizedDescription,
                    sourceKind: .paprikaSQLite,
                    displayName: displayName,
                    implementation: "direct Paprika SQLite source",
                    credentialSource: nil,
                    sourceLocation: databaseURL.path
                )
            }
        case .paprikaToken(_, _, let displayName, let credentialSource):
            return PantrySourceDoctorSnapshot(
                status: .ready,
                message: "The configured pantry source is ready.",
                sourceKind: .paprikaToken,
                displayName: displayName,
                implementation: "direct Paprika token source",
                credentialSource: credentialSource,
                sourceLocation: nil
            )
        case .kappari(let displayName):
            return PantrySourceDoctorSnapshot(
                status: .unsupported,
                message: "A kappari source is configured, but this build does not wire it yet.",
                sourceKind: .kappari,
                displayName: displayName,
                implementation: "planned kappari-backed source",
                credentialSource: nil,
                sourceLocation: nil
            )
        case .none:
            return PantrySourceDoctorSnapshot(
                status: .notConfigured,
                message: "No pantry source is configured.",
                sourceKind: nil,
                displayName: nil,
                implementation: nil,
                credentialSource: nil,
                sourceLocation: nil
            )
        case .invalid(let kind, let displayName, let sourceLocation, let error):
            return PantrySourceDoctorSnapshot(
                status: kind == .kappari ? .unsupported : .invalid,
                message: error.localizedDescription,
                sourceKind: kind,
                displayName: displayName,
                implementation: implementationDescription(for: kind),
                credentialSource: nil,
                sourceLocation: sourceLocation
            )
        }
    }

    private func resolvedSourceReference() throws -> ResolvedSourceReference {
        if let databasePath = environment[Self.defaultPaprikaSQLiteEnvironmentVariable]?.trimmedNonEmpty {
            let databaseURL = resolvedFileURL(rawPath: databasePath)
            return validatedPaprikaSQLiteReference(
                databaseURL: databaseURL,
                displayName: "environment",
                locationSource: "env:\(Self.defaultPaprikaSQLiteEnvironmentVariable)"
            )
        }

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
            if let databaseURL = Self.defaultPaprikaSQLiteURL(fileManager: fileManager) {
                return .paprikaSQLite(
                    databaseURL: databaseURL,
                    displayName: "default Paprika SQLite",
                    locationSource: "default"
                )
            }
            return .none
        }

        switch source.kind {
        case .paprikaSQLite:
            let sourceConfig = source.paprikaSQLite ?? PaprikaSQLiteSourceConfiguration()
            if let databasePath = sourceConfig.databasePath?.trimmedNonEmpty {
                return validatedPaprikaSQLiteReference(
                    databaseURL: resolvedFileURL(rawPath: databasePath),
                    displayName: source.displayName,
                    locationSource: "config:path"
                )
            }

            let pathEnvironmentVariable = sourceConfig.databasePathEnvironmentVariable?.trimmedNonEmpty
                ?? Self.defaultPaprikaSQLiteEnvironmentVariable
            if let databasePath = environment[pathEnvironmentVariable]?.trimmedNonEmpty {
                return validatedPaprikaSQLiteReference(
                    databaseURL: resolvedFileURL(rawPath: databasePath),
                    displayName: source.displayName,
                    locationSource: "env:\(pathEnvironmentVariable)"
                )
            }

            if let databaseURL = Self.defaultPaprikaSQLiteURL(fileManager: fileManager) {
                return .paprikaSQLite(
                    databaseURL: databaseURL,
                    displayName: source.displayName,
                    locationSource: "default"
                )
            }

            return .invalid(
                kind: .paprikaSQLite,
                displayName: source.displayName,
                sourceLocation: nil,
                error: PantrySourceProviderError.missingPaprikaSQLiteDatabase
            )
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
                    sourceLocation: nil,
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

    private func validatedPaprikaSQLiteReference(
        databaseURL: URL,
        displayName: String?,
        locationSource: String
    ) -> ResolvedSourceReference {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return .invalid(
                kind: .paprikaSQLite,
                displayName: displayName,
                sourceLocation: databaseURL.path,
                error: PantrySourceProviderError.paprikaSQLiteDatabaseNotFound(databaseURL.path)
            )
        }

        return .paprikaSQLite(
            databaseURL: databaseURL,
            displayName: displayName,
            locationSource: locationSource
        )
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

    private func resolvedFileURL(rawPath: String) -> URL {
        URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath).standardizedFileURL
    }

    private static func defaultPaprikaSQLiteURL(fileManager: FileManager) -> URL? {
        let candidatePaths = [
            "Library/Group Containers/72KVKW69K8.com.hindsightlabs.paprika.mac.v3/Data/Database/Paprika.sqlite",
            "Library/Application Support/Paprika Recipe Manager 3/Paprika.sqlite",
        ]

        for relativePath in candidatePaths {
            let databaseURL = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(relativePath)
                .standardizedFileURL
            if fileManager.fileExists(atPath: databaseURL.path) {
                return databaseURL
            }
        }

        return nil
    }

    private func implementationDescription(for kind: PantrySourceKind) -> String {
        switch kind {
        case .paprikaSQLite:
            return "direct Paprika SQLite source"
        case .paprikaToken:
            return "direct Paprika token source"
        case .kappari:
            return "planned kappari-backed source"
        }
    }
}

private enum ResolvedSourceReference {
    case paprikaSQLite(databaseURL: URL, displayName: String?, locationSource: String)
    case paprikaToken(token: String, baseURL: URL, displayName: String?, credentialSource: String)
    case kappari(displayName: String?)
    case invalid(kind: PantrySourceKind, displayName: String?, sourceLocation: String?, error: PantrySourceProviderError)
    case none
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
