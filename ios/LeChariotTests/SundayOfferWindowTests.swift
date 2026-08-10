import XCTest
@testable import LeChariot

/// **Der Sonntag** — der Tag, an dem eine gewählte Kette stumm aus dem
/// Angebote-Tab verschwand (Scotts Feldtest 09.08.).
///
/// Prospektwochen laufen Montag bis Samstag; der Sonntag ist das Loch
/// dazwischen. Für die sieben Filialen in 01219 galten an dem Tag **68 von
/// 3 038** Zeilen. Die App filterte das richtig — und sagte kein Wort dazu.
///
/// Alle Zusicherungen hier rechnen mit einem **gesetzten** „heute". Ein Test,
/// der `.now` nimmt, prüft an sechs von sieben Tagen etwas anderes als am
/// siebten — genau die Sorte Test, die im Sommer grün ist und im Winter fällt.
final class SundayOfferWindowTests: XCTestCase {
    /// Sonntag, 9. August 2026 — Scotts Feldtest-Tag.
    private let sonntag = DateFormatter.supabaseDay.date(from: "2026-08-09")!
    /// Der Samstag davor und der Montag danach.
    private let samstag = DateFormatter.supabaseDay.date(from: "2026-08-08")!
    private let montag = DateFormatter.supabaseDay.date(from: "2026-08-10")!

    private func offer(
        _ chain: String, _ marketId: String?, from: Date, until: Date
    ) -> Offer {
        Offer(
            marketId: marketId, market: chain, product: "Butter", price: 1.99,
            regularPrice: nil, unit: nil, category: "Molkerei & Eier", emoji: "🧈",
            validFrom: from, validUntil: until,
            basePrice: nil, baseUnit: nil, nationwide: false
        )
    }

    private func market(_ chain: String, _ id: String) -> Market {
        Market(chain: chain, branchName: "\(chain) Dresden", marketId: id, plz: "01219")
    }

    // MARK: Die abgelaufenen Zeilen

    /// Vor dieser Runde fielen sie zwischen `current` und `upcoming` heraus und
    /// wurden nirgends mehr angefasst — und mit ihnen das einzige Datum, das
    /// „wann hat die letzte Woche geendet" beantworten kann.
    func testTheEndedRowsAreTheOnesThatStoppedBeforeToday() {
        let abgelaufen = offer("Netto", "netto-1", from: samstag.addingTimeInterval(-5 * 86_400), until: samstag)
        let laufend = offer("Kaufland", "kaufland-1", from: samstag, until: montag)
        let kuenftig = offer("Penny", "penny-1", from: montag, until: montag.addingTimeInterval(5 * 86_400))

        let ended = OfferQuery.ended([abgelaufen, laufend, kuenftig], now: sonntag)

        XCTAssertEqual(ended.map(\.market), ["Netto"],
                       "Genau die Woche, die vor heute geendet hat — und keine andere")
    }

    /// Die Gegenprobe, ohne die die obere nichts beweist: Eine Zeile, die
    /// **heute** ausläuft, gilt heute noch. `valid_until` ist ein
    /// einschließender Tag, kein Zeitpunkt.
    func testARowExpiringTodayHasNotEndedYet() {
        let laeuftHeuteAus = offer("Lidl", "lidl-1", from: samstag.addingTimeInterval(-5 * 86_400), until: sonntag)

        XCTAssertTrue(OfferQuery.ended([laeuftHeuteAus], now: sonntag).isEmpty)
        XCTAssertEqual(OfferQuery.current([laeuftHeuteAus], now: sonntag).count, 1)
    }

    // MARK: Das Fenster je Kette

    func testTheWindowKeepsTheLatestEndAndTheEarliestStart() {
        let ended = [
            offer("Netto", "netto-1", from: samstag.addingTimeInterval(-12 * 86_400),
                  until: samstag.addingTimeInterval(-7 * 86_400)),
            offer("Netto", "netto-1", from: samstag.addingTimeInterval(-5 * 86_400), until: samstag),
        ]
        let upcoming = [
            offer("Netto", "netto-1", from: montag.addingTimeInterval(7 * 86_400),
                  until: montag.addingTimeInterval(12 * 86_400)),
            offer("Netto", "netto-1", from: montag, until: montag.addingTimeInterval(5 * 86_400)),
        ]

        let fenster = OfferCoverage.windows(ended: ended, upcoming: upcoming)["Netto"]

        XCTAssertEqual(fenster?.endedOn, samstag,
                       "Die **letzte** abgelaufene Woche zählt, nicht die erste")
        XCTAssertEqual(fenster?.startsOn, montag,
                       "Die **nächste** kommende Woche zählt, nicht die späteste")
    }

