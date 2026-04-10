import Darwin
import Foundation

public enum ConsolePromptError: Error, LocalizedError {
    case emptyValue(String)
    case inputClosed(String)
    case passwordReadFailed

    public var errorDescription: String? {
        switch self {
        case .emptyValue(let field):
            return "\(field) is required."
        case .inputClosed(let field):
            return "Could not read \(field) from standard input."
        case .passwordReadFailed:
            return "Could not read the password from the terminal."
        }
    }
}

public enum ConsolePrompt {
    public static func isInteractive() -> Bool {
        isatty(STDIN_FILENO) != 0 && isatty(STDERR_FILENO) != 0
    }

    public static func prompt(_ label: String, defaultValue: String? = nil) throws -> String {
        let suffix = defaultValue.map { " [\($0)]" } ?? ""
        writePrompt("\(label)\(suffix): ")

        guard let line = readLine(strippingNewline: true) else {
            throw ConsolePromptError.inputClosed(label.lowercased())
        }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, let defaultValue {
            return defaultValue
        }

        guard !trimmed.isEmpty else {
            throw ConsolePromptError.emptyValue(label)
        }

        return trimmed
    }

    public static func promptPassword(_ label: String) throws -> String {
        var buffer = [CChar](repeating: 0, count: 512)
        let prompt = "\(label): "

        guard readpassphrase(prompt, &buffer, buffer.count, 0) != nil else {
            throw ConsolePromptError.passwordReadFailed
        }

        let length = buffer.firstIndex(of: 0) ?? buffer.count
        let bytes = buffer.prefix(length).map { UInt8(bitPattern: $0) }
        let password = String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        buffer.withUnsafeMutableBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else {
                return
            }

            memset(baseAddress, 0, pointer.count)
        }

        guard !password.isEmpty else {
            throw ConsolePromptError.emptyValue(label)
        }

        return password
    }

    private static func writePrompt(_ prompt: String) {
        guard let data = prompt.data(using: .utf8) else {
            return
        }

        FileHandle.standardError.write(data)
    }
}
