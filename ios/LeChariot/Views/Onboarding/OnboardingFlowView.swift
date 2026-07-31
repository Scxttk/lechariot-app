import SwiftUI

enum OnboardingStep {
    /// Screens that carry a progress dot.
    static let total = 6
}

/// Drives the onboarding. Shown by ContentView until `RegionStore.isOnboardingComplete`.
///
/// The profile questions sit *after* the PLZ because registering a region used
/// to kick off a backend scrape of several minutes, and the questions filled
/// the wait. Since the postcode became a mere location there is nothing to wait
/// for, but the order stayed.
///
/// **Die Filialauswahl steht seit dem 2026-07-31 nicht mehr im Weg.** Sie war
/// der letzte Schritt, und sie war der Schritt, an dem Scott am Gerät hängen
/// blieb: eine lange, gesuchte Liste, bevor man überhaupt gesehen hat, wofür
/// man sie braucht („unübersichtlich", „das nervt"). Der Assistent endet jetzt
/// mit dem Angebot des Rundgangs und danach in der Einkaufsliste — dem
/// Bildschirm, für den es die App gibt. Der Rundgang zeigt unterwegs, wo
/// Filialen herkommen, und fragt am Ende danach.
struct OnboardingFlowView: View {
    @Environment(RegionStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(TutorialStore.self) private var tutorial
    let marketRepository: MarketRepositoryProtocol

    @State private var phase: Phase = .welcome
    /// PLZ currently going through the flow; nil while none was submitted yet.
    @State private var activePLZ: String?

    private enum Phase: Equatable {
        case welcome, name, region, household, diet, consent, tour
    }

    var body: some View {
        NavigationStack {
            // Der ZStack ist der gemeinsame Behälter, den die Regel braucht:
            // Er bleibt stehen, während die Schritte in ihm einander ablösen,
            // und trägt deshalb die Kurve. Ein `Group` täte es nicht — es
            // reicht Modifikatoren an seine Kinder durch, und die Kurve säße
            // dann an der Ansicht, die gerade verschwindet.
            ZStack {
                content
                    .stateTransition(.screen)
            }
            .stateAnimation(.screen, value: phase)
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
                phase = .household
            }
        case .household:
            HouseholdStepView { phase = .diet }
        case .diet:
            DietStepView { phase = .consent }
        case .consent:
            ConsentStepView {
                profile.markQuestionsCompleted()
                let plz = currentPLZ
                Task { await profile.sync(plz: plz) }
                // Der Rundgang wird angeboten, bevor abgeschlossen wird —
                // sonst stünde das Angebot schon über der fertigen App.
                if offersTour {
                    phase = .tour
                } else {
                    finishOnboarding()
                }
            }
        case .tour:
            TourStepView {
                // Erst starten, dann abschließen: Beides passiert in derselben
                // Aktualisierung, die Tabs erscheinen also schon mit dem
                // Rundgang darüber.
                tutorial.start(origin: .onboarding, hasMarkets: store.hasFavorites)
                finishOnboarding()
            } onSkip: {
                tutorial.decline()
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
    /// Profil-Upload bleibt trotzdem stehen: Wer die Frage am Ende des
    /// Rundgangs mit Ja beantwortet, hat danach Filialen, und der Upload aus
    /// der Filialauswahl heraus gibt es nicht — die Spalte aus Migration v15
    /// füllt sich beim nächsten Start.
    private func finishOnboarding() {
        store.completeOnboarding()
        guard let plz = currentPLZ else { return }
        store.selectRegion(plz)
        let branchIds = store.favoriteMarkets.map(\.marketId)
        Task { await profile.sync(plz: plz, branchIds: branchIds) }
    }

    /// Der Rundgang wird angeboten — außer in UI-Läufen, die ihn nicht meinen.
    ///
    /// Er hängt einen Bildschirm ans Onboarding und sperrt danach die Liste
    /// hinter Sperrflächen; jede bestehende Journey würde daran hängenbleiben,
    /// ohne dass an ihr etwas kaputt wäre. Wer ihn prüfen will, startet mit
    /// `-uiTestingTutorial`.
    private var offersTour: Bool {
        #if DEBUG
        if UITestSupport.isActive { return UITestSupport.showsTutorial }
        #endif
        return true
    }

    /// Picks up where the user left off: they answered the questions before but
    /// never got past the tour offer. Ohne Region fehlt der Ort, sonst steht
    /// nur noch das Angebot aus — auf keinen Fall wieder Name und PLZ.
    private func resume() {
        guard profile.profile.hasCompletedQuestions else { return }
        guard !store.orderedReadyRegions.isEmpty else {
            phase = .region
            return
        }
        // Ohne Rundgang-Angebot (UI-Läufe) gäbe es nichts mehr zu zeigen — dann
        // ist der Assistent an dieser Stelle schlicht fertig.
        if offersTour { phase = .tour } else { finishOnboarding() }
    }
}

#Preview {
    OnboardingFlowView(marketRepository: MockMarketRepository())
        .environment(RegionStore())
        .environment(ProfileStore())
        .environment(TutorialStore())
}
