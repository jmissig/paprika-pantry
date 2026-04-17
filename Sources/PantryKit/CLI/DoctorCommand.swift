import ArgumentParser
import Foundation

public struct DoctorCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose current source and sidecar index health."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let snapshot = try context.makeSourceProvider().diagnose()
        let stats = try context.makeStore().indexStats()
        try context.write(
            DoctorReport(
                sourceSnapshot: snapshot,
                indexStats: stats,
                paths: context.paths,
                now: Date()
            )
        )
    }
}
