import Foundation
import Observation

// MARK: - Welche Führungsfläche die Liste zeigt

/// **Höchstens eine Führungsfläche zugleich** — die Vorfahrtsregel.
///
/// Die Liste trägt inzwischen vier Flächen, die alle „hilf mir anfangen"
/// sagen könnten: die Filialen-Karte (`NoMarketsCard`), die Beispiel-Angebote
/// auf der leeren Liste (`FirstItemCard`), die Einrichtungs-Checkliste
/// (`SetupChecklistCard`) und den geführten ersten Artikel. Zusammen wären sie
/// genau das Gedränge, gegen das der Bildschirm seit L-2 verteidigt wird —
/// also entscheidet **eine** Funktion, wer dran ist, und sie ist prüfbar.
///
/// Die Fälle, in der Reihenfolge, in der sie gewinnen:
///
/// 1. **Der Rundgang behält seine Bühne.** Seine Rahmen ankern an der
///    Filialen-Karte (`.planCard`); eine Checkliste an ihrer Stelle ließe den
///    Rahmen sich selbst überspringen. Während er läuft, sieht die Liste aus
///    wie vor diesem Umbau.
/// 2. **Vor dem allerersten Artikel zählt nur der erste Artikel** (NN/g:
///    Machen schlägt Zuschauen). Mit Filialen sind das die Beispiel-Angebote;
///    ohne bleibt die Filialen-Karte stehen — vier Journeys halten genau
///    diesen Bildschirm fest, und sie behalten recht. Die Einladung zum
///    ersten Artikel trägt dann die Ansprache darüber (`FirstItemPrompt`),
///    nicht eine zweite Karte.
/// 3. **Danach führt die Checkliste**, bis sie fertig oder weggewischt ist.
///    Sie enthält den Weg zur Filialauswahl selbst, deshalb ersetzt sie die
///    Filialen-Karte, statt neben ihr zu stehen.
/// 4. **Zuletzt die Filialen-Karte** — der Stand von vor diesem Umbau, für
///    alle, die die Checkliste weggewischt haben und trotzdem ohne Filiale
///    dastehen. Eine Sackgasse darf daraus nie werden.
///
/// Die Plan-Karte, die Treffer-Zeile und der Vorschlagsstreifen sind
/// **Produkt**, keine Führung — sie bleiben von dieser Regel unberührt.
enum ListGuidance: Equatable {
    /// Beispiel-Angebote als erste Artikel — nur auf der leeren Liste, nur
    /// solange noch nie ein Artikel angelegt wurde.
    case firstItem
    /// Die Einrichtungs-Checkliste.
    case checklist
    /// Die Filialen-Karte, unverändert die von vor diesem Umbau.
    case noMarkets
    case none

    static func surface(
        listIsEmpty: Bool,
        hasMarkets: Bool,
        firstItemAdded: Bool,
        checklistVisible: Bool,
        tourIsRunning: Bool
    ) -> ListGuidance {
        if tourIsRunning { return hasMarkets ? .none : .noMarkets }
        if listIsEmpty && !firstItemAdded { return hasMarkets ? .firstItem : .noMarkets }
        if checklistVisible { return .checklist }
        if !hasMarkets { return .noMarkets }
        return .none
    }
}

// MARK: - Beispiel-Angebote für die leere Liste

/// Ein Vorschlag auf der leeren Liste: ein Listenwort und der Markt, bei dem
/// es diese Woche im Angebot ist.
struct FirstItemExample: Equatable, Identifiable {
    let word: String
    let market: String
    let discountPercent: Int?

    var id: String { word }
    /// „diese Woche bei Kaufland im Angebot" — der Grund, aus dem der
    /// Vorschlag dasteht. Ein Vorschlag ohne Grund wäre nur eine längere
    /// Festliste.
    var reason: String { "diese Woche bei \(market) im Angebot" }
}

