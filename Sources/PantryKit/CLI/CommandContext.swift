import ArgumentParser
import Foundation

public struct CommandContext: Sendable {
    public let paths: PantryPaths
    public let outputFormat: OutputFormat

    public init(runtimeOptions: RuntimeOptions) throws {
        self.paths = try PantryPaths.resolve(options: runtimeOptions.pathOptions)
        self.outputFormat = try runtimeOptions.resolvedOutputFormat()
    }

    public func write<Value: ConsoleRenderable>(_ report: Value) throws {
        try ConsoleOutput.write(report, format: outputFormat) { value in
            value.humanDescription
        }
    }

    public func makeDatabase() -> PantryDatabase {
        PantryDatabase(path: paths.databaseFile)
    }

    public func makeStore() throws -> PantryStore {
        PantryStore(dbQueue: try makeDatabase().openQueue())
    }

    public func makeSourceProvider(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ConfiguredPantrySourceProvider {
        ConfiguredPantrySourceProvider(paths: paths, environment: environment)
    }

    public func makeSource(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> any PantrySource {
        try makeSourceProvider(environment: environment).makeSource()
    }

    public func makeRecipeReadService(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> RecipeReadService {
        RecipeReadService(source: try makeSource(environment: environment))
    }

    public func makeSourceStatsService(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> SourceStatsService {
        SourceStatsService(source: try makeSource(environment: environment))
    }

    public func makeMealReadService(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> MealReadService {
        try MealReadService(source: makeSource(environment: environment))
    }

    public func makeGroceryReadService(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> GroceryReadService {
        try GroceryReadService(source: makeSource(environment: environment))
    }

    public func makePantryItemReadService(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> PantryItemReadService {
        try PantryItemReadService(source: makeSource(environment: environment))
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
