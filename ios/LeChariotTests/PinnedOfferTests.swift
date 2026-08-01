import XCTest
@testable import LeChariot

/// **Ein Angebot an den Listeneintrag heften — und die vier Stellen, an denen
/// das still kaputtgehen kann.**
///
/// Der Wunsch kam am 2026-07-31 von einem Tester: Die App wählt je Eintrag das
/// billigste Angebot, er will aber den GRÜNLÄNDER Schnittkäse für 0,99 € statt
/// des Speck-Käse-Twisters für 0,69 € — dauerhaft auf der Liste. Alles daran
/// ist einfach, außer den vier Verneinungen hier: Keine bricht laut.
final class PinnedOfferTests: XCTestCase {

    // MARK: Der Schlüssel, der die Rotation überlebt

    private func offer(
        _ product: String,
        market: String = "Netto",
        marketId: String? = "netto-01219-1",
        price: Double? = 0.99,
        week: Int = 0
    ) -> Offer {
        var made = Offer(
            market: market, product: product, price: price, regularPrice: nil,
            unit: nil, category: "Molkerei & Eier", emoji: nil,
            validFrom: Date(timeIntervalSince1970: TimeInterval(week * 604_800)),
            validUntil: Date(timeIntervalSince1970: TimeInterval((week + 1) * 604_800)),
            basePrice: nil, baseUnit: nil, nationwide: false
        )
        made.marketId = marketId
        return made
    }

    /// **Die Falle, die am 2026-07-31 live vorgeführt wurde.** Beim Neuaufbau
    /// der Angebotstabelle wurden alle 38 413 Zeilen gelöscht und neu
    /// geschrieben; danach war jede `offers.id` eine andere. Der Schlüssel der
    /// Heftung darf davon nichts merken.
    func testThePinSurvivesTheWeeklyRotationThatChangesEveryRowId() {
        let dieseWoche = offer("GRÜNLÄNDER Schnittkäse", week: 0)
        let naechsteWoche = offer("GRÜNLÄNDER Schnittkäse", price: 1.09, week: 1)

        XCTAssertNotEqual(dieseWoche.id, naechsteWoche.id,
                          "Ohne verschiedene Zeilen-IDs prüft der Test nichts")

        let pin = dieseWoche.asPin
        XCTAssertTrue(naechsteWoche.matches(pin),
                      "Die Heftung muss das Produkt in der neuen Woche wiedererkennen")
        XCTAssertEqual(
            ShoppingListMatcher.pinnedOffer(pin, in: [naechsteWoche])?.price, 1.09,
            "Und sie muss den **neuen** Preis mitbringen, nicht den gemerkten"
        )
    }

    /// Gegenprobe zum Test darüber: Der Schlüssel unterscheidet trotzdem, was
    /// zu unterscheiden ist. Dieselbe Kette, andere Filiale, anderes Produkt —
    /// jedes für sich muss die Heftung verfehlen.
    func testThePinDistinguishesBranchAndProduct() {
        let pin = offer("GRÜNLÄNDER Schnittkäse").asPin

        XCTAssertFalse(offer("GRÜNLÄNDER Schnittkäse", marketId: "netto-01219-2").matches(pin),
                       "Zwei Filialen derselben Kette führen verschiedene Prospekte")
        XCTAssertFalse(offer("Speck-Käse-Twister").matches(pin))
    }

    /// Bundesweite Ketten (ALDI Nord und SÜD) hatten bis Migration v13 keine
    /// Filial-ID. Der Schlüssel fällt dann auf die Kette zurück — dieselbe
    /// Hälfte, aus der auch `Offer.id` seinen Markt-Teil bildet.
    func testWithoutABranchIdTheChainCarriesTheIdentity() {
        let ohne = offer("Käseaufschnitt", market: "Aldi", marketId: nil)
        XCTAssertEqual(ohne.pinKey, "Aldi|Käseaufschnitt")
        XCTAssertTrue(ohne.matches(ohne.asPin))
    }

