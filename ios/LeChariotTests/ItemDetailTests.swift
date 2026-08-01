import XCTest
@testable import LeChariot

/// **Die Detailzeile am Artikel — und die drei Wege, die sie nicht gehen darf.**
///
/// Was hier steht, ist eine Notiz für den Menschen im Laden. Sie ist kein
/// Suchwort, kein Zählwort und nichts, was das Telefon verlässt. Alle drei
/// Verneinungen brechen still: Wer die Zeile später an die Anfrage hängt, sieht
/// keinen Absturz, sondern eine Abdeckungszahl, die ein paar Prozent zu
/// niedrig ist.
final class ItemDetailTests: XCTestCase {

    // MARK: Das Vokabular

    /// In einer Auswahlgruppe **ersetzt** der neue Chip seinen Nachbarn, statt
    /// abgelehnt zu werden: Wer „500 g" auf „1 kg" korrigiert, tippt das, was
    /// er will, nicht das, was er nicht mehr will.
    func testAnExclusiveGroupKeepsOnlyTheLastChoice() {
        let nach = ItemDetailVocabulary.toggling("1 kg", in: ["500 g"])
        XCTAssertEqual(nach, ["1 kg"])
    }

    /// Und die Gegenprobe, ohne die der Test oben auch von einer Fassung
    /// erfüllt würde, die einfach alles ersetzt: Mehrfachgruppen sammeln.
    func testANonExclusiveGroupCollects() {
        let nach = ItemDetailVocabulary.toggling("laktosefrei", in: ["Bio"])
        XCTAssertEqual(nach, ["Bio", "laktosefrei"])
    }

    func testTappingAChosenChipRemovesIt() {
        XCTAssertEqual(ItemDetailVocabulary.toggling("Bio", in: ["Bio", "1 l"]), ["1 l"])
    }

    /// Die Zeile steht in Vokabularreihenfolge, nicht in Tippreihenfolge — eine
    /// Zeile, die sich beim Antippen umsortiert, sieht aus wie ein Fehler.
    func testTheLineReadsInVocabularyOrderNoMatterHowItWasTapped() {
        var detail: [String] = []
        for chip in ["Bio", "1 l", "2"] {
            detail = ItemDetailVocabulary.toggling(chip, in: detail)
        }
        XCTAssertEqual(detail, ["2", "1 l", "Bio"])
        XCTAssertEqual(ShoppingItem(text: "Milch", detail: detail).detailLine, "2 · 1 l · Bio")
    }

    /// Ein Wort aus einem älteren Vokabular bleibt am Artikel und bleibt
    /// entfernbar. Es ist weiterhin eine wahre Notiz darüber, was jemand
    /// wollte — nur hat es keine Gruppe mehr, unter der es sitzt.
    func testAWordThatLeftTheVocabularySurvivesAndStaysRemovable() {
        let mitFremdem = ItemDetailVocabulary.toggling("Bio", in: ["Halbfettstufe"])
        XCTAssertEqual(mitFremdem, ["Bio", "Halbfettstufe"])
        XCTAssertNil(ItemDetailVocabulary.group(of: "Halbfettstufe"))
        XCTAssertEqual(ItemDetailVocabulary.toggling("Halbfettstufe", in: mitFremdem), ["Bio"])
    }

    // MARK: Das persistierte Schema

    /// **Der Punkt, an dem eine Liste beim Update leer werden könnte.**
    ///
    /// Ein Tester hat die App seit dem 2026-07-30 auf dem Gerät. Sein Bestand
    /// wurde von einem Build geschrieben, der `detail` nicht kannte; ein
    /// Pflichtfeld hier hieße, dass `JSONDecoder` die ganze Liste verwirft und
    /// `ShoppingListStore` sie als „kaputt" behandelt.
    func testAListWrittenBeforeThisFieldExistedStillDecodes() throws {
        let alt = """
        [{"id":"8B2A1F3C-0000-4000-8000-000000000001","text":"Milch",\
        "isChecked":false,"addedAt":768000000}]
        """
        let items = try JSONDecoder().decode([ShoppingItem].self, from: Data(alt.utf8))
        XCTAssertEqual(items.map(\.text), ["Milch"])
        XCTAssertNil(items[0].detail)
        XCTAssertNil(items[0].detailLine)
    }

    func testANewItemRoundTripsThroughTheSameEncoder() throws {
        let item = ShoppingItem(text: "Milch", detail: ["1 l", "Bio"])
        let data = try JSONEncoder().encode([item])
        let zurueck = try JSONDecoder().decode([ShoppingItem].self, from: data)
        XCTAssertEqual(zurueck.first?.detail, ["1 l", "Bio"])
    }

