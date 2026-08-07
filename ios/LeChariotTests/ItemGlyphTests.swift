import XCTest
import SwiftUI
@testable import LeChariot

/// **Der Artikel-Zeichensatz — achtzig Zeichnungen, eine je Wörterbuchbegriff.**
///
/// Das Kategoriezeichen reichte, solange es im Abschnittskopf stand. Im Raster
/// trägt **jede Kachel** ihr eigenes Zeichen, und dort standen Erdbeeren,
/// Bananen, Tomaten, Zwiebeln und Salat mit demselben Apfel nebeneinander.
///
/// Diese Tests sichern dasselbe wie `CategorySymbolTests` für den
/// Kategoriesatz, nur gegen eine Liste, die sich ändert: Das Wörterbuch wächst
/// mit jeder Pflegerunde. Der erste Test ist deshalb der wichtigste — er sagt,
/// **welcher** neue Begriff noch keine Zeichnung hat, statt ihn still auf das
/// Kategoriezeichen durchfallen zu lassen.
final class ItemGlyphTests: XCTestCase {

    /// Das Feld, in dem gemessen wird. 100 × 100 statt 1 × 1, damit die
    /// Schwellen unten in etwas Ablesbarem stehen.
    private let feld = CGRect(x: 0, y: 0, width: 100, height: 100)

    // MARK: Der Satz deckt das Wörterbuch ab

    /// **Der Wachstumsmechanismus.** Jeder Begriff hat entweder eine Zeichnung
    /// oder steht namentlich in `ItemGlyph.withoutDrawing` — und beides
    /// zugleich geht nicht.
    ///
    /// Die Gegenrichtung zählt genauso: Eine Zeichnung für einen Begriff, den
    /// das Wörterbuch nicht (mehr) kennt, wird nie gezeigt und niemandem fällt
    /// es auf. Nach einer Pflegerunde, die einen Begriff umbenennt, sagt dieser
    /// Test, welche Zeichnung ins Leere zeigt.
    func testEveryDictionaryTermIsDrawnOrNamedAsAnException() {
        let wörterbuch = Set(MatchDictionary.allTerms)
        XCTAssertEqual(wörterbuch.count, 208,
                       "Das Wörterbuch hat sich geändert — die Zahl hier ist nur der Wecker, "
                       + "die Arbeit steht in den Meldungen darunter.")

        let gezeichnet = Set(ItemGlyph.drawnTerms)
        let ausnahmen = ItemGlyph.withoutDrawing

        let ohneAntwort = wörterbuch.subtracting(gezeichnet).subtracting(ausnahmen).sorted()
        XCTAssertTrue(ohneAntwort.isEmpty,
                      "Weder Zeichnung noch benannte Ausnahme: \(ohneAntwort)")

        let beides = gezeichnet.intersection(ausnahmen).sorted()
        XCTAssertTrue(beides.isEmpty,
                      "Steht in der Ausnahmeliste und hat trotzdem eine Zeichnung: \(beides)")

        let verwaist = gezeichnet.union(ausnahmen).subtracting(wörterbuch).sorted()
        XCTAssertTrue(verwaist.isEmpty,
                      "Zeigt auf einen Begriff, den das Wörterbuch nicht kennt: \(verwaist)")
    }

    /// Eine Ausnahme zeichnet **nichts** — und liefert nicht etwa ein leeres
    /// `Path()`, das der Aufrufstelle wie eine Zeichnung vorkäme. Nur so
    /// greift der Rückfall auf das Kategoriezeichen.
    func testTheNamedExceptionsHaveNoDrawingAtAll() {
        for begriff in ItemGlyph.withoutDrawing.sorted() {
            XCTAssertNil(ItemGlyph.drawing(for: begriff, in: feld),
                         "\(begriff) steht als Ausnahme und zeichnet trotzdem")
        }
        XCTAssertNil(ItemGlyph.drawing(for: "bauchschläferkissen", in: feld))
    }

    // MARK: Nichts verlässt die Kachel

