import Foundation

public struct SimpleAccountAuthenticator: PantryAuthenticator {
    public let strategy: AuthStrategy = .simpleAccount

    private let remoteClient: any PaprikaAccountRemoteClient
    private let now: @Sendable () -> Date

    public init(
        remoteClient: any PaprikaAccountRemoteClient = PaprikaSimpleAccountRemoteClient(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.remoteClient = remoteClient
        self.now = now
    }

    public func login(emailAddress: String, password: String) async throws -> PantrySession {
        let normalizedEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = try await remoteClient.login(emailAddress: normalizedEmail, password: password)
        return PantrySession(
            emailAddress: normalizedEmail,
            token: token,
            createdAt: now(),
            authStrategy: strategy
        )
    }
}
