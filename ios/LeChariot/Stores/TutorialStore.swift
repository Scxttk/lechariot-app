import Foundation
import Observation
import UIKit

// MARK: - Steps

/// Which tab a frame plays on. The overlay lives above the `TabView`, so the
/// tour has to say where it wants to be — `ContentView` owns the actual tab.
enum TutorialTab {
    case liste, einstellungen
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
    }

    let id: String
    let title: String
    let text: String
    let spotlight: Spotlight
    /// Berührungen erreichen das hervorgehobene Element. Alles außerhalb des
    /// Lochs ist immer tot — das ist der Zweck der Übung.
    ///
    /// Mitmachen heißt **nicht** weiterspringen: Die beiden Rahmen mit
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

    /// Der Rundgang. Reihenfolge so gewählt, dass nie gescrollt werden muss:
    /// Die ersten beiden Rahmen spielen auf dem leeren Bildschirm, wo
    /// Eingabezeile und Vorschläge gleichzeitig sichtbar sind; danach stehen
    /// Artikel auf der Liste und die Karte steht oben.
    static let tour: [TutorialStep] = [
        TutorialStep(
            id: "input",
            title: "Schreib auf, was du brauchst",
            text: "Tipp hier ein, was du einkaufen willst — ein Artikel pro Zeile. Probier es gleich aus.",
            spotlight: .anchor(.inputBar),
            allowsInteraction: true
        ),
        TutorialStep(
            id: "chips",
            title: "Oder nimm einen Vorschlag",
            text: "Häufig Gekauftes liegt schon bereit. Ein Tipp, und es steht auf der Liste.",
            spotlight: .anchor(.suggestions),
            allowsInteraction: true
        ),
        TutorialStep(
            id: "plan",
            title: "Ein Einkauf, ein Markt",
            text: "Diese Karte ist der Kern: Sie sagt dir, welche deiner Filialen die ganze Liste am günstigsten abdeckt — und was der Einkauf dort kostet.",
            spotlight: .anchor(.planCard),
            seedsDemoItems: true
        ),
        TutorialStep(
            id: "match",
            title: "Das günstigste Angebot",
            text: "Unter jedem Artikel steht das beste Angebot mit Preis und Markt. Tipp es an, um alle Treffer zu sehen — oder einen falschen wegzulegen.",
            spotlight: .anchor(.rowMatch)
        ),
        TutorialStep(
            id: "check",
            title: "Abhaken beim Einkaufen",
            text: "Im Laden tippst du den Kreis an, dann wandert der Artikel nach unten zu „Erledigt“. Zum Löschen wischst du die Zeile nach links.",
            spotlight: .anchor(.rowCheck)
        ),
        TutorialStep(
            id: "tabs",
            title: "Angebote und Einstellungen",
            text: "Unter „Angebote“ siehst du alles, was diese Woche günstig ist. Unter „Einstellungen“ änderst du deine Filialen.",
            spotlight: .tabBar
        ),
        TutorialStep(
            id: "settings",
            title: "Hier stellst du alles um",
            text: "Deine Filialen änderst du hier — und diesen Rundgang kannst du jederzeit noch einmal starten.",
            spotlight: .union(.settingsMarkets, .settingsHelp),
            tab: .einstellungen
        ),
    ]
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

    /// Überlebt Neustarts. Steuert nur noch, ob am Ende des Onboardings
    /// überhaupt gefragt wird — automatisch startet der Rundgang nie.
    private(set) var hasSeenTutorial: Bool

    /// Was der Rundgang selbst auf die Liste gelegt hat. Kommt am Ende wieder
    /// herunter, damit niemand mit drei fremden Artikeln dasteht.
    private(set) var seededItems: [ShoppingItem] = []

    let steps = TutorialStep.tour

    private let defaults: UserDefaults
    private static let key = "tutorial.hasSeen"
    private static let seededKey = "tutorial.seededItems"

    /// Artikel, die der Rundgang für die datenabhängigen Rahmen setzt.
    /// Grundnahrungsmittel aus `ShoppingSuggestions.staples`, also genau die
    /// Wörter, für die das Wörterbuch am zuverlässigsten Treffer liefert.
    static let demoItems = ["Milch", "Butter", "Kaffee"]

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        self.hasSeenTutorial = defaults.bool(forKey: Self.key)
        // Wird der Rundgang vom App-Tod unterbrochen, bleiben seine
        // Beispiel-Artikel sonst für immer auf der Liste stehen. Sie überleben
        // deshalb auf Platte und werden beim nächsten Start abgeräumt.
        if let data = defaults.data(forKey: Self.seededKey),
           let stored = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            self.seededItems = stored
        }
    }

    // MARK: Ablauf

    var stepCount: Int { steps.count }
    var step: TutorialStep { steps[min(index, steps.count - 1)] }
    var isLastStep: Bool { index >= steps.count - 1 }

    /// Das Angebot am Ende des Onboardings wurde abgelehnt.
    func decline() {
        markSeen()
    }

    /// Startet den Rundgang von vorn — aus dem Onboarding oder aus den
    /// Einstellungen.
    ///
    /// Sofort, nicht verzögert: Der erste Rahmen darf ruhig ein paar
    /// Millisekunden ohne Loch dastehen, die Schonfrist im Overlay fängt das ab.
    /// Ein „später starten"-Zustand war der Versuch, dem Layout zuvorzukommen —
    /// und genau der ist im Testlauf nie eingelöst worden.
    func start() {
        index = 0
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

    func finish() {
        isRunning = false
        index = 0
        markSeen()
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
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.seededKey)
    }
}