    /// **Jede Zeichnung nutzt ihre Kachel und bleibt darin.**
    ///
    /// Die Schwellen sind **gemessen, nicht geraten** (`tools/zeichensatz.swift
    /// … masse`): Die kürzeste lange Seite hat die Brotscheibe mit 60, die
    /// schmalste kurze die Weinflasche mit 32. Beim Kategoriesatz war der erste
    /// Versuch mit geratenen Schwellen falsch und ließ sechs gesunde
    /// Zeichnungen durchfallen — schmal ist bei einer Flasche Gestaltung und
    /// kein Fehler.
    ///
    /// Der Rand ist der eigentliche Punkt: Im Raster sitzt das Zeichen in einer
    /// festen Kachel, und was darüber hinausragt, wird an der Kante
    /// abgeschnitten.
    func testEveryGlyphFillsItsTileAndStaysInside() throws {
        let luft = 100 * CategoryGlyph.lineWidthRatio / 2
        for begriff in ItemGlyph.drawnTerms {
            let zeichnung = try XCTUnwrap(ItemGlyph.drawing(for: begriff, in: feld))
            let rahmen = zeichnung.stroke.boundingRect.union(zeichnung.fill.boundingRect)
            XCTAssertFalse(rahmen.isNull, "\(begriff) zeichnet nichts")
            XCTAssertGreaterThanOrEqual(
                max(rahmen.width, rahmen.height), 55,
                "\(begriff) nutzt die Kachel nicht aus: \(rahmen.size)")
            XCTAssertGreaterThanOrEqual(
                min(rahmen.width, rahmen.height), 28,
                "\(begriff) ist zu einem Strich entartet: \(rahmen.size)")
            XCTAssertGreaterThan(rahmen.minX, -luft, "\(begriff) ragt links aus der Kachel")
            XCTAssertGreaterThan(rahmen.minY, -luft, "\(begriff) ragt oben aus der Kachel")
            XCTAssertLessThan(rahmen.maxX, 100 + luft, "\(begriff) ragt rechts aus der Kachel")
            XCTAssertLessThan(rahmen.maxY, 100 + luft, "\(begriff) ragt unten aus der Kachel")
        }
    }

    /// **Jeder Punkt wächst mit der Kachel.**
    ///
    /// Der Test für den einen Fehler, den der Kategoriesatz beim Zeichnen
    /// wirklich hatte: Punkte, die aus rohen Einheitszahlen gebaut und nie
    /// durch `at()` geschickt wurden, landeten bei Bruchteilen eines Punktes
    /// neben dem Ursprung. Der Rahmentest darüber sieht das nicht — die
    /// verirrten Striche liegen **innerhalb** der Kachel.
    ///
    /// Bei achtzig Zeichnungen mit eigener Rechnerei (`achse`, `quer`, die
    /// Schleifen über Körner und Flocken) ist das kein Restrisiko, sondern der
    /// wahrscheinlichste Fehler überhaupt.
    func testEveryPointScalesWithTheTile() throws {
        for begriff in ItemGlyph.drawnTerms {
            let klein = try XCTUnwrap(ItemGlyph.drawing(for: begriff, in: feld))
            let groß = try XCTUnwrap(ItemGlyph.drawing(
                for: begriff, in: CGRect(x: 0, y: 0, width: 400, height: 400)))
            let a = klein.stroke.boundingRect.union(klein.fill.boundingRect)
            let b = groß.stroke.boundingRect.union(groß.fill.boundingRect)
            for (name, paar) in [("minX", (a.minX, b.minX)), ("minY", (a.minY, b.minY)),
                                 ("maxX", (a.maxX, b.maxX)), ("maxY", (a.maxY, b.maxY))] {
                XCTAssertEqual(paar.1, paar.0 * 4, accuracy: 0.5,
                               "\(begriff): \(name) wächst nicht mit der Kachel "
                               + "(\(paar.0) → \(paar.1)). Ein Punkt ist nicht durch at() gegangen.")
            }
        }
    }

    /// **Zwei Begriffe dürfen nicht dieselbe Zeichnung bekommen.**
    ///
    /// Bei achtzig abgetippten Rezepten ist die kopierte Zeile die
    /// naheliegendste Verwechslung, und im Raster fällt sie nicht auf: Zwei
    /// gleiche Zeichen stehen selten nebeneinander. Verglichen wird die
    /// Beschreibung des Pfades, nicht der Rahmen — zwei verschiedene Motive
    /// können denselben Rahmen haben.
    func testNoTwoTermsShareTheSameDrawing() {
        var gesehen: [String: String] = [:]
        for begriff in ItemGlyph.drawnTerms {
            guard let zeichnung = ItemGlyph.drawing(for: begriff, in: feld) else { continue }
            let abdruck = zeichnung.stroke.description + "|" + zeichnung.fill.description
            if let anderer = gesehen[abdruck] {
                XCTFail("\(begriff) und \(anderer) zeichnen dasselbe")
            }
            gesehen[abdruck] = begriff
        }
    }

