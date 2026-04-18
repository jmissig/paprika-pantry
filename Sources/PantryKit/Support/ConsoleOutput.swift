import Foundation

public enum ConsoleOutputError: Error, CustomStringConvertible {
    case unsupportedFormat(command: String, format: OutputFormat)

    public var description: String {
        switch self {
        case let .unsupportedFormat(command, format):
            return "`\(command)` does not support --format \(format.rawValue) yet. Use --format human or --format json."
        }
    }
}

public enum ConsoleOutput {
    public static func write<Value: Encodable>(
        _ value: Value,
        format: OutputFormat,
        human: (Value) -> String
    ) throws {
        switch format {
        case .human:
            print(human(value))
        case .json:
            let rendered = try JSONOutput.render(value)
            if let data = rendered.data(using: .utf8) {
                FileHandle.standardOutput.write(data)
            }
        case .csv:
            guard
                let renderable = value as? any CSVRenderable
            else {
                let command = (value as? any ConsoleRenderable)?.command ?? String(describing: Value.self)
                throw ConsoleOutputError.unsupportedFormat(command: command, format: format)
            }

            let rendered = renderable.csvDescription
            if let data = rendered.data(using: .utf8) {
                FileHandle.standardOutput.write(data)
            }
        }
    }
}
