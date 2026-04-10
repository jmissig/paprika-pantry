import Foundation

public struct PantryAuthState: Equatable, Sendable {
    public let config: PantryConfig?
    public let session: PantrySession?

    public init(config: PantryConfig?, session: PantrySession?) {
        self.config = config
        self.session = session
    }

    public var isAuthenticated: Bool {
        session != nil
    }
}

public struct PantryAuthStore {
    public let paths: PantryPaths

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(paths: PantryPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
    }

    public func loadState() throws -> PantryAuthState {
        PantryAuthState(
            config: try loadConfig(),
            session: try loadSession()
        )
    }

    public func loadConfig() throws -> PantryConfig? {
        try load(PantryConfig.self, from: paths.configFile)
    }

    public func saveConfig(_ config: PantryConfig) throws {
        try save(config, to: paths.configFile)
    }

    public func loadSession() throws -> PantrySession? {
        try load(PantrySession.self, from: paths.sessionFile)
    }

    public func saveSession(_ session: PantrySession) throws {
        try save(session, to: paths.sessionFile)
    }

    @discardableResult
    public func clearSession() throws -> Bool {
        try clearFile(at: paths.sessionFile)
    }

    private func load<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    private func save<Value: Encodable>(_ value: Value, to url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func clearFile(at url: URL) throws -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }

        try fileManager.removeItem(at: url)
        return true
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
