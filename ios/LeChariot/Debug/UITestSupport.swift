import Foundation

#if DEBUG

/// Makes UI-test runs hermetic and repeatable.
///
/// Two things otherwise make automated journeys useless here. The app talks to
/// live Supabase, so a test asserting on offers would depend on what the
/// scrapers found this week; and the simulator keeps preferences across
/// installs, so "delete the app first" does not reliably produce a first launch.
///
/// With `-uiTesting` the app serves fixtures instead of the network and writes
/// its state into a throwaway defaults suite that is emptied on every launch —
/// see `AppDefaults` for why the app's own domain cannot be cleared.
enum UITestSupport {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    private static let suiteName = "com.skoehler.lechariot.uitests"

    /// Launched with `-uiTestingKeepState`: use the test suite but do **not**
    /// empty it. Without this there is no way to test that anything survives
    /// an app restart — every launch would look like a fresh install, which is
    /// exactly the opposite of what such a journey asserts.
    private static let keepsState =
        ProcessInfo.processInfo.arguments.contains("-uiTestingKeepState")

    /// Launched with `-uiTestingAreaJustFetched`: pretend an earlier launch
    /// asked for this area's directory and the run has since finished.
    ///
    /// The whole point of that flow is that it spans app sessions — the run
    /// takes about three minutes and the user is long gone. A journey cannot
    /// wait three minutes for a real backend, so the state it would leave
    /// behind is seeded instead. The anchor is the Lidl the onboarding
    /// journeys pick, so it exists in the mock directory.
    static let seedsFinishedArea =
        ProcessInfo.processInfo.arguments.contains("-uiTestingAreaJustFetched")

    static let seededAreaAnchor = "lidl-01219-1"

    /// Launched with `-uiTestingTutorial`: offer and show the tour.
    ///
    /// Unter `-uiTesting` bleibt er sonst aus. Er hängt einen Bildschirm ans
    /// Onboarding und sperrt danach die Liste hinter Sperrflächen — jede
    /// bestehende Journey bliebe daran hängen, ohne dass an ihr etwas kaputt
    /// wäre. Deshalb: wer den Rundgang prüfen will, schaltet ihn ein.
    ///
    /// Das schützt vor dem Rundgang, nicht vor jeder Folge. Zwei Journeys
    /// mussten trotzdem nachgezogen werden, weil der neue Hilfe-Abschnitt die
    /// Einstellungen nach unten schiebt und beide an einer festen
    /// Scrollposition suchten — das ist eine echte Änderung der Oberfläche,
    /// kein Testartefakt.
    static let showsTutorial =
        ProcessInfo.processInfo.arguments.contains("-uiTestingTutorial")

    /// The defaults suite for this launch, emptied unless the launch asked to
    /// keep it. `nil` outside test runs.
    ///
    /// Emptying here rather than in `tearDown` keeps each launch independent
    /// of whether the previous test finished cleanly — a crashed journey must
    /// not leak its state into the next one.
    static func freshSuite() -> UserDefaults? {
        guard isActive, let suite = UserDefaults(suiteName: suiteName) else { return nil }
        if !keepsState { suite.removePersistentDomain(forName: suiteName) }
        return suite
    }
}

#endif