/// Was die leere Liste vorschlägt — Things-3-Stil: klar als Beispiel markiert,
/// ein Tipp legt es an, ein Tipp lässt es verschwinden, und **nichts davon
/// steht ungefragt auf der Liste**.
///
/// **Warum die Wörter aus den `match_key`-Tags kommen** und nicht aus den
/// Produkttiteln: dieselbe Überlegung wie in `ShoppingSuggestions.strip` — ein
/// Tag *ist* ein Listenwort („butter", „kaffee") und findet sich per
/// Konstruktion im Matcher wieder. Genau das macht den Vorschlag zum
/// Aha-Moment: Der angelegte Artikel bekommt sofort seine Treffer-Kachel.
///
/// **Ohne Filialen gibt es hier nichts** — und das ist eine Entscheidung, kein
/// Loch. `OfferStore.load(branchIds: [])` liefert bewusst leer, und die
/// naheliegende Abkürzung (die bundesweiten Penny/Kaufland-Zeilen auch ohne
/// Filiale zu holen) hieße, jemandem Angebote eines Marktes zu empfehlen, den
/// er nie gewählt hat — die Sorte Beeinflussung, gegen die die App antritt
/// (docs/ADS.md). Die Fläche fällt dann auf `prompt` zurück, und der Treffer-
/// Moment feuert nach, sobald Filialen gewählt sind.
enum FirstItemSuggestions {
    /// Der eine konkrete Satz, wenn es keine Angebote zu zeigen gibt:
    /// „Füg mal ‚Milch‘ hinzu". Das erste Grundnahrungsmittel, das noch nicht
    /// weggewischt wurde — wer den Milch-Vorschlag eben verworfen hat, dem
    /// dieselbe Milch noch einmal anzubieten wäre Streit, kein Vorschlag.
    static func prompt(excluding dismissed: Set<String> = []) -> String {
        ShoppingSuggestions.staples.first { !dismissed.contains($0) } ?? "Milch"
    }

    /// Höchstens drei — mehr wäre wieder eine Liste, und die soll der Nutzer
    /// selbst schreiben.
    static let limit = 3

