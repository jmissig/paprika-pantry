import Foundation

public struct SourceLastSyncReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let paprikaSync: PaprikaSyncDetails?
    public let paprikaSyncFreshnessSeconds: Int?
    public let paths: PantryPathReport

    public init(snapshot: PantrySourceDoctorSnapshot, paths: PantryPaths, now: Date) {
        self.command = "source last-sync-time"
        self.paprikaSync = snapshot.paprikaSync
        self.paprikaSyncFreshnessSeconds = snapshot.paprikaSync.map {
            max(0, Int(now.timeIntervalSince($0.lastSyncAt)))
        }

        if snapshot.paprikaSync != nil {
            self.status = "ok"
            self.message = "Loaded the last observed Paprika sync completion time from local metadata."
        } else {
            self.status = "unavailable"
            self.message = "No Paprika sync completion time was available in local metadata."
        }

        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
        ]

        lines.append(contentsOf: renderedPaprikaSyncLines(
            sync: paprikaSync,
            prefix: "paprika",
            freshnessSeconds: paprikaSyncFreshnessSeconds
        ))
        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}
