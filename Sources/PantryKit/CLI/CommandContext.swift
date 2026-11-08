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

    public func makeSidecarDatabase() -> PantrySidecarDatabase {
        PantrySidecarDatabase(path: paths.databaseFile)
    }

    public func makeReadStore(source: any PantrySource) throws -> PantrySidecarStore {
        guard let source = source as? any IndexablePantrySource else {
            throw IndexCompatibilityError.invalidRole("Source has no index compatibility contract")
        }
        return PantrySidecarStore(dbQueue: try makeSidecarDatabase().openReadOnlyQueue(), expectedContract: source.indexContract)
    }

    public func diagnosticStats(source: (any PantrySource)? = nil) -> PantryIndexStats {
        do {
            return try PantrySidecarStore(dbQueue: makeSidecarDatabase().openReadOnlyQueue(),
                role: .inspector((source as? any IndexablePantrySource)?.indexContract)).indexStats()
        } catch { return .unavailable(error.localizedDescription) }
    }

    public func makeIndexWriter() throws -> PantrySidecarStore {
        PantrySidecarStore(dbQueue: try makeSidecarDatabase().openQueue(), role: .writer)
    }

    public func makeSourceProvider(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ConfiguredPaprikaSourceProvider {
        ConfiguredPaprikaSourceProvider(paths: paths, environment: environment)
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

public protocol PantryLeafCommand: AsyncParsableCommand {
    var runtimeOptions: RuntimeOptions { get }
}

extension PantryLeafCommand {
    func makeContext() throws -> CommandContext {
        try CommandContext(runtimeOptions: runtimeOptions)
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
