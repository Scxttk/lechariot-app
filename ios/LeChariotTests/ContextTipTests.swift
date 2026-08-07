import XCTest
@testable import LeChariot

/// Die Regeln der Einmal-Tipps — geprüft als Rechnung, ohne eine Sprechblase
/// zu bauen (dasselbe Muster wie `TourTabTransition`).
///
/// Was hier auf dem Spiel steht: Ein Tipp, der zweimal kommt, ist schlimmer
/// als keiner — die Forschungsnotiz nennt ~76 % in unter drei Sekunden
/// weggewischte Tooltips. Jede Prüfung hier sichert deshalb eine der zwei
/// Zusagen: **einmal** und **im richtigen Moment**.
final class ContextTipRulesTests: XCTestCase {
    private let calm = ContextTipRules.Moment()

    // MARK: Angebote-Tab

    func testTheFirstOffersVisitEarnsTheNextWeekTip() {
        XCTAssertEqual(
            ContextTipRules.tipOnOffers(ContextTipLedger(), nextWeekAvailable: true, moment: calm),
            .nextWeekPreview
        )
    }

    func testWithoutTheNextWeekButtonThereIsNothingToPointAt() {
        XCTAssertNil(
            ContextTipRules.tipOnOffers(ContextTipLedger(), nextWeekAvailable: false, moment: calm)
        )
    }

    func testAShownTipNeverReturns() {
        var ledger = ContextTipLedger()
        ledger.shown.insert(.nextWeekPreview)
        XCTAssertNil(
            ContextTipRules.tipOnOffers(ledger, nextWeekAvailable: true, moment: calm)
        )
    }

    // MARK: Liste — Vorrang

    func testTheMatchLineOutranksEverythingOnTheList() {
        // Alle drei Listen-Tipps wären fällig — die Angebotszeile gewinnt,
        // denn sie ist der Grund, aus dem es die App gibt.
        var ledger = ContextTipLedger()
        ledger.itemsAdded = ContextTipTuning.itemsBeforeDetailsTip
        ledger.checkedOff = true
        XCTAssertEqual(
            ContextTipRules.tipOnList(ledger, matchVisible: true, hasOpenItems: true, guidanceVisible: false, moment: calm),
            .matchLine
        )
    }

    func testDetailsComeBeforeCheckOffWhenBothAreDue() {
        var ledger = ContextTipLedger()
        ledger.itemsAdded = ContextTipTuning.itemsBeforeDetailsTip
        ledger.checkedOff = true
        XCTAssertEqual(
            ContextTipRules.tipOnList(ledger, matchVisible: false, hasOpenItems: true, guidanceVisible: false, moment: calm),
            .itemDetails
        )
    }

    // MARK: Liste — Angaben-Tipp

    func testTheDetailsTipWaitsForEnoughItems() {
        var ledger = ContextTipLedger()
        ledger.itemsAdded = ContextTipTuning.itemsBeforeDetailsTip - 1
        XCTAssertNil(
            ContextTipRules.tipOnList(ledger, matchVisible: false, hasOpenItems: true, guidanceVisible: false, moment: calm),
            "Vor der Schwelle ist der Tipp nicht verdient"
        )
    }

    func testWhoFoundTheDetailsNeverGetsTheTip() {
        var ledger = ContextTipLedger()
        ledger.itemsAdded = 99
        ledger.usedDetails = true
        XCTAssertNil(
            ContextTipRules.tipOnList(ledger, matchVisible: false, hasOpenItems: true, guidanceVisible: false, moment: calm)
        )
    }

    // MARK: Liste — Abhaken-Tipp

    func testTheFirstCheckOffEarnsTheSwipeTip() {
        var ledger = ContextTipLedger()
        ledger.checkedOff = true
        XCTAssertEqual(
            ContextTipRules.tipOnList(ledger, matchVisible: false, hasOpenItems: true, guidanceVisible: false, moment: calm),
            .checkOff
        )
    }

    func testSessionsWithoutACheckOffEventuallyEarnTheTip() {
        var ledger = ContextTipLedger()
        ledger.listSessionsWithoutCheckOff = ContextTipTuning.listSessionsBeforeCheckOffTip - 1
        XCTAssertNil(
            ContextTipRules.tipOnList(ledger, matchVisible: false, hasOpenItems: true, guidanceVisible: false, moment: calm)
        )
        ledger.listSessionsWithoutCheckOff = ContextTipTuning.listSessionsBeforeCheckOffTip
        XCTAssertEqual(
            ContextTipRules.tipOnList(ledger, matchVisible: false, hasOpenItems: true, guidanceVisible: false, moment: calm),
            .checkOff
        )
    }

    func testAnEmptyListCarriesNoListTips() {
        var ledger = ContextTipLedger()
        ledger.checkedOff = true
        ledger.itemsAdded = 99
        XCTAssertNil(
            ContextTipRules.tipOnList(ledger, matchVisible: false, hasOpenItems: false, guidanceVisible: false, moment: calm),
            "Ohne offene Zeile gibt es keinen Anker — der Tipp zeigte ins Leere"
        )
    }

