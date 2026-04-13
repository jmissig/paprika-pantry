import ArgumentParser
import Foundation

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

    @Option(name: .long, help: "Paprika account email. Falls back to PAPRIKA_EMAIL or an interactive prompt.")
    public var email: String?

    @Option(name: .long, help: "Paprika account password. Falls back to PAPRIKA_PASSWORD or an interactive prompt.")
    public var password: String?

    public init() {}

    public mutating func run() throws {
        let context = try makeContext()
        let store = PantryAuthStore(paths: context.paths)
        let config = try store.loadConfig()
        let credentials = try resolvedCredentials(
            config: config,
            environment: ProcessInfo.processInfo.environment
        )
        let authenticator = SimpleAccountAuthenticator()
        let session = try BlockingAsync.run {
            try await authenticator.login(
                emailAddress: credentials.emailAddress,
                password: credentials.password
            )
        }

        try store.saveConfig(
            PantryConfig(
                authStrategy: authenticator.strategy,
                lastEmailAddress: session.emailAddress,
                updatedAt: session.createdAt
            )
        )
        try store.saveSession(session)

        try context.write(
            AuthLoginReport(
                authStrategy: session.authStrategy,
                emailAddress: session.emailAddress,
                sessionCreatedAt: session.createdAt,
                paths: context.paths.report
            )
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
        let context = try makeContext()
        let store = PantryAuthStore(paths: context.paths)
        let state = try store.loadState()
        try context.write(AuthStatusReport(state: state, paths: context.paths))
    }
}

public struct AuthLogoutCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "logout",
        abstract: "Log out of Paprika."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = PantryAuthStore(paths: context.paths)
        let clearedSession = try store.clearSession()
        try context.write(AuthLogoutReport(clearedSession: clearedSession, paths: context.paths.report))
    }
}

private struct LoginCredentials {
    let emailAddress: String
    let password: String
}

private enum AuthLoginCommandError: Error, LocalizedError {
    case missingEmail
    case missingPassword

    var errorDescription: String? {
        switch self {
        case .missingEmail:
            return "Missing email. Pass --email, set PAPRIKA_EMAIL, or run `auth login` interactively."
        case .missingPassword:
            return "Missing password. Pass --password, set PAPRIKA_PASSWORD, or run `auth login` interactively."
        }
    }
}

private extension AuthLoginCommand {
    func resolvedCredentials(
        config: PantryConfig?,
        environment: [String: String]
    ) throws -> LoginCredentials {
        let interactive = ConsolePrompt.isInteractive()
        let emailAddress = try resolvedEmailAddress(
            config: config,
            environment: environment,
            interactive: interactive
        )
        let password = try resolvedPassword(
            environment: environment,
            interactive: interactive
        )

        return LoginCredentials(emailAddress: emailAddress, password: password)
    }

    func resolvedEmailAddress(
        config: PantryConfig?,
        environment: [String: String],
        interactive: Bool
    ) throws -> String {
        if let explicit = email?.trimmedNonEmpty {
            return explicit
        }

        if let fromEnvironment = environment["PAPRIKA_EMAIL"]?.trimmedNonEmpty {
            return fromEnvironment
        }

        guard interactive else {
            throw AuthLoginCommandError.missingEmail
        }

        return try ConsolePrompt.prompt("Email", defaultValue: config?.lastEmailAddress)
    }

    func resolvedPassword(
        environment: [String: String],
        interactive: Bool
    ) throws -> String {
        if let explicit = password?.trimmedNonEmpty {
            return explicit
        }

        if let fromEnvironment = environment["PAPRIKA_PASSWORD"]?.trimmedNonEmpty {
            return fromEnvironment
        }

        guard interactive else {
            throw AuthLoginCommandError.missingPassword
        }

        return try ConsolePrompt.promptPassword("Password")
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
