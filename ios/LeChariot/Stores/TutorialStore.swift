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
    /// Hält die Angaben-Schicht offen, solange dieser Rahmen läuft.
    ///
    /// Ohne das hinge der Rahmen daran, dass der Tester im Rahmen davor
    /// wirklich etwas getippt hat — und wer nur „Weiter" drückt, bekäme einen
    /// Rahmen ohne Ziel, der sich nach der Schonfrist selbst überspringt.
    var showsDetailPanel = false

    /// Der Rundgang. Reihenfolge so gewählt, dass nie gescrollt werden muss:
    /// Der erste Rahmen spielt auf dem leeren Bildschirm, der zweite legt die
    /// Beispiel-Artikel und zeigt daran die Angaben-Schicht; danach stehen
    /// Artikel auf der Liste und die Karte steht oben.
    ///
    /// **`hasMarkets` ändert zwei Texte und einen Rahmen.** Seit dem 2026-07-31
    /// endet das Onboarding in der Liste statt in der Filialauswahl — der
    /// Rundgang läuft also im Normalfall über einer Liste **ohne** gewählte
    /// Filiale. An der Plan-Karte und an der Treffer-Zeile steht dann der
    /// Leerzustand, der genau das sagt; die beiden Rahmen darüber müssen
    /// dieselbe Zeitform sprechen. „Tipp es an, um alle Treffer zu sehen" über
    /// einer Zeile, in der nichts anzutippen ist, ist eine kleine Lüge — und
    /// die erste, die ein Tester zu sehen bekommt. Den Rahmen zur Vorschau gibt
    /// es ohne Filiale gar nicht — dazu unten mehr.
    ///
    /// **Der Rundgang hinkte der App hinterher** (Scott, 03.08.). Gebaut wurde
    /// er über einer App, die es so nicht mehr gibt: Seitdem kamen die
    /// Angaben-Schicht, die Vorschau „Nächste Woche", der Preisverlauf, das
    /// Anheften mehrerer Wahlen und der Freitext dazu, und keins davon kam
    /// darin vor.
    ///
    /// **Geschlossen mit zwei Rahmen, nicht mit fünf.** Ein Rundgang wird nicht
    /// dadurch besser, dass er alles erwähnt — die drei kleineren Zugaben
    /// (Preisverlauf, mehrere Heftungen, Freitext) stehen als Halbsatz in dem
    /// Rahmen, der ohnehin von ihrer Stelle handelt. Eigene Rahmen bekommen nur
    /// die zwei, die man sonst nicht findet: die Angaben-Schicht und die
    /// Vorschau hinter dem Knopf oben links.
    static func tour(hasMarkets: Bool) -> [TutorialStep] {
        var steps: [TutorialStep] = [
            TutorialStep(
                id: "input",
                title: "Schreib auf, was du brauchst",
                text: "Tipp hier ein, was du einkaufen willst — ein Artikel pro Zeile. Die Tastatur bleibt danach stehen, du kannst einfach weitertippen. Probier es gleich aus.",
                spotlight: .anchor(.inputBar),
                allowsInteraction: true
            ),
            TutorialStep(
                id: "details",
                title: "Menge, Größe, Sorte — wenn du magst",
                text: "Zu jedem neuen Artikel liegen hier seine Angaben. Das ist ein Angebot, keine Frage: Wer weitertippt, überspringt sie einfach. Hinter „Notiz …“ ist Platz für eigene Worte.",
                spotlight: .anchor(.detailPanel),
                seedsDemoItems: true,
                showsDetailPanel: true
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
                text: hasMarkets
                    ? "Diese Karte ist der Kern: Sie sagt dir, welche deiner Filialen die ganze Liste am günstigsten abdeckt — und was der Einkauf dort kostet."
                    : "Diese Karte ist der Kern: Sobald du Filialen gewählt hast, sagt sie dir, welche von ihnen die ganze Liste am günstigsten abdeckt — und was der Einkauf dort kostet.",
                spotlight: .anchor(.planCard)
            ),
            TutorialStep(
                id: "match",
                title: "Das günstigste Angebot",
                text: hasMarkets
                    ? "Unter jedem Artikel steht das beste Angebot mit Preis und Markt. Tipp es an: Dort stehen alle Treffer samt Preisverlauf, und du kannst dir eine — oder mehrere — Wahlen fest anheften."
                    : "Unter jedem Artikel steht dann das beste Angebot mit Preis und Markt. Antippen zeigt alle Treffer samt Preisverlauf und lässt dich deine Wahl fest anheften.",
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
        ]

        // **Nur mit Filialen.** Ohne sie steht im Angebote-Tab kein
        // Bildschirm, sondern der Hinweis „Keine Filiale gewählt" — der Knopf
        // „Nächste Woche" existiert dort gar nicht. Der Rahmen liefe also ins
        // Leere, überspränge sich nach der Schonfrist selbst und hinterließe
        // dabei genau das Blinzeln, das diese Runde abschaffen soll. Der
        // Normalfall direkt nach dem Onboarding ist **ohne** Filiale.
        if hasMarkets {
            steps.append(TutorialStep(
                id: "nextWeek",
                title: "Was ab Montag billiger wird",
                text: "Oben links führt „Nächste Woche“ in die Vorschau. Sie beantwortet die Frage, die es sonst nicht gibt: Was kaufe ich heute bewusst nicht, weil es nächste Woche günstiger ist?",
                spotlight: .navBar,
                tab: .angebote
            ))
        }

        steps.append(TutorialStep(
            id: "settings",
            title: "Hier stellst du alles um",
            text: "Deine Filialen änderst du hier — und diesen Rundgang kannst du jederzeit noch einmal starten.",
            spotlight: .union(.settingsMarkets, .settingsHelp),
            tab: .einstellungen
        ))
        return steps
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

    /// Die Frage „Märkte jetzt auswählen?" steht an. Wird beim Ende eines
    /// Rundgangs aus dem Onboarding gesetzt, der über einer Liste **ohne**
    /// Filiale lief — und nur dann.
    private(set) var asksForMarkets = false

    /// Der Rundgang in der Fassung, in der er gestartet wurde. Siehe
    /// `TutorialStep.tour(hasMarkets:)`.
    private(set) var steps = TutorialStep.tour(hasMarkets: true)

    /// Ob beim Start Filialen gewählt waren. Entscheidet zusammen mit `origin`
    /// über die Frage am Ende.
    private var startedWithMarkets = true

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
        markSeen()
    }

    /// Die Frage ist beantwortet — egal wie. Ohne das käme sie beim nächsten
    /// Rendern wieder.
    func dismissMarketQuestion() {
        asksForMarkets = false
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
        origin = .settings
        startedWithMarkets = true
        steps = TutorialStep.tour(hasMarkets: true)
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.seededKey)
    }
}
