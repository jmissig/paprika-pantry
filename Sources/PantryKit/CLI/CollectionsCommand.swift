import Foundation
import ArgumentParser

public struct RecipesCollectionsCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(commandName: "collections", abstract: "List source recipe collections (distinct from publication/source rollups).")
    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        guard let source = try context.makeSource() as? PaprikaSQLiteSource else {
            throw ValidationError("Collections are unavailable for this source.")
        }
        try context.write(CollectionsReport(collections: try source.listCollections()))
    }
}
