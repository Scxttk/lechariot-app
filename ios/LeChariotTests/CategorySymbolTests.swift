import XCTest
import UIKit
@testable import LeChariot

/// **Das Zeichen auf der Angebotskachel.**
///
/// Bis zum 2026-07-31 fiel die Kachel ohne Produktfoto auf das Emoji des
/// Imports zurück. Bei Lidl gibt es aus dem PDF-Prospekt kaum Bild-URLs, und
/// die Liste sah dort aus wie ein Emoji-Teppich (gemeldet am 2026-07-30).
///
/// Schritt 1 von zwei: Systemzeichen je Kategorie. Schritt 2 — ein eigener
/// gezeichneter Satz — steht als eigene Aufgabe. Diese Tests sichern, was
/// Schritt 1 verspricht, und nicht mehr.
final class CategorySymbolTests: XCTestCase {

    /// **Der Wachstumsmechanismus.** Kommt eine sechzehnte Kategorie dazu,
    /// sagt dieser Test welche — statt dass sie still auf den nächsten
    /// Rückfall durchfällt und niemandem auffällt.
    func testEveryCategoryHasASymbolAndNoSymbolIsOrphaned() {
        let ohne = Categories.all.filter { Categories.symbol(for: $0) == nil }
        XCTAssertTrue(ohne.isEmpty, "Ohne Zeichen: \(ohne)")

        let verwaist = Set(Categories.allSymbols.keys).subtracting(Categories.all).sorted()
        XCTAssertTrue(verwaist.isEmpty, "Zeichen für Kategorien, die es nicht gibt: \(verwaist)")
    }

    /// **Jeder Name muss ein Zeichen sein, das dieses iOS auch kennt.**
    ///
    /// `Image(systemName:)` zeichnet für einen unbekannten Namen schlicht
    /// nichts — keine Warnung, kein Absturz, eine leere Kachel. Genau die
    /// stille Sorte, gegen die dieses Projekt inzwischen mehrfach angetreten
    /// ist, und ein Tippfehler reicht.
    func testEverySymbolNameExistsOnThisSystem() {
        for (kategorie, name) in Categories.allSymbols.sorted(by: { $0.key < $1.key }) {
            XCTAssertNotNil(
                UIImage(systemName: name),
                "„\(name)“ (\(kategorie)) gibt es auf diesem System nicht — die Kachel bliebe leer"
            )
        }
    }

    // MARK: Die Leiter der Rückfälle

    private func stufe(category: String? = nil, emoji: String? = nil, title: String? = nil)
        -> OfferImageContent.Fallback {
        OfferImageContent.fallback(category: category, emoji: emoji, title: title)
    }

    /// Die Kategorie gewinnt gegen das Emoji — das ist die eigentliche
    /// Änderung. Vorher war es andersherum.
    func testTheCategorySymbolWinsOverTheImportsEmoji() {
        XCTAssertEqual(
            stufe(category: "Molkerei & Eier", emoji: "🥛", title: "Bio Vollmilch"),
            .symbol("waterbottle")
        )
    }

    /// Eine Kategorie, die diese Liste nicht kennt, darf kein Zeichen
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
