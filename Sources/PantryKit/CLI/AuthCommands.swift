import ArgumentParser

public struct AuthCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Manage Paprika authentication state.",
        subcommands: [
            AuthLoginCommand.self,
            AuthStatusCommand.self,
            AuthLogoutCommand.self,
        ]
    )

    public init() {}
}

public struct AuthLoginCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Log in to Paprika."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "auth login",
            plannedPhase: "Phase 2",
            message: "Simple account login is reserved for the first real sync slice."
        )
    }
}

public struct AuthStatusCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show local authentication status."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "auth status",
            plannedPhase: "Phase 2",
            message: "Authentication status needs real session storage and has not been implemented yet."
        )
    }
}

public struct AuthLogoutCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "logout",
        abstract: "Log out of Paprika."
    )

    public init() {}
    public mutating func run() throws {
        try emitStub(
            command: "auth logout",
            plannedPhase: "Phase 2",
            message: "Logout is reserved until session storage exists."
        )
    }
}
