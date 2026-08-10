import Foundation
import Observation

/// Was dieser Haushalt tatsächlich kauft — ein gewichteter Zähler, sonst nichts.
///
/// **Kein Modell, kein Training, keine Vorhersage.** Der Vorschlagsstreifen
/// zeigte bis hierher acht feste Grundnahrungsmittel; die erste Testerin von
/// außen (Scotts Mutter) hat dazu gesagt, was Bring! besser macht: Es zeigt,
/// was *sie* kauft. Das ist ein Zähler mit Alterung, und mehr soll es nicht
/// werden — die Überschrift ist deshalb eine Beobachtung und keine Vorhersage,
/// nie „Du brauchst vermutlich".
///
/// **Gezählt wird beim Abhaken, nicht beim Hinzufügen.** Hinzufügen heißt „ich
/// denke daran", Abhaken heißt „ich habe es gekauft". Ein versehentlich
/// getippter und wieder weggewischter Artikel darf nichts lehren, und
/// „Liste leeren" darf es auch nicht.
///
/// **Dieser Speicher ist der Vorrat, den Scott am 10.08. „Zuletzt verwendet"
/// genannt hat** („the products clicked should go into zuletzt verwendet,
/// that's the pool for the recommendation"). Er existiert seit dem 31.07. und
/// wird schon beim Abhaken gefüllt — was gefehlt hat, war der Rückweg: Ein
/// abgehakter Artikel zählte für den Streifen als „steht schon auf der Liste"
/// und war damit aus dem Vorrat gesperrt, während er im Abschnitt „Erledigt"
/// stehen blieb. Seit dem 10.08. zählen dort nur noch die **offenen** Artikel
/// (`ShoppingSuggestions.openWords`), und der Abschnitt räumt sich selbst auf
/// (`ShoppingListStore.checkedRetention`). Ein zweiter Zähler wäre die
/// falsche Antwort gewesen: Es gibt genau einen, und er steht hier.
///
/// **Die Größe des Vorrats, ausgeschrieben:** höchstens `capacity` Wörter,
/// jedes altert mit `halfLife`, und unter `forgetThreshold` fällt es ganz
/// heraus. Angezeigt werden davon `ShoppingSuggestions.personalLength`.
///
/// **Seit dem 10.08. heißt die Überschrift „Häufig auf der Liste", gezählt
/// wird aber weiter das Abhaken** — Scotts Wortwahl, und der Widerspruch ist
/// benannt statt stillschweigend behoben. Wer die Überschrift wörtlich nimmt,
/// erwartet einen Zähler auf `add`; das wäre die Umkehrung der Entscheidung
/// vom 2026-07-31 (der Absatz darüber) und beträfe jede Zeile hier. Ob der
/// Name der Rechnung folgt oder die Rechnung dem Namen, entscheidet Scott
/// getrennt; bis dahin gilt der Absatz oben unverändert.
///
/// **Was hier liegt, ist heikler als eine Einkaufsliste.** Eine Kaufhistorie
/// sagt etwas über Ernährung, Alkohol, Kinder, Gesundheit. Sie bleibt
/// vollständig auf dem Gerät, sie geht in keinen Upload, und sie lässt sich
/// **für sich allein** löschen (Einstellungen → „Vorschläge vergessen") — ohne
/// dass man dafür die ganze App zurücksetzen muss. Das ist Scotts Entscheidung
/// vom 2026-07-31 und der Grund, warum es einen eigenen Knopf gibt.
@MainActor
@Observable
final class PurchaseHistoryStore {

    /// Ein Wort und sein Gewicht zu einem Stichtag.
    ///
    /// Zwei Zahlen statt einer Liste von Zeitpunkten: Exponentielles Abklingen
    /// lässt sich exakt fortschreiben (`gewicht * 2^(-Δ/Halbwertszeit)`), und
    /// eine Liste von Kaufzeitpunkten wäre nicht nur größer, sondern auch das
    /// genauere Protokoll über einen Menschen — genau das, was hier nicht
    /// entstehen soll.
    struct Entry: Codable, Equatable {
        var weight: Double
        var updatedAt: Date
    }

    /// Nach acht Wochen zählt ein Kauf noch halb. Ohne Alterung steht der
    /// Streifen nach einem halben Jahr fest, und wer sich umstellt, sieht
    /// weiter seine alten Gewohnheiten.
    static let halfLife: TimeInterval = 8 * 7 * 24 * 60 * 60

    /// Obergrenze. Wird sie überschritten, fallen die leichtesten Einträge
    /// weg — das sind die ältesten oder die seltensten, also genau die, deren
    /// Verlust niemandem auffällt.
    static let capacity = 200

    /// **Wann ein Wort ganz aus dem Vorrat fällt.**
    ///
    /// Die Obergrenze allein war keine Alterung: Wer 30 verschiedene Wörter
    /// benutzt, blieb ewig unter `capacity` — und trug damit jeden einmaligen
    /// Ausrutscher für immer mit, nur immer leiser. Unter diesem Gewicht wird
    /// der Eintrag gelöscht statt weitergerechnet.
    ///
    /// 0,05 sind bei `halfLife` von acht Wochen gut **vier Halbwertszeiten**,
    /// also rund acht Monate für einen einzelnen Kauf. Wer etwas zweimal
    /// gekauft hat, behält es entsprechend länger. Die Zahl ist bewusst so
    /// niedrig, dass sie nur wegräumt, was den Streifen ohnehin nie wieder
    /// erreicht hätte — der Zweck ist der Vorrat, der sich selbst begrenzt,
    /// nicht ein schärferes Vergessen.
    static let forgetThreshold = 0.05

