import SwiftUI
import UIKit
import XCTest
@testable import LeChariot

/// **Die Preisfahne über den detaillierten Zeichnungen** — Bedienrunde 11.08.,
/// Punkt 2: „Preis in Kacheln soll etwas weiter oben und etwas weiter rechts
/// sein um Produkt nicht zu verdecken."
///
/// **Warum ein Bogen und keine Zusicherung.** „Verdeckt die Zeichnung" ist eine
/// Aussage über zwei übereinanderliegende Formen; eine Zahl allein sagt nicht,
/// ob das, was verschwindet, das Erkennungsmerkmal war. Der Bogen zeigt jede
/// der Zeichnungen aus den Detail-Tranchen (#133, #137) mit Fahne, dazu die
/// drei Fälle, die Scott genannt hat, groß.
///
/// **Der Anteil ist trotzdem gemessen**, offline gegen die Pfade gerechnet
/// (Kontur und Körperfläche getrennt, siehe [[Le Chariot Log]] zum 12.08.):
/// beim alten Versatz (+4, 0) lagen im Mittel **20 %** der Kontur und **23 %**
/// der Fläche unter der Fahne, beim neuen (+8, −5) sind es **7 %** und **4 %**.
/// Die Fläche zählt erst, seit jeder geschlossene Umriss eine trägt (#150) —
/// vorher war unter der Fahne meistens nichts.
@MainActor
final class KachelFahneShots: XCTestCase {
    /// Die 19 Zeichnungen der beiden Detail-Tranchen — sie vertragen am
    /// wenigsten Überdeckung, weil ihr Unterschied zum Nachbarn in den
    /// Einzelheiten steckt (Rindenband, Giebelkante, Noppen). Dazu `äpfel` und
    /// `fisch`: das eine ist Scotts dritter genannter Fall, das andere seit
    /// #150 neu gezeichnet.
    private static let detailzeichen = [
        "Milch", "Eier", "Brot", "Käse", "Zucker", "Zitronen", "Gurke", "Sahne",
        "Tee", "Butter", "Quark", "Joghurt", "Tomaten", "Salat", "Bananen",
        "Schinken", "Pilze", "Maiskolben", "Limonade", "Äpfel", "Fisch",
    ]

    /// Die drei, die Scott für den Bogen genannt hat — und sie haben dasselbe
    /// gemeinsam: Stiel der Banane, Kelch des Apfels und Giebel der Milchtüte
    /// liegen alle drei oben rechts, genau unter der Fahne.
    private static let schlimmsteFaelle = ["Bananen", "Äpfel", "Milch"]

    func testDieFahneUeberDenDetailzeichen() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .light ? "hell" : "dunkel"
            try schreibeBogen(FahnenBogen(namen: Self.detailzeichen),
                              named: "kachel-fahne-detailzeichen-\(suffix)",
                              scheme: scheme, groesse: CGSize(width: 393, height: 1000))
            // Dieselben drei doppelt: einmal mit gehefteter Wahl, denn die
            // Fahne trägt dann zusätzlich die Reißzwecke und wird breiter.
            try schreibeBogen(FahnenBogen(namen: Self.schlimmsteFaelle, gross: true),
                              named: "kachel-fahne-schlimmste-\(suffix)",
                              scheme: scheme, groesse: CGSize(width: 393, height: 420))
        }
    }

    /// **Der Bogen soll zeigen, was er behauptet.** Löst einer der Namen nicht
    /// auf seinen Begriff auf, steht auf der Kachel ein Fragezeichen — und ein
    /// Fragezeichen hat nichts, was die Fahne verdecken könnte.
    func testJederNameLoestAufSeineZeichnungAuf() {
        for name in Self.detailzeichen {
            let begriff = ItemGlyphTerm.term(for: name)
            XCTAssertEqual(begriff, name.lowercased(),
                           "\(name) auf dem Bogen zeigt die Zeichnung von \(begriff ?? "gar nichts")")
        }
    }
}

/// Das Raster, wie die Liste es zeigt — dieselbe Kachel, dieselben Spalten.
private struct FahnenBogen: View {
    let namen: [String]
    /// Groß heißt: zwei Reihen desselben Artikels, oben ohne, unten mit
    /// gehefteter Wahl.
    var gross = false

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: ShoppingGridTile.columns,
                          alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Name **und** Heftung im Schlüssel: Mit `id: \.self` auf
                    // dem Namen allein verschluckt `LazyVGrid` die zweite
                    // Reihe, weil beide Reihen dieselben Namen tragen.
                    ForEach(kacheln, id: \.schluessel) { eintrag in
                        ShoppingGridTile(
                            item: ShoppingItem(text: eintrag.name),
                            suggestion: vorschlag(eintrag.name, angeheftet: eintrag.angeheftet),
                            onToggle: {}, onOpenItem: {}, onDelete: {}
                        )
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: Theme.Spacing.xs, leading: Theme.Spacing.lg,
                    bottom: Theme.Spacing.xs, trailing: Theme.Spacing.lg
                ))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private struct Kachel {
        let name: String
        let angeheftet: Bool
        var schluessel: String { angeheftet ? name + "+" : name }
    }

    private var kacheln: [Kachel] {
        namen.map { Kachel(name: $0, angeheftet: false) }
            + (gross ? namen.map { Kachel(name: $0, angeheftet: true) } : [])
    }

    /// Derselbe Preis für alle — 1,29 € ist die Fahne, gegen die auch offline
    /// gerechnet wurde (39 × 15 pt). Zwei verschieden breite Fahnen auf einem
    /// Bogen wären zwei Fragen in einem Bild.
    private func vorschlag(_ name: String, angeheftet: Bool) -> ItemSuggestion {
        let angebot = Offer(
            marketId: "lidl-01219-1", market: "Lidl", product: name,
            price: 1.29, regularPrice: 1.99, unit: nil, category: "Obst & Gemüse",
            emoji: nil, validFrom: Date(), validUntil: Date(),
            basePrice: nil, baseUnit: nil, nationwide: true
        )
        return ItemSuggestion(match: OfferMatch(offer: angebot, kind: .direct),
                              isPinned: angeheftet)
    }
}
