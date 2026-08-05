import Foundation
import Observation

// MARK: - Die Tipps

/// Die vier Einmal-Tipps, die der gekürzte Rundgang hinterlässt.
///
/// Der Rundgang erzählte acht bis neun Rahmen am Stück, und die Forschung dazu
/// ist eindeutig (~76 % der Tooltips in unter drei Sekunden weggewischt, siehe
/// [[Le Chariot Onboarding-Forschung]]): Was nicht zum Kern-Loop gehört, wird
/// hier zum Einmal-Tipp im Moment der Relevanz. Die Texte stehen für sich —
/// sie dürfen nicht voraussetzen, dass der Rundgang dieselbe Stelle noch
/// erwähnt, denn genau das tut er nach der Kürzung nicht mehr.
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
}

// MARK: - Stellschrauben

/// **Alle Schwellwerte an einer Stelle**, damit „fühlt sich aufdringlich an"
/// eine Zahl zum Drehen hat und keine Suche durchs Repo.
enum ContextTipTuning {
    /// Höchstens **ein** Tipp je App-Sitzung. Die Momente, an denen Tipps
    /// hängen, kommen wieder (die Liste steht jeden Tag da, der Angebote-Tab
    /// auch) — ein verschobener Tipp ist also nicht verloren, er kommt in der
    /// nächsten Sitzung an seinem Moment wieder dran. Zwei Sprechblasen in
    /// einer Sitzung wären genau die Tour in Raten, die abgeschafft wird.
    static let tipsPerSession = 1

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

/// **Die Entscheidung, nicht die Sprechblase** — als reine Rechnung, nach dem
/// Muster von `TourTabTransition`: Ansichten melden, was gerade wahr ist, und
/// hier steht prüfbar, welcher Tipp daraus folgt.
enum ContextTipRules {
    /// Was nur für die laufende Sitzung gilt und deshalb nicht im Ledger liegt.
    struct Moment: Equatable {
        var tourIsRunning = false
        var activationsThisSession = 0
    }

    /// Während des Rundgangs spricht genau einer: der Rundgang. Und pro
    /// Sitzung höchstens `tipsPerSession` — siehe dort.
    static func mayActivate(_ moment: Moment) -> Bool {
        !moment.tourIsRunning
            && moment.activationsThisSession < ContextTipTuning.tipsPerSession
    }

    /// Die Liste steht ruhig da (kein Tipp-Fluss) — welcher Tipp jetzt?
    ///
    /// Reihenfolge ist Vorrang: Die Angebotszeile zuerst (sie ist der Grund,
    /// aus dem es die App gibt), dann die Angaben-Schicht, zuletzt das
    /// Abhaken. Es feuert höchstens einer — `tipsPerSession` sorgt dafür,
    /// dass die anderen in späteren Sitzungen an ihrem Moment drankommen.
    static func tipOnList(
        _ ledger: ContextTipLedger,
        matchVisible: Bool,
        hasOpenItems: Bool,
        moment: Moment
    ) -> ContextTip? {
        guard mayActivate(moment) else { return nil }
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
        tipVisibleHere: Bool,
        moment: Moment
    ) -> Bool {
        !moment.tourIsRunning
            && !tipVisibleHere
            && !ledger.dietPromptDone
            && !dietAnswered
            && ledger.offersVisits >= ContextTipTuning.offersVisitsBeforeDietPrompt
    }
}

// MARK: - Store

/// Buchhaltung der Kontext-Tipps: zählt die Momente, entscheidet über die
/// Regeln oben und merkt sich Gezeigtes über Neustarts hinweg.
///
/// **`active` ist bewusst nicht persistiert.** Eine Sprechblase, die einen
/// Neustart überlebt, zeigt auf einen Moment, der vorbei ist — nach dem
/// Neustart ist die Sitzung frisch und der nächste Tipp wartet auf seinen
/// eigenen Moment. Gezeigt-Merker und Zähler überleben dagegen auf Platte.
@MainActor
@Observable
final class ContextTipStore {
    private(set) var ledger: ContextTipLedger
    /// Der gerade angezeigte Tipp — höchstens einer, siehe `tipsPerSession`.
    private(set) var active: ContextTip?

    /// Von `ContentView` gespiegelt. Während des Rundgangs zählt und feuert
    /// hier nichts — die Beispiel-Artikel des Rundgangs sind keine Nutzung,
    /// und zwei Erklärschichten übereinander sind eine zu viel.
    var tourIsRunning = false

