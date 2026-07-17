import SwiftUI

@main
struct SmartshopApp: App {
    @State private var store: RegionStore
    private let marketRepository: MarketRepositoryProtocol

    init() {
        // Fall back to mocks when APIKeys.plist is absent (e.g. CI simulator builds).
        if let client = SupabaseClient.fromConfig() {
            _store = State(initialValue: RegionStore(repository: LiveRegionRepository(client: client)))
            marketRepository = LiveMarketRepository(client: client)
        } else {
            _store = State(initialValue: RegionStore(repository: MockRegionRepository()))
            marketRepository = MockMarketRepository()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(marketRepository: marketRepository)
                .environment(store)
        }
    }
}