    /// Leer wird als `nil` abgelegt, nicht als `[]` — zwei Schreibweisen für
    /// dasselbe laufen irgendwann auseinander.
    @MainActor
    func testClearingTheDetailStoresNothingRatherThanAnEmptyList() {
        let defaults = UserDefaults(suiteName: "ItemDetailTests")!
        defaults.removePersistentDomain(forName: "ItemDetailTests")
        defer { defaults.removePersistentDomain(forName: "ItemDetailTests") }

        let store = ShoppingListStore(defaults: defaults)
        store.add("Milch")
        store.setDetail(["Bio"], for: store.items[0])
        XCTAssertEqual(store.items[0].detail, ["Bio"])

        store.setDetail([], for: store.items[0])
        XCTAssertNil(store.items[0].detail)
        XCTAssertNil(ShoppingListStore(defaults: defaults).items[0].detail)
    }

    // MARK: Die drei Wege, die sie nicht geht

    /// **Der eigentliche Grund für die ganze Bauweise.** Stünde die Angabe in
    /// der Anfrage, verlangte `OfferMatcher` Stufe 1, dass auch sie einen
    /// Titel-Token trifft — „Bio" bricht das UND genauso wie „Landliebe", und
    /// der Artikel gälte überall als unabgedeckt, wo das Wort nicht im
    /// Prospekttitel steht.
    func testTheDetailDoesNotChangeWhichOfferIsFound() {
        let offers = [
            Offer(
                market: "Lidl", product: "Frische Vollmilch", price: 0.99, regularPrice: nil,
                unit: nil, category: "Milchprodukte", emoji: nil,
                validFrom: Date(timeIntervalSince1970: 0),
                validUntil: Date(timeIntervalSince1970: 604_800),
                basePrice: nil, baseUnit: nil, nationwide: false
            )
        ]
        let ohne = ShoppingItem(text: "Vollmilch")
        let mit = ShoppingItem(text: "Vollmilch", detail: ["Bio", "1 l"])

        XCTAssertEqual(mit.query, ohne.query, "Die Anfrage ist der Artikelname, sonst nichts")
        XCTAssertEqual(
            ShoppingListMatcher.cheapestMatch(for: mit.query, in: offers)?.offer.product,
            ShoppingListMatcher.cheapestMatch(for: ohne.query, in: offers)?.offer.product
        )
        // Und der Beleg, dass der Fall überhaupt scharf ist: Mit der Angabe in
        // der Anfrage findet derselbe Artikel nichts mehr.
        XCTAssertNil(
            ShoppingListMatcher.cheapestMatch(for: "Vollmilch Bio 1 l", in: offers),
            "Wäre die Angabe Teil der Anfrage, wäre der Artikel unabgedeckt"
        )
    }

    /// Der Häufigkeitszähler zählt den Artikel, nicht die Angabe — sonst wären
    /// „Milch" und „Milch, Bio" zwei Gewohnheiten.
    @MainActor
    func testThePurchaseCounterCountsTheItemAndNotTheNote() {
        let defaults = UserDefaults(suiteName: "ItemDetailCounterTests")!
        defaults.removePersistentDomain(forName: "ItemDetailCounterTests")
        defer { defaults.removePersistentDomain(forName: "ItemDetailCounterTests") }

        let history = PurchaseHistoryStore(defaults: defaults)
        let heute = Date(timeIntervalSince1970: 1_800_000_000)
        history.record(ShoppingItem(text: "Milch", detail: ["Bio"]).query, now: heute)
        history.record(ShoppingItem(text: "Milch", detail: ["1 l"]).query, now: heute)

        XCTAssertEqual(history.distinctWords, 1, "Eine Gewohnheit, nicht zwei")
        XCTAssertEqual(history.entries["milch"]?.weight, 2)
    }

