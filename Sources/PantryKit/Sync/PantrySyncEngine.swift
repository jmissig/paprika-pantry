import Foundation

public struct SyncSummary: Codable, Equatable, Sendable {
    public let startedAt: Date
    public let finishedAt: Date?
    public let changedRecipeCount: Int

    public init(startedAt: Date, finishedAt: Date? = nil, changedRecipeCount: Int) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.changedRecipeCount = changedRecipeCount
    }
}

public protocol PantrySyncEngine: Sendable {
    func run() async throws -> SyncSummary
}
