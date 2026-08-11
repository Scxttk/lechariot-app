import Foundation
import Observation

// MARK: - Die Tipps

/// Die vier Einmal-Schilder — **die ganze Erklärschicht der App.**
///
/// Bis zum 10.08. standen sie neben dem Rundgang und mussten ihm ausweichen.
/// Mit dem Abriss (Rundgang-Konzept §4) sind sie die Schicht 2: ein Schild am
/// Ort, im Moment seiner Bedingung, wegwischbar, nichts gesperrt. Die Forschung
/// dazu ist eindeutig (~78 % brechen klassische Touren ab, ~76 % der Tooltips
/// in unter drei Sekunden weggewischt, siehe [[Le Chariot Onboarding-Forschung]]).
///
/// Die Texte stehen für sich — sie dürfen nichts voraussetzen, was „die Tour
/// schon gesagt" hätte, denn die sagt nichts mehr.
///
/// `rawValue` liegt im Ledger auf Platte. Umbenennen kostet nur den Merker
/// (der Tipp käme einmal wieder), aber auch das nur absichtlich.
enum ContextTip: String, CaseIterable, Codable, Sendable {
    /// „Nächste Woche" oben links im Angebote-Tab — das bewusste Warten.
    case nextWeekPreview
    /// Die Angebotszeile unterm Artikel: alle Treffer, Preisverlauf, Anheften.
    case matchLine
    /// Menge/Größe/Notiz hinter dem Artikelnamen — ein Angebot, keine Frage.
    case itemDetails
    /// Kreis zum Abhaken, Wisch nach links zum Löschen.
    case checkOff

    /// Auf welchem Bildschirm das Schild hängt.
    ///
    /// Steht hier und nicht in der Ansicht, weil die Sitzungsgrenze daran
    /// hängt: gezählt wird **je Fläche**, siehe `ContextTipTuning`.
    enum Surface: Hashable, CaseIterable {
        case list, offers
    }

    var surface: Surface {
        switch self {
        case .nextWeekPreview: .offers
        case .matchLine, .itemDetails, .checkOff: .list
        }
    }
}

// MARK: - Stellschrauben

/// **Alle Schwellwerte an einer Stelle**, damit „fühlt sich aufdringlich an"
/// eine Zahl zum Drehen hat und keine Suche durchs Repo.
enum ContextTipTuning {
    /// Höchstens **ein** Schild je Fläche und App-Sitzung. Zwei Schilder auf
    /// demselben Bildschirm wären die Tour in Raten, die abgeschafft wird; die
    /// Momente kommen wieder (die Liste steht jeden Tag da), ein verschobenes
    /// Schild ist also nicht verloren.
    ///
    /// **Je Fläche, und das ist die Korrektur vom 10.08.** Bis dahin galt die
    /// Grenze für die ganze Sitzung, und damit hat der Vorschau-Tipp den
    /// Angebote-Tab praktisch nie erreicht: Auf der Liste feuert fast immer
    /// zuerst die Angebotszeile, danach war die Sitzung verbraucht. Scott am
    /// 10.08. abends, nach mehreren Durchläufen: „the tip for the future offers
    /// is still not in there." Das Rundgang-Konzept hatte es schon so gemeint —
    /// „der letzte hängt am Tab-Wechsel und kollidiert deshalb nie mit den
    /// anderen" (§6, Regel 3) —, nur stand es nicht so im Code.
    /// `ContextTipTests.testAListTipDoesNotEatTheOffersTip` hält den Fall fest.
    static let tipsPerSurfaceAndSession = 1

    /// Ab dem wievielten angelegten Artikel der Angaben-Tipp kommt — und nur,
    /// wenn die Angaben-Schicht bis dahin **nie** benutzt wurde. Wer Chips
    /// antippt oder das Blatt öffnet, hat die Schicht gefunden; ihm das noch
    /// zu erklären wäre der klassische Tooltip auf Bekanntes.
    static let itemsBeforeDetailsTip = 3