    /// **Die Angabe geht nicht mit in die Rückmeldung** — aktiv geprüft, nicht
    /// bloß unterlassen.
    ///
    /// Die Rückmeldung ist das Einzige an der Einkaufsliste, das das Gerät
    /// verlässt. Sie trägt heute das Listenwort, und „Butter" ist ein
    /// Gattungsbegriff; eine Notiz kann alles Mögliche enthalten. Geprüft wird
    /// deshalb der **kodierte Datensatz** und nicht der Aufrufweg: Ein Feld,
    /// das jemand später anhängt, fällt hier auf, auch wenn es an einer ganz
    /// anderen Stelle gefüllt wird.
    func testTheDetailNeverReachesTheFeedbackPayload() throws {
        // Ein Wort, das in keinem Prospekttitel vorkommt. Der erste Versuch
        // nahm „Bio" und fiel um — das Angebot in den Testdaten heißt „Bio
        // Vollmilch", das Wort stand also **zu Recht** im Datensatz, als
        // `product_title`. Eine Suche über den ganzen Datensatz kann „Bio, weil
        // der Prospekt es sagt" nicht von „Bio, weil wir die Notiz verraten
        // haben" unterscheiden; das Wort muss deshalb eines sein, das nur aus
        // der Notiz stammen kann.
        let verraeterisch = "Halbfettstufe"
        let item = ShoppingItem(text: "Butter", detail: [verraeterisch, "250 g"])
        let report = MatchFeedbackReport(
            installId: UUID(uuidString: "8B2A1F3C-0000-4000-8000-000000000002")!,
            query: item.query,
            offer: MockFixtures.offers[0],
            kind: .direct,
            reason: .wrongProduct,
            comment: ""
        )
        let data = try JSONEncoder().encode(report)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(report.query, "Butter", "Die Anfrage ist der Artikel, nicht der Artikel plus Notiz")
        XCTAssertFalse(json.contains(verraeterisch),
                       "Die Notiz darf an keiner Stelle des Datensatzes auftauchen")

        // Und die Schlüssel als Ganzes, damit ein **neues** Feld auffällt statt
        // nur ein bekanntes. Wer hier etwas hinzufügt, hat die Wahl bewusst zu
        // treffen — genau das ist der Zweck dieses Tests.
        let objekt = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(
            Set(objekt.keys),
            ["install_id", "query", "product_title", "market", "match_kind", "reason"],
            "Neues Feld im Rückmelde-Datensatz — ist es wirklich gewollt?"
        )
    }

    // MARK: Der Freitext ([UI-8], 2026-08-01)

    /// **Der Freitext verlässt das Gerät nie.**
    ///
    /// Die Chips sind bewusst ein Wortschatz — „es gibt nichts zu säubern,
    /// weil es nichts zu tippen gibt". Mit der Notiz gibt es doch etwas zu
    /// tippen, und damit ist dieser Test der Ort, an dem die Zusage steht:
    /// Was jemand hier hineinschreibt, kann alles sein, und es darf auf
    /// keinem fremden Server landen.
    ///
    /// Geprüft am **kodierten Datensatz**, nicht am Aufrufweg — ein Feld, das
    /// jemand später anhängt, fällt hier auf.
    func testTheNoteNeverReachesTheFeedbackPayload() throws {
        let verraeterisch = "Telefonnummer von Oma"
        let item = ShoppingItem(text: "Butter", note: verraeterisch)
        let report = MatchFeedbackReport(
            installId: UUID(uuidString: "8B2A1F3C-0000-4000-8000-000000000004")!,
            query: item.query,
            offer: MockFixtures.offers[0],
            kind: .direct,
            reason: .wrongProduct,
            comment: ""
        )
        let json = try XCTUnwrap(
            String(data: try JSONEncoder().encode(report), encoding: .utf8)
        )

        XCTAssertEqual(report.query, "Butter", "Die Anfrage ist der Artikel, nicht die Notiz")
        XCTAssertFalse(json.contains(verraeterisch),
                       "Die Notiz darf an keiner Stelle des Datensatzes auftauchen")
    }

    /// Und sie ändert nicht, was gefunden wird — dieselbe Regel wie bei den
    /// Chips: „Landliebe" als viertes Suchwort bräche die UND-Verknüpfung.
    func testTheNoteDoesNotChangeWhichOfferIsFound() {
        let ohne = ShoppingItem(text: "Vollmilch")
        let mit = ShoppingItem(text: "Vollmilch", note: "die im blauen Becher")
        XCTAssertEqual(ohne.query, mit.query)
        XCTAssertEqual(
            ShoppingListMatcher.suggestion(for: mit, in: MockFixtures.offers).match?.offer.product,
            ShoppingListMatcher.suggestion(for: ohne, in: MockFixtures.offers).match?.offer.product
        )
    }

    /// Sie steht aber unter dem Artikel — sonst hätte sie niemand geschrieben.
    func testTheNoteShowsUpUnderTheItem() {
        XCTAssertEqual(
            ShoppingItem(text: "Butter", detail: ["250 g"], note: "gesalzen").detailLine,
            "250 g · gesalzen"
        )
        XCTAssertEqual(ShoppingItem(text: "Butter", note: "gesalzen").detailLine, "gesalzen")
        XCTAssertNil(ShoppingItem(text: "Butter", note: "   ").detailLine,
                     "Leerzeichen sind keine Notiz")
    }

    /// Und ein Bestand von vor dem Freitext dekodiert weiter — dieselbe Falle
    /// wie bei `detail` und `pins`.
    func testAListWrittenBeforeTheNoteExistedStillDecodes() throws {
        let alt = """
        [{"id":"8B2A1F3C-0000-4000-8000-000000000005","text":"Butter",\
        "isChecked":false,"addedAt":768000000,"detail":["250 g"]}]
        """
        let items = try JSONDecoder().decode([ShoppingItem].self, from: Data(alt.utf8))
        XCTAssertNil(items[0].note)
        XCTAssertEqual(items[0].detailLine, "250 g")
    }
}