    private var activationsThisSession = 0
    private var offersVisitCountedThisSession = false
    private var listSessionCounted = false

    /// Unter `-uiTesting` bleiben die Tipps aus, sofern der Lauf sie nicht
    /// per `-uiTestingTips` bestellt — dieselbe Abwägung wie beim Rundgang
    /// (`UITestSupport.showsTutorial`): Eine Sprechblase über der Liste
    /// bliebe in jeder bestehenden Journey hängen, ohne dass an ihr etwas
    /// kaputt wäre.
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

    private var moment: ContextTipRules.Moment {
        ContextTipRules.Moment(
            tourIsRunning: tourIsRunning,
            activationsThisSession: activationsThisSession
        )
    }

    // MARK: Momente

    /// Die Liste steht ruhig da — Tipp-Fluss zu, nichts tippt. Zählt die
    /// Sitzung fürs Abhaken mit und entscheidet dann über die Regeln.
    func listSettled(matchVisible: Bool, hasOpenItems: Bool) {
        guard isEnabled, !tourIsRunning else { return }
        if !listSessionCounted, hasOpenItems, !ledger.checkedOff {
            listSessionCounted = true
            ledger.listSessionsWithoutCheckOff += 1
            persist()
        }
        activate(ContextTipRules.tipOnList(
            ledger, matchVisible: matchVisible, hasOpenItems: hasOpenItems,
            moment: moment
        ))
    }

    /// Ein Artikel ist auf die Liste gekommen — vom Nutzer, nicht vom
    /// Rundgang (der ist über `tourIsRunning` ausgesperrt).
    func itemAdded() {
        guard isEnabled, !tourIsRunning else { return }
        ledger.itemsAdded += 1
        persist()
    }

    /// Die Angaben-Schicht wurde benutzt (Chip angetippt oder Blatt geöffnet).
    /// Kein Rundgang-Riegel: Auch wer sie **im** Rundgang anfasst, hat sie
    /// gefunden — der Tipp dazu wäre danach in jedem Fall Bekanntes.
    func detailsUsed() {
        guard isEnabled, !ledger.usedDetails else { return }
        ledger.usedDetails = true
        persist()
    }

    /// Der erste Haken ist der Moment, in dem der Wisch zum Löschen die
    /// eine unsichtbare Sache an der Zeile ist — deshalb wird hier nicht nur
    /// gezählt, sondern auch gleich entschieden.
    func checkedOff(matchVisible: Bool, hasOpenItems: Bool) {
        guard isEnabled else { return }
        if !ledger.checkedOff {
            ledger.checkedOff = true
            persist()
        }
        guard !tourIsRunning else { return }
        activate(ContextTipRules.tipOnList(
            ledger, matchVisible: matchVisible, hasOpenItems: hasOpenItems,
            moment: moment
        ))
    }

    /// Der Angebote-Tab ist aufgegangen. Besuche zählen je Sitzung einmal —
    /// wer dreimal zwischen den Tabs wechselt, hat den Tab nicht dreimal
    /// besucht.
    func offersAppeared(nextWeekAvailable: Bool) {
        guard isEnabled, !tourIsRunning else { return }
        if !offersVisitCountedThisSession {
            offersVisitCountedThisSession = true
            ledger.offersVisits += 1
            persist()
        }
        activate(ContextTipRules.tipOnOffers(
            ledger, nextWeekAvailable: nextWeekAvailable, moment: moment
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
        guard isEnabled, !tourIsRunning, !ledger.dietPromptDone else { return false }
        if dietPromptOpen { return true }
        let shows = ContextTipRules.showsDietPrompt(
            ledger,
            dietAnswered: dietAnswered,
            tipVisibleHere: active == .nextWeekPreview,
            moment: moment
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
    /// beim Wegdrücken. Wer die Sprechblase stehen lässt und die App tötet,
    /// bekommt sie nicht noch einmal — lieber ein verpasster Tipp als einer,
    /// der wiederkommt.
    private func activate(_ tip: ContextTip?) {
        guard let tip, active != tip else { return }
        active = tip
        activationsThisSession += 1
        ledger.shown.insert(tip)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(ledger) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// Siehe `AppReset` — nach dem Zurücksetzen ist die Installation eine
    /// neue, und eine neue bekommt jeden Tipp wieder an seinem Moment.
    func resetAllData() {
        ledger = ContextTipLedger()
        active = nil
        dietPromptOpen = false
        activationsThisSession = 0
        offersVisitCountedThisSession = false
        listSessionCounted = false
        defaults.removeObject(forKey: Self.key)
    }
}
