import Foundation

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
        }
    }
}