    static func examples(
        from offers: [Offer],
        excluding dismissed: Set<String> = [],
        limit: Int = limit
    ) -> [FirstItemExample] {
        // Das beste Angebot je Tag — wie `ShoppingSuggestions.strip`, aber mit
        // dem Angebot selbst statt nur dem Wort, weil die Zeile seinen Markt
        // nennt.
        var best: [String: Offer] = [:]
        for offer in offers {
            // "nonfood" ist nie ein Listenwort; Alkohol wird ungefragt nicht
            // vorgeschlagen (Scotts Regel vom 2026-07-31, siehe `maySuggest`).
            for tag in offer.matchKeys where tag != "nonfood" && ShoppingSuggestions.maySuggest(tag) {
                if let seen = best[tag],
                   (seen.discountPercent ?? 0) >= (offer.discountPercent ?? 0) {
                    continue
                }
                best[tag] = offer
            }
        }
        return best
            .sorted { lhs, rhs in
                let l = lhs.value.discountPercent ?? 0
                let r = rhs.value.discountPercent ?? 0
                return l == r ? lhs.key < rhs.key : l > r
            }
            .map { tag, offer in
                FirstItemExample(
                    word: tag.prefix(1).uppercased() + tag.dropFirst(),
                    market: offer.market,
                    discountPercent: offer.discountPercent
                )
            }
            .filter { !dismissed.contains($0.word) }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Store

/// Merkt sich die zwei ersten Male, an denen die Checkliste und der geführte
/// erste Artikel hängen: der erste selbst angelegte Artikel und der erste
/// Angebots-Treffer.
///
/// **Beide Merker sind Einbahnstraßen** — wie `tutorial.hasSeen`: Was einmal
/// passiert ist, ist passiert, und eine Führung, die wieder von vorn anfängt,
/// weil jemand seine Liste geleert hat, führt niemanden.
///
/// Die anderen beiden Punkte der Checkliste („Profil erstellt", „Markt
/// gewählt") liegen bewusst **nicht** hier: Sie sind live aus `RegionStore`
/// ablesbar, und eine Kopie davon wäre ab der ersten Abweichung eine Lüge.
/// Nur der Abschluss wird versiegelt (`checklistDone`), damit die Karte nicht
/// zurückkommt, wenn später die letzte Filiale abgewählt wird — „einmal
/// fertig" ist eine Aussage über die Einrichtung, nicht über den Moment.
@MainActor
@Observable
final class SetupProgressStore {
    /// Der erste **selbst** angelegte Artikel. Die Beispiel-Artikel des
    /// Rundgangs zählen nicht — deshalb wird an den Bedienwegen aufgezeichnet
    /// und nicht in `ShoppingListStore.add`.
    private(set) var firstItemAdded: Bool
    /// Der erste Angebots-Treffer auf einem eigenen Artikel.
    private(set) var firstMatchSeen: Bool
    private(set) var checklistDismissed: Bool
    /// Alle vier Punkte waren gleichzeitig erfüllt — die Karte kommt nie
    /// wieder.
    private(set) var checklistDone: Bool

    private let defaults: UserDefaults

    private enum Keys {
        static let firstItem = "setup.firstItemAdded"
        static let firstMatch = "setup.firstMatchSeen"
        static let dismissed = "setup.checklistDismissed"
        static let done = "setup.checklistDone"
        static let all = [firstItem, firstMatch, dismissed, done]
    }

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        self.firstItemAdded = defaults.bool(forKey: Keys.firstItem)
        self.firstMatchSeen = defaults.bool(forKey: Keys.firstMatch)
        self.checklistDismissed = defaults.bool(forKey: Keys.dismissed)
        self.checklistDone = defaults.bool(forKey: Keys.done)
    }

    // MARK: Ereignisse

    func recordItemAdded() {
        guard !firstItemAdded else { return }
        firstItemAdded = true
        defaults.set(true, forKey: Keys.firstItem)
    }

    /// `true` genau beim Übergang — daran hängt das einmalige Aufleuchten der
    /// Treffer-Kachel. Jeder weitere Aufruf ist ein stilles Nein.
    @discardableResult
    func recordFirstMatch() -> Bool {
        guard !firstMatchSeen else { return false }
        firstMatchSeen = true
        defaults.set(true, forKey: Keys.firstMatch)
        return true
    }

    func dismissChecklist() {
        checklistDismissed = true
        defaults.set(true, forKey: Keys.dismissed)
    }

    /// Versiegelt den Abschluss, sobald alle vier Punkte gleichzeitig erfüllt
    /// sind. Getrennt vom Ablesen, damit keine Abfrage nebenbei schreibt.
    func sealIfComplete(hasMarkets: Bool) {
        guard !checklistDone, hasMarkets, firstItemAdded, firstMatchSeen else { return }
        checklistDone = true
        defaults.set(true, forKey: Keys.done)
    }

    // MARK: Ablesen

    /// Ob die Checkliste überhaupt noch etwas zu melden hat. Der dritte Term
    /// deckt den einen Durchgang ab, in dem alles fertig ist, aber noch
    /// niemand versiegelt hat — fertig ist fertig, auch ungestempelt.
    func checklistIsVisible(hasMarkets: Bool) -> Bool {
        !checklistDismissed && !checklistDone
            && !(hasMarkets && firstItemAdded && firstMatchSeen)
    }

    // MARK: Zurücksetzen

    /// Siehe `AppReset`.
    func resetAllData() {
        firstItemAdded = false
        firstMatchSeen = false
        checklistDismissed = false
        checklistDone = false
        for key in Keys.all { defaults.removeObject(forKey: key) }
    }
}
