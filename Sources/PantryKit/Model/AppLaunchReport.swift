import Foundation

public struct AppLaunchReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let status: String
    public let message: String
    public let effect: String
    public let appBundlePath: String
    public let bundleIdentifier: String?
    public let launchedVia: String
    public let waitedForSync: Bool
    public let waitTimeoutSeconds: Int?
    public let pollIntervalSeconds: Double?
    public let initialPaprikaSync: PaprikaSyncDetails?
    public let observedPaprikaSync: PaprikaSyncDetails?
    public let syncAdvanced: Bool?
    public let observedSyncFreshnessSeconds: Int?
    public let paths: PantryPathReport

    public init(
        command: String,
        status: String,
        message: String,
        effect: String,
        appBundlePath: String,
        bundleIdentifier: String?,
        launchedVia: String,
        waitedForSync: Bool = false,
        waitTimeoutSeconds: Int? = nil,
        pollIntervalSeconds: Double? = nil,
        initialPaprikaSync: PaprikaSyncDetails? = nil,
        observedPaprikaSync: PaprikaSyncDetails? = nil,
        syncAdvanced: Bool? = nil,
        observedSyncFreshnessSeconds: Int? = nil,
        paths: PantryPaths
    ) {
        self.command = command
        self.status = status
        self.message = message
        self.effect = effect
        self.appBundlePath = appBundlePath
        self.bundleIdentifier = bundleIdentifier
        self.launchedVia = launchedVia
        self.waitedForSync = waitedForSync
        self.waitTimeoutSeconds = waitTimeoutSeconds
        self.pollIntervalSeconds = pollIntervalSeconds
        self.initialPaprikaSync = initialPaprikaSync
        self.observedPaprikaSync = observedPaprikaSync
        self.syncAdvanced = syncAdvanced
        self.observedSyncFreshnessSeconds = observedSyncFreshnessSeconds
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

        if waitedForSync {
            lines.append("waited_for_sync: yes")

            if let waitTimeoutSeconds {
                lines.append("wait_timeout_seconds: \(waitTimeoutSeconds)")
            }

            if let pollIntervalSeconds {
                lines.append("poll_interval_seconds: \(renderedDecimal(pollIntervalSeconds))")
            }

            lines.append(contentsOf: renderedPaprikaSyncLines(
                sync: initialPaprikaSync,
                prefix: "initial_paprika",
                freshnessSeconds: nil
            ))
            lines.append(contentsOf: renderedPaprikaSyncLines(
                sync: observedPaprikaSync,
                prefix: "observed_paprika",
                freshnessSeconds: observedSyncFreshnessSeconds
            ))

            if let syncAdvanced {
                lines.append("observed_sync_advance: \(syncAdvanced ? "yes" : "no")")
            }
        }

        lines.append("home: \(paths.home)")
        lines.append("config: \(paths.config)")
        lines.append("database: \(paths.database)")
        return lines.joined(separator: "\n")
    }
}
