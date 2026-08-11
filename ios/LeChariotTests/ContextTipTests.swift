import XCTest
@testable import LeChariot

/// Die Regeln der vier Einmal-Schilder — geprüft als Rechnung, ohne ein Schild
/// zu bauen.
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

    /// **Der Deckel gilt je Fläche, nicht je Sitzung** — und das ist der
    /// Fehler, den Scott am 10.08. abends gemeldet hat: „the tip for the future
    /// offers is still not in there." Auf der Liste feuert fast immer zuerst
    /// die Angebotszeile; mit einem sitzungsweiten Deckel war der Angebote-Tab
    /// danach stumm, Sitzung für Sitzung. Die Rechnung dazu, in beide
    /// Richtungen.
    func testAListTipDoesNotEatTheOffersTip() {
        let spentOnList = ContextTipRules.Moment(
            activationsOnSurface: ContextTipTuning.tipsPerSurfaceAndSession
        )
        XCTAssertNil(
            ContextTipRules.tipOnList(ContextTipLedger(), matchVisible: true, hasOpenItems: true, guidanceVisible: false, moment: spentOnList),
            "Zwei Schilder auf einer Fläche wären die Tour in Raten"
        )
        XCTAssertEqual(
            ContextTipRules.tipOnOffers(ContextTipLedger(), nextWeekAvailable: true, moment: calm),
            .nextWeekPreview,
            "Die Fläche des Angebote-Tabs ist eine eigene — hier ist noch nichts verbraucht"
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

    /// Der Deckel selbst: **ein** Schild je Fläche und Sitzung. Wer ihn
    /// anhebt, soll das hier absichtlich tun — mit der Begründung in
    /// `ContextTipTuning` vor Augen, nicht nebenbei.
    func testOneTipPerSurfaceAndSessionIsTheContract() {
        XCTAssertEqual(ContextTipTuning.tipsPerSurfaceAndSession, 1)
    }

    /// Jedes Schild kennt seine Fläche — daran hängt der Deckel.
    func testEveryTipKnowsItsSurface() {
        XCTAssertEqual(ContextTip.nextWeekPreview.surface, .offers)
        for tip in [ContextTip.matchLine, .itemDetails, .checkOff] {
            XCTAssertEqual(tip.surface, .list, "\(tip) gehört auf die Liste")
        }
    }

    // MARK: Ernährungsfrage

    func testTheDietPromptWaitsForTheSecondVisit() {
        var ledger = ContextTipLedger()
        ledger.offersVisits = ContextTipTuning.offersVisitsBeforeDietPrompt - 1
        XCTAssertFalse(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: false, tipVisibleHere: false)
        )
        ledger.offersVisits = ContextTipTuning.offersVisitsBeforeDietPrompt
        XCTAssertTrue(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: false, tipVisibleHere: false)
        )
    }

    func testAnAnsweredProfileSilencesTheDietPrompt() {
        var ledger = ContextTipLedger()
        ledger.offersVisits = 99
        XCTAssertFalse(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: true, tipVisibleHere: false),
            "Wer im Profil schon Angaben hat, hat die Frage beantwortet — egal wo"
        )
    }

    func testADismissedDietPromptStaysDismissed() {
        var ledger = ContextTipLedger()
        ledger.offersVisits = 99
        ledger.dietPromptDone = true
        XCTAssertFalse(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: false, tipVisibleHere: false)
        )
    }

    func testTheDietPromptYieldsToAVisibleTip() {
        var ledger = ContextTipLedger()
        ledger.offersVisits = 99
        XCTAssertFalse(
            ContextTipRules.showsDietPrompt(ledger, dietAnswered: false, tipVisibleHere: true),
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

    /// Auf **einer** Fläche höchstens eines — der zweite Moment der Liste muss
    /// bis zur nächsten Sitzung warten.
    func testOnlyOneTipActivatesPerSurfaceAndSession() {
        let store = makeStore()
        store.checkedOff(matchVisible: false, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(store.activeTip(on: .list), .checkOff)

        store.listSettled(matchVisible: true, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(store.activeTip(on: .list), .checkOff, "Das zweite Schild derselben Fläche wartet")

        let nextSession = makeStore()
        nextSession.listSettled(matchVisible: true, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(nextSession.activeTip(on: .list), .matchLine)
    }

    /// **Der Fall aus Scotts Bedienrunde**, eine Ebene über der Regel: Ein
    /// Schild auf der Liste darf das des Angebote-Tabs nicht verbrauchen — und
    /// es darf es auch nicht wegnehmen, wenn beide in derselben Sitzung
    /// standen.
    func testTheListTipDoesNotSwallowTheOffersTipInTheSameSession() {
        let store = makeStore()
        store.checkedOff(matchVisible: false, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(store.activeTip(on: .list), .checkOff)

        store.offersAppeared(nextWeekAvailable: true)
        XCTAssertEqual(store.activeTip(on: .offers), .nextWeekPreview,
                       "Der Vorschau-Tipp hat seine eigene Fläche")
        XCTAssertEqual(store.activeTip(on: .list), .checkOff,
                       "…und nimmt der Liste ihr Schild nicht weg")
    }

    func testAShownTipSurvivesTheRestart() {
        let store = makeStore()
        store.offersAppeared(nextWeekAvailable: true)
        XCTAssertEqual(store.activeTip(on: .offers), .nextWeekPreview)

        let restarted = makeStore()
        XCTAssertNil(restarted.activeTip(on: .offers), "Ein Schild überlebt keinen Neustart")
        restarted.offersAppeared(nextWeekAvailable: true)
        XCTAssertNil(restarted.activeTip(on: .offers), "Gezeigt heißt gezeigt — auch nach Neustart")
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

    /// **„Tipps wieder anzeigen"** aus den Einstellungen: Die Merker fallen,
    /// die Zähler des Verhaltens bleiben — wer die Angaben-Schicht längst
    /// benutzt, bekommt ihr Schild auch danach nicht.
    func testShowingTipsAgainClearsWhatWasShownButNotWhatWasDone() {
        let store = makeStore()
        store.itemAdded()
        store.detailsUsed()
        store.offersAppeared(nextWeekAvailable: true)
        XCTAssertEqual(store.activeTip(on: .offers), .nextWeekPreview)

        store.showTipsAgain()
        XCTAssertTrue(store.ledger.shown.isEmpty)
        XCTAssertNil(store.activeTip(on: .offers))
        XCTAssertEqual(store.ledger.itemsAdded, 1, "Was der Nutzer getan hat, bleibt gezählt")
        XCTAssertTrue(store.ledger.usedDetails)

        // Auf Platte auch: Ein Neustart weiß nichts mehr von „schon gezeigt".
        XCTAssertTrue(makeStore().ledger.shown.isEmpty)

        // Und der Moment darf sofort wieder feuern, nicht erst nach einem
        // Neustart.
        store.offersAppeared(nextWeekAvailable: true)
        XCTAssertEqual(store.activeTip(on: .offers), .nextWeekPreview)
    }

    /// Weggetippt heißt weg — aber nicht wieder fällig.
    func testDismissingATipTakesItOffTheScreenForGood() {
        let store = makeStore()
        store.offersAppeared(nextWeekAvailable: true)
        store.dismissTip(on: .offers)
        XCTAssertNil(store.activeTip(on: .offers))
        store.offersAppeared(nextWeekAvailable: true)
        XCTAssertNil(store.activeTip(on: .offers), "Gezeigt bleibt gezeigt")
    }

    func testTheFirstCheckOffActivatesTheSwipeTip() {
        let store = makeStore()
        store.checkedOff(matchVisible: false, hasOpenItems: true, guidanceVisible: false)
        XCTAssertEqual(store.activeTip(on: .list), .checkOff)
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
        XCTAssertNil(store.activeTip(on: .offers))
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
        XCTAssertNil(store.activeTip(on: .offers))

        // Und zwar auch auf Platte — der nächste Start weiß nichts mehr.
        let restarted = makeStore()
        XCTAssertEqual(restarted.ledger, ContextTipLedger())
    }
}