    /// Eine Kette darf auch nur eine Hälfte haben — Netto hatte am 09.08.
    /// genau das nicht, ALDI Nord dafür beides.
    func testAWindowMayKnowOnlyOneOfTheTwoDates() {
        let nurEnde = OfferCoverage.windows(
            ended: [offer("Netto", "netto-1", from: samstag, until: samstag)], upcoming: []
        )["Netto"]
        XCTAssertEqual(nurEnde?.endedOn, samstag)
        XCTAssertNil(nurEnde?.startsOn)
        XCTAssertTrue(nurEnde?.isKnown == true)

        let leer = OfferCoverage.ChainOfferWindow()
        XCTAssertFalse(leer.isKnown, "Ohne beides gibt es nichts zu erzählen")
    }

    // MARK: Welche Kette einen Chip behält

    func testAChosenChainWithoutValidOffersKeepsItsChip() {
        let favoriten = [market("Lidl", "lidl-1"), market("Netto", "netto-1")]
        let laufend = [offer("Lidl", "lidl-1", from: samstag, until: montag)]
        let fenster = OfferCoverage.windows(
            ended: [offer("Netto", "netto-1", from: samstag, until: samstag)],
            upcoming: []
        )

        let ruhend = OfferCoverage.restingChains(
            favorites: favoriten, current: laufend, windows: fenster
        )

        XCTAssertEqual(ruhend, ["Netto"], "Lidl liefert, Netto ruht — und ruhen ist sagbar")
    }

    /// **Die Regel von 2026-07-31 bleibt für den Fall, für den sie gilt.** Ein
    /// Chip ohne Grund dahinter führt in „Nichts für diesen Filter", und das
    /// ist genau die Sackgasse, gegen die `chipChains` gebaut wurde.
    func testAChainWeKnowNothingAboutGetsNoChip() {
        let favoriten = [market("Lidl", "lidl-1"), market("EDEKA", "edeka-1")]
        let laufend = [offer("Lidl", "lidl-1", from: samstag, until: montag)]

        XCTAssertTrue(
            OfferCoverage.restingChains(favorites: favoriten, current: laufend, windows: [:]).isEmpty,
            "Über EDEKA wissen wir nichts — dann steht dort auch kein Chip"
        )
    }

    /// Und eine Kette, die gerade liefert, ruht nicht, auch wenn sie ein
    /// Fenster hat: Ihre alte Woche ist längst abgelaufen, ihre neue läuft.
    func testASupplyingChainNeverCountsAsResting() {
        let favoriten = [market("Lidl", "lidl-1")]
        let laufend = [offer("Lidl", "lidl-1", from: samstag, until: montag)]
        let fenster = OfferCoverage.windows(
            ended: [offer("Lidl", "lidl-1", from: samstag.addingTimeInterval(-10 * 86_400),
                          until: samstag.addingTimeInterval(-5 * 86_400))],
            upcoming: []
        )

        XCTAssertTrue(
            OfferCoverage.restingChains(favorites: favoriten, current: laufend, windows: fenster).isEmpty
        )
    }

    // MARK: Die Leiste

    func testTheChipBarCarriesTheRestingChainsToo() {
        var browser = OfferBrowser()
        let laufend = [offer("Lidl", "lidl-1", from: samstag, until: montag)]

        XCTAssertEqual(browser.chipChains(in: laufend), ["Lidl"],
                       "Ohne ruhende Ketten bleibt die alte Regel unverändert")
        XCTAssertEqual(browser.chipChains(in: laufend, resting: ["Netto", "Aldi"]),
                       ["Aldi", "Lidl", "Netto"])

        // Und der aktive Filter überlebt weiterhin eine Aktualisierung.
        browser.market = "Penny"
        XCTAssertEqual(browser.chipChains(in: laufend, resting: ["Netto"]),
                       ["Lidl", "Netto", "Penny"])
    }

    // MARK: Die Sätze

