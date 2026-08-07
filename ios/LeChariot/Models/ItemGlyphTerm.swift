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
/// **Eindeutig ist es nicht mehr, und das war ein stiller Fehler.** Beim ersten
/// Bau stimmte der Satz noch: 730 einwortige Synonyme, keins zeigte auf zwei
/// Begriffe, also durfte die Auflösung alphabetisch aus dem `Set` greifen. Nach
/// den elf Tranchen sind es **1531 Synonyme, davon 95 mehrdeutig** — und
/// alphabetisch gewinnt dann, wer vorne im Alphabet steht: Chicorée, Chinakohl,
/// Porree, Staudensellerie und Zuckermais bekamen allesamt das Zeichen von
/// **Brokkoli**, Torte und Croissant das der Warengruppe `backwaren`, Pfeffer
/// und Petersilie das von `gewürze` — einer Ausnahme, die gar keine Zeichnung
/// hat. Welches Bild eine Zeile trägt, hing am Anfangsbuchstaben.
///
/// Deshalb `beste(aus:für:)` statt `sorted().first`. Nachgemessen: 48 der 95
/// Fälle bekommen dadurch ein anderes — und in jedem durchgesehenen Fall das
/// richtigere — Zeichen.
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
        if let treffer = beste(aus: MatchDictionary.terms(forPhrase: wendung), für: wendung) {
            return treffer
        }
        for wort in normalisiert.reversed() {
            if let treffer = beste(aus: MatchDictionary.terms(forToken: wort), für: wort) {
                return treffer
            }
        }
        return nil
    }

    /// Welcher Begriff gemeint ist, wenn ein Wort auf mehrere zeigt.
    ///
    /// 1. **Heißt der Begriff wie das Wort, ist er es.** „Kuchen" meint
    ///    `kuchen` und nicht `backwaren`, auch wenn `backwaren` das Wort in
    ///    seiner Synonymliste führt.
    /// 2. **Sonst gewinnt der feinere** — gemessen an der Zahl seiner
    ///    Synonyme. Ein Begriff, der fünfzig Wörter einsammelt, ist eine
    ///    Warengruppe; einer mit dreien ist ein Ding. Fürs Zuordnen von
    ///    Angeboten ist die Warengruppe brauchbar, für ein **Bild** ist sie
    ///    falsch: `brokkoli` trägt Porree mit, aber Porree sieht nicht so aus.
    /// 3. Bei Gleichstand alphabetisch, damit dieselbe Eingabe immer dasselbe
    ///    Zeichen bekommt.
    ///
    /// Die Regel kennt **keine Zeichnungen** — sonst hinge die Warenkunde an
    /// der Frage, was schon gezeichnet ist, und ein neu gezeichneter Begriff
    /// würde die Bedeutung getippter Wörter rückwirkend verschieben.
    private static func beste(aus kandidaten: Set<String>, für wort: String) -> String? {
        if kandidaten.contains(wort) { return wort }
        return kandidaten.min {
            let a = MatchDictionary.synonymCount(for: $0)
            let b = MatchDictionary.synonymCount(for: $1)
            return a == b ? $0 < $1 : a < b
        }
    }
}
