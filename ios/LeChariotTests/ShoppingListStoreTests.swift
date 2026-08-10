import XCTest
@testable import LeChariot

@MainActor
final class ShoppingListStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ShoppingListStoreTests")
        defaults.removePersistentDomain(forName: "ShoppingListStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "ShoppingListStoreTests")
        super.tearDown()
    }

    private func makeStore() -> ShoppingListStore {
        ShoppingListStore(defaults: defaults)
    }

    // MARK: Add & dedupe

    func testAddTrimsAndAppends() {
        let store = makeStore()
        XCTAssertTrue(store.add("  Milch "))
        XCTAssertEqual(store.items.map(\.text), ["Milch"])
    }

    func testAddRejectsEmptyAndDuplicates() {
        let store = makeStore()
        XCTAssertFalse(store.add("   "))
        XCTAssertTrue(store.add("Milch"))
        XCTAssertFalse(store.add("milch"))
        XCTAssertEqual(store.items.count, 1)
    }

    // MARK: Erledigtes blockiert nicht (Scott, 10.08., Punkt C)

    /// **Der Fehler aus der Bedienrunde vom 10.08.**, wörtlich: „if a product
    /// like Milch is erledigt I can't add a new Milch item".
    ///
    /// Die Dubletten-Abweisung sah nur den Text und nicht den Haken. Wer Milch
    /// gekauft und abgehakt hatte, bekam beim nächsten Einkauf keine Milch mehr
    /// auf die Liste — und die App sagte dazu nichts, weil ein abgewiesenes
    /// `add` still ist.
    func testACheckedItemDoesNotBlockAddingItAgain() {
        let store = makeStore()
        store.add("Milch")
        store.toggle(store.items[0])

        XCTAssertTrue(store.add("Milch"), "Erledigtes darf die Neuanlage nicht blockieren")
        XCTAssertEqual(store.uncheckedItems.map(\.text), ["Milch"])
    }

    /// **Ein Produkt, eine Zeile — wie bei Bring!.** Dort ist ein Artikel
    /// entweder auf der Liste oder nicht; ein zweites „Milch" daneben gibt es
    /// nicht. Das erneute Anlegen weckt deshalb die abgehakte Zeile wieder auf,
    /// statt eine zweite anzulegen.
    func testReAddingRevivesTheCheckedRowInsteadOfMakingASecondOne() {
        let store = makeStore()
        store.add("Milch")
        let original = store.items[0]
        store.toggle(original)

        store.add("milch")   // andere Schreibweise, derselbe Artikel
        XCTAssertEqual(store.items.count, 1, "Es darf keine zweite Milch entstehen")
        XCTAssertEqual(store.items[0].id, original.id, "Es ist dieselbe Zeile")
        XCTAssertFalse(store.items[0].isChecked)
        XCTAssertEqual(store.items[0].text, "Milch",
                       "Die Schreibweise der Zeile bleibt, die Neuanlage benennt sie nicht um")
    }

    /// Die geweckte Zeile behält, was an ihr hängt — Angaben, Notiz, Wahl.
    /// Bring! merkt sich die Spezifikation eines Artikels über den Einkauf
    /// hinaus; wer „1,5 %" einmal eingetragen hat, will es nicht jede Woche neu
    /// tippen.
    func testTheRevivedRowKeepsItsDetail() {
        let store = makeStore()
        store.add("Milch")
        store.setDetail(["1,5 %"], note: "für Oma", for: store.items[0])
        store.toggle(store.items[0])

        store.add("Milch")
        XCTAssertFalse(store.items[0].isChecked, "Ohne das Wecken prüft der Rest hier nichts")
        XCTAssertEqual(store.items[0].detail, ["1,5 %"])
        XCTAssertEqual(store.items[0].note, "für Oma")
    }

    /// **Und die geweckte Zeile ist die zuletzt angelegte.** Das Mengen-Menü
    /// hängt an `lastAdded` ([UI-8]); käme die Zeile an ihrem alten Platz
    /// zurück, öffnete die Angaben-Schicht über einem fremden Artikel.
    func testTheRevivedRowIsTheLastAdded() {
        let store = makeStore()
        store.add("Milch")
        store.add("Brot")
        store.toggle(store.items[0])   // Milch abhaken

        store.add("Milch")
        XCTAssertEqual(store.lastAdded?.text, "Milch")
        XCTAssertEqual(store.items.map(\.text), ["Brot", "Milch"])
    }

    /// Ein **offener** Artikel bleibt eine Dublette — daran ändert sich nichts.
    func testAnOpenItemStillBlocks() {
        let store = makeStore()
        store.add("Milch")
        XCTAssertFalse(store.add("Milch"))
        XCTAssertEqual(store.items.count, 1)
    }

    // MARK: Lebensdauer des Erledigten (Scott, 10.08.: „when does erledigt products get deleted")

    /// **Was heute passiert, schwarz auf weiß.** Erledigtes verschwindet von
    /// selbst nach `checkedRetention` — vorher nur auf Ansage („Erledigte
    /// entfernen", „Liste leeren", Wischen, App-Reset). Bis zum 10.08. gab es
    /// die Alterung gar nicht: Ein Haken vom Juli stand im August noch da.
    func testCheckedItemsAgeOutAfterTheRetention() {
        let store = makeStore()
        store.add("Milch")
        let heute = Date(timeIntervalSince1970: 1_754_000_000)
        store.toggle(store.items[0], now: heute)

        store.sweepChecked(now: heute.addingTimeInterval(ShoppingListStore.checkedRetention - 60))
        XCTAssertEqual(store.items.count, 1, "Kurz davor steht es noch")

        store.sweepChecked(now: heute.addingTimeInterval(ShoppingListStore.checkedRetention + 60))
        XCTAssertTrue(store.items.isEmpty, "Danach räumt die Liste selbst auf")
    }

    /// Offene Artikel altern **nicht**. Die Liste ist zuerst ein Merkzettel;
    /// was nie abgehakt wurde, ist noch gewollt.
    func testOpenItemsNeverAgeOut() {
        let store = makeStore()
        store.add("Zahnpasta")
        store.sweepChecked(now: .now.addingTimeInterval(365 * 24 * 60 * 60))
        XCTAssertEqual(store.items.map(\.text), ["Zahnpasta"])
    }

    /// **Ein Haken aus einem älteren Build fängt bei null an.** Auf den Geräten
    /// der Tester liegen abgehakte Artikel ohne Zeitpunkt. Die beim ersten
    /// Aufräumen sofort wegzuwerfen hieße, ein Update Daten löschen zu lassen,
    /// die der Nutzer nie zum Löschen freigegeben hat.
    func testALegacyCheckedItemStartsItsClockAtTheFirstSweep() {
        // Genau der Datensatz, den ein Build vor dem 10.08. geschrieben hat:
        // abgehakt, ohne `checkedAt`.
        let alt = """
        [{"id":"\(UUID().uuidString)","text":"Milch","isChecked":true,\
        "addedAt":760000000}]
        """
        defaults.set(Data(alt.utf8), forKey: "shopping.items")
        let store = makeStore()
        XCTAssertEqual(store.items.count, 1, "Die alte Liste muss lesbar bleiben")
        XCTAssertNil(store.items[0].checkedAt)

        let jetzt = Date(timeIntervalSince1970: 1_754_000_000)
        store.sweepChecked(now: jetzt)
        XCTAssertEqual(store.items.count, 1, "Beim ersten Aufräumen wird nur gestempelt")
        XCTAssertEqual(store.items[0].checkedAt, jetzt)

        store.sweepChecked(now: jetzt.addingTimeInterval(ShoppingListStore.checkedRetention + 60))
        XCTAssertTrue(store.items.isEmpty)
    }

    /// Der Haken wieder ab heißt: die Uhr ist wieder aus.
    func testUncheckingClearsTheClock() {
        let store = makeStore()
        store.add("Milch")
        store.toggle(store.items[0])
        XCTAssertNotNil(store.items[0].checkedAt)
        store.toggle(store.items[0])
        XCTAssertNil(store.items[0].checkedAt)
    }

    /// Und das Aufwecken über `add` löscht die Uhr genauso — sonst räumte der
    /// nächste Durchlauf einen **offenen** Artikel weg.
    func testRevivingClearsTheClock() {
        let store = makeStore()
        store.add("Milch")
        store.toggle(store.items[0])
        store.add("Milch")
        XCTAssertNil(store.items[0].checkedAt)
    }

    // MARK: Toggle, remove, clear

    func testToggleMovesItemBetweenOpenAndChecked() {
        let store = makeStore()
        store.add("Milch")
        let item = store.items[0]
        store.toggle(item)
        XCTAssertTrue(store.items[0].isChecked)
        XCTAssertEqual(store.uncheckedItems.count, 0)
        XCTAssertEqual(store.checkedItems.count, 1)
        store.toggle(store.items[0])
        XCTAssertFalse(store.items[0].isChecked)
    }

    func testRemoveAndClearChecked() {
        let store = makeStore()
        store.add("Milch")
        store.add("Brot")
        store.add("Eier")
        store.toggle(store.items[0])
        store.remove(store.items[1])
        XCTAssertEqual(store.items.map(\.text), ["Milch", "Eier"])
        store.clearChecked()
        XCTAssertEqual(store.items.map(\.text), ["Eier"])
        store.clearAll()
        XCTAssertTrue(store.items.isEmpty)
    }

    // MARK: Persistence

    func testItemsSurviveReload() {
        let store = makeStore()
        store.add("Milch")
        store.add("Brot")
        store.toggle(store.items[1])

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.items.map(\.text), ["Milch", "Brot"])
        XCTAssertTrue(reloaded.items[1].isChecked)
    }

    // MARK: Matcher

    private func offer(
        product: String,
        price: Double? = 1.0,
        basePrice: Double? = nil,
        market: String = "Lidl"
    ) -> Offer {
        Offer(
            market: market, product: product, price: price, regularPrice: nil,
            unit: nil, category: "Sonstiges", emoji: nil,
            validFrom: MockFixtures.day.date(from: "2026-07-13")!,
            validUntil: MockFixtures.day.date(from: "2026-07-19")!,
            basePrice: basePrice, baseUnit: nil, nationwide: false
        )
    }

    func testMatcherFindsCheapestCaseInsensitive() {
        let offers = [
            offer(product: "Bio Vollmilch", price: 1.29),
            offer(product: "Frische Vollmilch", price: 0.99),
            offer(product: "Orangen", price: 0.49),
        ]
        let match = ShoppingListMatcher.cheapestMatch(for: "vollmilch", in: offers)
        XCTAssertEqual(match?.offer.product, "Frische Vollmilch")
    }

    func testMatcherIgnoresOffersWithoutPrice() {
        let offers = [
            offer(product: "Vollmilch", price: nil),
            offer(product: "Vollmilch extra", price: 1.49),
        ]
        let match = ShoppingListMatcher.cheapestMatch(for: "Vollmilch", in: offers)
        XCTAssertEqual(match?.offer.product, "Vollmilch extra")
    }

    func testMatcherReturnsNilWithoutHitOrForEmptyText() {
        let offers = [offer(product: "Orangen")]
        XCTAssertNil(ShoppingListMatcher.cheapestMatch(for: "Milch", in: offers))
        XCTAssertNil(ShoppingListMatcher.cheapestMatch(for: "   ", in: offers))
    }

    func testMatcherBreaksPriceTieByBasePrice() {
        let offers = [
            offer(product: "Butter 250g", price: 1.99, basePrice: 7.96),
            offer(product: "Butter 500g", price: 1.99, basePrice: 3.98),
        ]
        let match = ShoppingListMatcher.cheapestMatch(for: "Butter", in: offers)
        XCTAssertEqual(match?.offer.product, "Butter 500g")
    }

    // MARK: Quick-add suggestions

    /// The point of the strip: take one staple, the others are still there.
    func testTakingASuggestionLeavesTheOthersStanding() {
        let remaining = ShoppingSuggestions.remaining(for: [ShoppingItem(text: "Milch")])

        XCTAssertFalse(remaining.contains("Milch"))
        XCTAssertEqual(remaining.count, ShoppingSuggestions.staples.count - 1)
        XCTAssertEqual(remaining.first, "Brot")
    }

    /// `add` refuses duplicates case-insensitively — suggesting one anyway
    /// would offer a chip that does nothing when tapped.
    func testSuggestionsMatchTheListCaseInsensitively() {
        let remaining = ShoppingSuggestions.remaining(for: [ShoppingItem(text: "milch")])

        XCTAssertFalse(remaining.contains("Milch"))
    }

    /// **Diese Zusicherung stand bis zum 10.08. auf dem Kopf.**
    ///
    /// Sie hieß „ein abgehakter Artikel steht immer noch auf der Liste", mit
    /// der Begründung, ein Vorschlag darauf wäre die App im Widerspruch zum
    /// Nutzer — und `add` würde die Dublette ohnehin abweisen. Genau diese
    /// Abweisung war Scotts Fehler C. Ohne sie ist der Vorschlag kein
    /// Widerspruch mehr, sondern der kurze Weg zurück: Abgehaktes gehört in den
    /// Vorrat („Zuletzt verwendet", Punkt D), nicht in eine Sperrliste.
    func testACheckedItemIsBackInThePool() {
        let remaining = ShoppingSuggestions.remaining(
            for: [ShoppingItem(text: "Brot", isChecked: true)]
        )

        XCTAssertTrue(remaining.contains("Brot"))
    }

    func testNothingLeftToSuggestReturnsAnEmptyStrip() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }

        XCTAssertTrue(ShoppingSuggestions.remaining(for: items).isEmpty)
    }

    func testUnrelatedItemsLeaveTheSuggestionsAlone() {
        let remaining = ShoppingSuggestions.remaining(for: [ShoppingItem(text: "Schokolade")])

        XCTAssertEqual(remaining, ShoppingSuggestions.staples)
    }

    // MARK: Corrupt persistence

    func testCorruptPersistedDataResetsToEmptyList() {
        defaults.set(Data("{broken".utf8), forKey: "shopping.items")
        let store = makeStore()
        XCTAssertTrue(store.items.isEmpty)
        // Store stays usable and re-persists cleanly after the reset.
        XCTAssertTrue(store.add("Milch"))
        XCTAssertEqual(makeStore().items.map(\.text), ["Milch"])
    }
}

