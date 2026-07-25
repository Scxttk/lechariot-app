import SwiftUI

enum OnboardingStep {
    /// Screens that carry a progress dot. The branch picker closes the flow and
    /// is deliberately not counted — it is a searchable list, not a question.
    static let total = 6
}

/// Drives the onboarding. Shown by ContentView until `RegionStore.isOnboardingComplete`.
///
/// The profile questions sit *after* the PLZ on purpose: registering a new
/// region kicks off a backend scrape that takes minutes, and `RegionStore`
/// polls it in its own task regardless of what is on screen. So the questions
/// fill that time, and by the time the user reaches the branch picker the sync
/// has usually finished — instead of staring at a spinner first and answering
/// questions afterwards.
struct OnboardingFlowView: View {
    @Environment(RegionStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    let marketRepository: MarketRepositoryProtocol
    /// Follows a request for a store the backend has never fetched. Created
    /// here so it outlives a single picker appearance.
    @State private var branchRequests = BranchRequestStore(
        repository: AppRepositories.branchRequests()
    )

    @State private var phase: Phase = .welcome
    /// PLZ currently going through the flow; nil while none was submitted yet.
    @State private var activePLZ: String?

    private enum Phase {
        case welcome, name, region, household, diet, consent, markets
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
        }
    }

    /// Final phase: the branches. If the backend is still scraping we show the
    /// waiting screen here — by now it usually is not.
    @ViewBuilder
    private var marketsPhase: some View {
        if let plz = currentPLZ {
            switch store.syncState(for: plz) {
            case .ready:
                MarketPickerView(
                    plz: plz,
                    marketRepository: marketRepository,
                    branchRequests: branchRequests
                ) {
                    store.selectRegion(plz)
                    // The only place that records onboarding as done. "Fertig"
                    // is disabled until a branch is picked, so reaching here
                    // always means a usable setup.
                    store.completeOnboarding()
                    // Second sync, now that the branches are known. The consent
                    // step runs BEFORE the picker, so the first upload can only
                    // ever carry an empty branch list — without this the column
                    // added in migration v15 would stay empty for everyone.
                    let branchIds = store.favoriteMarkets.map(\.marketId)
                    Task { await profile.sync(plz: plz, branchIds: branchIds) }
                }
            case .requested, .syncing, .failed:
                WaitingView(plz: plz) {
                    store.removeRegion(plz)
                    activePLZ = nil
                    phase = .region
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
        .environment(RegionStore(repository: MockRegionRepository()))
        .environment(ProfileStore())
}
