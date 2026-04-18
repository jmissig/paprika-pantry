import Foundation

public struct PaprikaSyncDetails: Codable, Equatable, Sendable {
    public let lastSyncAt: Date
    public let signalSource: String
    public let signalLocation: String

    public init(
        lastSyncAt: Date,
        signalSource: String,
        signalLocation: String
    ) {
        self.lastSyncAt = lastSyncAt
        self.signalSource = signalSource
        self.signalLocation = signalLocation
    }
}

public struct PaprikaAppInstallation: Codable, Equatable, Sendable {
    public let appBundlePath: String
    public let bundleIdentifier: String?
    public let executablePath: String?
    public let executablePresent: Bool
    public let customURLSchemes: [String]

    public init(
        appBundlePath: String,
        bundleIdentifier: String?,
        executablePath: String?,
        executablePresent: Bool,
        customURLSchemes: [String]
    ) {
        self.appBundlePath = appBundlePath
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
        self.executablePresent = executablePresent
        self.customURLSchemes = customURLSchemes
    }
}

public struct PantryStoredSourceState: Codable, Equatable, Sendable {
    public let sourceType: String
    public let sourceLocation: String?
    public let observedAt: Date
    public let paprikaSync: PaprikaSyncDetails?

    public init(
        sourceType: String,
        sourceLocation: String?,
        observedAt: Date,
        paprikaSync: PaprikaSyncDetails?
    ) {
        self.sourceType = sourceType
        self.sourceLocation = sourceLocation
        self.observedAt = observedAt
        self.paprikaSync = paprikaSync
    }
}
