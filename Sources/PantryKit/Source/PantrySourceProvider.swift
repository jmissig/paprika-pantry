import Foundation

public enum PantrySourceKind: String, Codable, Equatable, Sendable {
    case paprikaSQLite = "paprika-sqlite"
    case paprikaToken = "paprika-token"
    case kappari

    var isLegacyUnsupported: Bool {
        self != .paprikaSQLite
    }
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

public struct PantrySourceConfiguration: Codable, Equatable, Sendable {
    public let kind: PantrySourceKind
    public let displayName: String?
    public let paprikaSQLite: PaprikaSQLiteSourceConfiguration?

    public init(
        kind: PantrySourceKind,
        displayName: String? = nil,
        paprikaSQLite: PaprikaSQLiteSourceConfiguration? = nil
    ) {
        self.kind = kind
        self.displayName = displayName
        self.paprikaSQLite = paprikaSQLite
    }
}

public enum PantrySourceProviderError: Error, LocalizedError, Equatable {
    case notConfigured
    case missingPaprikaSQLiteDatabase
    case paprikaSQLiteDatabaseNotFound(String)
    case invalidPaprikaSQLiteDatabase(String)
    case unsupportedSource(PantrySourceKind)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No pantry source is configured. Set PAPRIKA_PANTRY_SOURCE_PAPRIKA_DB, add a local paprika-sqlite source block to config.json, or install Paprika in its default path."
        case .missingPaprikaSQLiteDatabase:
            return "The paprika-sqlite source needs a Paprika.sqlite path. Configure source.paprikaSQLite.databasePath, set PAPRIKA_PANTRY_SOURCE_PAPRIKA_DB, or install Paprika in its default path."
        case .paprikaSQLiteDatabaseNotFound(let rawValue):
            return "The configured Paprika.sqlite database was not found: \(rawValue)"
        case .invalidPaprikaSQLiteDatabase(let message):
            return "The configured Paprika.sqlite database is not readable: \(message)"
        case .unsupportedSource(let kind):
            return "The legacy \(kind.rawValue) source is no longer supported. Use the local Paprika SQLite database instead."
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
    public let sourceLocation: String?
    public let schemaFlavor: String?
    public let accessMode: String?
    public let queryOnly: Bool?
    public let journalMode: String?
    public let hasWriteAheadLogFiles: Bool?
    public let paprikaSync: PaprikaSyncDetails?
    public let appInstallation: PaprikaAppInstallation?

