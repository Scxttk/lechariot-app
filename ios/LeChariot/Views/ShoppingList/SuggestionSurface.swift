import Foundation

/// **Was über der Eingabezeile steht — und wann.**
///
/// Die Fläche über dem Feld hat vier mögliche Gestalten, und welche dransteht,
/// hängt an vier Fragen. Die Regel steht hier und nicht in der Ansicht, weil
/// man am Simulator zwar eine offene oder eine zugeklappte Fläche sieht, aber
/// nicht **warum** — als Funktion mit vier Eingaben ist sie prüfbar.
///
/// **Die Regel ist am 10.08. umgedreht worden** (Bedienrunde, Punkt E, nach
/// Bring!):
///
/// > „The vorgeschlagenen offers spawn in bring only if you start typing so
/// > they spawn when the keyboard gets opened, if u type a letter the matching
/// > starts and where previous the vorgeschlagenen offers came now coming
/// > actual products that match it"
///
/// Also: **Tastatur auf heißt Vorschläge**, und **ab dem ersten Buchstaben**
/// stehen an derselben Stelle die passenden Produkte. Bis dahin galt seit dem
/// 08.08. das Gegenteil — die Fläche startete beim Tippen zugeklappt und kam
/// nur über einen Winkel-Knopf zurück.
///
/// **Damit fällt der Knopf weg, und das ist der zweite Auftrag derselben Runde**
/// (Punkt B-2: „I don't like both the collaps buttons"). Er hatte genau eine
/// Aufgabe: eine Fläche zu holen, die sich beim Tippen versteckt. Eine Fläche,
/// die dem Tippen folgt, muss niemand holen. Übrig bleibt unten links **ein**
/// Knopf, „Fertig" — der einzige Ausgang, der auch ohne Tastatur trägt.
///
/// **Was von der alten Regel bleibt, ist ihr Anlass:** Zwei Schichten
/// übereinander (Wörterbuch über den Angaben des vorigen Artikels) lassen von
/// der Liste einen Streifen übrig. Deshalb weicht beim Tippen weiterhin eine
/// von beiden — nur ist es jetzt die Angaben-Schicht und nicht die
/// Vorschlagsfläche.
///
/// **Und die Wahl des Nutzers ist ersatzlos weg.** Sie war die erste Regel
/// („eine Kachel antippen heißt: ich benutze die Fläche") und hing an einem
/// Knopf, den es nicht mehr gibt; was sie ausdrückte, sagt jetzt der Zustand
/// selbst — Tastatur oder nicht, Feld leer oder nicht.
enum SuggestionSurface {

    /// Die vier Gestalten der Fläche.
    enum Shape: Equatable {
        /// Nichts — die Fläche gibt ihren Platz der Liste zurück.
        case none
        /// Das Raster „Häufig auf der Liste", volle Höhe.
        case staples
        /// Dieselben Vorschläge als **eine** seitlich scrollende Reihe, 44 pt
        /// statt 148 — die Fassung neben der Angaben-Schicht.
        case staplesRow
        /// Die Produkte, die zum getippten Anfang passen.
        case terms
    }

    /// - Parameters:
    ///   - isTyping: Ob etwas im Eingabefeld steht.
    ///   - keyboardIsUp: Ob das Feld den Fokus hat.
    ///   - detailPanelIsUp: Ob die Angaben-Schicht über der Zeile steht.
    ///   - listIsEmpty: Ob die Einkaufsliste leer ist.
    static func shape(isTyping: Bool,
                      keyboardIsUp: Bool,
                      detailPanelIsUp: Bool,
                      listIsEmpty: Bool) -> Shape {
        // 1. **Wer tippt, bekommt Produkte.** Der Fall gewinnt vor der
        //    Angaben-Schicht: Sobald wieder getippt wird, ist der vorige
        //    Artikel abgehandelt, und zwei Schichten übereinander sind genau
        //    das, was am 08.08. abgeräumt wurde.
        if isTyping { return .terms }
        // 2. **Neben der Schicht nur die schmale Reihe, und nur ohne
        //    Tastatur.** Der Weg dorthin ist der Tipp auf „Häufig auf der
        //    Liste"; dort steht keine Tastatur, und der nächste Vorschlag muss
        //    **einen Tipp** weit weg bleiben (der Fehler vom 26.07.). Mit
        //    Tastatur kostete die Reihe die letzte Kachelreihe der Liste.
        if detailPanelIsUp { return keyboardIsUp ? .none : .staplesRow }
        // 3. **Tastatur auf, Feld leer: Vorschläge** — Scotts Punkt E. Und
        //    weiterhin auf der leeren Liste, wo sie die Einladung tragen.
        if keyboardIsUp || listIsEmpty { return .staples }
        // 4. Sonst gehört der Platz der Liste.
        return .none
    }
}