    // MARK: Sitzung

    func testTheTourSilencesEveryTip() {
        var ledger = ContextTipLedger()
        ledger.checkedOff = true
        let touring = ContextTipRules.Moment(tourIsRunning: true, activationsThisSession: 0)
        XCTAssertNil(ContextTipRules.tipOnOffers(ledger, nextWeekAvailable: true, moment: touring))
        XCTAssertNil(ContextTipRules.tipOnList(ledger, matchVisible: true, hasOpenItems: true, guidanceVisible: false, moment: touring))
    }

    func testTheSessionCapSilencesTheSecondTip() {
        let spent = ContextTipRules.Moment(
            tourIsRunning: false,
            activationsThisSession: ContextTipTuning.tipsPerSession
        )
        XCTAssertNil(
            ContextTipRules.tipOnList(ContextTipLedger(), matchVisible: true, hasOpenItems: true, guidanceVisible: false, moment: spent)
        )
    }

    /// **Eine Führungsfläche zugleich** — solange Checkliste oder
    /// Filialen-Karte führen (`ListGuidance`), feuert kein Listen-Tipp. Er
    /// ist nicht verloren: Ohne Aktivierung fällt kein Gezeigt-Merker, der
    /// Moment kommt in einer freien Sitzung wieder.
    func testNoListTipWhileAnotherGuidanceSurfaceLeads() {
        var ledger = ContextTipLedger()
        ledger.checkedOff = true
        XCTAssertNil(
            ContextTipRules.tipOnList(ledger, matchVisible: true, hasOpenItems: true, guidanceVisible: true, moment: calm),
            "Neben der Checkliste wäre der Tipp die zweite Karte im Gedränge"
        )
        XCTAssertFalse(
            ledger.shown.contains(.matchLine),
            "Ein zurückgehaltener Tipp darf nicht als gezeigt gelten"
        )
    }

    /// Der Deckel selbst: **ein** Tipp je Sitzung. Wer ihn anhebt, soll das
    /// hier absichtlich tun — mit der Begründung in `ContextTipTuning` vor
    /// Augen, nicht nebenbei.
    func testOneTipPerSessionIsTheContract() {
        XCTAssertEqual(ContextTipTuning.tipsPerSession, 1)
    }

    // MARK: Ernährungsfrage

    func testTheDietPromptWaitsForTheSecondVisit() {
        var ledger = ContextTipLedger()
        ledger.offersVisits = ContextTipTuning.offersVisitsBeforeDietPrompt - 1
        XCTAssertFalse(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: false, tipVisibleHere: false, moment: calm)
        )
        ledger.offersVisits = ContextTipTuning.offersVisitsBeforeDietPrompt
        XCTAssertTrue(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: false, tipVisibleHere: false, moment: calm)
        )
    }

    func testAnAnsweredProfileSilencesTheDietPrompt() {
        var ledger = ContextTipLedger()
        ledger.offersVisits = 99
        XCTAssertFalse(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: true, tipVisibleHere: false, moment: calm),
            "Wer im Profil schon Angaben hat, hat die Frage beantwortet — egal wo"
        )
    }

    func testADismissedDietPromptStaysDismissed() {
        var ledger = ContextTipLedger()
        ledger.offersVisits = 99
        ledger.dietPromptDone = true
        XCTAssertFalse(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: false, tipVisibleHere: false, moment: calm)
        )
    }

    func testTheDietPromptYieldsToAVisibleTip() {
        var ledger = ContextTipLedger()
        ledger.offersVisits = 99
        XCTAssertFalse(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: false, tipVisibleHere: true, moment: calm),
            "Karte und Sprechblase gleichzeitig wären ein Formular"
        )
    }
}

