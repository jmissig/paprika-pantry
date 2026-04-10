import Foundation

public struct CommandReport: Codable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let plannedPhase: String
    public let message: String
    public let details: [String: String]
    public let paths: PantryPathReport

    public init(
        command: String,
        status: String,
        plannedPhase: String,
        message: String,
        details: [String: String],
        paths: PantryPathReport
    ) {
        self.command = command
        self.status = status
        self.plannedPhase = plannedPhase
        self.message = message
        self.details = details
        self.paths = paths
    }
}

extension CommandReport {
    public static func stub(
        command: String,
        plannedPhase: String,
        message: String,
        details: [String: String],
        paths: PantryPaths
    ) -> CommandReport {
        CommandReport(
            command: command,
            status: "stub",
            plannedPhase: plannedPhase,
            message: message,
            details: details,
            paths: paths.report
        )
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "planned: \(plannedPhase)",
        ]

        for key in details.keys.sorted() {
            if let value = details[key] {
                lines.append("\(key): \(value)")
            }
        }

        lines.append("home: \(paths.home)")
        lines.append("config: \(paths.config)")
        lines.append("session: \(paths.session)")
        lines.append("database: \(paths.database)")
        return lines.joined(separator: "\n")
    }
}
