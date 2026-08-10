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

    /// Launched with `-uiTestingTips`: die Einmal-Tipps und die
    /// Ernährungsfrage anschalten.
    ///
    /// Unter `-uiTesting` bleiben sie sonst aus: Ein Schild über der Liste oder
    /// im Angebote-Tab bliebe in jeder bestehenden Journey hängen, ohne dass an
    /// ihr etwas kaputt wäre. Wer die Schilder prüfen will, schaltet sie ein.
    static let showsContextTips =
        ProcessInfo.processInfo.arguments.contains("-uiTestingTips")

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
    /// `LocatedPLZJourneyTests`, `MarketPromptJourneyTests`, `RestartJourneyTests` —
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

    /// Zusätzlich `-uiTestingOnboardedThreeChains`: eine **dritte** Filiale,
    /// deren Kette Zeilen der Folgewoche hat.
    ///
    /// Die Vorschau-Parität braucht drei Zustände gleichzeitig: zwei Ketten mit
    /// Vorschau (sonst zeigt die Markt-Leiste nichts — sie erscheint erst ab
    /// zwei) und eine ohne (sonst ist der Abschnitt „Ohne Vorschau" leer und
    /// die Zusage „auch unter Filter" nicht prüfbar). Siehe
    /// `MockFixtures.thirdChainOffers`.
    private static let seedsThreeChains =
        ProcessInfo.processInfo.arguments.contains("-uiTestingOnboardedThreeChains")

    /// Die Filialen, die das Saatgut wählt — dieselben, die die Onboarding-
    /// Journeys im Picker antippen, damit beide Wege denselben Zustand
    /// erreichen. Lidl zuerst: Wer nur eine bekommt, bekommt die, auf die die
    /// alten Helfer getippt haben.
    static let seededBranches = [
        Market(chain: "Lidl", branchName: "Dresden Reick",
               marketId: "lidl-01219-1", plz: "01219"),
        Market(chain: "Aldi", branchName: "Dresden Prohlis",
               marketId: "aldi-01219-1", plz: "01219"),
        Market(chain: "Netto", branchName: "Dresden Strehlen",
               marketId: "netto-01219-1", plz: "01219"),
    ]

    static let seededPLZ = "01219"

    /// Launched with `-uiTestingSunday`: der Sonntagszustand — zwei gewählte
    /// Ketten ohne gültige Angebote, eine mit.
    ///
    /// Siehe `MockFixtures.sunday`. Ein eigener Schalter und nicht das
    /// Standard-Saatgut: Ein halbes Dutzend Journeys prüft gegen
    /// `MockFixtures.offers`, und eine Kette, die über Nacht keine Zeilen mehr
    /// hat, würde sie alle umwerfen, ohne dass an ihnen etwas kaputt wäre.
    static let servesSundayOffers =
        ProcessInfo.processInfo.arguments.contains("-uiTestingSunday")

    /// `-uiTestingBulkOffers <n>`: `n` Zeilen **je Kette** für die laufende
    /// Woche, halb so viele für die Vorschau.
    ///
    /// Nur das Messgeschirr setzt das. Ohne die Zahl im Argument stünde die
    /// Größe des Prospekts im App-Quelltext statt im Test, der sie braucht —
    /// und ein Messstand, dessen Vorrat man nicht drehen kann, misst genau
    /// einen Fall.
    static var bulkOfferCount: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uiTestingBulkOffers"),
              i + 1 < args.count, let n = Int(args[i + 1]), n > 0 else { return nil }
        return n
    }

    /// Eine, zwei oder drei Filialen — je nachdem, was der Lauf braucht. Die
    /// Reihenfolge ist die von `seededBranches`, damit ein Lauf mit zwei
    /// Filialen genau den Zustand bekommt, den er vor dem 2026-08-02 hatte.
    private static var seededFavorites: [Market] {
        if seedsThreeChains { return seededBranches }
        if seedsAllBranches { return Array(seededBranches.prefix(2)) }
        return [seededBranches[0]]
    }

    /// Launched with `-uiTestingOnboardingLost`: den Merker „Onboarding
    /// durchlaufen" abräumen und **sonst nichts** anfassen.
    ///
    /// Damit lässt sich Scotts Meldung aus Build `2026.0801.1951` nachstellen,
    /// ohne sich auf eine Ursache festzulegen: Der Assistent läuft ein zweites
    /// Mal, PLZ, Filialen und Profil liegen unverändert da.
    ///
    /// Ein eigener Schalter statt „App löschen und neu aufsetzen": Ein Neustart
    /// von Null räumt den Merker mit ab und könnte die Regel deshalb gar nicht
    /// prüfen.
    private static let dropsOnboardingFlag =
        ProcessInfo.processInfo.arguments.contains("-uiTestingOnboardingLost")

    /// Legt den Zustand hin, den ein durchlaufenes Onboarding hinterlassen
    /// hätte. Läuft in `LeChariotApp.init`, also bevor irgendeine Ansicht ihn
    /// liest.
    @MainActor
    static func seedOnboardedState(regions: RegionStore, profile: ProfileStore) {
        if dropsOnboardingFlag { regions.forgetOnboardingCompletion() }
        guard seedsOnboardedState else { return }
        regions.seedOnboarded(
            region: seededPLZ,
            favorites: seededFavorites
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
