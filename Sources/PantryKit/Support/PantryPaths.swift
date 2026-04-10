import Foundation

public enum PantryPathError: Error {
    case missingApplicationSupportDirectory
}

public struct PantryBaseDirectories: Equatable, Sendable {
    public let applicationSupportDirectory: URL

    public init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
    }

    public static func current(fileManager: FileManager = .default) throws -> PantryBaseDirectories {
        guard let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw PantryPathError.missingApplicationSupportDirectory
        }

        return PantryBaseDirectories(applicationSupportDirectory: applicationSupportDirectory)
    }
}

public struct PantryPathOptions: Equatable, Sendable {
    public var homeDirectory: URL?
    public var configFile: URL?
    public var sessionFile: URL?
    public var databaseFile: URL?

    public init(
        homeDirectory: URL? = nil,
        configFile: URL? = nil,
        sessionFile: URL? = nil,
        databaseFile: URL? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.configFile = configFile
        self.sessionFile = sessionFile
        self.databaseFile = databaseFile
    }
}

public struct PantryPathReport: Codable, Equatable, Sendable {
    public let home: String
    public let config: String
    public let session: String
    public let database: String

    public init(home: String, config: String, session: String, database: String) {
        self.home = home
        self.config = config
        self.session = session
        self.database = database
    }
}

public struct PantryPaths: Equatable, Sendable {
    public static let applicationDirectoryName = "paprika-pantry"

    public let homeDirectory: URL
    public let configFile: URL
    public let sessionFile: URL
    public let databaseFile: URL

    public init(homeDirectory: URL, configFile: URL, sessionFile: URL, databaseFile: URL) {
        self.homeDirectory = homeDirectory.standardizedFileURL
        self.configFile = configFile.standardizedFileURL
        self.sessionFile = sessionFile.standardizedFileURL
        self.databaseFile = databaseFile.standardizedFileURL
    }

    public static func resolve(
        options: PantryPathOptions = PantryPathOptions(),
        baseDirectories: PantryBaseDirectories? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> PantryPaths {
        let baseDirectories = try baseDirectories ?? PantryBaseDirectories.current(fileManager: fileManager)
        let effectiveOptions = mergedWithEnvironment(options, environment: environment)

        let homeDirectory = (effectiveOptions.homeDirectory
            ?? baseDirectories.applicationSupportDirectory.appendingPathComponent(applicationDirectoryName, isDirectory: true))
            .standardizedFileURL

        let configFile = (effectiveOptions.configFile
            ?? homeDirectory.appendingPathComponent("config.json"))
            .standardizedFileURL

        let sessionFile = (effectiveOptions.sessionFile
            ?? homeDirectory.appendingPathComponent("session.json"))
            .standardizedFileURL

        let databaseFile = (effectiveOptions.databaseFile
            ?? homeDirectory.appendingPathComponent("pantry.sqlite"))
            .standardizedFileURL

        return PantryPaths(
            homeDirectory: homeDirectory,
            configFile: configFile,
            sessionFile: sessionFile,
            databaseFile: databaseFile
        )
    }

    public var report: PantryPathReport {
        PantryPathReport(
            home: homeDirectory.path,
            config: configFile.path,
            session: sessionFile.path,
            database: databaseFile.path
        )
    }

    private static func mergedWithEnvironment(
        _ options: PantryPathOptions,
        environment: [String: String]
    ) -> PantryPathOptions {
        PantryPathOptions(
            homeDirectory: options.homeDirectory ?? environment["PAPRIKA_PANTRY_HOME"].map(fileURL(from:)),
            configFile: options.configFile ?? environment["PAPRIKA_PANTRY_CONFIG"].map(fileURL(from:)),
            sessionFile: options.sessionFile ?? environment["PAPRIKA_PANTRY_SESSION"].map(fileURL(from:)),
            databaseFile: options.databaseFile ?? environment["PAPRIKA_PANTRY_DATABASE"].map(fileURL(from:))
        )
    }

    private static func fileURL(from rawPath: String) -> URL {
        URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath)
    }
}
