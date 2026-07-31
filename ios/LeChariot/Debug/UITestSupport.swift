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

    /// Launched with `-uiTestingOnboarded`: start **behind** the onboarding,
    /// with PLZ 01219 ready and the fixture Lidl chosen.
    ///
    /// **Gemessen, nicht geschätzt:** Ein voller UI-Lauf kostet rund 20
    /// Minuten, und 72 % davon ist der Assistent — `ShoppingListInputJourneyTests`
    /// tippt *ein* Wort und braucht 18 s, weil davor sieben Bildschirme liegen.
    /// 48 Journeys × 18 s ≈ 864 s, für einen Zustand, den drei Journeys
    /// tatsächlich prüfen und 45 nur durchqueren.
    ///
    /// Die Journeys, die den Assistenten *meinen* — `OnboardingJourneyTests`,
    /// `LocatedPLZJourneyTests`, `TutorialJourneyTests`, `RestartJourneyTests` —
    /// laufen weiter durch ihn hindurch. Ohne diese Trennung würde das Argument
    /// genau die Strecke wegkürzen, die es zu prüfen gilt.
    static let seedsOnboardedState =
        ProcessInfo.processInfo.arguments.contains("-uiTestingOnboarded")

    /// Zusätzlich `-uiTestingOnboardedAllBranches`: **beide** Filialen des
    /// Fixture-Verzeichnisses statt nur der einen.
    ///
    /// Die Chip-Leiste der Angebote erscheint erst ab zwei Ketten — eine
    /// Journey, die sie prüft, braucht also einen anderen Startzustand als
    /// eine, die ihre Abwesenheit prüft. Zwei Saatgut-Fassungen sind billiger
    /// als eine Journey, die sich ihre zweite Filiale erst zusammenklickt.
    private static let seedsAllBranches =
        ProcessInfo.processInfo.arguments.contains("-uiTestingOnboardedAllBranches")

    /// Die Filialen, die das Saatgut wählt — dieselben, die die Onboarding-
    /// Journeys im Picker antippen, damit beide Wege denselben Zustand
    /// erreichen. Lidl zuerst: Wer nur eine bekommt, bekommt die, auf die die
    /// alten Helfer getippt haben.
    static let seededBranches = [
        Market(chain: "Lidl", branchName: "Dresden Reick",
               marketId: "lidl-01219-1", plz: "01219"),
        Market(chain: "Aldi", branchName: "Dresden Prohlis",
               marketId: "aldi-01219-1", plz: "01219"),
    ]

    static let seededPLZ = "01219"

    /// Legt den Zustand hin, den ein durchlaufenes Onboarding hinterlassen
    /// hätte. Läuft in `LeChariotApp.init`, also bevor irgendeine Ansicht ihn
    /// liest.
    @MainActor
    static func seedOnboardedState(regions: RegionStore, profile: ProfileStore) {
        guard seedsOnboardedState else { return }
        regions.seedOnboarded(
            region: seededPLZ,
            favorites: seedsAllBranches ? seededBranches : [seededBranches[0]]
        )
        // Ohne das hielte `OnboardingFlowView.resume` den Assistenten für
        // unterbrochen — sichtbar wird es erst, wenn jemand zurücksetzt.
        profile.markQuestionsCompleted()
    }

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
