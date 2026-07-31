import SwiftUI

enum OnboardingStep {
    /// Screens that carry a progress dot. The branch picker closes the flow and
    /// is deliberately not counted — it is a searchable list, not a question.
    static let total = 6
}

/// Drives the onboarding. Shown by ContentView until `RegionStore.isOnboardingComplete`.
///
/// The profile questions sit *after* the PLZ because registering a region used
/// to kick off a backend scrape of several minutes, and the questions filled
/// the wait. Since the postcode became a mere location there is nothing to wait
/// for, but the order stayed: the picker is the one screen that needs a
/// decision, and it reads better last.
struct OnboardingFlowView: View {
    @Environment(RegionStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(TutorialStore.self) private var tutorial
    let marketRepository: MarketRepositoryProtocol

    @State private var phase: Phase = .welcome
    /// PLZ currently going through the flow; nil while none was submitted yet.
    @State private var activePLZ: String?

    private enum Phase {
        case welcome, name, region, household, diet, consent, markets, tour
    }

    var body: some View {
        NavigationStack {
            content
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
                phase = .markets
            }
        case .markets:
            marketsPhase
        case .tour:
            TourStepView {
                // Erst starten, dann abschließen: Beides passiert in derselben
                // Aktualisierung, die Tabs erscheinen also schon mit dem
                // Rundgang darüber.
                tutorial.start()
                finishOnboarding()
            } onSkip: {
                tutorial.decline()
                finishOnboarding()
            }
        }
    }

    /// Final phase: the branches.
    @ViewBuilder
    private var marketsPhase: some View {
        if let plz = currentPLZ {
            switch store.syncState(for: plz) {
            case .ready:
                MarketPickerView(
                    plz: plz,
                    marketRepository: marketRepository
                ) {
                    store.selectRegion(plz)
                    // Der Rundgang wird angeboten, bevor abgeschlossen wird —
                    // sonst stünde das Angebot schon über der fertigen App.
                    if offersTour {
                        phase = .tour
                    } else {
                        finishOnboarding()
                    }
                }
            case .unknown:
                RegionSetupView(step: 3) { plz in
                    activePLZ = plz
                    phase = .markets
                }
            }
        } else {
            RegionSetupView(step: 3) { plz in
                activePLZ = plz
                phase = .markets
            }
        }
    }

    private var currentPLZ: String? {
        activePLZ ?? store.orderedReadyRegions.first
    }

    /// The only place that records onboarding as done. The picker's "Fertig" is
    /// disabled until a branch is picked, so reaching here always means a usable
    /// setup — the tour screen in between only adds a question, never a state.
    private func finishOnboarding() {
        store.completeOnboarding()
        guard let plz = currentPLZ else { return }
        // Second sync, now that the branches are known. The consent step runs
        // BEFORE the picker, so the first upload can only ever carry an empty
        // branch list — without this the column added in migration v15 would
        // stay empty for everyone.
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

    /// Picks up where the user left off. Two cases matter: they answered the
    /// questions before but never finished picking branches, and they later
    /// removed their last branch in Settings — both resume at the picker
    /// instead of asking for a name and a PLZ all over again.
    private func resume() {
        guard profile.profile.hasCompletedQuestions else { return }
        phase = store.orderedReadyRegions.isEmpty ? .region : .markets
    }
}

#Preview {
    OnboardingFlowView(marketRepository: MockMarketRepository())
        .environment(RegionStore())
        .environment(ProfileStore())
        .environment(TutorialStore())
}