    /// Nach wie vielen Sitzungen mit offenen Artikeln und ohne einen einzigen
    /// Haken der Abhaken-Tipp kommt. Wer abhakt, bekommt ihn früher — direkt
    /// nach dem ersten Haken, denn da ist der Wisch zum Löschen die eine
    /// Sache an dieser Zeile, die man nicht sieht.
    static let listSessionsBeforeCheckOffTip = 3

    /// Ab dem wievielten Besuch im Angebote-Tab die Ernährungsfrage steht.
    /// Nicht beim ersten: Da gehört der Moment dem Tab selbst (und meist dem
    /// Vorschau-Tipp) — eine Frage neben einer Sprechblase wäre ein Formular.
    static let offersVisitsBeforeDietPrompt = 2
}

// MARK: - Ledger

/// Was über Sitzungen hinweg zählt. Eine kleine Codable-Ablage in den
/// UserDefaults, dieselbe Begründung wie bei `ProfileStore`.
struct ContextTipLedger: Codable, Equatable {
    /// Gezeigt heißt gezeigt — auch wer sofort weitertippt, bekommt denselben
    /// Tipp kein zweites Mal. Lieber ein verpasster Tipp als ein wiederholter.
    var shown: Set<ContextTip> = []
    var itemsAdded = 0
    var usedDetails = false
    var checkedOff = false
    var listSessionsWithoutCheckOff = 0
    var offersVisits = 0
    var dietPromptDone = false
}

// MARK: - Regeln

/// **Die Entscheidung, nicht das Schild** — als reine Rechnung: Ansichten
/// melden, was gerade wahr ist, und hier steht prüfbar, welches Schild daraus
/// folgt.
enum ContextTipRules {
    /// Was nur für die laufende Sitzung gilt und deshalb nicht im Ledger liegt.
    struct Moment: Equatable {
        /// Wie viele Schilder auf **dieser** Fläche in dieser Sitzung schon
        /// standen.
        var activationsOnSurface = 0
    }

    /// Je Fläche und Sitzung höchstens `tipsPerSurfaceAndSession` — siehe dort.
    static func mayActivate(_ moment: Moment) -> Bool {
        moment.activationsOnSurface < ContextTipTuning.tipsPerSurfaceAndSession
    }

    /// Die Liste steht ruhig da (kein Tipp-Fluss) — welcher Tipp jetzt?
    ///
    /// Reihenfolge ist Vorrang: Die Angebotszeile zuerst (sie ist der Grund,
    /// aus dem es die App gibt), dann die Angaben-Schicht, zuletzt das
    /// Abhaken. Es feuert höchstens einer — `tipsPerSurfaceAndSession` sorgt
    /// dafür, dass die anderen in späteren Sitzungen an ihrem Moment drankommen.
    ///
    /// `guidanceVisible` heißt: Auf der Liste führt gerade eine andere Fläche
    /// (Checkliste, Filialen-Karte — die Vorfahrt steht in `ListGuidance`).
    /// Dann feuert kein Tipp — **eine** Führungsfläche zugleich, dieselbe
    /// Regel, die die Ernährungsfrage schon einhält (`showsDietPrompt`,
    /// `tipVisibleHere`), nur in die andere Richtung. Der Tipp ist damit nicht
    /// verloren: Sein Moment kommt wieder, sobald die Fläche frei ist —
    /// dasselbe Versprechen wie bei `tipsPerSession`.
    static func tipOnList(
        _ ledger: ContextTipLedger,
        matchVisible: Bool,
        hasOpenItems: Bool,
        guidanceVisible: Bool,
        moment: Moment
    ) -> ContextTip? {
        guard mayActivate(moment), !guidanceVisible else { return nil }
        if matchVisible, !ledger.shown.contains(.matchLine) {
            return .matchLine
        }
        if hasOpenItems,
           !ledger.usedDetails,
           !ledger.shown.contains(.itemDetails),
           ledger.itemsAdded >= ContextTipTuning.itemsBeforeDetailsTip {
            return .itemDetails
        }
        if hasOpenItems, wantsCheckOffTip(ledger) {
            return .checkOff
        }
        return nil
    }

