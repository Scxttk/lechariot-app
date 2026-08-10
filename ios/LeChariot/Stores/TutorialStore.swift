import Foundation
import Observation
import UIKit

// MARK: - Steps

/// Which tab a frame plays on. The overlay lives above the `TabView`, so the
/// tour has to say where it wants to be — `ContentView` owns the actual tab.
enum TutorialTab {
    case liste, angebote, einstellungen
}

/// One frame of the tour: what is highlighted, what is said, and what the user
/// has to do to get past it.
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
        /// **Kein Loch.** Nur die Schlusskarte hat das, und auch nur in der
        /// Fassung ohne Filialen: Sie leuchtet nichts aus, sie verabschiedet.
        /// Vom Selbst-Überspringen sind Rahmen zum Lesen ohnehin ausgenommen —
        /// die Ausnahme hängt am `deed`, nicht hier, siehe
        /// `TutorialOverlay.skipIfNothingToShow`.
        case nothing
    }

    /// **Was der Nutzer tun muss, damit der Rahmen weitergeht** (09.08.).
    ///
    /// Das ist der Prinzipwechsel aus Scotts Bedienrunde vom 08.08., Punkt A:
    /// „the app only highlights where to click and why and the user clicks
    /// through it by himself so he'll remember better whats doable." Bis hierher
    /// war jeder Rahmen ein Text mit einem „Weiter"-Knopf; wer dreimal auf
    /// „Weiter" tippte, hatte den Rundgang gesehen, ohne die App einmal
    /// angefasst zu haben. **Jetzt gibt es „Weiter" nicht mehr** — der Rahmen
    /// geht weiter, wenn die Handlung passiert ist, und sonst gar nicht. Der
    /// einzige andere Ausgang bleibt „Tour beenden".
    ///
    /// **Das dreht die Regel vom 2026-07-30 um, und zwar bewusst.** Damals
    /// trugen zwei Rahmen `advance: .itemAdded` und sprangen, sobald ein Artikel
    /// auf der Liste landete; Scotts Bruder meldete „der erste Punkt ist
    /// automatisch und zu schnell". Der Fehler war aber nicht das Weiterschalten
    /// durch eine Handlung, sondern dass es **daneben** noch einen zweiten Weg
    /// gab: Wer den Vorschlag antippte, während er den Text noch las, wurde
    /// mitten im Satz weitergeschoben, ohne es gewollt zu haben. Jetzt ist die
    /// Handlung der einzige Weg und im Text angesagt — dann ist das
    /// Weiterschalten die Antwort auf etwas, das man gerade absichtlich getan
    /// hat, und keine Überraschung.
    enum Deed: Equatable {
        /// Nur lesen; der Knopf beendet den Rundgang. Genau **einmal** je
        /// Fassung, als Schlusskarte.
        case reads
        /// Ein Artikel steht auf der Liste, der vorher nicht dort stand.
        case addsItem
        /// Ein Artikel ist abgehakt.
        case checksItem
        /// Der Angebote-Tab steht.
        case opensOffersTab
        /// Die Vorschau „Nächste Woche" steht.
        case opensNextWeek
    }

    let id: String
    let title: String
    let text: String
    let spotlight: Spotlight
    let deed: Deed
    var tab: TutorialTab = .liste

    /// Berührungen erreichen das hervorgehobene Element. Alles außerhalb des
    /// Lochs bleibt tot — das ist der Zweck der Übung.
    ///
    /// Kein eigenes Feld mehr: Ein Rahmen, der auf eine Handlung wartet, **muss**
    /// sie zulassen, sonst ist er eine Sackgasse. Nur die Schlusskarte hat
    /// nichts durchzulassen.
    var allowsInteraction: Bool { deed != .reads }

    /// Der Rundgang legt die Eingabe-Schicht weg, bevor dieser Rahmen kommt.
    ///
    /// Nach dem Anlegen eines Artikels stehen Tastatur und Angaben-Schicht;
    /// zusammen sind das seit dem 08.08. rund zwei Drittel des Bildschirms
    /// (Bring!s Aufteilung, Punkt C). Die Tab-Leiste liegt dann unter der
    /// Tastatur, und ein Rahmen, der auf einen Tipp darauf wartet, wartet für
    /// immer.
    ///
    /// Deshalb gilt es für **alles außer dem ersten Rahmen**: Wer aufschreibt,
    /// braucht die Tastatur; wer danach etwas antippen soll, braucht den
    /// Bildschirm.
    ///
    /// **Eine Vermutung, die hier stand und falsch war, gehört mit hierher:**
    /// Als der Vorschläge-Rahmen sich still übersprang, sah es aus, als fehle
    /// der Winkel-Knopf während des Tipp-Flusses. Er ist die ganze Zeit da —
    /// der Grund war ein verschluckter Anker (siehe `TutorialAnchor`). Für
    /// diesen Rahmen ist das Wegräumen deshalb kein Muss, für den Rahmen zur
    /// Tab-Leiste schon; einheitlich bleibt es trotzdem, weil „wer etwas
    /// antippen soll, braucht den Bildschirm" die einfachere Regel ist als eine
    /// Ausnahmeliste.
    var clearsInputFlow: Bool {
        switch deed {
        case .addsItem, .reads: false
        default: true
        }
    }

    /// **Der Rundgang zum Mitmachen** (09.08.) — fünf Handgriffe und eine
    /// Schlusskarte, mit Filialen; ohne sie drei und die Schlusskarte.
    ///
    /// Die Geschichte davor in zwei Sätzen: Am 03.08. wuchs der Rundgang auf
    /// neun Rahmen, weil er „der App hinterherhinkte"; am 06.08. schrumpfte er
    /// auf drei, weil ein Rahmen, der zeigt, was ohnehin auf dem Bildschirm
    /// steht, nur Zeit kostet. **Beide Male ging es darum, wie viel *vorgeführt*
    /// wird.** Scotts Auftrag vom 08.08. wechselt die Achse: Vorgeführt wird gar
    /// nichts mehr, die App hebt hervor und sagt warum, und **der Nutzer tippt
    /// selbst** (siehe `Deed`).
    ///
    /// **Die Lehre vom 06.08. bleibt trotzdem stehen und ist der Grund, warum
    /// hier nicht mehr steht.** Der Plan-Rahmen ist ersatzlos weg: Er zeigte auf
    /// eine Karte, die der Rundgang sich mit drei geliehenen Artikeln selbst
    /// hinlegen musste. Jetzt legt der Nutzer im ersten Rahmen seinen eigenen
    /// Artikel an, die Karte erscheint darüber als Folge davon — der Satz dazu
    /// steht in Rahmen 1. Was man durch die eigene Handlung entstehen sieht,
    /// braucht keinen eigenen Rahmen.
    ///
    /// **Eine Stelle kommt dazu, aus Scotts Liste** (Bedienrunde 08.08., Punkt
    /// A): die Vorschau „Nächste Woche" samt der Hinweiszeile aus #90 — ein
    /// Weg, den niemand von allein geht.
    ///
    /// **Der Rahmen zum Vorschläge-Menü ist am 10.08. ersatzlos ausgefallen.**
    /// Er zeigte auf den Winkel-Knopf („Hinter dem Winkel liegen deine
    /// Vorschläge"), und den gibt es nicht mehr: Seit Punkt E steht die
    /// Vorschlagsfläche von selbst da, sobald die Tastatur kommt. Ein Rahmen,
    /// der auf ein Ziel wartet, das es nicht gibt, überspringt sich selbst —
    /// genau der Fehler, den Scott am Rundgang meldet (Punkt F-1). Was der
    /// Rundgang stattdessen zeigen soll — Marktauswahl, Angebote nächster
    /// Woche, was Tippen tut, was **Halten** tut —, steht in Punkt F und ist
    /// ein eigenes Arbeitspaket; hier bleibt vorerst der kürzere Rundgang.
    ///
    /// **Fünf Rahmen, und das ist jetzt die Zahl aus der Onboarding-Forschung.**
    /// Sie kam aus Touren zum *Lesen*; hier ist jeder Rahmen ein Tipp, und der
    /// letzte ist der Abschied. Wer abbrechen will, hat auf jedem Rahmen „Tour
    /// beenden".
    ///
    /// `hasMarkets` streicht die zwei Angebote-Rahmen, statt nur ihren Text zu
    /// drehen: Ohne gewählte Filiale steht auf dem Angebote-Tab „Keine Filiale
    /// gewählt" und es gibt weder Liste noch Vorschau-Knopf. Ein Rahmen, der auf
    /// einen Tipp wartet, den man nicht tun kann, ist eine Sackgasse — und der
    /// Normalfall nach dem Onboarding ist genau dieser, seit es seit dem
    /// 2026-07-31 in der Liste endet statt in der Filialauswahl.
    ///
    /// `showsNextWeek` hängt am Schalter, nicht am Geschmack: Ohne die Vorschau
    /// gibt es den Knopf „Nächste Woche" nicht, und dann fällt mit ihm auch der
    /// Rahmen zur Tab-Leiste weg — er ist der **Weg** dorthin, und ein Weg zu
    /// nichts ist ein Rahmen, der zeigt, was man ohnehin sieht. Als Parameter
    /// mit Vorgabe, damit die Zusicherungen beide Fassungen prüfen können, ohne
    /// am globalen Schalter zu drehen.
    static func tour(hasMarkets: Bool,
                     showsNextWeek: Bool = FeatureFlags.nextWeekPreview) -> [TutorialStep] {
        var steps: [TutorialStep] = [
            TutorialStep(
                id: "input",
                title: "Schreib deinen ersten Artikel auf",
                text: hasMarkets
                    ? "Tipp ins Feld und leg einen Artikel an — oben steht dann, welche deiner Filialen ihn am günstigsten hat."
                    : "Tipp ins Feld und leg einen Artikel an.",
                spotlight: .anchor(.inputBar),
                deed: .addsItem
            ),
            TutorialStep(
                id: "check",
                title: "Im Laden abhaken",
                text: "Tipp die Kachel an — der Artikel wandert nach unten zu „Erledigt“.",
                spotlight: .anchor(.rowCheck),
                deed: .checksItem
            ),
        ]

        guard hasMarkets, showsNextWeek else {
            steps.append(
                TutorialStep(
                    id: "done",
                    title: "Das war’s",
                    text: hasMarkets
                        ? "Den Rundgang findest du jederzeit wieder unter „Einstellungen“."
                        : "Angebote siehst du, sobald du eine Filiale gewählt hast. Den Rundgang findest du jederzeit unter „Einstellungen“.",
                    spotlight: .nothing,
                    deed: .reads
                )
            )
            return steps
        }

        steps.append(contentsOf: [
            TutorialStep(
                id: "offers",
                title: "Alle Angebote deiner Filialen",
                text: "Tipp unten auf „Angebote“.",
                spotlight: .tabBar,
                deed: .opensOffersTab
            ),
            TutorialStep(
                id: "nextWeek",
                title: "Schon nächste Woche sehen",
                text: "Oben links liegt die Vorschau. Tipp auf „Nächste Woche“.",
                spotlight: .navBar,
                deed: .opensNextWeek,
                tab: .angebote
            ),
            // **Die Karte sagt nicht noch einmal, was in der Zeile steht.** Der
            // erste Entwurf tat genau das („Diese Preise gelten noch nicht.
            // Sie zeigen, was demnächst günstig wird …") — und war damit
            // derselbe Fehler, der beim alten Rahmen 1 als „ugly" auffiel: Text
            // über Text, einmal hell, einmal abgedunkelt. Seit #90 sagt die
            // Zeile es selbst und laut; die Karte zeigt nur hin und
            // verabschiedet sich.
            TutorialStep(
                id: "done",
                title: "Das war’s",
                text: "Lies die getönte Zeile oben — dann weißt du, woran du bei diesen Preisen bist. Den Rundgang findest du wieder unter „Einstellungen“.",
                spotlight: .anchor(.nextWeekNotice),
                deed: .reads,
                tab: .angebote
            ),
        ])
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

    /// Was ein **alter** Rundgang auf die Liste gelegt hat. Kommt beim nächsten
    /// Start wieder herunter; gelegt wird seit dem 09.08. nichts mehr, siehe
    /// `removeDemoItems`.
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

    /// **Der Nutzer hat etwas getan — geht der Rahmen davon weiter?**
    ///
    /// Die eine Stelle, an der der Rundgang weiterschaltet, seit es „Weiter"
    /// nicht mehr gibt. Die Melder sitzen dort, wo die Handlung wirklich
    /// passiert (`TutorialOverlay` für die Liste, `ContentView` für den Tab,
    /// `ShoppingListView` für die Vorschläge, `NextWeekView` für die Vorschau)
    /// und melden **immer**, ob der Rundgang läuft oder nicht — die Entscheidung
    /// steht hier und nicht siebenmal am Rand.
    ///
    /// Der Vergleich ist absichtlich stur auf den *aktuellen* Rahmen: Wer im
    /// dritten Rahmen einen weiteren Artikel anlegt, hat den ersten nicht noch
    /// einmal erledigt.
    func report(_ deed: TutorialStep.Deed) {
        guard isRunning, step.deed == deed else { return }
        next()
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

    // MARK: Beispiel-Artikel — nur noch das Aufräumen

    /// **Gesät wird seit dem 09.08. nichts mehr.** Der Rundgang legte bis dahin
    /// Milch, Butter und Kaffee selbst auf die Liste, weil der Plan-Rahmen sonst
    /// auf einen Leerzustand gezeigt hätte. Mit dem Rundgang zum Mitmachen legt
    /// der Nutzer seinen eigenen Artikel an; damit sind geliehene Artikel, ihre
    /// Persistenz und ihr Abräumen ersatzlos weg.
    ///
    /// **Was bleibt, ist der Rückweg für bestehende Installationen:** Wer den
    /// alten Rundgang mitten im Lauf abgeschossen hat, hat seine drei Artikel
    /// noch auf Platte. `init` liest sie, `ContentView` räumt sie beim nächsten
    /// Start ab — sonst stünden sie dort für immer, und niemand wüsste warum.
    /// Diese Hälfte fällt weg, wenn kein Gerät sie mehr trägt.
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
