import Foundation
import Observation
import UIKit

// MARK: - Steps

/// Which tab a frame plays on. The overlay lives above the `TabView`, so the
/// tour has to say where it wants to be — `ContentView` owns the actual tab.
enum TutorialTab {
    case liste, angebote, einstellungen
}

/// One frame of the tour: what is highlighted, what is said, and how it ends.
struct TutorialStep: Identifiable, Equatable {
    /// What the hole is cut around.
    enum Spotlight: Equatable {
        case anchor(TutorialTarget)
        /// Two tagged views at once — used for the settings frame, which points
        /// at the branches and the restart button together.
        case union(TutorialTarget, TutorialTarget)
        /// Die Tab-Leiste zeichnet UIKit; sie trägt keinen Anker und wird aus
        /// der sicheren Fläche hergeleitet. Siehe `TutorialOverlay.tabBarBand`.
        case tabBar
        /// Die Navigationsleiste, aus derselben Not wie `tabBar` — der Knopf
        /// „Nächste Woche" ist ein `ToolbarItem` und liegt damit außerhalb des
        /// SwiftUI-Baums, aus dem die Anker kommen. Siehe
        /// `TutorialOverlay.navBarBand`.
        case navBar
    }

    let id: String
    let title: String
    let text: String
    let spotlight: Spotlight
    /// Berührungen erreichen das hervorgehobene Element. Alles außerhalb des
    /// Lochs ist immer tot — das ist der Zweck der Übung.
    ///
    /// Mitmachen heißt **nicht** weiterspringen: Die Rahmen mit
    /// `allowsInteraction` gingen bis zum 2026-07-30 von allein weiter, sobald
    /// ein Artikel auf der Liste landete (`advance: .itemAdded`). Scotts Bruder
    /// hat es beim ersten Anfassen gemeldet — „der erste Punkt ist automatisch
    /// und zu schnell": Wer den Vorschlag antippt, während er noch liest, wird
    /// mitten im Satz weitergeschoben, und der Text, der erklärt was er gerade
    /// getan hat, ist weg. Jeder Rahmen wartet jetzt auf „Weiter".
    var allowsInteraction = false
    var tab: TutorialTab = .liste
    /// Legt beim Betreten Beispiel-Artikel auf die Liste. Ohne die gäbe es für
    /// die Karte und die Zeilen nichts zu zeigen — und genau die erklären,
    /// wofür die App da ist.
    var seedsDemoItems = false

