import Foundation
import Observation

/// Die Frage nach den Filialen am Ende des Onboardings — und sonst nichts.
///
/// **Das ist der Rest des `TutorialStore`.** Er führte bis zum 10.08. den
/// Rundgang; mit dem Abriss (Rundgang-Konzept §4) bleibt genau die eine
/// Aufgabe übrig, die nie zum Rundgang gehörte: Wer aus dem Assistenten ohne
/// gewählte Filiale herauskommt, steht vor einer Liste, die nichts vergleichen
/// kann. Die Frage hing früher am Ende des Rundgangs und am „Später" seines
/// Angebots — beide Türen gibt es nicht mehr, die Frage schon.
///
/// **Die Marktauswahl ist kein Tipp, sondern eine Voraussetzung** (§6): Ohne
/// Filiale kann die App nichts vergleichen. Deshalb steht sie hier als eigener
/// Schritt und nicht als eines der vier Schilder.
///
/// **Der Schlüssel behält seinen alten Namen.** `tutorial.marketPrompt.answered`
/// liegt auf jedem Gerät, das die App schon hat; ihn umzubenennen hieße, allen
/// die Frage ein zweites Mal zu stellen — für nichts als einen hübscheren
/// String auf Platte.
@MainActor
@Observable
final class MarketPromptStore {
    /// Das Markt-Sheet steht an: Der Assistent ist durch und es gibt keine
    /// Filiale.
    private(set) var asksForMarkets = false

    /// Das Markt-Sheet wurde schon einmal gezeigt und beantwortet — egal wie.
    /// Überlebt Neustarts: Ein Hinweis, der bei jeder Gelegenheit wiederkommt,
    /// ist keine Hilfe, sondern eine Mahnung.
    private(set) var hasAnsweredMarketPrompt: Bool

    private let defaults: UserDefaults
    private static let answeredKey = "tutorial.marketPrompt.answered"

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        self.hasAnsweredMarketPrompt = defaults.bool(forKey: Self.answeredKey)
    }

    /// Der Assistent ist fertig. Ohne Filiale wird gefragt — einmal.
    func onboardingFinished(hasMarkets: Bool) {
        asksForMarkets = !hasMarkets && !hasAnsweredMarketPrompt
    }

    /// Die Frage ist beantwortet — egal wie: „Märkte wählen", „Später" oder
    /// weggewischt. Der Merker überlebt Neustarts, denn das Sheet ist ein
    /// Angebot und keine Mahnung — einmal gezeigt, danach bleiben der
    /// Leerzustand der Liste und die Einstellungen als Wege.
    func dismissMarketQuestion() {
        asksForMarkets = false
        guard !hasAnsweredMarketPrompt else { return }
        hasAnsweredMarketPrompt = true
        defaults.set(true, forKey: Self.answeredKey)
    }

    /// Siehe `AppReset`. Schlüssel nach der Zuweisung entfernen, sonst
    /// schreibt ihn der nächste Lauf sofort zurück.
    func resetAllData() {
        asksForMarkets = false
        hasAnsweredMarketPrompt = false
        defaults.removeObject(forKey: Self.answeredKey)
    }
}
