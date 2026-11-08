import ArgumentParser
import Foundation

public struct DoctorCommand: PantryLeafCommand {
    @OptionGroup public var runtimeOptions: RuntimeOptions
    public static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose current source and sidecar index health."
    )

    public init() {}
    public mutating func run() async throws {
        let context = try makeContext()
        let snapshot = try context.makeSourceProvider().diagnose()
        let source = snapshot.status == .ready ? try context.makeSource() : nil
        let stats = context.diagnosticStats(source: source)
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