    public init(
        status: PantrySourceDoctorStatus,
        message: String,
        sourceKind: PantrySourceKind?,
        displayName: String?,
        implementation: String?,
        sourceLocation: String?,
        schemaFlavor: String? = nil,
        accessMode: String? = nil,
        queryOnly: Bool? = nil,
        journalMode: String? = nil,
        hasWriteAheadLogFiles: Bool? = nil,
        paprikaSync: PaprikaSyncDetails? = nil,
        appInstallation: PaprikaAppInstallation? = nil
    ) {
        self.status = status
        self.message = message
        self.sourceKind = sourceKind
        self.displayName = displayName
        self.implementation = implementation
        self.sourceLocation = sourceLocation
        self.schemaFlavor = schemaFlavor
        self.accessMode = accessMode
        self.queryOnly = queryOnly
        self.journalMode = journalMode
        self.hasWriteAheadLogFiles = hasWriteAheadLogFiles
        self.paprikaSync = paprikaSync
        self.appInstallation = appInstallation
    }
}

public protocol PantrySourceProvider: Sendable {
    func makeSource() throws -> any PantrySource
    func diagnose() throws -> PantrySourceDoctorSnapshot
}

public struct ConfiguredPantrySourceProvider: PantrySourceProvider, @unchecked Sendable {
    public static let defaultPaprikaSQLiteEnvironmentVariable = "PAPRIKA_PANTRY_SOURCE_PAPRIKA_DB"

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
        case .unsupported(let kind, _):
            throw PantrySourceProviderError.unsupportedSource(kind)
        case .invalid(_, _, let error):
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
                    sourceLocation: databaseURL.path,
                    schemaFlavor: source.inspection.schemaFlavor,
                    accessMode: source.inspection.accessMode,
                    queryOnly: source.inspection.queryOnly,
                    journalMode: source.inspection.journalMode,
                    hasWriteAheadLogFiles: source.inspection.hasWriteAheadLogFiles,
                    paprikaSync: source.inspection.paprikaSync,
                    appInstallation: source.inspection.appInstallation
                )
            } catch let error as PaprikaSQLiteSourceError {
                return PantrySourceDoctorSnapshot(
                    status: .invalid,
                    message: PantrySourceProviderError.invalidPaprikaSQLiteDatabase(error.localizedDescription).localizedDescription,
                    sourceKind: .paprikaSQLite,
                    displayName: displayName,
                    implementation: "direct Paprika SQLite source",
                    sourceLocation: databaseURL.path
                )
            }
        case .unsupported(let kind, let displayName):
            return PantrySourceDoctorSnapshot(
                status: .unsupported,
                message: PantrySourceProviderError.unsupportedSource(kind).localizedDescription,
                sourceKind: kind,
                displayName: displayName,
                implementation: "legacy source configuration",
                sourceLocation: nil
            )
        case .none:
            return PantrySourceDoctorSnapshot(
                status: .notConfigured,
                message: "No pantry source is configured.",
                sourceKind: nil,
                displayName: nil,
                implementation: nil,
                sourceLocation: nil
            )
        case .invalid(let kind, let displayName, let error):
            return PantrySourceDoctorSnapshot(
                status: .invalid,
                message: error.localizedDescription,
                sourceKind: kind,
                displayName: displayName,
                implementation: implementationDescription(for: kind),
                sourceLocation: nil
            )
        }
    }

    private func resolvedSourceReference() throws -> ResolvedSourceReference {
        if let databasePath = environment[Self.defaultPaprikaSQLiteEnvironmentVariable]?.trimmedNonEmpty {
            let databaseURL = resolvedFileURL(rawPath: databasePath)
            return validatedPaprikaSQLiteReference(
                databaseURL: databaseURL,
                displayName: "environment"
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

        guard !source.kind.isLegacyUnsupported else {
            return .unsupported(kind: source.kind, displayName: source.displayName)
        }

        let sourceConfig = source.paprikaSQLite ?? PaprikaSQLiteSourceConfiguration()
        if let databasePath = sourceConfig.databasePath?.trimmedNonEmpty {
            return validatedPaprikaSQLiteReference(
                databaseURL: resolvedFileURL(rawPath: databasePath),
                displayName: source.displayName
            )
        }

        let pathEnvironmentVariable = sourceConfig.databasePathEnvironmentVariable?.trimmedNonEmpty
            ?? Self.defaultPaprikaSQLiteEnvironmentVariable
        if let databasePath = environment[pathEnvironmentVariable]?.trimmedNonEmpty {
            return validatedPaprikaSQLiteReference(
                databaseURL: resolvedFileURL(rawPath: databasePath),
                displayName: source.displayName
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
            error: PantrySourceProviderError.missingPaprikaSQLiteDatabase
        )
    }

    private func validatedPaprikaSQLiteReference(
        databaseURL: URL,
        displayName: String?
    ) -> ResolvedSourceReference {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return .invalid(
                kind: .paprikaSQLite,
                displayName: displayName,
                error: PantrySourceProviderError.paprikaSQLiteDatabaseNotFound(databaseURL.path)
            )
        }

        return .paprikaSQLite(
            databaseURL: databaseURL,
            displayName: displayName,
            locationSource: "configured"
        )
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
        case .paprikaToken, .kappari:
            return "legacy source configuration"
        }
    }
}

private enum ResolvedSourceReference {
    case paprikaSQLite(databaseURL: URL, displayName: String?, locationSource: String)
    case unsupported(kind: PantrySourceKind, displayName: String?)
    case invalid(kind: PantrySourceKind, displayName: String?, error: PantrySourceProviderError)
    case none
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
