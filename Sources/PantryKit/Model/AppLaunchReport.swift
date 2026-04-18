import Foundation

public struct AppLaunchReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let effect: String
    public let appBundlePath: String
    public let bundleIdentifier: String?
    public let launchedVia: String
    public let paths: PantryPathReport

    public init(
        command: String,
        status: String,
        message: String,
        effect: String,
        appBundlePath: String,
        bundleIdentifier: String?,
        launchedVia: String,
        paths: PantryPaths
    ) {
        self.command = command
        self.status = status
        self.message = message
        self.effect = effect
        self.appBundlePath = appBundlePath
        self.bundleIdentifier = bundleIdentifier
        self.launchedVia = launchedVia
        self.paths = paths.report
    }

    public var humanDescription: String {
        var lines = [
            "\(command): \(message)",
            "status: \(status)",
            "effect: \(effect)",
            "app_bundle: \(appBundlePath)",
            "launched_via: \(launchedVia)",
        ]

        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            lines.append("bundle_identifier: \(bundleIdentifier)")
        }

        lines.append("home: \(paths.home)")
        lines.append("config: \(paths.config)")
        lines.append("database: \(paths.database)")
        return lines.joined(separator: "\n")
    }
}