    /// Der Rundgang: vier Rahmen, nur der Kern-Loop.
    ///
    /// **Gekürzt von acht bis neun auf vier** (05.08.). Die Forschungsrunde zum
    /// Onboarding war eindeutig: Touren über fünf Schritten werden abgebrochen,
    /// und Rahmen, die UI beschreiben statt Ziele, erklären nichts. Der alte
    /// Rundgang erzählte in neun Rahmen fast die ganze App — die Angaben-
    /// Schicht, das Abhaken, die Vorschau „Nächste Woche", Preisverlauf und
    /// Anheften. **Nichts davon ist ersatzlos gestrichen:** Diese Inhalte
    /// wandern als Einmal-Tipps (TipKit) an die Stelle, an der sie relevant
    /// werden — eigenes Arbeitspaket, siehe Onboarding-Plan vom 05.08. Hier
    /// bleibt, was man braucht, um die App zum ersten Mal zu benutzen:
    /// aufschreiben, ablesen, stöbern, umstellen.
    ///
    /// Reihenfolge so gewählt, dass nie gescrollt werden muss: Der erste
    /// Rahmen spielt auf dem leeren Bildschirm, der zweite legt die
    /// Beispiel-Artikel selbst und zeigt daran die Karte oben.
    ///
    /// **Drei Rahmen, und zwar seit dem 06.08.**
    ///
    /// Vorher waren es neun, über drei Tabs, mit Überblendung dazwischen.
    /// Scotts Befund: zu viel. Und die Messung vom 03.08. sagt dasselbe von der
    /// anderen Seite — der Rundgang steht bei rund **+100 % Instruktionen**
    /// gegen den gespeicherten Grundwert und ist damit die teuerste Strecke der
    /// App, für etwas, das jeder Nutzer genau einmal sieht.
    ///
    /// **Was den Ausschlag gab, welche drei bleiben:** Der Rundgang gibt es,
    /// weil Testern nach dem Onboarding nicht klar war, *was sie tun sollen*.
    /// Das sind drei Handgriffe — aufschreiben, den Markt ablesen, im Laden
    /// abhaken. Alles andere im alten Rundgang erklärte Dinge, die auf dem
    /// Bildschirm ohnehin stehen (die Vorschlagskacheln, die Tab-Leiste, die
    /// Angebotszeile unter dem Artikel) oder die man erst später sucht (die
    /// Vorschau, die Einstellungen). Ein Rahmen, der etwas zeigt, das man sieht,
    /// kostet nur Zeit.
    ///
    /// **Und alle drei spielen auf der Liste.** Damit ist der Tab-Wechsel im
    /// Rundgang keine Strecke mehr, sondern nur noch der Weg hinein, wenn er aus
    /// den Einstellungen gestartet wurde.
    ///
    /// `hasMarkets` ändert weiter einen Text: Seit dem 2026-07-31 endet das
    /// Onboarding in der Liste statt in der Filialauswahl, der Rundgang läuft
    /// also im Normalfall über einer Liste **ohne** gewählte Filiale. „Sie sagt
    /// dir, welche Filiale am günstigsten ist" über einer Karte, die den
    /// Leerzustand zeigt, ist eine kleine Lüge — und die erste, die ein Tester
    /// zu sehen bekommt.
    static func tour(hasMarkets: Bool) -> [TutorialStep] {
        [
            TutorialStep(
                id: "input",
                title: "Schreib auf, was du brauchst",
                text: "Tipp hier ein, was du einkaufen willst — ein Artikel pro Zeile. Die Tastatur bleibt danach stehen, du kannst einfach weitertippen. Probier es gleich aus.",
                spotlight: .anchor(.inputBar),
                allowsInteraction: true
            ),
            TutorialStep(
                id: "plan",
                title: "Ein Einkauf, ein Markt",
                text: hasMarkets
                    ? "Diese Karte ist der Kern: Sie sagt dir, welche deiner Filialen die ganze Liste am günstigsten abdeckt — und was der Einkauf dort kostet. Unter jedem Artikel steht das beste Angebot dazu."
                    : "Diese Karte ist der Kern: Sobald du Filialen gewählt hast, sagt sie dir, welche von ihnen die ganze Liste am günstigsten abdeckt — und was der Einkauf dort kostet. Unter jedem Artikel steht dann das beste Angebot dazu.",
                spotlight: .anchor(.planCard),
                seedsDemoItems: true
            ),
            TutorialStep(
                id: "check",
                title: "Abhaken beim Einkaufen",
                text: "Im Laden tippst du den Kreis an, dann wandert der Artikel nach unten zu „Erledigt“. Zum Löschen wischst du die Zeile nach links. Diesen Rundgang findest du jederzeit wieder unter „Einstellungen“.",
                spotlight: .anchor(.rowCheck)
            ),
        ]
    }
}

// MARK: - Store

/// Führt einmal durch die Einkaufsliste — und danach nur noch auf Wunsch.
///
/// Warum es das gibt: Testern war nach dem Onboarding nicht klar, was sie tun
/// sollen. Der Bildschirm ist ein Eingabefeld und ein paar Vorschläge; dass
/// daraus eine Empfehlung für *einen* Markt wird, sieht man erst, wenn etwas
/// auf der Liste steht. Der Rundgang zeigt genau diesen Weg einmal vor.
///
/// Angeboten wird er am Ende des Onboardings, nicht aufgezwungen — und danach
/// nur noch über die Einstellungen. Von allein startet er nie.
@MainActor
@Observable
final class TutorialStore {
    private(set) var isRunning = false
    private(set) var index = 0

    /// Einmal beim Start gelesen statt laufend abgefragt. Mitten im Rundgang
    /// VoiceOver einzuschalten ist kein Fall, für den sich ein Umbau jedes
    /// Rahmens lohnt.
    private(set) var isVoiceOverRunning = false

    /// Überlebt Neustarts. Steuert, ob am Ende des Onboardings überhaupt
    /// gefragt wird — siehe `offersTourAfterOnboarding`.
    private(set) var hasSeenTutorial: Bool

    /// Was der Rundgang selbst auf die Liste gelegt hat. Kommt am Ende wieder
    /// herunter, damit niemand mit drei fremden Artikeln dasteht.
    private(set) var seededItems: [ShoppingItem] = []

    /// Woher der laufende Rundgang gestartet wurde.
    ///
    /// Der Unterschied trägt genau eine Folge: Nur der Rundgang **aus dem
    /// Onboarding** fragt am Ende nach den Filialen. Wer ihn aus den
    /// Einstellungen noch einmal ansieht, hat seine Wahl längst getroffen —
    /// für bestehende Installationen ändert sich damit nichts.
    enum Origin {
        case onboarding, settings
    }

