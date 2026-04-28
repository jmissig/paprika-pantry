import ArgumentParser
import Foundation

public enum OutputFormat: String, CaseIterable, Codable, ExpressibleByArgument, Sendable {
    case auto
    case text
    case json
    case csv
}

public enum OutputFormatOptionsError: Error, CustomStringConvertible {
    case conflictingJSONAndFormat(OutputFormat)

    public var description: String {
        switch self {
        case let .conflictingJSONAndFormat(format):
            return "--json conflicts with --format \(format.rawValue); use only one output override"
        }
    }
}

public enum JSONOutputError: Error {
    case invalidUTF8
}

public enum JSONOutput {
    public static func render<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(value)
        guard var string = String(data: data, encoding: .utf8) else {
            throw JSONOutputError.invalidUTF8
        }

        if !string.hasSuffix("\n") {
            string.append("\n")
        }

        return string
    }
}
