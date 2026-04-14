import Foundation

public struct PantryConfigStore: @unchecked Sendable {
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

    public func loadConfig() throws -> PantryConfig? {
        guard fileManager.fileExists(atPath: paths.configFile.path) else {
            return nil
        }

        let data = try Data(contentsOf: paths.configFile)
        return try decoder.decode(PantryConfig.self, from: data)
    }

    public func saveConfig(_ config: PantryConfig) throws {
        try fileManager.createDirectory(
            at: paths.configFile.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let data = try encoder.encode(config)
        try data.write(to: paths.configFile, options: .atomic)
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
