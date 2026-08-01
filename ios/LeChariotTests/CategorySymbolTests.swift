import XCTest
import SwiftUI
@testable import LeChariot

/// **Das Zeichen auf der Angebotskachel.**
///
/// Bis zum 2026-07-31 fiel die Kachel ohne Produktfoto auf das Emoji des
/// Imports zurück. Bei Lidl gibt es aus dem PDF-Prospekt kaum Bild-URLs, und
/// die Liste sah dort aus wie ein Emoji-Teppich (gemeldet am 2026-07-30).
///
/// Schritt 1 lieh sich fünfzehn Systemglyphen aus SF Symbols. Seit dem
/// 2026-08-01 steht hier Schritt 2: der **eigene gezeichnete Satz** in
/// `CategoryGlyph`. Diese Tests sichern, dass jede Kategorie eine Zeichnung
/// hat, dass jede Zeichnung auch etwas zeichnet, und dass die Leiter der
/// Rückfälle darunter unverändert greift.
final class CategorySymbolTests: XCTestCase {

    /// Das Quadrat, in dem gemessen wird. 100 × 100 statt 1 × 1, damit die
    /// Schwellen unten in etwas Ablesbarem stehen.
    private let feld = CGRect(x: 0, y: 0, width: 100, height: 100)

    // MARK: Der Satz ist vollständig

    /// **Der Wachstumsmechanismus.** Kommt eine sechzehnte Kategorie dazu,
    /// sagt dieser Test welche — statt dass sie still auf den nächsten
    /// Rückfall durchfällt und niemandem auffällt.
    func testEveryCategoryHasAGlyphAndNoGlyphIsOrphaned() {
        let ohne = Categories.all.filter { !Categories.hasSymbol($0) }
        XCTAssertTrue(ohne.isEmpty, "Ohne Zeichnung: \(ohne)")

        let verwaist = Set(CategoryGlyph.drawnCategories).subtracting(Categories.all).sorted()
        XCTAssertTrue(verwaist.isEmpty, "Zeichnungen für Kategorien, die es nicht gibt: \(verwaist)")
    }

    /// **Jede Zeichnung muss etwas zeichnen, und zwar in der ganzen Kachel.**
    ///
    /// Der Vorgänger prüfte, ob `UIImage(systemName:)` den Namen kennt — ein
    /// Tippfehler dort ergab eine leere Kachel ohne Warnung. Beim eigenen
    /// Satz gibt es keine Namen mehr, die falsch sein können, dafür Rezepte,
    /// die versehentlich nichts oder fast nichts hinterlassen: ein `guard`,
    /// der zu früh greift, ein Pfad, der nie geschlossen wird, oder — schon
    /// einmal passiert — Punkte, die nicht durch `at()` gehen und deshalb bei
    /// ein paar Pixeln links oben landen statt in der Kachel.
    ///
    /// Deshalb wird der **Rahmen** gemessen und nicht nur „nicht leer".
    ///
    /// **Die Schwellen sind erlaufen, nicht gewählt**, und der erste Versuch
    /// war falsch: 60 % auf *beiden* Achsen. Daran fielen sechs Zeichnungen
    /// durch, die völlig in Ordnung sind — eine Flasche ist schmal (48 breit),
    /// ein Weinglas auch (48), ein Brotlaib flach (56,5 hoch). Das ist
    /// Gestaltung, kein Fehler. Geprüft wird deshalb, was ein kaputtes Rezept
    /// wirklich verrät: Die **lange** Seite muss die Kachel ausnutzen
    /// (≥ 70 von 100 — die kleinste ist die Milchtüte mit 84), und die
    /// **kurze** darf nicht zum Strich entarten (≥ 40; die schmalsten sind
    /// Flasche und Glas mit 48).
    ///
    /// Und der Rahmen muss **in** der Kachel liegen — gegen eine Zeichnung,
    /// die neben der Kachel landet. Gegen eine, die *in* der Kachel an der
    /// falschen Stelle landet, hilft er nicht; dafür steht
    /// `testEveryPointScalesWithTheTile` weiter unten.
    func testEveryGlyphDrawsSomethingThatFillsItsTile() throws {
        for kategorie in Categories.all {
            let zeichnung = try XCTUnwrap(CategoryGlyph.drawing(for: kategorie, in: feld),
                                          "\(kategorie) hat gar keine Zeichnung")
            let rahmen = zeichnung.stroke.boundingRect.union(zeichnung.fill.boundingRect)
            XCTAssertFalse(rahmen.isNull, "\(kategorie) zeichnet nichts")
            XCTAssertGreaterThanOrEqual(
                max(rahmen.width, rahmen.height), 70,
                "\(kategorie) nutzt die Kachel nicht aus: \(rahmen.size)")
            XCTAssertGreaterThanOrEqual(
                min(rahmen.width, rahmen.height), 40,
                "\(kategorie) ist zu einem Strich entartet: \(rahmen.size)")
            // Luft nach außen: die halbe Strichstärke darf über den Rand.
            let luft = 100 * CategoryGlyph.lineWidthRatio
            XCTAssertGreaterThan(rahmen.minX, -luft, "\(kategorie) ragt links aus der Kachel")
            XCTAssertGreaterThan(rahmen.minY, -luft, "\(kategorie) ragt oben aus der Kachel")
            XCTAssertLessThan(rahmen.maxX, 100 + luft, "\(kategorie) ragt rechts aus der Kachel")
            XCTAssertLessThan(rahmen.maxY, 100 + luft, "\(kategorie) ragt unten aus der Kachel")
        }
    }