    /// Die Kachel ist quadratisch, auch wenn das Rechteck es nicht ist: In ein
    /// doppelt so breites Rechteck gelegt kommt dieselbe Zeichnung heraus, nur
    /// mittig. Eine in die Breite gezogene Möhre wäre keine.
    func testTheGlyphStaysSquareInsideAWideRect() {
        let form = ItemGlyphShape(term: "möhren", part: .stroke)
        let imQuadrat = form.path(in: CGRect(x: 0, y: 0, width: 100, height: 100)).boundingRect
        let imBreiten = form.path(in: CGRect(x: 0, y: 0, width: 200, height: 100)).boundingRect
        XCTAssertEqual(imBreiten.width, imQuadrat.width, accuracy: 0.5,
                       "Die Zeichnung wurde in die Breite gezogen")
        XCTAssertEqual(imBreiten.height, imQuadrat.height, accuracy: 0.5,
                       "Die Zeichnung wurde in die Höhe gezogen")
        XCTAssertEqual(imBreiten.midX, 100, accuracy: 1, "Nicht mittig")
    }

    // MARK: Vom Artikeltext zum Begriff

    /// Der Weg, für den der ganze Satz gebaut ist: Was jemand tippt, muss beim
    /// richtigen Begriff landen.
    func testTheTermResolverAnswersFromTheDictionary() {
        XCTAssertEqual(ItemGlyphTerm.term(for: "Erdbeeren"), "beeren")
        XCTAssertEqual(ItemGlyphTerm.term(for: "Vollmilch"), "milch")
        XCTAssertEqual(ItemGlyphTerm.term(for: "Zahnpasta"), "windeln/hygiene")
        // Mehrwortig: als Wendung, nicht als Einzelwort — „creme" allein ist
        // kein Begriff.
        XCTAssertEqual(ItemGlyphTerm.term(for: "Crème fraîche"), "sahne")
        // Kopf-final: das letzte Wort ist der Artikel, das erste die Sorte.
        XCTAssertEqual(ItemGlyphTerm.term(for: "Erdbeer Joghurt"), "joghurt")
        // Die Sperrlisten gelten mit: „Erdnussbutter" ist in `butter` gesperrt
        // und steht in keiner anderen exact-Liste — also kein Begriff und
        // damit das Kategoriezeichen. Das ist der Fall, für den es die
        // Rückfallleiter gibt.
        XCTAssertNil(ItemGlyphTerm.term(for: "Erdnussbutter"))
        // **Eine Sperre gilt aber nur für den Begriff, der sie aufstellt.**
        // „Buttermilch" ist in `butter` gesperrt und steht zugleich in der
        // exact-Liste von `milch`; sie bekommt die Milchtüte. „Milchreis" ist
        // in `milch` gesperrt und steht bei `pudding`. Beides ist die Meinung
        // des Zuordners, und dieser Satz hat dazu keine zweite: Wer es anders
        // will, ändert das Wörterbuch, nicht die Zeichnungen.
        XCTAssertEqual(ItemGlyphTerm.term(for: "Buttermilch"), "milch")
        XCTAssertEqual(ItemGlyphTerm.term(for: "Milchreis"), "pudding")
        XCTAssertNil(ItemGlyphTerm.term(for: "Bauchschläferkissen"))
        XCTAssertNil(ItemGlyphTerm.term(for: "   "))
    }

    /// Und der Weg bis zur Zeichnung, für die Wörter aus Scotts eigener Liste:
    /// Jedes davon muss ein Zeichen bekommen, das **es selbst** meint — nicht
    /// das seiner Kategorie. Das war der Anlass für den ganzen Satz.
    func testTheFiveThatUsedToShareOneAppleNowDiffer() throws {
        let wörter = ["Erdbeeren", "Bananen", "Tomaten", "Zwiebeln", "Salat"]
        var abdrücke: Set<String> = []
        for wort in wörter {
            let begriff = try XCTUnwrap(ItemGlyphTerm.term(for: wort), "\(wort) ohne Begriff")
            let zeichnung = try XCTUnwrap(ItemGlyph.drawing(for: begriff, in: feld),
                                          "\(wort) → \(begriff) ohne Zeichnung")
            abdrücke.insert(zeichnung.stroke.description + "|" + zeichnung.fill.description)
        }
        XCTAssertEqual(abdrücke.count, wörter.count,
                       "Zwei dieser fünf tragen wieder dasselbe Zeichen")
    }
}
