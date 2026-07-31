import XCTest
@testable import LeChariot

/// **Der persönliche Vorschlagsstreifen — ein gewichteter Zähler, sonst nichts.**
///
/// Die Regeln stehen im [[Le Chariot Liste-Konzept]] und sind fast alle
/// Verneinungen: Hinzufügen zählt **nicht**, „Liste leeren" löscht **nicht**,
/// Alkohol wird **nicht** vorgeschlagen. Verneinungen gehen still verloren —
/// wer den Zähler später ans Hinzufügen hängt, sieht nichts kaputtgehen, außer
/// hier.
@MainActor
final class PurchaseHistoryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    /// Fester Stichtag: Mit `.now` würde die Alterung die Erwartungen unter
    /// den Tests verschieben, je nachdem wann sie laufen.
    private let heute = Date(timeIntervalSince1970: 1_800_000_000)

    private func wochen(_ n: Double) -> Date {
        heute.addingTimeInterval(-n * 7 * 24 * 60 * 60)
    }

    override func setUp() {
        super.setUp()
        suiteName = "history.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func store() -> PurchaseHistoryStore {
        PurchaseHistoryStore(defaults: defaults)
    }

    // MARK: Zählen

    func testWhatIsBoughtOftenComesFirst() {
        let s = store()
        for _ in 0..<3 { s.record("Milch", now: heute) }
        s.record("Kaffee", now: heute)
        XCTAssertEqual(s.top(2, now: heute), ["milch", "kaffee"])
    }

    /// Groß/klein und Leerraum sind derselbe Kauf — sonst stünde „Butter"
    /// dreimal im Streifen, weil jemand einmal „butter " getippt hat.
    func testTheSameWordInAnotherSpellingIsTheSamePurchase() {
        let s = store()
        s.record("Butter", now: heute)
        s.record("  butter ", now: heute)
        XCTAssertEqual(s.distinctWords, 1)
        XCTAssertEqual(s.entries["butter"]?.weight, 2)
    }

    /// **Alterung.** Nach acht Wochen zählt ein Kauf noch halb. Ohne das steht
    /// der Streifen nach einem halben Jahr fest, und wer sich umstellt, sieht
    /// weiter seine alten Gewohnheiten.
    func testAnOldPurchaseWeighsLessThanARecentOne() {
        let s = store()
        // Zwei Käufe vor 16 Wochen (2 × ¼ = 0,5) gegen einen von heute (1,0).
        s.record("Wurst", now: wochen(16))
        s.record("Wurst", now: wochen(16))
        s.record("Tofu", now: heute)
        XCTAssertEqual(s.top(2, now: heute), ["tofu", "wurst"])
    }

    /// Und die Gegenprobe, ohne die der Test oben auch von einem kaputten
    /// Zähler erfüllt würde: Ohne Altersunterschied gewinnt die Menge.
    func testWithoutAnAgeDifferenceTheCountDecides() {
        let s = store()
        s.record("Wurst", now: heute)
        s.record("Wurst", now: heute)
        s.record("Tofu", now: heute)
        XCTAssertEqual(s.top(2, now: heute), ["wurst", "tofu"])
    }

    /// Gleichstand geht nach Wort und nicht nach Zufall — ein Streifen, dessen
    /// Reihenfolge bei jedem Zeichnen wechselt, sieht aus wie ein Fehler.
    func testATieIsBrokenByTheWordSoTheStripDoesNotJump() {
        let s = store()
        for wort in ["Zucker", "Apfel", "Milch"] { s.record(wort, now: heute) }
        XCTAssertEqual(s.top(3, now: heute), ["apfel", "milch", "zucker"])
    }

    // MARK: Kaltstart und Grenzen

    func testTheStaplesGoAwayOnlyOnceEnoughDistinctWordsAreThere() {
        let s = store()
        for i in 0..<(PurchaseHistoryStore.coldStartThreshold - 1) {
            s.record("wort\(i)", now: heute)
        }
        XCTAssertTrue(s.needsStaples, "Ein Wort zu wenig — die festen müssen bleiben")

        s.record("letztes", now: heute)
        XCTAssertFalse(s.needsStaples)
    }

    /// Über der Obergrenze fallen die **leichtesten** Einträge weg, nicht die
    /// zuletzt eingetragenen.
    func testAboveTheCapTheLightestEntriesGo() {
        let s = store()
        for i in 0..<PurchaseHistoryStore.capacity {
            s.record("fuellwort\(i)", now: heute)
            s.record("fuellwort\(i)", now: heute)   // Gewicht 2
        }
        s.record("einmalig", now: heute)            // Gewicht 1, das leichteste

        XCTAssertEqual(s.distinctWords, PurchaseHistoryStore.capacity)
        XCTAssertNil(s.entries["einmalig"], "Der leichteste Eintrag muss weichen")
        XCTAssertNotNil(s.entries["fuellwort0"])
    }

    // MARK: Vergessen

    func testTheHistorySurvivesARestart() {
        let s = store()
        s.record("Käse", now: heute)
        XCTAssertEqual(store().top(1, now: heute), ["käse"])
    }

    /// **„Vorschläge vergessen" räumt wirklich ab** — auch auf der Platte, und
    /// nicht nur im Speicher. Ein zurückgelassener leerer Datensatz wäre kein
    /// Vergessen, sondern ein Vergessen-Aussehen.
    func testForgettingWipesMemoryAndDisk() {
        let s = store()
        s.record("Bier", now: heute)
        s.forget()
        XCTAssertTrue(s.entries.isEmpty)
        XCTAssertNil(defaults.data(forKey: "purchase.history"))
        XCTAssertTrue(store().entries.isEmpty, "Nach einem Neustart wäre sie wieder da")
    }

    func testExcludedWordsDoNotAppear() {
        let s = store()
        s.record("Milch", now: heute)
        s.record("Brot", now: heute)
        XCTAssertEqual(s.top(2, excluding: ["milch"], now: heute), ["brot"])
    }
}

