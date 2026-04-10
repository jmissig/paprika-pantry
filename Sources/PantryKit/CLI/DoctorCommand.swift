import ArgumentParser

public struct DoctorCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose local cache health."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "doctor",
            plannedPhase: "Later",
            message: "Doctor is intentionally deferred until sync and freshness signals exist."
        )
    }
}