    // MARK: Das persistierte Schema

    /// **Der Punkt, an dem eine Liste beim Update leer werden könnte** — schon
    /// einmal für `detail` durchdacht, und derselbe Nachweis gilt hier.
    ///
    /// Geprüft wird an einem Datensatz, wie ihn ein Build **vor** dieser
    /// Änderung geschrieben hat, nicht am erzeugten Initialisierer: Der weiß
    /// von seinen eigenen Vorgabewerten und kann deshalb gar nichts beweisen.
    func testAListWrittenBeforeThePinExistedStillDecodes() throws {
        let alt = """
        [{"id":"8B2A1F3C-0000-4000-8000-000000000001","text":"Käse",\
        "isChecked":false,"addedAt":768000000,"detail":["500 g"]}]
        """
        let items = try JSONDecoder().decode([ShoppingItem].self, from: Data(alt.utf8))
        XCTAssertEqual(items.map(\.text), ["Käse"])
        XCTAssertEqual(items[0].detail, ["500 g"], "Das ältere Feld darf dabei nicht verloren gehen")
        XCTAssertNil(items[0].pinned)
    }

    /// Und der Gegenbeweis, dass der Test oben scharf ist: Ein Bestand, der
    /// **überhaupt kein** Feld von heute kennt, dekodiert genauso.
    func testAListFromBeforeBothOptionalFieldsStillDecodes() throws {
        let ganzAlt = """
        [{"id":"8B2A1F3C-0000-4000-8000-000000000009","text":"Milch",\
        "isChecked":true,"addedAt":768000000}]
        """
        let items = try JSONDecoder().decode([ShoppingItem].self, from: Data(ganzAlt.utf8))
        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items[0].detail)
        XCTAssertNil(items[0].pinned)
    }

    @MainActor
    func testThePinRoundTripsThroughTheStoreAndSurvivesARestart() {
        let defaults = UserDefaults(suiteName: "PinnedOfferTests")!
        defaults.removePersistentDomain(forName: "PinnedOfferTests")
        defer { defaults.removePersistentDomain(forName: "PinnedOfferTests") }

        let store = ShoppingListStore(defaults: defaults)
        store.add("Käse")
        store.setPin(offer("GRÜNLÄNDER Schnittkäse").asPin, for: store.items[0])

        let neuGestartet = ShoppingListStore(defaults: defaults)
        XCTAssertEqual(neuGestartet.items[0].pinned?.product, "GRÜNLÄNDER Schnittkäse")
        XCTAssertEqual(neuGestartet.items[0].pinned?.market, "Netto")

        store.setPin(nil, for: store.items[0])
        XCTAssertNil(ShoppingListStore(defaults: defaults).items[0].pinned)
    }

    // MARK: Was die Zeile zeigt

    /// Der Kern des Wunsches: Nicht das billigste, sondern das gewählte.
    func testThePinnedOfferBeatsTheCheapestOne() {
        let twister = offer("Speck-Käse-Twister", price: 0.69)
        let gruenlaender = offer("GRÜNLÄNDER Schnittkäse", price: 0.99)
        let offers = [twister, gruenlaender]

        let ohne = ShoppingItem(text: "Käse")
        XCTAssertEqual(
            ShoppingListMatcher.suggestion(for: ohne, in: offers).match?.offer.product,
            "Speck-Käse-Twister",
            "Ohne Heftung bleibt es beim billigsten — sonst prüft der Test daneben"
        )

        let mit = ShoppingItem(text: "Käse", pinned: gruenlaender.asPin)
        let vorschlag = ShoppingListMatcher.suggestion(for: mit, in: offers)
        XCTAssertEqual(vorschlag.match?.offer.product, "GRÜNLÄNDER Schnittkäse")
        XCTAssertTrue(vorschlag.isPinned)
        XCTAssertNil(vorschlag.dormantPin, "Solange es sie gibt, schläft die Heftung nicht")
    }

    /// **Entscheidung vom 2026-07-31: kein stiller Rückfall.** Ist das
    /// geheftete Produkt diese Woche nicht im Angebot, rechnet die App wieder
    /// mit dem billigsten — aber die Zeile bekommt den Satz dazu.
    func testAPinWithoutAnOfferThisWeekIsSaidOutLoud() {
        let twister = offer("Speck-Käse-Twister", price: 0.69)
        let item = ShoppingItem(text: "Käse", pinned: offer("GRÜNLÄNDER Schnittkäse").asPin)

        let vorschlag = ShoppingListMatcher.suggestion(for: item, in: [twister])
        XCTAssertEqual(vorschlag.match?.offer.product, "Speck-Käse-Twister",
                       "Der Rückfall selbst ist richtig")
        XCTAssertFalse(vorschlag.isPinned)
        XCTAssertEqual(vorschlag.dormantPin?.product, "GRÜNLÄNDER Schnittkäse",
                       "…er darf nur nicht stumm sein")
        XCTAssertEqual(vorschlag.dormantPin?.absenceLine,
                       "GRÜNLÄNDER Schnittkäse ist diese Woche nicht im Angebot")
    }

    /// Ein geheftetes Angebot, das der Matcher diese Woche gar nicht mehr unter
    /// das Listenwort sortiert, bleibt trotzdem stehen. Die Heftung ist eine
    /// Aussage über ein Produkt, keine Suchanfrage — und ein Prospekttitel, der
    /// ein Wort verliert, darf die eigene Wahl nicht wegräumen.
    func testThePinIsNotSubjectToTheMatcher() {
        let umbenannt = offer("GRÜNLÄNDER Schnittkäse", price: 0.99)
        let item = ShoppingItem(text: "Schnittkäse Bergbauern", pinned: umbenannt.asPin)

        XCTAssertNil(
            ShoppingListMatcher.cheapestMatch(for: item.query, in: [umbenannt]),
            "Ohne Heftung fände die Anfrage hier nichts — sonst prüft der Test daneben"
        )
        XCTAssertEqual(
            ShoppingListMatcher.suggestion(for: item, in: [umbenannt]).match?.offer.product,
            "GRÜNLÄNDER Schnittkäse"
        )
    }

    /// Heften und Weglegen sind zwei Aussagen über dasselbe Angebot. Steht
    /// beides gleichzeitig da, gewinnt die Heftung — sie ist die deutlichere.
    /// (Die Oberfläche lässt es gar nicht so weit kommen, siehe
    /// `MatchDetailView.setPin`; die Regel steht trotzdem fest, weil ein
    /// undefinierter Fall irgendwann einer wird.)
    func testAPinnedOfferStaysEvenWhenItIsAlsoRejected() {
        let gruenlaender = offer("GRÜNLÄNDER Schnittkäse", price: 0.99)
        let twister = offer("Speck-Käse-Twister", price: 0.69)
        let item = ShoppingItem(text: "Käse", pinned: gruenlaender.asPin)

        let vorschlag = ShoppingListMatcher.suggestion(
            for: item, in: [twister, gruenlaender],
            isRejected: { $0.product == "GRÜNLÄNDER Schnittkäse" }
        )
        XCTAssertEqual(vorschlag.match?.offer.product, "GRÜNLÄNDER Schnittkäse")
        XCTAssertTrue(vorschlag.isPinned)
    }

    // MARK: Die Wege, die die Wahl nicht geht

    /// **Die geheftete Wahl geht nicht mit in die Rückmeldung** — aktiv
    /// geprüft, nicht bloß unterlassen. Dieselbe Bauart wie
    /// `ItemDetailTests.testTheDetailNeverReachesTheFeedbackPayload`: geprüft
    /// wird der **kodierte Datensatz**, damit ein Feld, das jemand später
    /// anhängt, auch dann auffällt, wenn es woanders gefüllt wird.
    ///
    /// Warum es zählt: Die Rückmeldung ist das Einzige an der Einkaufsliste,
    /// das das Gerät verlässt, und sie trägt schon das Listenwort. Ein
    /// Produkttitel, den diese Person selbst ausgewählt hat, ist eine Aussage
    /// über ihren Geschmack — und im Wörterbuch hätte er ohnehin nichts zu
    /// suchen. Die Rückmeldung berichtet über das Angebot, über das sie
    /// gefragt wurde, nicht über das daneben.
    func testThePinNeverReachesTheFeedbackPayload() throws {
        // Ein Produktname, der nur aus der Heftung stammen kann: Das Angebot,
        // über das die Rückmeldung geht, heißt anders. Sonst könnte der Test
        // „steht drin, weil der Prospekt es sagt" nicht von „steht drin, weil
        // wir die Wahl verraten haben" unterscheiden.
        let verraeterisch = "GRÜNLÄNDER Schnittkäse"
        let item = ShoppingItem(
            text: "Käse",
            pinned: offer(verraeterisch).asPin
        )
        let report = MatchFeedbackReport(
            installId: UUID(uuidString: "8B2A1F3C-0000-4000-8000-000000000003")!,
            query: item.query,
            offer: offer("Speck-Käse-Twister", market: "Lidl", marketId: "lidl-01219-1", price: 0.69),
            kind: .direct,
            reason: .wrongVariant,
            comment: ""
        )
        let data = try JSONEncoder().encode(report)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(report.query, "Käse", "Die Anfrage ist der Artikel, nicht die Wahl")
        XCTAssertFalse(json.contains(verraeterisch),
                       "Die geheftete Wahl darf an keiner Stelle des Datensatzes auftauchen")
        XCTAssertFalse(json.contains("netto-01219-1"),
                       "Und ihre Filiale erst recht nicht")

        // Die Schlüssel als Ganzes, damit ein **neues** Feld auffällt statt nur
        // ein bekanntes.
        let objekt = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(
            Set(objekt.keys),
            ["install_id", "query", "product_title", "market", "match_kind", "reason"],
            "Neues Feld im Rückmelde-Datensatz — ist es wirklich gewollt?"
        )
    }

    /// Die Wahl bewegt die Suchanfrage nicht — genauso wenig wie die
    /// Detailzeile. Wer „Käse" auf der Liste hat und GRÜNLÄNDER heftet, sucht
    /// weiter nach Käse; sonst wäre der Artikel überall unabgedeckt, wo diese
    /// eine Marke nicht im Prospekt steht.
    func testThePinDoesNotChangeTheQuery() {
        let item = ShoppingItem(text: "Käse", pinned: offer("GRÜNLÄNDER Schnittkäse").asPin)
        XCTAssertEqual(item.query, "Käse")
        XCTAssertEqual(item.query, ShoppingItem(text: "Käse").query)
    }

    /// Der Häufigkeitszähler zählt den Artikel, nicht die Wahl.
    @MainActor
    func testThePurchaseCounterCountsTheItemAndNotThePin() {
        let defaults = UserDefaults(suiteName: "PinnedOfferCounterTests")!
        defaults.removePersistentDomain(forName: "PinnedOfferCounterTests")
        defer { defaults.removePersistentDomain(forName: "PinnedOfferCounterTests") }

        let history = PurchaseHistoryStore(defaults: defaults)
        let heute = Date(timeIntervalSince1970: 1_800_000_000)
        history.record(ShoppingItem(text: "Käse").query, now: heute)
        history.record(
            ShoppingItem(text: "Käse", pinned: offer("GRÜNLÄNDER Schnittkäse").asPin).query,
            now: heute
        )

        XCTAssertEqual(history.distinctWords, 1, "Eine Gewohnheit, nicht zwei")
        XCTAssertEqual(history.entries["käse"]?.weight, 2)
    }
}
