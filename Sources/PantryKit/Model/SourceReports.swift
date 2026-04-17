import Foundation

public struct SourceDoctorReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let sourceKind: PantrySourceKind?
    public let displayName: String?
    public let implementation: String?
    public let credentialSource: String?
    public let sourceLocation: String?
    public let schemaFlavor: String?
    public let accessMode: String?
    public let queryOnly: Bool?
    public let journalMode: String?
    public let hasWriteAheadLogFiles: Bool?
    public let paths: PantryPathReport

    public init(snapshot: PantrySourceDoctorSnapshot, paths: PantryPaths) {
        self.command = "source doctor"
        self.status = snapshot.status.rawValue
        self.message = snapshot.message
        self.sourceKind = snapshot.sourceKind
        self.displayName = snapshot.displayName
        self.implementation = snapshot.implementation
        self.credentialSource = snapshot.credentialSource
        self.sourceLocation = snapshot.sourceLocation
        self.schemaFlavor = snapshot.schemaFlavor
        self.accessMode = snapshot.accessMode
        self.queryOnly = snapshot.queryOnly
        self.journalMode = snapshot.journalMode
        self.hasWriteAheadLogFiles = snapshot.hasWriteAheadLogFiles
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

        if let sourceLocation, !sourceLocation.isEmpty {
            lines.append("source_location: \(sourceLocation)")
        }

        if let schemaFlavor, !schemaFlavor.isEmpty {
            lines.append("schema: \(schemaFlavor)")
        }

        if let accessMode, !accessMode.isEmpty {
            lines.append("access_mode: \(accessMode)")
        }

        if let queryOnly {
            lines.append("query_only: \(queryOnly ? "yes" : "no")")
        }

        if let journalMode, !journalMode.isEmpty {
            lines.append("journal_mode: \(journalMode)")
        }

        if let hasWriteAheadLogFiles {
            lines.append("wal_files: \(hasWriteAheadLogFiles ? "present" : "absent")")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}