    /// Ab so vielen **verschiedenen** abgehakten Wörtern trägt der persönliche
    /// Teil den Streifen allein, und die festen Grundnahrungsmittel
    /// verschwinden. Die Zahl ist verhandelbar, das Prinzip nicht.
    static let coldStartThreshold = 12

    private(set) var entries: [String: Entry]

    private let defaults: UserDefaults
    private static let key = "purchase.history"

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode([String: Entry].self, from: data) {
            self.entries = stored
        } else {
            self.entries = [:]
        }
    }

    /// Wie viele verschiedene Wörter je gekauft wurden — der Kaltstart hängt
    /// daran.
    var distinctWords: Int { entries.count }

    /// Ob der Streifen die festen Grundnahrungsmittel noch braucht.
    var needsStaples: Bool { distinctWords < Self.coldStartThreshold }

    // MARK: Zählen

    /// Merkt sich einen Kauf. Aufgerufen wird das beim **Abhaken**.
    func record(_ rawText: String, now: Date = .now) {
        let word = Self.normalized(rawText)
        guard !word.isEmpty else { return }
        let previous = entries[word].map { decayed($0, to: now) } ?? 0
        entries[word] = Entry(weight: previous + 1, updatedAt: now)
        trim()
        persist()
    }

    /// Die meistgekauften Wörter, frisch gealtert, ohne die bereits
    /// ausgeschlossenen.
    ///
    /// - Parameter excluding: normalisierte Wörter, die nicht vorkommen sollen
    ///   (was schon auf der Liste steht, und was der Streifen schon zeigt).
    func top(_ count: Int, excluding: Set<String> = [], now: Date = .now) -> [String] {
        let ranked = ranking(excluding: excluding, at: now)
        return Array(ranked.prefix(count))
    }

    /// Die Wörter nach Gewicht, schwerste zuerst.
    ///
    /// Als eigene Funktion und mit ausgeschriebenen Zwischenschritten: In einer
    /// Kette geschrieben brauchte der Typprüfer zu lange und brach ab („unable
    /// to type-check this expression in reasonable time").
    private func ranking(excluding: Set<String>, at now: Date) -> [String] {
        var gewichtet: [(word: String, weight: Double)] = []
        gewichtet.reserveCapacity(entries.count)
        for (word, entry) in entries where !excluding.contains(word) {
            gewichtet.append((word: word, weight: decayed(entry, to: now)))
        }
        // Gleichstand nach Wort, damit die Reihenfolge nicht bei jedem
        // Zeichnen eine andere ist — ein Streifen, der springt, sieht aus wie
        // ein Fehler.
        gewichtet.sort { links, rechts in
            links.weight == rechts.weight
                ? links.word < rechts.word
                : links.weight > rechts.weight
        }
        return gewichtet.map(\.word)
    }

    // MARK: Löschen

    /// **Nur die Vorschläge vergessen**, ohne die App zurückzusetzen.
    ///
    /// Eine Kaufhistorie sagt etwas über den Haushalt, das eine Einkaufsliste
    /// nicht sagt. Wer sie loswerden will, soll dafür nicht Filialen, Profil
    /// und Onboarding mit aufgeben müssen.
    func forget() {
        entries = [:]
        defaults.removeObject(forKey: Self.key)
    }

    /// Siehe `AppReset`. Identisch zu `forget()`, steht aber als eigener Name
    /// da, weil jeder Store diesen Vertrag erfüllt und ein Store ohne ihn beim
    /// nächsten Reset still übrig bliebe.
    func resetAllData() { forget() }

    // MARK: Intern

    /// Kleinschreibung und Leerraum weg — „Butter", „butter " und „ BUTTER"
    /// sind derselbe Kauf. Bewusst **nicht** `OfferMatcher.normalize`: Das
    /// wirft alles außer Buchstaben weg und würde „H-Milch" und „HMilch"
    /// zusammenziehen, aber auch „0,7% Milch" verstümmeln. Hier reicht der
    /// schwächere Griff, weil das Wort später sowieso durch den Matcher geht.
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func decayed(_ entry: Entry, to now: Date) -> Double {
        let age = now.timeIntervalSince(entry.updatedAt)
        guard age > 0 else { return entry.weight }
        return entry.weight * pow(2, -age / Self.halfLife)
    }

    /// Zwei Grenzen, in dieser Reihenfolge: **weggealtert** (unter
    /// `forgetThreshold`) und **zu viele** (über `capacity`).
    ///
    /// Gemessen wird zum Zeitpunkt des jüngsten Eintrags, nicht `.now` — sonst
    /// hinge das Ergebnis an der Uhr und wäre nicht prüfbar. Für die Alterung
    /// heißt das: Sie greift, wenn der Vorrat benutzt wird, und nicht,
    /// während das Telefon in der Tasche liegt. Genau das ist gewollt — wer
    /// die App einen Sommer lang nicht aufmacht, findet danach seinen Vorrat
    /// vor und nicht einen leeren Streifen.
    private func trim() {
        let stichtag = entries.values.map(\.updatedAt).max() ?? .now
        entries = entries.filter { decayed($0.value, to: stichtag) >= Self.forgetThreshold }
        guard entries.count > Self.capacity else { return }
        let behalten = Set(ranking(excluding: [], at: stichtag).prefix(Self.capacity))
        entries = entries.filter { behalten.contains($0.key) }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