    private(set) var origin: Origin = .settings

    /// Das Markt-Sheet steht an. Wird gesetzt, wenn jemand am Ende des
    /// Onboardings noch keine Filiale hat — nach einem Rundgang aus dem
    /// Onboarding wie nach einem abgelehnten Angebot („Später"). Die zweite
    /// Hälfte ist neu (05.08.): Wer den Rundgang überspringt, sah die Frage
    /// vorher **nie** — die `NoMarketsCard` in der Liste war sein einziger
    /// Weg, und die erklärt sich erst, wenn man sie findet.
    private(set) var asksForMarkets = false

    /// Das Markt-Sheet wurde schon einmal gezeigt und beantwortet — egal wie.
    /// Überlebt Neustarts: Ein Hinweis, der bei jeder Gelegenheit wiederkommt,
    /// ist keine Hilfe, sondern eine Mahnung.
    private(set) var hasAnsweredMarketPrompt: Bool

    /// Der Rundgang in der Fassung, in der er gestartet wurde. Siehe
    /// `TutorialStep.tour(hasMarkets:)`.
    private(set) var steps = TutorialStep.tour(hasMarkets: true)

    /// Ob beim Start Filialen gewählt waren. Entscheidet zusammen mit `origin`
    /// über die Frage am Ende.
    private var startedWithMarkets = true

    private let defaults: UserDefaults
    private static let key = "tutorial.hasSeen"
    private static let seededKey = "tutorial.seededItems"
    private static let marketPromptKey = "tutorial.marketPrompt.answered"

