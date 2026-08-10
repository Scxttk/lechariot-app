import XCTest
@testable import LeChariot

/// Die Frage nach den Filialen — der Rest des `TutorialStore`, den der Abriss
/// des Rundgangs übrig lässt.
///
/// Die Zusagen sind die alten, nur hängen sie jetzt am Abschluss des
/// Assistenten statt am Ende des Rundgangs: **Wer ohne Filiale herauskommt,
/// wird gefragt — und zwar genau einmal.**
@MainActor
final class MarketPromptStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "MarketPromptStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore() -> MarketPromptStore {
        MarketPromptStore(defaults: defaults)
    }

    func testWithoutMarketsTheQuestionStands() {
        let store = makeStore()
        store.onboardingFinished(hasMarkets: false)
        XCTAssertTrue(store.asksForMarkets)
    }

    func testWithMarketsNobodyIsAsked() {
        let store = makeStore()
        store.onboardingFinished(hasMarkets: true)
        XCTAssertFalse(store.asksForMarkets)
    }

    /// **Einmal, und dann nie wieder** — auch nicht nach einem Neustart. Das
    /// Sheet ist ein Angebot und keine Mahnung; danach bleiben der Leerzustand
    /// der Liste und die Einstellungen als Wege.
    func testAnAnsweredQuestionNeverComesBack() {
        let store = makeStore()
        store.onboardingFinished(hasMarkets: false)
        store.dismissMarketQuestion()
        XCTAssertFalse(store.asksForMarkets)

        let restarted = makeStore()
        XCTAssertTrue(restarted.hasAnsweredMarketPrompt)
        restarted.onboardingFinished(hasMarkets: false)
        XCTAssertFalse(restarted.asksForMarkets)
    }

    /// Nach dem Zurücksetzen ist die Installation eine neue — und eine neue
    /// wird wieder gefragt.
    func testResetMakesTheQuestionDueAgain() {
        let store = makeStore()
        store.onboardingFinished(hasMarkets: false)
        store.dismissMarketQuestion()
        store.resetAllData()
        XCTAssertFalse(store.hasAnsweredMarketPrompt)

        let restarted = makeStore()
        restarted.onboardingFinished(hasMarkets: false)
        XCTAssertTrue(restarted.asksForMarkets)
    }
}

/// Was der alte Rundgang auf Platte gelassen hat — siehe `TourResidue`.
@MainActor
final class TourResidueTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "TourResidueTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Der Fall, für den es das Aufräumen gibt: Ein Gerät, das den Rundgang vor
    /// dem 09.08. mitten im Lauf verloren hat, trägt seine drei geliehenen
    /// Artikel weiter — und niemand wüsste, woher sie kommen.
    func testTheBorrowedItemsComeOffTheListOnce() {
        let list = ShoppingListStore(defaults: defaults)
        _ = list.add("Milch")
        _ = list.add("Kaffee")
        guard let geliehen = list.items.first(where: { $0.text == "Milch" }) else {
            return XCTFail("Der Artikel steht nicht auf der Liste")
        }
        let data = try? JSONEncoder().encode([geliehen])
        defaults.set(data, forKey: "tutorial.seededItems")
        defaults.set(true, forKey: "tutorial.hasSeen")

        TourResidue.sweep(from: list, defaults: defaults)

        XCTAssertEqual(list.items.map(\.text), ["Kaffee"],
                       "Nur der geliehene Artikel geht, der eigene bleibt")
        for key in TourResidue.keys {
            XCTAssertNil(defaults.object(forKey: key), "\(key) muss weg sein")
        }
    }

    func testWithoutResidueNothingHappens() {
        let list = ShoppingListStore(defaults: defaults)
        _ = list.add("Butter")
        TourResidue.sweep(from: list, defaults: defaults)
        XCTAssertEqual(list.items.count, 1)
    }
}
