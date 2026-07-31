import XCTest
@testable import LeChariot

/// **Die Herkunfts-Zeile — und der Grund, warum `created_at` als Zeichenkette
/// im Modell steht.**
///
/// Die Zeile sagt drei Dinge: welche Kette, bis wann der Preis gilt, wann er
/// geholt wurde. Zwei davon standen schon in der Zeile; das dritte ist neu und
/// ist genau das, was still falsch werden kann.
final class OfferProvenanceTests: XCTestCase {

    /// Ein Datensatz in der Form, die PostgREST wirklich liefert — abgeschrieben
    /// von einer echten Zeile am 2026-07-31.
    private let echteZeile = """
    [{"market":"Lidl","product":"Bio Vollmilch","price":0.99,"regular_price":1.29,\
    "unit":"je 1 l","category":"Molkerei & Eier","emoji":null,\
    "valid_from":"2026-07-27","valid_until":"2026-08-01",\
    "base_price":null,"base_unit":null,"nationwide":false,\
    "market_id":"LIDL_5745","match_key":[],"image_url":null,\
    "created_at":"2026-07-31T10:22:14.055484+00:00"}]
    """

    // MARK: Die Falle im Decoder

    /// **Der eigentliche Fund.** Der Decoder dieser Tabelle parst Daten mit
    /// `"yyyy-MM-dd"`, weil `valid_from` und `valid_until` reine Tage sind.
    /// `created_at` ist ein voller Zeitstempel. Stünde es als `Date?` im
    /// Modell, bekäme `decodeIfPresent` den Zeitstempel, gäbe ihn an diesen
    /// Formatter, bekäme nil zurück — und **würfe**. Ein Optional fängt einen
    /// fehlenden Schlüssel ab, niemals einen unlesbaren Wert.
    ///
    /// Ergebnis wäre: keine einzige Angebotszeile dekodiert, der Angebote-Tab
    /// leer, und zwar erst in der Produktion, weil die Testdaten das Feld bis
    /// heute nicht hatten.
    func testTheRealRowDecodesThroughTheAppsOwnDecoder() throws {
        let offers = try JSONDecoder.supabase.decode([Offer].self, from: Data(echteZeile.utf8))
        XCTAssertEqual(offers.count, 1)
        XCTAssertEqual(offers[0].product, "Bio Vollmilch")
        XCTAssertEqual(offers[0].createdAt, "2026-07-31T10:22:14.055484+00:00")
    }

    /// Und der Beleg, dass die Falle echt ist und nicht nur befürchtet: Dasselbe
    /// Feld als `Date` deklariert, derselbe Decoder, derselbe Datensatz.
    ///
    /// Fällt dieser Test um, ist der Kommentar in `Offer.createdAt` falsch
    /// geworden — dann darf man das Feld auch als `Date?` führen.
    func testTheSameFieldAsADateWouldBringTheWholeTabDown() {
        struct NaiveOffer: Decodable {
            let product: String
            let createdAt: Date?
            enum CodingKeys: String, CodingKey {
                case product
                case createdAt = "created_at"
            }
        }
        XCTAssertThrowsError(
            try JSONDecoder.supabase.decode([NaiveOffer].self, from: Data(echteZeile.utf8)),
            "Wenn das hier nicht mehr wirft, ist die Begründung im Modell hinfällig"
        )
    }

    // MARK: Zeitzone

    /// Der Zeitstempel steht in UTC, gelesen wird die Zeile in Dresden. Im
    /// Sommer sind das zwei Stunden — eine Zeile, die die rohe Stunde druckt,
    /// ist genau um diese zwei daneben.
    func testTheStampIsReadInBerlinAndNotInUTC() throws {
        let offers = try JSONDecoder.supabase.decode([Offer].self, from: Data(echteZeile.utf8))
        let geholt = try XCTUnwrap(offers[0].fetchedAt)

        let zeile = offers[0].provenanceLine(now: geholt)
        XCTAssertTrue(zeile.contains("abgerufen 12:22"),
                      "10:22 UTC sind 12:22 in Berlin — geliefert: \(zeile)")
    }