// MARK: - Der Streifen

/// Die drei Stufen des Vorschlagsstreifens, und die Wörter, die nie darin
/// stehen dürfen.
final class PersonalSuggestionStripTests: XCTestCase {

    private func offer(_ product: String, tags: [String], discount: Int?) -> Offer {
        var o = Offer(
            market: "Lidl", product: product,
            price: discount.map { 100 - Double($0) } ?? 1.0,
            regularPrice: discount != nil ? 100 : nil,
            unit: nil, category: "Sonstiges", emoji: nil,
            validFrom: Date(timeIntervalSince1970: 0),
            validUntil: Date(timeIntervalSince1970: 604_800),
            basePrice: nil, baseUnit: nil, nationwide: false
        )
        o.matchKey = tags
        return o
    }

    /// Stufe 1 steht vorn. Das ist der ganze Punkt der Änderung.
    func testWhatTheHouseholdBuysComesBeforeTheStaples() {
        let strip = ShoppingSuggestions.strip(
            for: [], offers: [], history: ["hafermilch", "gulasch"], limit: 4
        )
        XCTAssertEqual(Array(strip.prefix(2)), ["Hafermilch", "Gulasch"])
    }

    /// Der Kaltstart lässt sich abschalten — und dann sind die acht festen
    /// Wörter wirklich weg, nicht nur nach hinten geschoben.
    func testWithoutTheColdStartTheStaplesAreGone() {
        let strip = ShoppingSuggestions.strip(
            for: [], offers: [offer("Gouda", tags: ["käse"], discount: 20)],
            history: ["hafermilch"], includeStaples: false
        )
        XCTAssertEqual(strip, ["Hafermilch", "Käse"])
        XCTAssertFalse(strip.contains("Brot"), "Die Grundnahrungsmittel sind Kaltstart, nicht Inventar")
    }

    /// **Alkohol wird nicht vorgeschlagen** — aus keiner der beiden Quellen.
    ///
    /// Nicht moralisch begründet: Das Telefon wird herumgereicht, und die App
    /// liegt auf den Geräten von Scotts Großeltern. Ein Streifen, der „Bier"
    /// hochspült, erzählt jedem, der gerade draufschaut, etwas über den
    /// Haushalt.
    func testAlcoholIsHeldBackFromBothSources() {
        let ausHistorie = ShoppingSuggestions.strip(
            for: [], offers: [], history: ["bier", "pils", "milch"], includeStaples: false
        )
        XCTAssertEqual(ausHistorie, ["Milch"], "geliefert: \(ausHistorie)")

        let ausAngeboten = ShoppingSuggestions.strip(
            for: [], offers: [
                offer("Radeberger Pilsner", tags: ["bier"], discount: 50),
                offer("Gouda jung", tags: ["käse"], discount: 10),
            ],
            includeStaples: false
        )
        XCTAssertEqual(ausAngeboten, ["Käse"], "geliefert: \(ausAngeboten)")
    }

    /// Die Sperre geht übers Wörterbuch, nicht über eine eigene Wortliste —
    /// „Prosecco" ist dort ein Synonym von `wein`, ohne dass es hier steht.
    func testTheBlockRidesOnTheDictionaryNotOnASecondList() {
        XCTAssertFalse(ShoppingSuggestions.maySuggest("Prosecco"))
        XCTAssertFalse(ShoppingSuggestions.maySuggest("Wodka"))
        XCTAssertTrue(ShoppingSuggestions.maySuggest("Traubensaft"))
        XCTAssertTrue(ShoppingSuggestions.maySuggest("Milch"))
    }

    /// Der persönliche Teil ist gedeckelt: Der Streifen soll nicht zur
    /// Historie werden, was diese Woche im Angebot ist muss sichtbar bleiben.
    func testThePersonalPartIsCapped() {
        let viele = (0..<10).map { "wort\($0)" }
        let strip = ShoppingSuggestions.strip(
            for: [], offers: [], history: viele, includeStaples: false, limit: 8
        )
        XCTAssertEqual(strip.count, ShoppingSuggestions.personalLength)
    }

    /// Was schon auf der Liste steht, wird nicht noch einmal vorgeschlagen —
    /// die Regel galt vorher und muss für die neue Stufe genauso gelten.
    func testWhatIsAlreadyOnTheListIsNotSuggestedAgain() {
        let strip = ShoppingSuggestions.strip(
            for: [ShoppingItem(text: "Hafermilch")],
            offers: [], history: ["hafermilch", "gulasch"], includeStaples: false
        )
        XCTAssertEqual(strip, ["Gulasch"])
    }
}