    /// Abhaken-Tipp: nach dem ersten Haken (dann ist der Wisch zum Löschen
    /// die Neuigkeit) **oder** nach `listSessionsBeforeCheckOffTip` Sitzungen,
    /// in denen offene Artikel herumlagen und nie einer abgehakt wurde.
    private static func wantsCheckOffTip(_ ledger: ContextTipLedger) -> Bool {
        guard !ledger.shown.contains(.checkOff) else { return false }
        return ledger.checkedOff
            || ledger.listSessionsWithoutCheckOff
                >= ContextTipTuning.listSessionsBeforeCheckOffTip
    }

    /// Der Angebote-Tab ist aufgegangen — Vorschau-Tipp?
    ///
    /// `nextWeekAvailable` ist der Feature-Schalter samt Knopf: Ohne den Knopf
    /// „Nächste Woche" gäbe es nichts, worauf die Sprechblase zeigt.
    static func tipOnOffers(
        _ ledger: ContextTipLedger,
        nextWeekAvailable: Bool,
        moment: Moment
    ) -> ContextTip? {
        guard mayActivate(moment),
              nextWeekAvailable,
              !ledger.shown.contains(.nextWeekPreview) else { return nil }
        return .nextWeekPreview
    }

    /// Ob die Ernährungsfrage im Angebote-Tab steht.
    ///
    /// `dietAnswered` heißt: Im Profil steht schon mindestens eine Angabe —
    /// dann ist die Frage beantwortet, egal wo. Wegdrücken (`dietPromptDone`)
    /// ist eine ebenso vollständige Antwort; die Frage kommt nie wieder,
    /// ändern kann man die Angaben jederzeit in den Einstellungen.
    /// `tipVisibleHere` hält die Karte zurück, solange auf demselben
    /// Bildschirm gerade eine Sprechblase steht — eins nach dem anderen.
    static func showsDietPrompt(
        _ ledger: ContextTipLedger,
        dietAnswered: Bool,
        tipVisibleHere: Bool
    ) -> Bool {
        !tipVisibleHere
            && !ledger.dietPromptDone
            && !dietAnswered
            && ledger.offersVisits >= ContextTipTuning.offersVisitsBeforeDietPrompt
    }
}

// MARK: - Store

/// Buchhaltung der Schilder: zählt die Momente, entscheidet über die
/// Regeln oben und merkt sich Gezeigtes über Neustarts hinweg.
///
/// **`active` ist bewusst nicht persistiert.** Ein Schild, das einen Neustart
/// überlebt, zeigt auf einen Moment, der vorbei ist — nach dem Neustart ist die
/// Sitzung frisch und das nächste Schild wartet auf seinen eigenen Moment.
/// Gezeigt-Merker und Zähler überleben dagegen auf Platte.
@MainActor
@Observable
final class ContextTipStore {
    private(set) var ledger: ContextTipLedger
    /// Das Schild, das gerade steht — höchstens eines **je Fläche**, siehe
    /// `tipsPerSurfaceAndSession`. Zwei Flächen gleichzeitig sieht ohnehin
    /// niemand; getrennt gehalten, damit ein Schild im Angebote-Tab nicht das
    /// der Liste wegnimmt, das dort schon als gezeigt gilt.
    private(set) var active: [ContextTip.Surface: ContextTip] = [:]

    private var activations: [ContextTip.Surface: Int] = [:]
    private var offersVisitCountedThisSession = false
    private var listSessionCounted = false

    /// Unter `-uiTesting` bleiben die Schilder aus, sofern der Lauf sie nicht
    /// per `-uiTestingTips` bestellt: Ein Schild über der Liste bliebe in jeder
    /// bestehenden Journey hängen, ohne dass an ihr etwas kaputt wäre.
    let isEnabled: Bool