    func testTheRestingTextNamesBothDatesWhenBothAreKnown() {
        let text = OfferEmptyResultView.restingText(
            OfferCoverage.ChainOfferWindow(endedOn: samstag, startsOn: montag)
        )

        XCTAssertTrue(text.contains("endeten"), text)
        XCTAssertTrue(text.contains("August"), text)
        XCTAssertTrue(text.contains("gelten ab"), text)
    }

    /// **Behauptet wird nur, was im Fenster steht.** Ohne Vorschau darf kein
    /// Satz über die nächste Woche fallen — das ist derselbe Fehler wie „schau
    /// später noch einmal vorbei" über EDEKA Böse.
    func testTheRestingTextStaysSilentAboutWhatItDoesNotKnow() {
        let nurEnde = OfferEmptyResultView.restingText(
            OfferCoverage.ChainOfferWindow(endedOn: samstag, startsOn: nil)
        )
        XCTAssertTrue(nurEnde.contains("endeten"), nurEnde)
        XCTAssertFalse(nurEnde.contains("gelten ab"), nurEnde)

        XCTAssertEqual(OfferEmptyResultView.restingText(OfferCoverage.ChainOfferWindow()), "")
    }

    /// Der Satz im Abschnitt „Ohne Angebote" bekommt dasselbe Ende mit.
    func testTheBranchReasonNamesTheEndOnceItIsKnown() {
        let ohneEnde = NoOffersReason.text(for: .ready, upcomingFrom: montag)
        XCTAssertFalse(ohneEnde.contains("endeten"), ohneEnde)

        let mitEnde = NoOffersReason.text(for: .ready, upcomingFrom: montag, endedOn: samstag)
        XCTAssertTrue(mitEnde.contains("endeten"), mitEnde)
        XCTAssertTrue(mitEnde.contains("gilt ab"), mitEnde)
    }

    /// **Der Satz, der etwas über den Markt behauptet, weicht einem Datum.**
    /// „Dieser Markt veröffentlicht seinen Prospekt nicht online" ist über eine
    /// Kette, deren Woche am Samstag geendet hat, schlicht falsch — dieselbe
    /// Klasse Fehler wie am 02.08. in Ahlbeck.
    func testAKnownEndBeatsTheClaimAboutTheMarket() {
        XCTAssertEqual(
            NoOffersReason.text(for: .ready),
            "Dieser Markt veröffentlicht seinen Prospekt nicht online.",
            "Für den Fall, für den er gedacht war, bleibt der Satz stehen"
        )

        let mitEnde = NoOffersReason.text(for: .ready, endedOn: samstag)
        XCTAssertFalse(mitEnde.contains("nicht online"), mitEnde)
        XCTAssertTrue(mitEnde.contains("endeten"), mitEnde)
    }

    // MARK: Das Fixture

    /// Der Bilderbogen und die Journey hängen daran, dass `MockFixtures.sunday`
    /// den Zustand wirklich herstellt — an **jedem** Wochentag, nicht nur
    /// sonntags. Ohne diese Zusicherung wäre der Bogen einen Tag die Woche ein
    /// Beleg und sechs Tage ein Bild von etwas anderem.
    func testTheSundayFixtureRestsTwoChainsOnAnyWeekday() {
        let jetzt = Date.now
        let mine = MockFixtures.sunday
        let laufend = OfferQuery.current(mine, now: jetzt)
        let fenster = OfferCoverage.windows(
            ended: OfferQuery.ended(mine, now: jetzt),
            upcoming: OfferQuery.upcoming(mine, now: jetzt)
        )

        XCTAssertEqual(Set(laufend.map(\.market)), ["Lidl"],
                       "Genau eine Kette liefert — sonst wäre der Sonntag keiner")
        XCTAssertNotNil(fenster["Aldi"]?.endedOn)
        XCTAssertNotNil(fenster["Aldi"]?.startsOn, "Aldi ruht **mit** Vorschau")
        XCTAssertNotNil(fenster["Netto"]?.endedOn)
        XCTAssertNil(fenster["Netto"]?.startsOn, "Netto ruht **ohne** Vorschau")

        let ruhend = OfferCoverage.restingChains(
            favorites: UITestSupport.seededBranches, current: laufend, windows: fenster
        )
        XCTAssertEqual(ruhend, ["Aldi", "Netto"])
    }
}
