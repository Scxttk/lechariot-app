import SwiftUI

/// Drives the onboarding steps: PLZ setup → waiting for sync → market picker.
/// Shown by ContentView until `RegionStore.isOnboardingComplete`.
struct OnboardingFlowView: View {
    @Environment(RegionStore.self) private var store
    let marketRepository: MarketRepositoryProtocol

    /// PLZ currently going through the flow; nil while none was submitted yet.
    @State private var activePLZ: String?

    var body: some View {
        NavigationStack {
            Group {
                // Re-entry case: the user removed their last Wunschmarkt in
                // Settings but still has a ready region — resume at the market
                // picker instead of asking for the PLZ again.
                if let plz = activePLZ ?? store.orderedReadyRegions.first {
                    switch store.syncState(for: plz) {
                    case .ready:
                        MarketPickerView(plz: plz, marketRepository: marketRepository) {
                            store.selectRegion(plz)
                        }
                    case .requested, .syncing, .failed:
                        WaitingView(plz: plz) {
                            store.removeRegion(plz)
                            activePLZ = nil
                        }
                    case .unknown:
                        RegionSetupView { activePLZ = $0 }
                    }
                } else {
                    RegionSetupView { activePLZ = $0 }
                }
            }
        }
    }
}

#Preview {
    OnboardingFlowView(marketRepository: MockMarketRepository())
        .environment(RegionStore(repository: MockRegionRepository()))
}
