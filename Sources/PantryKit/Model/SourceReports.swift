import Foundation

public struct SourceDoctorReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let sourceKind: PantrySourceKind?
    public let displayName: String?
    public let implementation: String?
    public let credentialSource: String?
    public let paths: PantryPathReport

    public init(snapshot: PantrySourceDoctorSnapshot, paths: PantryPaths) {
        self.command = "source doctor"
        self.status = snapshot.status.rawValue
        self.message = snapshot.message
        self.sourceKind = snapshot.sourceKind
        self.displayName = snapshot.displayName
        self.implementation = snapshot.implementation
        self.credentialSource = snapshot.credentialSource
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
        ]

        if let sourceKind {
            lines.append("kind: \(sourceKind.rawValue)")
        }

        if let displayName, !displayName.isEmpty {
            lines.append("display_name: \(displayName)")
        }

        if let implementation, !implementation.isEmpty {
            lines.append("implementation: \(implementation)")
        }

        if let credentialSource, !credentialSource.isEmpty {
            lines.append("credential_source: \(credentialSource)")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}
