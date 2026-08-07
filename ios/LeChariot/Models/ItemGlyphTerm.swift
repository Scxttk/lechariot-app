import Foundation

/// **Vom getippten Artikel zum Wörterbuchbegriff** — die eine Frage, die
/// zwischen „Erdbeeren" und der Erdbeere auf der Kachel steht.
///
/// **Kein zweites Wörterbuch.** Gefragt wird genau das, was der Zuordner
/// ohnehin kennt (`MatchDictionary`, gespeist aus `matching-woerterbuch.json`).
/// Eine eigene Liste „Wort → Zeichnung" wäre die dritte Stelle, an der
/// Warenkunde gepflegt wird, und zwei Listen, die dasselbe wissen müssen, gehen
/// auseinander — dieselbe Begründung wie in `ShoppingSections` und
/// `Categories.hasSymbol`.
///
/// **Warum das überhaupt eindeutig sein kann:** Nachgezählt am Wörterbuch vom
/// 2026-08-07 — 730 einwortige Synonyme, und **kein einziges** zeigt auf zwei
/// Begriffe. Die Auflösung greift also nie in ein `Set` und nimmt irgendetwas
/// heraus; es gibt je Wort höchstens eine Antwort.
///
/// Diese Datei steht bewusst **nicht** neben den Zeichnungen: `ItemGlyphs.swift`
/// darf nur SwiftUI kennen, sonst lässt sich der Prüfbogen
/// (`tools/zeichensatz.swift`) nicht mehr ohne App-Ziel übersetzen.
enum ItemGlyphTerm {

    /// Der Begriff, den dieser Artikeltext meint — oder `nil`, wenn das
    /// Wörterbuch ihn nicht kennt. Dann bleibt das Kategoriezeichen.
    ///
    /// **Erst die ganze Wendung, dann die Wörter.** „Crème fraîche" ist als
    /// Ganzes `sahne`; einzeln ist „creme" gar nichts.
    ///
    /// **Und unter den Wörtern gewinnt das letzte.** Deutsche Komposita und
    /// Aufzählungen sind kopf-final: Bei „Erdbeer Joghurt" ist das Joghurt der
    /// Artikel und die Erdbeere die Sorte. Das erste Wort zu nehmen hieße,
    /// jedem Joghurt die Frucht aufs Zeichen zu schreiben.
    ///
    /// **Ohne die Suffix-Regeln des Wörterbuchs**, aus demselben Grund, aus
    /// dem `MatchDictionary` sie für die Suche auslässt: Sie sind fürs
    /// Abgrasen von Produkttiteln gebaut und greifen auf ein Suchwort zu weit.
    static func term(for text: String) -> String? {
        let normalisiert = OfferMatcher.normalize(text)
            .split(separator: " ")
            .map(String.init)
        guard !normalisiert.isEmpty else { return nil }

        let wendung = normalisiert.joined(separator: " ")
        if let treffer = MatchDictionary.terms(forPhrase: wendung).sorted().first {
            return treffer
        }
        for wort in normalisiert.reversed() {
            if let treffer = MatchDictionary.terms(forToken: wort).sorted().first {
                return treffer
            }
        }
        return nil
    }
}
