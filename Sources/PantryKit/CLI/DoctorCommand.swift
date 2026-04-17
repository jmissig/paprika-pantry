import ArgumentParser

public struct DoctorCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose local pantry state."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "doctor",
            plannedPhase: "Later",
            message: "Broader doctor output is still deferred; use `source doctor` for direct Paprika source readiness today."
        )
    }
}