    private let defaults: UserDefaults
    private static let key = "tips.ledger"

    init(defaults: UserDefaults = AppDefaults.shared, enabled: Bool? = nil) {
        self.defaults = defaults
        #if DEBUG
        self.isEnabled = enabled
            ?? (!UITestSupport.isActive || UITestSupport.showsContextTips)
        #else
        self.isEnabled = enabled ?? true
        #endif
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(ContextTipLedger.self, from: data) {
            self.ledger = stored
        } else {
            self.ledger = ContextTipLedger()
        }
    }

    private func moment(on surface: ContextTip.Surface) -> ContextTipRules.Moment {
        ContextTipRules.Moment(activationsOnSurface: activations[surface, default: 0])
    }

    /// Das Schild, das auf dieser Fläche gerade steht.
    func activeTip(on surface: ContextTip.Surface) -> ContextTip? { active[surface] }

    /// Weggetippt — das ✗ des Schilds. Der Merker ist beim Anzeigen schon
    /// gefallen (siehe `activate`), hier geht nur die Karte weg.
    func dismissTip(on surface: ContextTip.Surface) {
        active[surface] = nil
    }

    // MARK: Momente

    /// Die Liste steht ruhig da — Tipp-Fluss zu, nichts tippt. Zählt die
    /// Sitzung fürs Abhaken mit und entscheidet dann über die Regeln.
    ///
    /// `guidanceVisible` kommt aus `ListGuidance` (ohne den Tipp selbst
    /// gerechnet): Führt gerade eine andere Fläche, wartet der Tipp — die
    /// Sitzung zählt trotzdem, denn gezählt wird Verhalten, nicht Platz.
    func listSettled(matchVisible: Bool, hasOpenItems: Bool, guidanceVisible: Bool) {
        guard isEnabled else { return }
        if !listSessionCounted, hasOpenItems, !ledger.checkedOff {
            listSessionCounted = true
            ledger.listSessionsWithoutCheckOff += 1
            persist()
        }
        activate(ContextTipRules.tipOnList(
            ledger, matchVisible: matchVisible, hasOpenItems: hasOpenItems,
            guidanceVisible: guidanceVisible, moment: moment(on: .list)
        ))
    }

    /// Ein Artikel ist auf die Liste gekommen.
    func itemAdded() {
        guard isEnabled else { return }
        ledger.itemsAdded += 1
        persist()
    }

    /// Die Angaben-Schicht wurde benutzt (Chip angetippt oder Blatt geöffnet)
    /// — wer sie gefunden hat, braucht das Schild dazu nicht mehr.
    func detailsUsed() {
        guard isEnabled, !ledger.usedDetails else { return }
        ledger.usedDetails = true
        persist()
    }

    /// Der erste Haken ist der Moment, in dem der Wisch zum Löschen die
    /// eine unsichtbare Sache an der Zeile ist — deshalb wird hier nicht nur
    /// gezählt, sondern auch gleich entschieden.
    func checkedOff(matchVisible: Bool, hasOpenItems: Bool, guidanceVisible: Bool) {
        guard isEnabled else { return }
        if !ledger.checkedOff {
            ledger.checkedOff = true
            persist()
        }
        activate(ContextTipRules.tipOnList(
            ledger, matchVisible: matchVisible, hasOpenItems: hasOpenItems,
            guidanceVisible: guidanceVisible, moment: moment(on: .list)
        ))
    }

    /// Der Angebote-Tab ist aufgegangen. Besuche zählen je Sitzung einmal —
    /// wer dreimal zwischen den Tabs wechselt, hat den Tab nicht dreimal
    /// besucht.
    func offersAppeared(nextWeekAvailable: Bool) {
        guard isEnabled else { return }
        if !offersVisitCountedThisSession {
            offersVisitCountedThisSession = true
            ledger.offersVisits += 1
            persist()
        }
        activate(ContextTipRules.tipOnOffers(
            ledger, nextWeekAvailable: nextWeekAvailable, moment: moment(on: .offers)
        ))
    }