// MARK: - Vorschläge wachsen nach (Backlog 2026-07-25)

@MainActor
final class SuggestionStripTests: XCTestCase {
    private let day = Calendar.supabase.date(from: DateComponents(year: 2026, month: 7, day: 20))!

    private func offer(_ product: String, tags: [String], price: Double, was: Double?) -> Offer {
        Offer(
            marketId: "lidl-01219-1", market: "Lidl", product: product, price: price,
            regularPrice: was, unit: nil, category: "Sonstiges", emoji: nil,
            validFrom: day, validUntil: day, basePrice: nil, baseUnit: nil,
            nationwide: false, matchKey: tags
        )
    }

    /// Der eigentliche Punkt: Der Streifen behält seine Länge, statt mit jedem
    /// Tippen zu schrumpfen. Vorher war er nach acht Grundnahrungsmitteln weg.
    func testTheStripKeepsItsLengthAsStaplesAreUsedUp() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
        let offers = (1...12).map {
            offer("Angebot \($0)", tags: ["ware\($0)"], price: 1.0, was: 2.0)
        }

        let strip = ShoppingSuggestions.strip(for: items, offers: offers)

        XCTAssertEqual(strip.count, ShoppingSuggestions.stripLength)
        // Nichts davon steht schon auf der Liste.
        XCTAssertTrue(strip.allSatisfy { !ShoppingSuggestions.staples.contains($0) })
    }

    /// Solange Grundnahrungsmittel übrig sind, führen sie — sie sind die
    /// wahrscheinlichere Wahl als ein zufälliges Wochenangebot.
    func testStaplesComeFirst() {
        let strip = ShoppingSuggestions.strip(
            for: [], offers: [offer("Sekt", tags: ["sekt"], price: 3.0, was: 9.0)]
        )

        XCTAssertEqual(Array(strip.prefix(ShoppingSuggestions.staples.count)),
                       ShoppingSuggestions.staples)
    }

    /// Der Nachschub ist nach Rabatt sortiert — dann hat der Vorschlag einen
    /// Grund, und genau das unterscheidet ihn von einer längeren festen Liste.
    func testTopUpsAreOrderedByDiscount() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
        let offers = [
            offer("Wenig reduziert", tags: ["mehl"], price: 1.80, was: 2.00),   // 10 %
            offer("Stark reduziert", tags: ["joghurt"], price: 3.00, was: 9.00), // 67 %
            offer("Ohne Streichpreis", tags: ["reis"], price: 1.00, was: nil),  //  0 %
        ]

        let strip = ShoppingSuggestions.strip(for: items, offers: offers)

        XCTAssertEqual(strip, ["Joghurt", "Mehl", "Reis"])
    }

    /// **Der Rabatt entscheidet die Reihenfolge, aber nicht die Aufnahme.**
    ///
    /// Bis zum 2026-07-31 stand in dem Test darüber `sekt` als das am
    /// stärksten reduzierte Angebot, und der Streifen zeigte es an erster
    /// Stelle. Seit Scotts Entscheidung wird Alkohol nicht mehr ungefragt
    /// vorgeschlagen — der Fall ist deshalb aus dem Test oben heraus- und
    /// hierher gewandert, statt still verschwunden zu sein.
    ///
    /// Das Angebot bleibt in den Angeboten und in der Suche. Zurückgehalten
    /// wird nur der **Vorschlag**.
    func testTheDeepestDiscountDoesNotBuyAlcoholAWayIntoTheStrip() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
        let offers = [
            offer("Stark reduziert", tags: ["sekt"], price: 3.00, was: 9.00),   // 67 %
            offer("Wenig reduziert", tags: ["mehl"], price: 1.80, was: 2.00),   // 10 %
        ]

        let strip = ShoppingSuggestions.strip(for: items, offers: offers)

        XCTAssertEqual(strip, ["Mehl"], "geliefert: \(strip)")
    }

    /// Non-Food ist kein Einkaufslisten-Eintrag. Ein Akkuschrauber im Prospekt
    /// darf nicht als Vorschlag auftauchen.
    func testNonFoodIsNeverSuggested() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
        let offers = [
            offer("Akku-Schrauber", tags: ["nonfood"], price: 29.99, was: 59.99),
            offer("Gouda", tags: ["gouda"], price: 1.99, was: 2.49),
        ]

        let strip = ShoppingSuggestions.strip(for: items, offers: offers)

        XCTAssertEqual(strip, ["Gouda"])
    }

    /// Was schon auf der Liste steht, kommt nicht als Angebot zurück.
    func testAnItemAlreadyOnTheListIsNotSuggestedAgain() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
            + [ShoppingItem(text: "gouda")]
        let offers = [offer("Gouda", tags: ["gouda"], price: 1.99, was: 2.49)]

        XCTAssertTrue(ShoppingSuggestions.strip(for: items, offers: offers).isEmpty)
    }

    /// Ohne Angebote bleibt es beim alten Verhalten — kein Absturz, keine
    /// leeren Kacheln.
    func testWithoutOffersTheStaplesStillWork() {
        XCTAssertEqual(ShoppingSuggestions.strip(for: [], offers: []),
                       ShoppingSuggestions.staples)
    }
}
