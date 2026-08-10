import XCTest
@testable import LeChariot

@MainActor
final class TutorialStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "tutorial.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeStore() -> TutorialStore {
        TutorialStore(defaults: defaults)
    }

    private func makeList() -> ShoppingListStore {
        ShoppingListStore(defaults: defaults)
    }

    // MARK: Der Rundgang selbst

    func testAFreshInstallHasNotSeenTheTour() {
        let store = makeStore()
        XCTAssertFalse(store.hasSeenTutorial)
        XCTAssertFalse(store.isRunning)
    }

    /// Er startet nie von allein — nur auf „Los geht's" oder aus den
    /// Einstellungen. Das ist der Unterschied zwischen Hilfe und Belästigung.
    func testTheTourOnlyRunsWhenItIsAskedFor() {
        let store = makeStore()
        XCTAssertFalse(store.isRunning)

        store.start(origin: .settings, hasMarkets: true)
        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.index, 0)
    }

    func testEveryStepIsReachedBeforeTheTourEnds() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)

        for expected in 0..<store.stepCount {
            XCTAssertEqual(store.index, expected)
            XCTAssertTrue(store.isRunning)
            store.next()
        }

        XCTAssertFalse(store.isRunning, "Weiter auf dem letzten Rahmen beendet den Rundgang")
    }

    func testFinishingIsRemembered() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)
        while store.isRunning { store.next() }

        XCTAssertTrue(store.hasSeenTutorial)
        XCTAssertTrue(makeStore().hasSeenTutorial, "der Merker muss den Neustart überleben")
    }

    /// Abbrechen zählt wie Durchlaufen: Wer „Tour beenden" tippt, will nicht
    /// beim nächsten Start wieder gefragt werden.
    func testAbortingCountsAsSeen() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)
        store.next()
        store.skip()

        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.index, 0)
        XCTAssertTrue(makeStore().hasSeenTutorial)
    }

    func testDecliningTheOfferCountsAsSeenToo() {
        let store = makeStore()
        store.decline(hasMarkets: true)

        XCTAssertFalse(store.isRunning)
        XCTAssertTrue(makeStore().hasSeenTutorial)
    }

    // MARK: Das Angebot am Ende des Assistenten

    /// **Der Fund vom 2026-08-02.** Der Merker wurde geschrieben und von keiner
    /// Ansicht gelesen; `OnboardingFlowView.offersTour` gab `true` zurück. Ein
    /// zweiter Lauf des Assistenten — aus welchem Grund auch immer — bot den
    /// Rundgang deshalb wieder an. Diese vier Fälle sind die Regel, die es
    /// vorher nur im Kommentar gab.
    func testTheTourIsOfferedOnceAndThenNotAgain() {
        XCTAssertTrue(makeStore().offersTourAfterOnboarding,
                      "frische Installation: der Rundgang wird angeboten")

        let store = makeStore()
        store.decline(hasMarkets: true)
        XCTAssertFalse(store.offersTourAfterOnboarding)
        XCTAssertFalse(makeStore().offersTourAfterOnboarding,
                       "und auch nach einem Neustart nicht wieder — das war die Meldung")
    }

    func testWalkingTheTourAlsoEndsTheOffer() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)
        while store.isRunning { store.next() }

        XCTAssertFalse(makeStore().offersTourAfterOnboarding)
    }

    /// Die Gegenrichtung, und sie ist gewollt: Wer alles zurücksetzt, ist eine
    /// neue Installation und bekommt den Rundgang wieder angeboten.
    func testAnExplicitResetOffersTheTourAgain() {
        let store = makeStore()
        store.decline(hasMarkets: true)
        XCTAssertFalse(store.offersTourAfterOnboarding)

        store.resetAllData()
        XCTAssertTrue(store.offersTourAfterOnboarding)
        XCTAssertTrue(makeStore().offersTourAfterOnboarding,
                      "kein Schlüssel darf den Reset überleben")
    }

    func testStepsAreDistinctAndSpeakGerman() {
        let store = makeStore()
        XCTAssertEqual(Set(store.steps.map(\.id)).count, store.steps.count, "doppelte Schritt-IDs")
        for step in store.steps {
            XCTAssertFalse(step.title.isEmpty)
            XCTAssertFalse(step.text.isEmpty)
        }
    }

    /// **Jetzt lässt jeder Rahmen bis auf den letzten durch** — bis zum 09.08.
    /// war es genau einer.
    ///
    /// Die Umkehr gehört zum Prinzipwechsel: Ein Rahmen, der auf eine Handlung
    /// wartet, **muss** sie zulassen. Was bleibt, ist die andere Hälfte der
    /// alten Zusicherung — durchgelassen wird nur, was im Loch liegt, und die
    /// Schlusskarte lässt gar nichts durch.
    func testEveryWaitingStepLetsTouchesThrough() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)

        XCTAssertEqual(store.steps.filter { !$0.allowsInteraction }.map(\.id), ["done"])
    }

    /// **Kein Rahmen läuft von allein weiter — er läuft weiter, wenn der Nutzer
    /// das Richtige tut.**
    ///
    /// Bis zum 2026-07-30 sprangen zwei Rahmen los, sobald ein Artikel auf der
    /// Liste landete (`advance: .itemAdded`) — mitten im Lesen, gemeldet vom
    /// ersten Tester außerhalb des Hauses. **Seit dem 09.08. ist genau das
    /// wieder der Weg**, aber als einziger und angesagt: Der Store selbst
    /// bewegt sich nur auf `report`, und ein Artikel, den niemand über den
    /// Melder anmeldet, bewegt gar nichts.
    func testTheStoreOnlyMovesOnAReportedDeed() {
        let store = makeStore()
        let list = makeList()
        store.start(origin: .settings, hasMarkets: true)
        let before = store.index

        _ = list.add("Butter")
        _ = list.add("Milch")

        XCTAssertEqual(store.index, before,
                       "der Store liest die Liste nicht mit — er wartet auf die Meldung")
        XCTAssertTrue(store.isRunning)
    }

    /// Auf dem letzten Rahmen heißt der Primärknopf „Fertig" und tut dasselbe
    /// wie „Tour beenden" — deshalb blendet das Overlay den Abbruch dort aus.
    /// Der Test hält die Bedingung fest, an der es hängt.
    func testTheLastStepIsTheOnlyOneWhereFinishingAndAbortingAreTheSame() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)

        for _ in 0..<(store.steps.count - 1) {
            XCTAssertFalse(store.isLastStep, "Schritt \(store.index) ist nicht der letzte")
            store.next()
        }

        XCTAssertTrue(store.isLastStep)
    }

    // MARK: Die Frage nach den Filialen

    /// Der eigentliche Punkt des Umbaus vom 2026-07-31: Das Onboarding endet in
    /// der Liste, der Rundgang zeigt sie, und **am Ende** wird gefragt.
    func testATourFromOnboardingWithoutMarketsAsksForThemAtTheEnd() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)
        while store.isRunning { store.next() }

        XCTAssertTrue(store.asksForMarkets)
        store.dismissMarketQuestion()
        XCTAssertFalse(store.asksForMarkets, "beantwortet ist beantwortet")
    }

    /// Auch der Abbruch führt zur Frage: Wer „Tour beenden" tippt, hat trotzdem
    /// keine Filiale, und ihn still in einer Liste stehenzulassen, die nichts
    /// vergleichen kann, wäre die Sackgasse von vorher.
    func testAbortingATourFromOnboardingAsksToo() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)
        store.next()
        store.skip()

        XCTAssertTrue(store.asksForMarkets)
    }

    /// **Die Bedingung, die bestehende Installationen schützt.** Wer den
    /// Rundgang aus den Einstellungen noch einmal ansieht, wird nie gefragt —
    /// egal ob er gerade Filialen hat oder nicht.
    func testATourFromTheSettingsNeverAsks() {
        for hasMarkets in [true, false] {
            let store = makeStore()
            store.start(origin: .settings, hasMarkets: hasMarkets)
            while store.isRunning { store.next() }

            XCTAssertFalse(store.asksForMarkets,
                           "aus den Einstellungen, hasMarkets: \(hasMarkets)")
        }
    }

    /// Und der andere Rand: aus dem Onboarding, aber mit Filialen — der Fall
    /// einer Installation, die ihre Filialen vor dem Umbau gewählt hat und den
    /// Assistenten neu durchläuft.
    func testATourFromOnboardingWithMarketsDoesNotAsk() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: true)
        while store.isRunning { store.next() }

        XCTAssertFalse(store.asksForMarkets)
    }

    /// Ein zweiter Rundgang darf nicht die Antwort des ersten erben.
    func testStartingAgainClearsAPendingQuestion() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)
        store.skip()
        XCTAssertTrue(store.asksForMarkets)

        store.start(origin: .settings, hasMarkets: false)
        XCTAssertFalse(store.asksForMarkets)
    }

    /// **Der Weg, den es vorher nicht gab** (05.08.): Wer das Angebot mit
    /// „Später" ablehnt und keine Filiale hat, bekommt die Markt-Frage
    /// trotzdem. Vorher hing sie nur am Ende des Rundgangs — Überspringer
    /// standen wortlos vor einer Liste, die nichts vergleichen kann.
    func testDecliningTheOfferWithoutMarketsAsksToo() {
        let store = makeStore()
        store.decline(hasMarkets: false)

        XCTAssertTrue(store.asksForMarkets)
    }

    /// Und die Gegenrichtung: Wer beim Ablehnen schon Filialen hat, hat die
    /// Frage längst beantwortet — für bestehende Installationen ändert sich
    /// nichts.
    func testDecliningTheOfferWithMarketsDoesNotAsk() {
        let store = makeStore()
        store.decline(hasMarkets: true)

        XCTAssertFalse(store.asksForMarkets)
    }

    // MARK: Was der Rundgang sagt

    /// **Ohne Filiale fallen die zwei Angebote-Rahmen weg, statt umformuliert
    /// zu werden** (09.08.).
    ///
    /// Bis dahin drehte `hasMarkets` nur einen Text: Der Plan-Rahmen sprach in
    /// der Zukunft, wenn die Karte den Leerzustand zeigte. Ein Rahmen, der auf
    /// eine **Handlung** wartet, kann das nicht — auf dem Angebote-Tab steht
    /// ohne Filiale „Keine Filiale gewählt", es gibt weder Liste noch
    /// Vorschau-Knopf. Ein Rahmen, der auf einen Tipp wartet, den man nicht tun
    /// kann, ist eine Sackgasse; also gibt es ihn dort nicht.
    ///
    /// **Und das ist der Normalfall**, nicht der Sonderfall: Seit dem
    /// 2026-07-31 endet das Onboarding in der Liste statt in der Filialauswahl.
    func testWithoutBranchesTheOffersFramesAreGoneEntirely() {
        let withMarkets = TutorialStep.tour(hasMarkets: true)
        let without = TutorialStep.tour(hasMarkets: false)

        XCTAssertEqual(withMarkets.map(\.id),
                       ["input", "check", "offers", "nextWeek", "done"])
        XCTAssertEqual(without.map(\.id), ["input", "check", "done"])

        XCTAssertFalse(
            without.contains { $0.tab != .liste },
            "ohne Filiale bleibt der Rundgang auf der Liste — dort ist alles, was er zeigen kann"
        )
        XCTAssertFalse(
            without[0].text.contains("günstigsten"),
            "ohne Filiale verspricht der erste Rahmen keinen Preisvergleich"
        )
    }

    /// Dasselbe am anderen Schalter: Ohne die Vorschau gibt es den Knopf
    /// „Nächste Woche" nicht — und dann fällt der Rahmen zur Tab-Leiste mit weg,
    /// denn er ist der Weg dorthin.
    func testWithoutTheNextWeekPreviewTheOffersFramesAreGoneToo() {
        let ohneVorschau = TutorialStep.tour(hasMarkets: true, showsNextWeek: false)

        XCTAssertEqual(ohneVorschau.map(\.id), ["input", "check", "done"])
        XCTAssertFalse(ohneVorschau.contains { $0.tab != .liste })
        XCTAssertFalse(
            ohneVorschau.last!.text.contains("Filiale gewählt"),
            "mit Filialen ist der Abschied nicht der Satz für jemanden ohne"
        )
    }

    // MARK: Der Nutzer tippt selbst (09.08.)

    /// **Jeder Rahmen bis auf den letzten wartet auf eine eigene Handlung.**
    ///
    /// Das ist der Prinzipwechsel aus Scotts Bedienrunde vom 08.08. als
    /// Zusicherung: Der Rundgang führt nichts mehr vor. Wer hier einen Rahmen
    /// hinzufügt, muss sagen, was der Nutzer dafür tut — sonst ist es wieder
    /// eine Folie.
    ///
    /// **Dieser Test ersetzt `testTheTourShowsTheThreeHandlesAndNothingElse`**,
    /// der seit dem 06.08. die drei Rahmen festhielt („aufschreiben, den Markt
    /// ablesen, im Laden abhaken"). Er stand dort absichtlich, damit die
    /// Kürzung nicht versehentlich zurückgedreht wird — hier wird sie
    /// **absichtlich** verändert: Der Plan-Rahmen fällt weg (die Karte
    /// erscheint jetzt als Folge der eigenen ersten Eingabe, der Satz dazu steht
    /// in Rahmen 1), und eine Stelle kommt dazu, die Scott ausdrücklich genannt
    /// hat — die Vorschau „Nächste Woche".
    ///
    /// Was von der Lehre vom 06.08. bleibt: **kein Rahmen, der zeigt, was man
    /// ohnehin sieht.** Deshalb ist es hier eine Aussage über Handlungen und
    /// nicht über Bildschirmelemente.
    func testEveryFrameButTheLastWaitsForTheUsersOwnTap() {
        let tour = TutorialStep.tour(hasMarkets: true)

        XCTAssertEqual(
            tour.map(\.deed),
            [.addsItem, .checksItem, .opensOffersTab, .opensNextWeek, .reads]
        )
        XCTAssertEqual(tour.filter { $0.deed == .reads }.map(\.id), ["done"],
                       "genau eine Karte ist zum Lesen da, und das ist der Abschied")
        XCTAssertEqual(tour.last?.id, "done", "und sie steht am Ende")
    }

    /// Die Stelle aus Scotts Liste, an ihrem Anker — ohne Rundgang praktisch
    /// nicht zu finden: Die Vorschau liegt hinter einem Knopf in der
    /// Navigationsleiste des Angebote-Tabs.
    ///
    /// **Die zweite Stelle ist am 10.08. weggefallen.** Sie war das
    /// Vorschläge-Menü hinter dem Winkel-Knopf; seit Punkt E steht die Fläche
    /// von selbst da, sobald die Tastatur kommt, und der Knopf existiert nicht
    /// mehr. Die Gegenprobe steht gleich darunter.
    func testTheTourShowsThePlaceNobodyFindsOnTheirOwn() {
        let tour = TutorialStep.tour(hasMarkets: true)

        XCTAssertNil(tour.first { $0.id == "suggestions" },
                     "Der Rahmen zeigt auf einen Knopf, den es nicht mehr gibt")
        XCTAssertEqual(tour.first { $0.id == "nextWeek" }?.spotlight, .navBar)
        XCTAssertEqual(tour.first { $0.id == "done" }?.spotlight,
                       .anchor(.nextWeekNotice),
                       "die Schlusskarte erklärt die Hinweiszeile aus #90")
    }

    /// **Ein Rahmen, der eine Handlung erwartet, muss sie zulassen** — sonst
    /// ist er eine Sackgasse. Und die Schlusskarte lässt nichts durch: Dort ist
    /// nichts mehr zu tun.
    func testWaitingFramesLetTheTouchThrough() {
        for step in TutorialStep.tour(hasMarkets: true) {
            XCTAssertEqual(step.allowsInteraction, step.deed != .reads, step.id)
        }
    }

    /// **Und er bleibt kurz.** Seit dem 10.08. sind es fünf Rahmen — die Zahl
    /// aus der Onboarding-Forschung, wenn auch aus Touren zum *Lesen*. Hier ist
    /// jeder Rahmen ein Tipp und der letzte der Abschied. Die Grenze steht,
    /// damit „noch einer" eine Entscheidung bleibt und keine Gewohnheit.
    func testTheTourStaysShort() {
        XCTAssertLessThanOrEqual(
            TutorialStep.tour(hasMarkets: true).count, 6,
            "Mehr als fünf Handgriffe und einen Abschied macht niemand mit"
        )
    }

    /// **Der Rundgang verlässt die Liste nur, weil der Nutzer ihn hinüberträgt.**
    ///
    /// Bis zum 06.08. wechselte er zweimal von allein den Tab, und das war
    /// Scotts „visuell desaströs" vom 03.08. — eine `TabView` blendet nicht
    /// über, sie tauscht. Jetzt tippt der Nutzer selbst auf „Angebote", und der
    /// Rahmen **davor** steht noch auf der Liste. Damit gibt es keinen
    /// Tab-Wechsel mehr, den niemand bestellt hat.
    func testTheTourOnlyLeavesTheListBehindTheUsersOwnTap() {
        let tour = TutorialStep.tour(hasMarkets: true)

        XCTAssertEqual(tour.filter { $0.tab != .liste }.map(\.id), ["nextWeek", "done"])
        XCTAssertEqual(tour.first { $0.id == "offers" }?.tab, .liste,
                       "der Rahmen, der um den Tipp bittet, steht noch auf der Liste")
    }

    /// **Der Melder schaltet nur den Rahmen weiter, der auf ihn wartet.**
    /// Wer im dritten Rahmen einen weiteren Artikel anlegt, hat den ersten nicht
    /// noch einmal erledigt.
    func testOnlyTheDeedTheCurrentFrameAsksForMovesItOn() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)

        store.report(.checksItem)
        XCTAssertEqual(store.index, 0, "eine fremde Handlung schaltet nicht weiter")

        store.report(.addsItem)
        XCTAssertEqual(store.index, 1)

        store.report(.addsItem)
        XCTAssertEqual(store.index, 1, "und dieselbe zweimal auch nicht")

        store.report(.checksItem)
        XCTAssertEqual(store.index, 2)
    }

    /// **Das Angebot am Ende des Onboardings zählt seine Handgriffe, statt sie
    /// zu behaupten.**
    ///
    /// Hier stand bis zum 09.08. eine Liste von Hand, und drei ihrer vier
    /// Zeilen waren falsch geworden („Ablesen, welcher Markt am günstigsten
    /// ist", „Filialen wählen und ändern"). Der Kommentar berief sich auf einen
    /// Wächter, den es nie gab — den gibt es jetzt, und die Liste kommt aus dem
    /// Rundgang selbst.
    func testTheOfferListsExactlyTheToursOwnDeeds() {
        let handgriffe = TutorialStep.tour(hasMarkets: false).filter { $0.deed != .reads }

        XCTAssertEqual(TourStepView.frameCount, handgriffe.count)
        XCTAssertEqual(TourStepView.points.count, handgriffe.count)
        XCTAssertFalse(TourStepView.points.contains { $0.text.isEmpty })
        XCTAssertTrue(TourStepView.subtitle.hasPrefix("Zwei Handgriffe"),
                      "Das Zahlwort muss zur Zahl passen: \(TourStepView.subtitle)")
    }

    /// Melden darf jeder, immer — die Melder sitzen in Ansichten, die es auch
    /// ohne Rundgang gibt.
    func testReportingWhileNoTourRunsDoesNothing() {
        let store = makeStore()
        store.report(.addsItem)

        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.index, 0)
    }

    /// Der Store friert die Fassung beim Start ein — die Filialauswahl liegt
    /// während des Rundgangs hinter den Sperrflächen, ein Text, der mitten im
    /// Lesen die Zeitform wechselt, wäre schlimmer als ein veralteter.
    func testTheStoreKeepsTheVariantItStartedWith() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)

        XCTAssertEqual(store.steps.map(\.text),
                       TutorialStep.tour(hasMarkets: false).map(\.text))
    }

    // MARK: Beispiel-Artikel — der Rückweg für alte Installationen

    /// **Der Rundgang legt seit dem 09.08. nichts mehr auf die Liste**, und
    /// genau deshalb steht dieser Test hier.
    ///
    /// Bis dahin lieh er sich Milch, Butter und Kaffee, weil der Plan-Rahmen
    /// sonst auf einen Leerzustand gezeigt hätte, und räumte sie am Ende wieder
    /// ab. Wer die App mitten im Rundgang abgeschossen hat, hat sie noch — auf
    /// Platte, unter `tutorial.seededItems`. Das Abräumen muss den Umbau
    /// deshalb überleben, sonst stehen auf diesen Geräten für immer drei
    /// Artikel, die niemand geschrieben hat und deren Herkunft niemand erklären
    /// kann.
    ///
    /// Der Zustand wird hier direkt hingelegt, nicht mehr erzeugt: Die
    /// Funktion, die ihn erzeugt hat, gibt es nicht mehr — das **ist** der Fall.
    func testItemsAnOldTourLeftBehindAreStillTidiedAway() {
        let list = makeList()
        list.add("Milch")
        list.add("Butter")
        list.add("Zahnstocher")
        let geliehen = list.items.filter { $0.text != "Zahnstocher" }
        defaults.set(try! JSONEncoder().encode(geliehen), forKey: "tutorial.seededItems")

        let afterUpdate = makeStore()
        XCTAssertEqual(afterUpdate.seededItems.count, 2, "der alte Merker wird gelesen")

        afterUpdate.removeDemoItems(from: list)

        XCTAssertEqual(list.items.map(\.text), ["Zahnstocher"],
                       "was der Nutzer selbst geschrieben hat, bleibt stehen")
        XCTAssertTrue(makeStore().seededItems.isEmpty,
                      "und der Merker geht mit — sonst räumt jeder Start noch einmal auf")
    }

    // MARK: Zurücksetzen

    func testResetPutsEverythingBack() {
        let store = makeStore()
        let list = makeList()
        // Aus dem Onboarding und ohne Filialen: der einzige Weg, bei dem am
        // Ende eine Frage offensteht — sonst prüfte die Zusicherung unten nur
        // einen Wert, der ohnehin nie gesetzt war.
        store.start(origin: .onboarding, hasMarkets: false)
        store.finish()
        // Die Frage auch beantworten: Nur so liegt der Einmal-Merker auf der
        // Platte, dessen Abräumen unten zugesichert wird.
        store.dismissMarketQuestion()

        store.resetAllData()

        XCTAssertFalse(store.hasSeenTutorial)
        XCTAssertTrue(store.seededItems.isEmpty)
        XCTAssertFalse(store.asksForMarkets, "auch eine offene Frage gehört weggeräumt")
        XCTAssertFalse(store.hasAnsweredMarketPrompt,
                       "nach dem Reset ist die Installation neu — und darf wieder gefragt werden")
        let fresh = makeStore()
        XCTAssertFalse(fresh.hasSeenTutorial, "kein Schlüssel darf auf der Platte zurückbleiben")
        XCTAssertTrue(fresh.seededItems.isEmpty)
        XCTAssertFalse(fresh.hasAnsweredMarketPrompt)
    }
}
