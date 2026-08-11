import SwiftUI

enum OnboardingStep {
    /// Screens that carry a progress dot. **Every** screen has its own dot
    /// since 2026-08-05 — consent and the tour offer shared dot 6 before,
    /// which made the bar claim one screen less than the flow had.
    ///
    /// **Sechs seit dem 10.08.:** Das Rundgang-Angebot war der siebte, und den
    /// Rundgang gibt es nicht mehr.
    static let total = 6
}

/// Drives the onboarding. Shown by ContentView until `RegionStore.isOnboardingComplete`.
///
/// **Die Profilfragen (Haushalt, Ernährung) sind seit dem 2026-08-05 raus.**
/// Sie saßen nach der PLZ, weil das Registrieren einer Region früher einen
/// minutenlangen Backend-Scrape anstieß und die Fragen die Wartezeit füllten.
/// Den Scrape gibt es seit Migration v16 nicht mehr — übrig blieben fünf
/// Frage-Bildschirme vor dem ersten Zeigen, deren Antworten sichtbar nie
/// etwas änderten. Das Datenmodell bleibt (`UserProfile`); gefragt wird
/// später dort, wo die Antwort etwas ändert.
///
/// An ihrer Stelle: **Ketten liken** (welche Märkte magst du — keine
/// Filialsuche) und ein **Belohnungsschritt**, der mit echten Zahlen aus dem
/// Verzeichnis zeigt, was der Orts-Schritt gebracht hat.
///
/// **Die Filialauswahl steht seit dem 2026-07-31 nicht mehr im Weg.** Sie war
/// der letzte Schritt, und sie war der Schritt, an dem Scott am Gerät hängen
/// blieb: eine lange, gesuchte Liste, bevor man überhaupt gesehen hat, wofür
/// man sie braucht („unübersichtlich", „das nervt").
///
/// **Der Assistent endet seit dem 10.08. in der Einkaufsliste** — dem
/// Bildschirm, für den es die App gibt. Davor lag das Angebot des Rundgangs;
/// mit dem Abriss (Rundgang-Konzept §4) fällt der siebte Schritt weg. Was die
/// App kann, sagt sie jetzt am Ort: vier Einmal-Schilder statt einer Führung.
/// Die Frage nach den Filialen bleibt und hängt jetzt direkt am Abschluss
/// (`MarketPromptStore`) statt am Ende des Rundgangs.
struct OnboardingFlowView: View {
    @Environment(RegionStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(MarketPromptStore.self) private var marketPrompt

    @State private var phase: Phase = .welcome
    /// PLZ currently going through the flow; nil while none was submitted yet.
    @State private var activePLZ: String?
    /// Was der Ketten-Schritt über die Gegend herausbekommen hat — der
    /// Belohnungsschritt zeigt genau diese Zahlen, ohne selbst zu laden.
    @State private var nearby: NearbyMarkets?

    private enum Phase: Equatable {
        case welcome, name, region, chains, payoff, consent

        /// Welcher Punkt leuchtet. Eins zu eins, seit jeder Bildschirm seinen
        /// eigenen Punkt hat — siehe `OnboardingStep.total`.
        ///
        /// Die Zuordnung sitzt hier und nicht mehr im Schritt-Bildschirm: Die
        /// Punkte liegen seit dem 06.08. **außerhalb** des Übergangs, damit sie
        /// beim Schrittwechsel nicht mit verschwinden, und brauchen deshalb
        /// eine Nummer, die der Fluss kennt und der einzelne Schritt nicht.
        var step: Int {
            switch self {
            case .welcome: 1
            case .name: 2
            case .region: 3
            case .chains: 4
            case .payoff: 5
            case .consent: 6
            }
        }
    }

    var body: some View {
        NavigationStack {
            // Der ZStack ist der gemeinsame Behälter, den die Regel braucht:
            // Er bleibt stehen, während die Schritte in ihm einander ablösen,
            // und trägt deshalb die Kurve. Ein `Group` täte es nicht — es
            // reicht Modifikatoren an seine Kinder durch, und die Kurve säße
            // dann an der Ansicht, die gerade verschwindet.
            VStack(spacing: 0) {
                // **Das eine Stück Gerüst, das über die Schritte hinweg lebt.**
                //
                // Es steht bewusst **außerhalb** des Übergangs: Was hier liegt,
                // verschwindet beim Schrittwechsel nicht und kann sich deshalb
                // bewegen, statt neu zu erscheinen. Genau daran hing das
                // Blinzeln — vorher verschwand der ganze Bildschirm, Punkte
                // eingeschlossen, und es gab keinen einzigen ruhenden Halt für
                // das Auge.
                OnboardingProgressDots(step: phase.step, totalSteps: OnboardingStep.total)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .readableWidth()

                ZStack {
                    content
                        .stateTransition(.screen)
                }
                .stateAnimation(.screen, value: phase)
            }
            .background { Theme.background.ignoresSafeArea() }
        }
        .onAppear(perform: resume)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .welcome:
            WelcomeStepView { phase = .name }
        case .name:
            NameStepView { phase = .region }
        case .region:
            RegionSetupView(step: 3) { plz in
                activePLZ = plz
                phase = .chains
            }
        case .chains:
            ChainLikingStepView(plz: currentPLZ) { found in
                nearby = found
                phase = .payoff
            }
        case .payoff:
            PayoffStepView(
                plz: currentPLZ,
                nearby: nearby,
                likedCount: profile.likedChains.count
            ) { phase = .consent }
        case .consent:
            ConsentStepView {
                profile.markQuestionsCompleted()
                let plz = currentPLZ
                Task { await profile.sync(plz: plz) }
                finishOnboarding()
            }
        }
    }

