import ArgumentParser
import Foundation

public struct RuntimeOptions: ParsableArguments, Sendable {
    @Flag(name: .long, help: "Emit structured JSON output.")
    public var json = false

    @Option(name: .long, help: "Override the managed pantry home directory.")
    public var home: String?

    @Option(name: .long, help: "Override the config file path.")
    public var config: String?

    @Option(name: .customLong("db-path"), help: "Override the SQLite database path.")
    public var database: String?

    public init() {}
}

public enum RuntimeConfiguration {
    nonisolated(unsafe) private static var currentOptions = RuntimeOptions()

    public static var current: RuntimeOptions {
        currentOptions
    }

    public static func setCurrent(_ options: RuntimeOptions) {
        currentOptions = options
    }
}

extension RuntimeOptions {
    var outputFormat: OutputFormat {
        json ? .json : .human
    }

    var pathOptions: PantryPathOptions {
        PantryPathOptions(
            homeDirectory: home.map(Self.fileURL(from:)),
            configFile: config.map(Self.fileURL(from:)),
            databaseFile: database.map(Self.fileURL(from:))
        )
    }

    private static func fileURL(from rawPath: String) -> URL {
        URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath)
    }
}
