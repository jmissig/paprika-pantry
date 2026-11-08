import Foundation

public struct CollectionsReport: ConsoleRenderable, CSVRenderable, Equatable, Sendable {
    public let command = "recipes collections"
    public let collections: [SourceCollection]
    public var humanDescription: String {
        (["\(command): \(collections.count) collections"] + collections.map {
            "\($0.name) [\($0.uid)] default=\($0.isDefault)"
        }).joined(separator: "\n")
    }
    public var csvHeaders: [String] { ["uid", "name", "is_default"] }
    public var csvRows: [[String]] { collections.map { [$0.uid, $0.name, String($0.isDefault)] } }
}