    private var currentPLZ: String? {
        activePLZ ?? store.orderedReadyRegions.first
    }

    /// The only place that records onboarding as done.
    ///
    /// **Ohne Filiale.** Bis zum 2026-07-31 kam man hier nur mit einer an, weil
    /// das „Fertig" des Pickers bis dahin gesperrt war; jetzt ist die Liste der
    /// erste Bildschirm und die Filialen werden dort gewählt. Der zweite
    /// Profil-Upload bleibt trotzdem stehen: Wer die Frage danach mit Ja
    /// beantwortet, hat Filialen, und einen Upload aus der Filialauswahl heraus
    /// gibt es nicht — die Spalte aus Migration v15 füllt sich beim nächsten
    /// Start.
    ///
    /// **Hier hängt seit dem 10.08. die Frage nach den Filialen.** Sie hing
    /// vorher am Ende des Rundgangs und am „Später" seines Angebots; beide
    /// Türen sind mit ihm weg, die Frage nicht — ohne Filiale kann die App
    /// nichts vergleichen.
    private func finishOnboarding() {
        store.completeOnboarding()
        marketPrompt.onboardingFinished(hasMarkets: store.hasFavorites)
        guard let plz = currentPLZ else { return }
        store.selectRegion(plz)
        let branchIds = store.favoriteMarkets.map(\.marketId)
        Task { await profile.sync(plz: plz, branchIds: branchIds) }
    }

    /// Picks up where the user left off: they got through the consent step
    /// before (`hasCompletedQuestions` — der Name stammt aus der Zeit der
    /// Profilfragen, gesetzt wird er unverändert am Einwilligungsschritt).
    /// Ohne Region fehlt der Ort und der Rest des Wegs läuft ab dort noch
    /// einmal; sonst ist der Assistent an dieser Stelle schlicht fertig — auf
    /// keinen Fall wieder ganz von vorn. Die gemerkten Ketten überleben beides,
    /// sie liegen im `ProfileStore`.
    private func resume() {
        guard profile.profile.hasCompletedQuestions else { return }
        guard !store.orderedReadyRegions.isEmpty else {
            phase = .region
            return
        }
        finishOnboarding()
    }
}

#Preview {
    OnboardingFlowView()
        .environment(RegionStore())
        .environment(ProfileStore())
        .environment(MarketPromptStore())
}
