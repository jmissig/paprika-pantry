import Foundation

public struct RemoteRecipeStub: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let hash: String?

    public init(uid: String, name: String, hash: String?) {
        self.uid = uid
        self.name = name
        self.hash = hash
    }
}

public protocol PaprikaRemoteClient: Sendable {
    func listRecipeStubs() async throws -> [RemoteRecipeStub]
}