/// Die Buchhaltung dazu: Zähler je Sitzung, Merker auf Platte.
@MainActor
final class ContextTipStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "ContextTipStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore() -> ContextTipStore {
        ContextTipStore(defaults: defaults, enabled: true)
    }

    func testOnlyOneTipActivatesPerSession() {
        let store = makeStore()
        store.offersAppeared(nextWeekAvailable: true)
        XCTAssertEqual(store.active, .nextWeekPreview)

        // Der Treffer-Moment kommt in derselben Sitzung — er muss warten.
        store.listSettled(matchVisible: true, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(store.active, .nextWeekPreview)

        // Nächste Sitzung: Der Moment wiederholt sich, jetzt ist er dran.
        let nextSession = makeStore()
        nextSession.listSettled(matchVisible: true, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(nextSession.active, .matchLine)
    }

    func testAShownTipSurvivesTheRestart() {
        let store = makeStore()
        store.offersAppeared(nextWeekAvailable: true)
        XCTAssertEqual(store.active, .nextWeekPreview)

        let restarted = makeStore()
        XCTAssertNil(restarted.active, "Eine Sprechblase überlebt keinen Neustart")
        restarted.offersAppeared(nextWeekAvailable: true)
        XCTAssertNil(restarted.active, "Gezeigt heißt gezeigt — auch nach Neustart")
    }

    func testTabSwitchesCountAsOneVisit() {
        let store = makeStore()
        // Dreimal hin und her in einer Sitzung …
        store.offersAppeared(nextWeekAvailable: false)
        store.offersAppeared(nextWeekAvailable: false)
        store.offersAppeared(nextWeekAvailable: false)
        XCTAssertEqual(store.ledger.offersVisits, 1)

        // … die zweite Sitzung ist der zweite Besuch — und mit ihm die Frage.
        let nextSession = makeStore()
        nextSession.offersAppeared(nextWeekAvailable: false)
        XCTAssertEqual(nextSession.ledger.offersVisits, 2)
        XCTAssertTrue(nextSession.showsDietPrompt(dietAnswered: false))
    }

    func testSessionsWithoutACheckOffAreCountedOncePerSession() {
        let store = makeStore()
        store.listSettled(matchVisible: false, hasOpenItems: true, guidanceVisible: false)
        store.listSettled(matchVisible: false, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(store.ledger.listSessionsWithoutCheckOff, 1)
    }

    func testTheTourKeepsTheCountersStill() {
        let store = makeStore()
        store.tourIsRunning = true
        // Der Rundgang legt Beispiel-Artikel — die zählen nicht.
        store.itemAdded()
        store.itemAdded()
        store.offersAppeared(nextWeekAvailable: true)
        store.listSettled(matchVisible: true, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(store.ledger.itemsAdded, 0)
        XCTAssertEqual(store.ledger.offersVisits, 0)
        XCTAssertNil(store.active)
    }

    func testTheFirstCheckOffActivatesTheSwipeTip() {
        let store = makeStore()
        store.checkedOff(matchVisible: false, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(store.active, .checkOff)
        XCTAssertTrue(store.ledger.checkedOff)
    }

    func testDismissingTheDietPromptIsFinal() {
        let store = makeStore()
        store.offersAppeared(nextWeekAvailable: false)
        let second = makeStore()
        second.offersAppeared(nextWeekAvailable: false)
        XCTAssertTrue(second.showsDietPrompt(dietAnswered: false))

        second.dismissDietPrompt()
        XCTAssertFalse(second.showsDietPrompt(dietAnswered: false))

        let third = makeStore()
        third.offersAppeared(nextWeekAvailable: false)
        XCTAssertFalse(third.showsDietPrompt(dietAnswered: false), "Wegdrücken ist eine endgültige Antwort")
    }

    /// **Der erste angetippte Chip darf die Frage nicht wegnehmen.** Genau das
    /// tat sie: Mit der Angabe im Profil wurde `dietAnswered` wahr, die Regel
    /// nahm die Karte weg — und „Fertig" wie eine zweite Angabe waren nie
    /// erreichbar. Der Journey-Mitschnitt zeigte eine Sekunde zwischen dem
    /// Tipp auf „Vegetarisch" und dem verschwundenen Knopf.
    func testAnAnswerInProgressKeepsTheDietPromptOpen() {
        let store = makeStore()
        store.offersAppeared(nextWeekAvailable: false)
        let second = makeStore()
        second.offersAppeared(nextWeekAvailable: false)
        XCTAssertTrue(second.showsDietPrompt(dietAnswered: false))

        XCTAssertTrue(second.showsDietPrompt(dietAnswered: true),
                      "Wer gerade antippt, dem darf die Karte nicht wegrutschen")
        second.dismissDietPrompt()
        XCTAssertFalse(second.showsDietPrompt(dietAnswered: true),
                       "…erst \u{201E}Fertig\u{201C} beendet sie")
    }

    /// Die Gegenprobe: Wer die Angabe **vorher** im Profil stehen hat, dem geht
    /// die Frage gar nicht erst auf.
    func testAnAlreadyAnsweredProfileNeverOpensThePrompt() {
        let store = makeStore()
        store.offersAppeared(nextWeekAvailable: false)
        let second = makeStore()
        second.offersAppeared(nextWeekAvailable: false)
        XCTAssertFalse(second.showsDietPrompt(dietAnswered: true))
    }

    func testADisabledStoreStaysSilent() {
        let store = ContextTipStore(defaults: defaults, enabled: false)
        store.offersAppeared(nextWeekAvailable: true)
        store.itemAdded()
        XCTAssertNil(store.active)
        XCTAssertEqual(store.ledger.itemsAdded, 0)
        XCTAssertFalse(store.showsDietPrompt(dietAnswered: false))
    }

    func testResetForgetsEverything() {
        let store = makeStore()
        store.itemAdded()
        store.offersAppeared(nextWeekAvailable: true)
        store.dismissDietPrompt()
        store.resetAllData()
        XCTAssertEqual(store.ledger, ContextTipLedger())
        XCTAssertNil(store.active)

        // Und zwar auch auf Platte — der nächste Start weiß nichts mehr.
        let restarted = makeStore()
        XCTAssertEqual(restarted.ledger, ContextTipLedger())
    }
}
