import XCTest
import SwiftUI
@testable import LeChariot

/// **Die zwei gezeichneten Zeichen der Bedienoberfläche** ([UI-3], 01.08.).
///
/// Vorher standen dort `sparkles` und `wand.and.sparkles` — zwei
/// Glitzer-Glyphen, die Zauberei versprechen, wo eine Einführung und ein
/// Aufräumen stehen. Geprüft wird dasselbe wie beim Kategoriensatz: dass jede
/// Zeichnung etwas zeichnet, dass sie die Kachel ausnutzt und dass sie darin
/// bleibt.
final class AppGlyphTests: XCTestCase {
    private let feld = CGRect(x: 0, y: 0, width: 100, height: 100)

    func testEveryGlyphDrawsSomethingThatFillsItsTile() {
        for glyph in AppGlyph.all {
            let zeichnung = glyph.drawing(in: feld)
            let rahmen = zeichnung.stroke.boundingRect.union(zeichnung.fill.boundingRect)
            XCTAssertFalse(rahmen.isNull, "\(glyph) zeichnet nichts")
            XCTAssertGreaterThanOrEqual(
                max(rahmen.width, rahmen.height), 70,
                "\(glyph) nutzt die Kachel nicht aus: \(rahmen.size)")
            XCTAssertGreaterThanOrEqual(
                min(rahmen.width, rahmen.height), 40,
                "\(glyph) ist zu einem Strich entartet: \(rahmen.size)")

            let luft = 100 * AppGlyph.lineWidthRatio
            XCTAssertGreaterThan(rahmen.minX, -luft, "\(glyph) ragt links aus der Kachel")
            XCTAssertGreaterThan(rahmen.minY, -luft, "\(glyph) ragt oben aus der Kachel")
            XCTAssertLessThan(rahmen.maxX, 100 + luft, "\(glyph) ragt rechts aus der Kachel")
            XCTAssertLessThan(rahmen.maxY, 100 + luft, "\(glyph) ragt unten aus der Kachel")
        }
    }

    /// Jeder Punkt geht durch `at()` und wächst deshalb mit der Kachel. Ein
    /// vergessenes `at()` landet bei ein paar Pixeln links oben und fällt in
    /// der 13-pt-Zeile nicht auf — im verschobenen Rechteck schon.
    func testEveryPointScalesAndMovesWithTheTile() {
        let verschoben = CGRect(x: 400, y: 250, width: 60, height: 60)
        for glyph in AppGlyph.all {
            let klein = glyph.drawing(in: feld)
            let groß = glyph.drawing(in: verschoben)
            let a = klein.stroke.boundingRect.union(klein.fill.boundingRect)
            let b = groß.stroke.boundingRect.union(groß.fill.boundingRect)

            XCTAssertEqual(b.width / a.width, 0.6, accuracy: 0.01, "\(glyph) skaliert nicht")
            XCTAssertGreaterThan(b.minX, 400 - 6, "\(glyph) folgt der Kachel nicht nach rechts")
            XCTAssertGreaterThan(b.minY, 250 - 6, "\(glyph) folgt der Kachel nicht nach unten")
        }
    }

    /// Der Bedienzeichensatz ist **nicht** Teil der fünfzehn Kategorien — der
    /// Test drüben hält fest, dass es genau fünfzehn sind, und diese zwei
    /// gehören nicht dazu.
    func testTheActionGlyphsAreNotCategories() {
        XCTAssertFalse(CategoryGlyph.drawnCategories.contains("tour"))
        XCTAssertEqual(CategoryGlyph.drawnCategories.count, 15)
    }

    /// Beide Zeichen benutzen dieselbe Strichstärke wie der Kategoriensatz —
    /// ein zweiter Wert wäre ein zweiter Zeichenstil.
    func testTheStrokeMatchesTheCategorySet() {
        XCTAssertEqual(AppGlyph.lineWidthRatio, CategoryGlyph.lineWidthRatio)
    }
}
