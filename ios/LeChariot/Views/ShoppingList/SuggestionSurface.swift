import Foundation

/// **Ob die Vorschlagsfläche über der Eingabezeile offen steht.**
///
/// Seit L-2 ist der Vorschlagsstreifen kein Listenabschnitt mehr, sondern eine
/// Fläche, die mit der Eingabezeile unten klebt. Damit stellt sich eine Frage,
/// die es vorher nicht gab: Wann ist sie zu?
///
/// Die Regel steht hier und nicht in der Ansicht, weil sie aus vier Fällen
/// besteht und drei davon durch Ausprobieren am Simulator nicht zu erkennen
/// sind — man sieht einen offenen oder einen zugeklappten Streifen, aber nicht,
/// **warum**. Als Funktion mit drei Eingaben ist sie prüfbar.
///
/// Die Fälle, in der Reihenfolge, in der sie gewinnen:
///
/// 1. **Was der Nutzer zuletzt getan hat.** Eine Kachel antippen heißt „ich
///    benutze die Fläche", in die Zeile tippen heißt „ich weiß, was ich
///    brauche". Der Knopf links im Feld ist die ausdrückliche Fassung davon.
/// 2. **Wer tippt, bekommt sie nicht ungefragt** (2026-08-08). Bis dahin zog
///    die Fläche beim ersten Buchstaben von selbst auf — nicht über diese
///    Regel, sondern an ihr vorbei: Das Wörterbuch-Raster stand
///    bedingungslos, sobald etwas im Feld war. Damit lagen beim Tippen des
///    zweiten Artikels **zwei** Flächen übereinander, das Raster über den
///    Angaben des ersten, und von der Liste blieb ein Streifen. Bring! zeigt
///    an dieser Stelle genau eine Schicht.
/// 3. **Sonst die Liste selbst:** leer auf, gefüllt zu.
///
/// **Der Rundgang hatte hier bis zum 09.08. Vorfahrt und zog die Fläche auf,
/// solange er lief.** Der Grund war ein Rahmen, der die Vorschlagskacheln
/// ausleuchtete: Eine zugeklappte Fläche trägt keinen Anker, und ein Rahmen ohne
/// Ziel überspringt sich selbst. Der Rundgang zum Mitmachen zeigt statt der
/// Kacheln den **Knopf** und wartet darauf, dass der Nutzer ihn drückt — eine
/// Fläche, die von selbst offen steht, hätte diesem Rahmen sein Ziel genommen.
/// Was eine Sonderregel war, ist damit die Handlung, um die es geht.
///
/// Die Wahl gilt für die Sitzung und wird **nicht** gespeichert. Eine Fläche,
/// die sich für immer merkt, dass sie einmal offen war, frisst dauerhaft ein
/// Fünftel des Bildschirms für einen Vorschlag, den niemand angefordert hat.
enum SuggestionSurface {

    /// - Parameters:
    ///   - choice: Was der Nutzer in dieser Sitzung zuletzt getan hat, oder
    ///     `nil`, solange er nichts getan hat.
    ///   - listIsEmpty: Ob die Einkaufsliste leer ist.
    ///   - isTyping: Ob gerade etwas im Eingabefeld steht.
    static func isExpanded(choice: Bool?, listIsEmpty: Bool, isTyping: Bool) -> Bool {
        if let choice { return choice }
        if isTyping { return false }
        return listIsEmpty
    }
}