    /// **Jeder Punkt muss mit der Kachel wachsen.**
    ///
    /// Das ist der Test für den einen Fehler, den dieser Satz beim Zeichnen
    /// tatsächlich hatte: Die Äste der Schneeflocke wurden aus rohen
    /// Einheitszahlen gebaut und nie durch `at()` geschickt. Sie landeten
    /// dadurch bei Bruchteilen eines Punktes neben dem Ursprung statt am Arm
    /// — auf dem Prüfbogen ein Fleck neben der Flocke, bei 13 pt Schmutz.
    ///
    /// **Der Rahmentest darüber fängt das nicht**, und das ist nachgeprüft
    /// und nicht vermutet: Der Fehler wurde nach dem Beheben noch einmal
    /// eingebaut, und alle elf Tests blieben grün. Die Achsen der Flocke
    /// spannen die Kachel weiterhin auf, und die verirrten Striche liegen in
    /// der Ecke **innerhalb** der Kachel — für einen Rahmen ist das nicht zu
    /// unterscheiden.
    ///
    /// Was den Unterschied macht, ist die **Skalierung**: Ein Punkt, der
    /// durch `at()` geht, wird viermal so groß, wenn die Kachel viermal so
    /// groß wird. Eine Einheitszahl, die es nicht tut, bleibt stehen, wo sie
    /// ist. Ein Verhältnis braucht keine Schwelle, die jemand geraten hat.
    func testEveryPointScalesWithTheTile() throws {
        for kategorie in Categories.all {
            let klein = try XCTUnwrap(CategoryGlyph.drawing(for: kategorie, in: feld))
            let groß = try XCTUnwrap(CategoryGlyph.drawing(
                for: kategorie, in: CGRect(x: 0, y: 0, width: 400, height: 400)))
            let a = klein.stroke.boundingRect.union(klein.fill.boundingRect)
            let b = groß.stroke.boundingRect.union(groß.fill.boundingRect)
            for (name, paar) in [("minX", (a.minX, b.minX)), ("minY", (a.minY, b.minY)),
                                 ("maxX", (a.maxX, b.maxX)), ("maxY", (a.maxY, b.maxY))] {
                XCTAssertEqual(paar.1, paar.0 * 4, accuracy: 0.5,
                               "\(kategorie): \(name) wächst nicht mit der Kachel "
                               + "(\(paar.0) → \(paar.1), erwartet \(paar.0 * 4)). "
                               + "Ein Punkt ist nicht durch at() gegangen.")
            }
        }
    }

    /// **Zwei Kategorien dürfen nicht dieselbe Zeichnung bekommen.**
    ///
    /// Beim Abtippen von fünfzehn Rezepten ist eine kopierte Zeile die
    /// naheliegendste Verwechslung, und sie fällt beim Ansehen nicht auf:
    /// Zwei gleiche Zeichen stehen selten nebeneinander. Verglichen wird die
    /// Beschreibung des Pfades, nicht der Rahmen — zwei verschiedene Motive
    /// können denselben Rahmen haben.
    func testNoTwoCategoriesShareTheSameDrawing() {
        var gesehen: [String: String] = [:]
        for kategorie in Categories.all {
            guard let zeichnung = CategoryGlyph.drawing(for: kategorie, in: feld) else { continue }
            let abdruck = zeichnung.stroke.description + "|" + zeichnung.fill.description
            if let anderer = gesehen[abdruck] {
                XCTFail("\(kategorie) und \(anderer) zeichnen dasselbe")
            }
            gesehen[abdruck] = kategorie
        }
    }

