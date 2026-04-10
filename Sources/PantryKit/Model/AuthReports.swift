import Foundation

public struct AuthLoginReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let authStrategy: AuthStrategy
    public let emailAddress: String
    public let sessionCreatedAt: Date
    public let paths: PantryPathReport

    public init(
        command: String = "auth login",
        status: String = "authenticated",
        message: String = "Saved a local Paprika session.",
        authStrategy: AuthStrategy,
        emailAddress: String,
        sessionCreatedAt: Date,
        paths: PantryPathReport
    ) {
        self.command = command
        self.status = status
        self.message = message
        self.authStrategy = authStrategy
        self.emailAddress = emailAddress
        self.sessionCreatedAt = sessionCreatedAt
        self.paths = paths
    }

    public var humanDescription: String {
        [
            "\(command): \(message)",
            "status: \(status)",
            "strategy: \(authStrategy.rawValue)",
            "email: \(emailAddress)",
            "session_created_at: \(renderedTimestamp(sessionCreatedAt))",
            renderedPaths(paths),
        ].joined(separator: "\n")
    }
}

public struct AuthStatusReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let isAuthenticated: Bool
    public let hasConfig: Bool
    public let hasSession: Bool
    public let configuredAuthStrategy: AuthStrategy?
    public let configuredEmailAddress: String?
    public let sessionAuthStrategy: AuthStrategy?
    public let sessionEmailAddress: String?
    public let sessionCreatedAt: Date?
    public let paths: PantryPathReport

    public init(
        command: String = "auth status",
        status: String,
        message: String,
        isAuthenticated: Bool,
        hasConfig: Bool,
        hasSession: Bool,
        configuredAuthStrategy: AuthStrategy?,
        configuredEmailAddress: String?,
        sessionAuthStrategy: AuthStrategy?,
        sessionEmailAddress: String?,
        sessionCreatedAt: Date?,
        paths: PantryPathReport
    ) {
        self.command = command
        self.status = status
        self.message = message
        self.isAuthenticated = isAuthenticated
        self.hasConfig = hasConfig
        self.hasSession = hasSession
        self.configuredAuthStrategy = configuredAuthStrategy
        self.configuredEmailAddress = configuredEmailAddress
        self.sessionAuthStrategy = sessionAuthStrategy
        self.sessionEmailAddress = sessionEmailAddress
        self.sessionCreatedAt = sessionCreatedAt
        self.paths = paths
    }

    public init(state: PantryAuthState, paths: PantryPaths) {
        let hasSession = state.session != nil
        let hasConfig = state.config != nil

        self.init(
            status: hasSession ? "authenticated" : "not-authenticated",
            message: hasSession ? "A local Paprika session is present." : "No local Paprika session is saved.",
            isAuthenticated: hasSession,
            hasConfig: hasConfig,
            hasSession: hasSession,
            configuredAuthStrategy: state.config?.authStrategy,
            configuredEmailAddress: state.config?.lastEmailAddress,
            sessionAuthStrategy: state.session?.authStrategy,
            sessionEmailAddress: state.session?.emailAddress,
            sessionCreatedAt: state.session?.createdAt,
            paths: paths.report
        )
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
            "config: \(hasConfig ? "present" : "absent")",
            "session: \(hasSession ? "present" : "absent")",
        ]

        if let strategy = sessionAuthStrategy ?? configuredAuthStrategy {
            lines.append("strategy: \(strategy.rawValue)")
        }

        if let emailAddress = sessionEmailAddress ?? configuredEmailAddress {
            lines.append("email: \(emailAddress)")
        }

        if let sessionCreatedAt {
            lines.append("session_created_at: \(renderedTimestamp(sessionCreatedAt))")
        }

        if !hasSession {
            lines.append("next: paprika-pantry auth login")
        }

        lines.append(renderedPaths(paths))
        return lines.joined(separator: "\n")
    }
}

public struct AuthLogoutReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let clearedSession: Bool
    public let paths: PantryPathReport

    public init(
        command: String = "auth logout",
        clearedSession: Bool,
        paths: PantryPathReport
    ) {
        self.command = command
        self.clearedSession = clearedSession
        self.status = clearedSession ? "logged-out" : "already-logged-out"
        self.message = clearedSession ? "Cleared the local Paprika session." : "No local Paprika session was present."
        self.paths = paths
    }

    public var humanDescription: String {
        [
            "\(command): \(message)",
            "status: \(status)",
            "session: \(clearedSession ? "cleared" : "absent")",
            renderedPaths(paths),
        ].joined(separator: "\n")
    }
}

private func renderedTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}

private func renderedPaths(_ paths: PantryPathReport) -> String {
    [
        "home: \(paths.home)",
        "config: \(paths.config)",
        "session: \(paths.session)",
        "database: \(paths.database)",
    ].joined(separator: "\n")
}
