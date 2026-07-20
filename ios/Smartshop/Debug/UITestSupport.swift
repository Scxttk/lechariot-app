import Foundation

#if DEBUG

/// Makes UI-test runs hermetic and repeatable.
///
/// Two things otherwise make automated journeys useless here. The app talks to
/// live Supabase, so a test asserting on offers would depend on what the
/// scrapers found this week; and the simulator keeps preferences across
/// installs (its preference daemon happily writes cached values back into a
/// freshly created container), so "delete the app first" does not reliably
/// produce a first launch.
///
/// With `-uiTesting` the app wipes its own defaults during startup — before any
/// store reads them — and serves fixtures instead of the network.
enum UITestSupport {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    /// Must run before the first `UserDefaults` read of the launch.
    static func prepareCleanLaunchIfNeeded() {
        guard isActive, let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
}

#endif
