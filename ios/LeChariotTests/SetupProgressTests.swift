import XCTest
@testable import LeChariot

/// Der geführte erste Artikel, die Beispiel-Angebote der leeren Liste und die
/// Einrichtungs-Checkliste — die Zustandsmaschine dahinter, ohne Bildschirm.
@MainActor
final class SetupProgressTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "setup.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeStore() -> SetupProgressStore {
        SetupProgressStore(defaults: defaults)
    }

    // MARK: Die zwei ersten Male

    func testAFreshInstallHasSeenNothingYet() {
        let store = makeStore()
        XCTAssertFalse(store.firstItemAdded)
        XCTAssertFalse(store.firstMatchSeen)
        XCTAssertTrue(store.checklistIsVisible(hasMarkets: false))
    }

    func testTheFirstItemIsRememberedAcrossRestarts() {
        makeStore().recordItemAdded()
        XCTAssertTrue(makeStore().firstItemAdded, "der Merker muss den Neustart überleben")
    }

    /// `true` genau beim Übergang — daran hängt das einmalige Aufleuchten.
    /// Jeder weitere Aufruf muss ein stilles Nein sein, sonst glüht die Kachel
    /// bei jedem Start.
    func testTheFirstMatchFiresExactlyOnce() {
        let store = makeStore()
        XCTAssertTrue(store.recordFirstMatch(), "der Übergang selbst")
        XCTAssertFalse(store.recordFirstMatch(), "und nie wieder")
        XCTAssertFalse(makeStore().recordFirstMatch(), "auch nicht nach einem Neustart")
    }

    // MARK: Die Checkliste

    func testDismissingTheChecklistSticks() {
        makeStore().dismissChecklist()
        XCTAssertFalse(makeStore().checklistIsVisible(hasMarkets: false),
                       "weggewischt ist weggewischt, auch nach einem Neustart")
    }

    /// Das Siegel: Waren alle vier Punkte einmal gleichzeitig erfüllt, kommt
    /// die Karte nie wieder — auch dann nicht, wenn später die letzte Filiale
    /// abgewählt wird. „Einmal fertig" ist eine Aussage über die Einrichtung,
    /// nicht über den Moment.
    func testACompletedChecklistNeverComesBack() {
        let store = makeStore()
        store.recordItemAdded()
        store.recordFirstMatch()
        store.sealIfComplete(hasMarkets: true)

        XCTAssertTrue(store.checklistDone)
        XCTAssertFalse(makeStore().checklistIsVisible(hasMarkets: false),
                       "ohne Filiale und nach Neustart: die Karte bleibt weg")
    }

    func testTheSealNeedsAllFourPointsAtOnce() {
        let store = makeStore()
        store.recordItemAdded()
        store.sealIfComplete(hasMarkets: true)
        XCTAssertFalse(store.checklistDone, "ohne Treffer kein Siegel")

        store.recordFirstMatch()
        store.sealIfComplete(hasMarkets: false)
        XCTAssertFalse(store.checklistDone, "ohne Filiale kein Siegel")

        store.sealIfComplete(hasMarkets: true)
        XCTAssertTrue(store.checklistDone)
    }

    /// Auch ungestempelt gilt fertig als fertig: In dem einen Durchgang
    /// zwischen „alles erfüllt" und dem Siegel darf die Karte nicht stehen.
    func testAFinishedButUnsealedChecklistIsAlreadyInvisible() {
        let store = makeStore()
        store.recordItemAdded()
        store.recordFirstMatch()

        XCTAssertTrue(store.checklistIsVisible(hasMarkets: false),
                      "ohne Filiale fehlt noch ein Punkt")
        XCTAssertFalse(store.checklistIsVisible(hasMarkets: true))
    }

    func testResetPutsEverythingBack() {
        let store = makeStore()
        store.recordItemAdded()
        store.recordFirstMatch()
        store.dismissChecklist()
        store.sealIfComplete(hasMarkets: true)

        store.resetAllData()

        XCTAssertFalse(store.firstItemAdded)
        XCTAssertFalse(store.firstMatchSeen)
        XCTAssertTrue(store.checklistIsVisible(hasMarkets: false))
        let fresh = makeStore()
        XCTAssertFalse(fresh.firstItemAdded, "kein Schlüssel darf auf der Platte zurückbleiben")
        XCTAssertFalse(fresh.firstMatchSeen)
        XCTAssertTrue(fresh.checklistIsVisible(hasMarkets: false))
    }

    // MARK: Die Vorfahrtsregel

    /// Der Rundgang behält seine Bühne: Seine Rahmen ankern an der
    /// Filialen-Karte, also sieht die Liste während der Führung aus wie vor
    /// diesem Umbau — Karte ohne Filialen, sonst nichts.
    func testTheTourKeepsItsStage() {
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: true, hasMarkets: false, firstItemAdded: false,
                checklistVisible: true, tourIsRunning: true,
                flowActive: false, tipActive: false
            ),
            .noMarkets
        )
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: false, hasMarkets: true, firstItemAdded: false,
                checklistVisible: true, tourIsRunning: true,
                flowActive: false, tipActive: false
            ),
            .none
        )
    }

    /// Direkt nach dem Onboarding (leer, keine Filiale): Die Filialen-Karte
    /// bleibt stehen — vier Journeys halten genau diesen Bildschirm fest. Die
    /// Einladung zum ersten Artikel trägt die Ansprache, keine zweite Karte.
    func testRightAfterOnboardingTheNoMarketsCardStays() {
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: true, hasMarkets: false, firstItemAdded: false,
                checklistVisible: true, tourIsRunning: false,
                flowActive: false, tipActive: false
            ),
            .noMarkets
        )
    }

    /// Mit Filialen und noch nie einem Artikel: die Beispiel-Angebote.
    func testWithMarketsTheEmptyListShowsTheExamples() {
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: true, hasMarkets: true, firstItemAdded: false,
                checklistVisible: true, tourIsRunning: false,
                flowActive: false, tipActive: false
            ),
            .firstItem
        )
    }

    /// Nach dem ersten Artikel führt die Checkliste — sie enthält den Weg zur
    /// Filialauswahl selbst und ersetzt die Karte, statt neben ihr zu stehen.
    func testAfterTheFirstItemTheChecklistLeads() {
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: false, hasMarkets: false, firstItemAdded: true,
                checklistVisible: true, tourIsRunning: false,
                flowActive: false, tipActive: false
            ),
            .checklist
        )
    }

    /// Checkliste weggewischt, trotzdem keine Filiale: Die Karte kommt zurück.
    /// Eine Sackgasse darf daraus nie werden.
    func testADismissedChecklistFallsBackToTheNoMarketsCard() {
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: false, hasMarkets: false, firstItemAdded: true,
                checklistVisible: false, tourIsRunning: false,
                flowActive: false, tipActive: false
            ),
            .noMarkets
        )
    }

    /// **Während des Tipp-Flusses führt niemand.** Mit stehender Tastatur
    /// bleiben der Liste rund 180 pt (gemessen 05.08.: Angaben-Schicht ab
    /// y = 341 von 852) — eine Checkliste darüber schöbe genau die Zeile
    /// hinter die Tastatur, deren Treffer-Kachel der Aha-Moment ist. Ohne
    /// Filialen bleibt die Karte am Platz der Plan-Karte stehen: Ein Platz,
    /// der beim Tippen auf- und zuginge, wäre ein springender Bildschirm.
    func testDuringTheAddFlowTheRowsKeepTheScreen() {
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: false, hasMarkets: true, firstItemAdded: true,
                checklistVisible: true, tourIsRunning: false,
                flowActive: true, tipActive: true
            ),
            .none
        )
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: false, hasMarkets: false, firstItemAdded: true,
                checklistVisible: true, tourIsRunning: false,
                flowActive: true, tipActive: false
            ),
            .noMarkets
        )
    }

    /// **Ein aktiver Einmal-Tipp schlägt die Checkliste** — sein Merker ist
    /// beim Aktivieren schon gefallen, ihn zu verstecken hieße ihn
    /// verbrennen. Dass beide gleichzeitig wollen, verhindert die
    /// Aktivierung (`ContextTipRules.tipOnList`, `guidanceVisible`).
    func testAnActiveTipOutranksTheChecklist() {
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: false, hasMarkets: true, firstItemAdded: true,
                checklistVisible: true, tourIsRunning: false,
                flowActive: false, tipActive: true
            ),
            .tip
        )
    }

    /// Alles eingerichtet: keine Führung mehr. Der Bildschirm gehört der
    /// Liste.
    func testAFullySetUpListShowsNoGuidanceAtAll() {
        XCTAssertEqual(
            ListGuidance.surface(
                listIsEmpty: false, hasMarkets: true, firstItemAdded: true,
                checklistVisible: false, tourIsRunning: false,
                flowActive: false, tipActive: false
            ),
            .none
        )
    }

    // MARK: Die Beispiel-Angebote

    private func offer(
        _ product: String,
        market: String = "Kaufland",
        price: Double = 1.99,
        regular: Double? = nil,
        tags: [String]
    ) -> Offer {
        Offer(
            market: market,
            product: product,
            price: price,
            regularPrice: regular,
            unit: nil,
            category: "Molkerei & Eier",
            emoji: nil,
            validFrom: .now,
            validUntil: .now,
            basePrice: nil,
            baseUnit: nil,
            matchKey: tags
        )
    }

    /// Der tiefste Rabatt zuerst — ein Vorschlag hat einen Grund dieser Woche,
    /// das ist der ganze Unterschied zu einer längeren Festliste.
    func testExamplesRankByDiscountAndNameTheirMarket() {
        let examples = FirstItemSuggestions.examples(from: [
            offer("Markenbutter", market: "Kaufland", price: 1.39, regular: 1.99, tags: ["butter"]),
            offer("Röstkaffee", market: "Penny", price: 4.79, regular: 5.99, tags: ["kaffee"]),
            offer("Vollmilch", market: "Lidl", tags: ["milch"]),
        ])

        XCTAssertEqual(examples.map(\.word), ["Butter", "Kaffee", "Milch"])
        XCTAssertEqual(examples.first?.market, "Kaufland")
        XCTAssertEqual(examples.first?.reason, "diese Woche bei Kaufland im Angebot")
    }

    func testExamplesStopAtThree() {
        let offers = ["butter", "kaffee", "milch", "eier", "nudeln"].map {
            offer($0, tags: [$0])
        }
        XCTAssertEqual(FirstItemSuggestions.examples(from: offers).count, 3,
                       "mehr wäre wieder eine Liste — die soll der Nutzer selbst schreiben")
    }

    /// Dieselben Regeln wie im Vorschlagsstreifen: kein Alkohol ungefragt,
    /// kein Nonfood-Tag als Listenwort.
    func testExamplesKeepTheSuggestionRules() {
        let examples = FirstItemSuggestions.examples(from: [
            offer("Pilsener", price: 0.99, regular: 1.99, tags: ["bier"]),
            offer("Spülmaschinentabs", price: 3.99, regular: 7.99, tags: ["nonfood"]),
            offer("Markenbutter", tags: ["butter"]),
        ])

        XCTAssertEqual(examples.map(\.word), ["Butter"])
    }

    func testDismissedExamplesStayGone() {
        let offers = [
            offer("Markenbutter", regular: 2.99, tags: ["butter"]),
            offer("Vollmilch", tags: ["milch"]),
        ]
        let examples = FirstItemSuggestions.examples(from: offers, excluding: ["Butter"])
        XCTAssertEqual(examples.map(\.word), ["Milch"])
    }

    func testWithoutOffersThereAreNoExamples() {
        XCTAssertTrue(FirstItemSuggestions.examples(from: []).isEmpty)
    }

    // MARK: Der eine Satz

    /// „Füg mal ‚Milch‘ hinzu" — und wer die Milch eben weggewischt hat,
    /// bekommt nicht dieselbe Milch noch einmal angeboten.
    func testThePromptSkipsWhatWasJustDismissed() {
        XCTAssertEqual(FirstItemSuggestions.prompt(), "Milch")
        XCTAssertEqual(FirstItemSuggestions.prompt(excluding: ["Milch"]), "Brot")
    }
}