    /// Ein Zeitstempel ohne Sekundenbruchteile kommt genauso vor — PostgREST
    /// lässt sie weg, wenn es keine gibt. Ein Formatter allein kann nicht
    /// beides.
    func testBothTimestampShapesParse() {
        XCTAssertNotNil(OfferProvenance.fetchedAt("2026-07-31T10:22:14.055484+00:00"))
        XCTAssertNotNil(OfferProvenance.fetchedAt("2026-07-31T10:22:14+00:00"))
        XCTAssertNil(OfferProvenance.fetchedAt(nil))
        XCTAssertNil(OfferProvenance.fetchedAt("gestern früh"))
    }

    // MARK: Die Zeile

    private func datum(_ text: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = OfferProvenance.zone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: text)!
    }

    func testTheShapeScottAskedFor() {
        let zeile = OfferProvenance.line(
            market: "Netto",
            validUntil: datum("2026-08-02 00:00"),
            fetchedAt: datum("2026-08-01 06:30"),
            now: datum("2026-08-01 09:00")
        )
        // **Zwei Abweichungen von der Zeile aus dem Backlog, beide bewusst.**
        //
        // „Sa." mit Punkt, weil das die deutsche Abkürzung ist und `de_DE` sie
        // so schreibt. Und **„So.", nicht „Sa."**: Der 02.08.2026 ist ein
        // Sonntag. Die Beispielzeile im Backlog hat den Wochentag um einen
        // daneben — genau der Grund, ihn zu rechnen statt abzuschreiben.
        XCTAssertEqual(zeile, "Netto · gültig bis So. 02.08. · abgerufen 06:30")
    }

    /// **Der Fall, der die Zeile aus dem Backlog korrigiert.** Gemessen am
    /// 2026-07-31: EDEKAs jüngste Zeile war vom 27.07., für Angebote, die noch
    /// bis zum 01.08. gelten. Nichts hatte sie seither neu geholt — kein
    /// Fehler, aber `abgerufen 19:23` allein läse sich als „heute früh".
    func testAStampFromAnotherDayCarriesItsDay() {
        let zeile = OfferProvenance.line(
            market: "EDEKA",
            validUntil: datum("2026-08-01 00:00"),
            fetchedAt: datum("2026-07-27 19:23"),
            now: datum("2026-07-31 09:00")
        )
        XCTAssertEqual(zeile, "EDEKA · gültig bis Sa. 01.08. · abgerufen Mo. 27.07. 19:23")
    }

    /// Verglichen wird der **Kalendertag**, nicht „weniger als 24 Stunden her":
    /// Um 00:30 ist ein Abruf von gestern 23:50 vierzig Minuten alt und
    /// trotzdem von gestern.
    func testFortyMinutesAgoCanStillBeYesterday() {
        let zeile = OfferProvenance.line(
            market: "Lidl",
            validUntil: datum("2026-08-01 00:00"),
            fetchedAt: datum("2026-07-30 23:50"),
            now: datum("2026-07-31 00:30")
        )
        XCTAssertTrue(zeile.contains("abgerufen Do. 30.07. 23:50"), "geliefert: \(zeile)")
    }

    /// Ohne Zeitstempel fehlt der dritte Teil — statt „abgerufen unbekannt".
    /// Eine Zeile, die ihre eigene Unwissenheit ausstellt, nützt dem Leser
    /// nichts und ist für den nächsten Entwickler eine Einladung, sie
    /// irgendwie zu füllen.
    func testWithoutAStampTheLineSaysTwoThingsAndNotThree() {
        let zeile = OfferProvenance.line(
            market: "Kaufland",
            validUntil: datum("2026-08-05 00:00"),
            fetchedAt: nil,
            now: datum("2026-07-31 09:00")
        )
        XCTAssertEqual(zeile, "Kaufland · gültig bis Mi. 05.08.")
    }

    /// Zeilen aus der Zeit vor dieser Spalte tragen sie nicht — und müssen
    /// weiter dekodieren.
    func testARowWithoutTheColumnStillDecodes() throws {
        let ohne = """
        [{"market":"Lidl","product":"Butter","price":1.49,"regular_price":null,\
        "unit":null,"category":"Molkerei & Eier","emoji":null,\
        "valid_from":"2026-07-27","valid_until":"2026-08-01",\
        "base_price":null,"base_unit":null,"nationwide":false}]
        """
        let offers = try JSONDecoder.supabase.decode([Offer].self, from: Data(ohne.utf8))
        XCTAssertNil(offers[0].fetchedAt)
        XCTAssertEqual(offers[0].provenanceLine(now: datum("2026-07-31 09:00")),
                       "Lidl · gültig bis Sa. 01.08.")
    }
}
