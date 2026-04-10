import ArgumentParser
import Foundation

public struct CommandContext: Sendable {
    public let paths: PantryPaths
    public let outputFormat: OutputFormat

    public init(runtimeOptions: RuntimeOptions) throws {
        self.paths = try PantryPaths.resolve(options: runtimeOptions.pathOptions)
        self.outputFormat = runtimeOptions.outputFormat
    }

    public func write(_ report: CommandReport) throws {
        try ConsoleOutput.write(report, format: outputFormat) { value in
            value.humanDescription
        }
    }
}

public protocol PantryLeafCommand: ParsableCommand {}

extension PantryLeafCommand {
    func makeContext() throws -> CommandContext {
        try CommandContext(runtimeOptions: RuntimeConfiguration.current)
    }

    func emitStub(
        command: String,
        plannedPhase: String,
        message: String,
        details: [String: String] = [:]
    ) throws {
        let context = try makeContext()
        let report = CommandReport.stub(
            command: command,
            plannedPhase: plannedPhase,
            message: message,
            details: details,
            paths: context.paths
        )
        try context.write(report)
    }
}