    /// Die Kachel ist quadratisch, auch wenn das Rechteck es nicht ist: In
    /// ein doppelt so breites Rechteck gelegt, kommt **dieselbe** Zeichnung
    /// heraus, nur in die Mitte gerückt. Eine gestreckte Milchtüte wäre keine.
    ///
    /// Verglichen wird gegen das Quadrat und nicht Breite gegen Höhe: Die
    /// Tüte ist auch im Quadrat 56 × 84, sie ist eben hochkant. Ohne das
    /// Quadrieren in `path(in:)` wäre sie hier 112 breit.
    func testTheGlyphStaysSquareInsideAWideRect() {
        let form = CategoryGlyphShape(category: "Molkerei & Eier", part: .stroke)
        let imQuadrat = form.path(in: CGRect(x: 0, y: 0, width: 100, height: 100)).boundingRect
        let imBreiten = form.path(in: CGRect(x: 0, y: 0, width: 200, height: 100)).boundingRect
        XCTAssertEqual(imBreiten.width, imQuadrat.width, accuracy: 0.5,
                       "Die Zeichnung wurde in die Breite gezogen")
        XCTAssertEqual(imBreiten.height, imQuadrat.height, accuracy: 0.5,
                       "Die Zeichnung wurde in die Höhe gezogen")
        XCTAssertEqual(imBreiten.midX, 100, accuracy: 1, "Nicht mittig")
    }

    /// Eine Kategorie, die der Satz nicht kennt, zeichnet nichts — und liefert
    /// nicht etwa ein leeres `Path()`, das aussähe wie eine Zeichnung.
    func testAnUnknownCategoryHasNoDrawingAtAll() {
        XCTAssertNil(CategoryGlyph.drawing(for: "Blumen & Pflanzen", in: feld))
        XCTAssertFalse(Categories.hasSymbol("Blumen & Pflanzen"))
    }

    // MARK: Die Leiter der Rückfälle

    private func stufe(category: String? = nil, emoji: String? = nil, title: String? = nil)
        -> OfferImageContent.Fallback {
        OfferImageContent.fallback(category: category, emoji: emoji, title: title)
    }

    /// Die Kategorie gewinnt gegen das Emoji — die Reihenfolge der Leiter ist
    /// dieselbe geblieben, nur die erste Sprosse zeichnet jetzt selbst.
    func testTheCategoryGlyphWinsOverTheImportsEmoji() {
        XCTAssertEqual(
            stufe(category: "Molkerei & Eier", emoji: "🥛", title: "Bio Vollmilch"),
            .glyph("Molkerei & Eier")
        )
    }

    /// Eine Kategorie, die dieser Satz nicht kennt, darf keine Zeichnung
    /// erfinden — dann trägt das Emoji weiter. Der Import kann Kategorien
    /// liefern, die hier noch fehlen.
    func testAnUnknownCategoryFallsThroughToTheEmoji() {
        XCTAssertEqual(
            stufe(category: "Blumen & Pflanzen", emoji: "🌷", title: "Tulpen"),
            .emoji("🌷")
        )
    }

    /// Weder Kategorie noch Emoji: der Anfangsbuchstabe, gestaltet.
    func testWithoutCategoryOrEmojiTheInitialCarriesTheTile() {
        XCTAssertEqual(stufe(title: "bauchschläferkissen"), .initial("B"))
        XCTAssertEqual(stufe(title: "  Ölsardinen"), .initial("Ö"))
    }

    /// Eine Ziffer ist auch ein Anfang — „1000 Blüten Tee" bekommt die 1 und
    /// nicht den Einkaufswagen.
    func testADigitIsAValidInitialToo() {
        XCTAssertEqual(stufe(title: "1000 Blüten Tee"), .initial("1"))
    }

    /// Fängt der Titel mit Satzzeichen an oder ist er leer, bleibt der
    /// Einkaufswagen. Ein „•" auf der Kachel wäre schlimmer als gar nichts.
    func testPunctuationOrNothingLeavesTheCart() {
        XCTAssertEqual(stufe(title: "— ohne Namen"), .cart)
        XCTAssertEqual(stufe(title: "   "), .cart)
        XCTAssertEqual(stufe(), .cart)
    }

    /// Ein leeres Emoji-Feld ist kein Emoji. Der Import liefert für ungetaggte
    /// Zeilen den leeren String, nicht `nil` — ohne diese Prüfung stünde dort
    /// eine leere Kachel statt des Buchstabens.
    func testAnEmptyEmojiStringIsNotAnEmoji() {
        XCTAssertEqual(stufe(emoji: "", title: "Gulasch"), .initial("G"))
    }
}