    // MARK: Ernährungsfrage

    /// **Einmal aufgeklappt, bleibt die Frage stehen** — bis sie beantwortet
    /// ist (`dismissDietPrompt`).
    ///
    /// Ohne diesen Riegel verschwand die Karte beim **ersten angetippten
    /// Chip**: Die Angabe steht danach im Profil, `dietAnswered` wird wahr,
    /// und die Regel nimmt die Frage weg. Damit waren eine zweite Angabe und
    /// der Knopf „Fertig" nie erreichbar — im Journey-Mitschnitt lag genau
    /// eine Sekunde zwischen dem Tipp auf „Vegetarisch" und dem Verschwinden
    /// des Knopfs. `dietAnswered` beantwortet die Frage „soll die Karte
    /// aufgehen", nicht „darf sie stehen bleiben".
    ///
    /// Sitzungsweit und bewusst nicht auf Platte: Nach einem Neustart
    /// entscheidet die Regel wieder von vorn.
    @ObservationIgnored private var dietPromptOpen = false

    func showsDietPrompt(dietAnswered: Bool) -> Bool {
        guard isEnabled, !ledger.dietPromptDone else { return false }
        if dietPromptOpen { return true }
        let shows = ContextTipRules.showsDietPrompt(
            ledger,
            dietAnswered: dietAnswered,
            tipVisibleHere: active[.offers] != nil
        )
        if shows { dietPromptOpen = true }
        return shows
    }

    /// „Fertig" wie „Ich esse alles" wie das X — jede Antwort ist endgültig.
    func dismissDietPrompt() {
        guard !ledger.dietPromptDone else { return }
        ledger.dietPromptDone = true
        persist()
    }

    // MARK: Innereien

    /// Aktivieren heißt gezeigt: Der Merker fällt **beim** Anzeigen, nicht
    /// beim Wegdrücken. Wer das Schild stehen lässt und die App tötet,
    /// bekommt es nicht noch einmal — lieber ein verpasstes Schild als eines,
    /// das wiederkommt.
    private func activate(_ tip: ContextTip?) {
        guard let tip, active[tip.surface] != tip else { return }
        active[tip.surface] = tip
        activations[tip.surface, default: 0] += 1
        ledger.shown.insert(tip)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(ledger) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// **„Tipps wieder anzeigen"** — der Wiederholweg aus den Einstellungen
    /// (Rundgang-Konzept §4, Schicht 3). Er ersetzt „Rundgang erneut ansehen"
    /// und erfüllt dieselbe HIG-Vorgabe: Ein Tutorial ist optional, wird nach
    /// dem Überspringen nie wieder vorgesetzt und ist später leicht
    /// wiederzufinden.
    ///
    /// Zurückgesetzt wird, **was gezeigt wurde** — nicht, was der Nutzer getan
    /// hat. Wer die Angaben-Schicht längst benutzt, bekommt ihr Schild auch
    /// nach dem Zurücksetzen nicht: Die Regeln sollen weiter für ihn gelten,
    /// er will die Schilder nur wieder sehen dürfen. Die Sitzungszähler fallen
    /// mit, sonst wartet der erste wieder bis zum nächsten Start.
    func showTipsAgain() {
        ledger.shown = []
        active = [:]
        activations = [:]
        persist()
    }

    /// Siehe `AppReset` — nach dem Zurücksetzen ist die Installation eine
    /// neue, und eine neue bekommt jedes Schild wieder an seinem Moment.
    func resetAllData() {
        ledger = ContextTipLedger()
        active = [:]
        dietPromptOpen = false
        activations = [:]
        offersVisitCountedThisSession = false
        listSessionCounted = false
        defaults.removeObject(forKey: Self.key)
    }
}