    /// Artikel, die der Rundgang für die datenabhängigen Rahmen setzt.
    /// Grundnahrungsmittel aus `ShoppingSuggestions.staples`, also genau die
    /// Wörter, für die das Wörterbuch am zuverlässigsten Treffer liefert.
    static let demoItems = ["Milch", "Butter", "Kaffee"]

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        self.hasSeenTutorial = defaults.bool(forKey: Self.key)
        self.hasAnsweredMarketPrompt = defaults.bool(forKey: Self.marketPromptKey)
        // Wird der Rundgang vom App-Tod unterbrochen, bleiben seine
        // Beispiel-Artikel sonst für immer auf der Liste stehen. Sie überleben
        // deshalb auf Platte und werden beim nächsten Start abgeräumt.
        if let data = defaults.data(forKey: Self.seededKey),
           let stored = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            self.seededItems = stored
        }
    }

    // MARK: Ablauf

    /// Ob das Onboarding den Rundgang anbieten darf.
    ///
    /// **Der Merker war bis zum 2026-08-02 tot.** Er wurde geschrieben und von
    /// keiner einzigen Ansicht gelesen — im ganzen Verlauf des Repos hat nie
    /// eine auf ihn zugegriffen; `OnboardingFlowView.offersTour` gab schlicht
    /// `true` zurück. Der Kommentar darüber („steuert, ob gefragt wird") war
    /// eine Zusage, die nirgends eingelöst wurde. Wer den Assistenten aus
    /// welchem Grund auch immer ein zweites Mal sah, bekam den Rundgang wieder
    /// vorgesetzt — und `resume()` springt sofort auf genau diesen Schritt.
    ///
    /// Gemeldet am 01.08. aus Build `2026.0801.1951`: „Der Rundgang startet
    /// wieder automatisch los."
    ///
    /// Ein Zurücksetzen darf ihn weiter anbieten: `resetAllData()` räumt den
    /// Schlüssel ab, und danach ist die Installation eine neue.
    var offersTourAfterOnboarding: Bool { !hasSeenTutorial }

    var stepCount: Int { steps.count }
    var step: TutorialStep { steps[min(index, steps.count - 1)] }
    var isLastStep: Bool { index >= steps.count - 1 }

    /// Das Angebot am Ende des Onboardings wurde abgelehnt.
    ///
    /// **„Später" führt trotzdem zur Markt-Frage** (05.08.). Wer den Rundgang
    /// überspringt und keine Filiale hat, stand vorher wortlos vor einer
    /// Liste, die nichts vergleichen kann — die Frage hing nur am Ende des
    /// Rundgangs, und den hat er gerade abgelehnt.
    func decline(hasMarkets: Bool) {
        markSeen()
        asksForMarkets = !hasMarkets && !hasAnsweredMarketPrompt
    }

    /// Startet den Rundgang von vorn — aus dem Onboarding oder aus den
    /// Einstellungen.
    ///
    /// Sofort, nicht verzögert: Der erste Rahmen darf ruhig ein paar
    /// Millisekunden ohne Loch dastehen, die Schonfrist im Overlay fängt das ab.
    /// Ein „später starten"-Zustand war der Versuch, dem Layout zuvorzukommen —
    /// und genau der ist im Testlauf nie eingelöst worden.
    ///
    /// `hasMarkets` wird beim Start eingefroren statt laufend abgefragt: Die
    /// Filialauswahl ist während des Rundgangs hinter den Sperrflächen, sie
    /// kann sich also nicht ändern — und ein Text, der mitten im Lesen die
    /// Zeitform wechselt, wäre schlimmer als ein leicht veralteter.
    func start(origin: Origin, hasMarkets: Bool) {
        index = 0
        self.origin = origin
        startedWithMarkets = hasMarkets
        steps = TutorialStep.tour(hasMarkets: hasMarkets)
        asksForMarkets = false
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isRunning = true
    }

    func next() {
        if isLastStep {
            finish()
        } else {
            index += 1
        }
    }

    func skip() {
        finish()
    }

    /// Beendet den Rundgang — „Fertig" wie „Tour beenden".
    ///
    /// Die Frage nach den Filialen hängt an beiden Ausgängen: Wer abbricht,
    /// hat trotzdem keine Filiale, und ihn danach still in einer Liste
    /// stehenzulassen, die nichts vergleichen kann, wäre genau die Sackgasse,
    /// gegen die der ganze Umbau antritt.
    func finish() {
        isRunning = false
        index = 0
        asksForMarkets = origin == .onboarding && !startedWithMarkets
            && !hasAnsweredMarketPrompt
        markSeen()
    }

    /// Die Frage ist beantwortet — egal wie: „Märkte wählen", „Später" oder
    /// weggewischt. Der Merker überlebt Neustarts, denn das Sheet ist ein
    /// Angebot und keine Mahnung — einmal gezeigt, danach bleiben der
    /// Leerzustand der Liste und die Einstellungen als Wege.
    func dismissMarketQuestion() {
        asksForMarkets = false
        guard !hasAnsweredMarketPrompt else { return }
        hasAnsweredMarketPrompt = true
        defaults.set(true, forKey: Self.marketPromptKey)
    }

    private func markSeen() {
        guard !hasSeenTutorial else { return }
        hasSeenTutorial = true
        defaults.set(true, forKey: Self.key)
    }

    // MARK: Beispiel-Artikel

    /// Legt die Beispiel-Artikel auf die Liste — aber nur die, die nicht schon
    /// dort stehen. `add` meldet `false` für Doppelte, also bleibt stehen, was
    /// der Tester in den ersten beiden Rahmen selbst getippt hat, und es wird
    /// ihm hinterher auch nicht weggeräumt.
    func seedDemoItems(into list: ShoppingListStore) {
        guard seededItems.isEmpty else { return }
        for text in Self.demoItems where list.add(text) {
            if let added = list.items.last {
                seededItems.append(added)
            }
        }
        persistSeededItems()
    }

    /// Räumt genau die eigenen Artikel wieder ab. Wird bei jedem Ende gerufen —
    /// „Fertig“ wie „Tour beenden“ —, deshalb sitzt der Aufruf in `ContentView`
    /// an `isRunning` und nicht an einem einzelnen Knopf.
    func removeDemoItems(from list: ShoppingListStore) {
        guard !seededItems.isEmpty else { return }
        for item in seededItems {
            list.remove(item)
        }
        seededItems = []
        persistSeededItems()
    }

    private func persistSeededItems() {
        guard !seededItems.isEmpty else {
            defaults.removeObject(forKey: Self.seededKey)
            return
        }
        if let data = try? JSONEncoder().encode(seededItems) {
            defaults.set(data, forKey: Self.seededKey)
        }
    }

    /// Siehe `AppReset`. Schlüssel nach der Zuweisung entfernen, sonst
    /// schreibt ihn der nächste Lauf sofort zurück.
    func resetAllData() {
        isRunning = false
        index = 0
        seededItems = []
        hasSeenTutorial = false
        asksForMarkets = false
        hasAnsweredMarketPrompt = false
        origin = .settings
        startedWithMarkets = true
        steps = TutorialStep.tour(hasMarkets: true)
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.seededKey)
        defaults.removeObject(forKey: Self.marketPromptKey)
    }
}
