import SwiftUI

@main
struct SmartshopApp: App {
    @State private var store: RegionStore
    private let marketRepository: MarketRepositoryProtocol

    init() {
        // Product thumbnails load via AsyncImage/URLCache; the storage URLs are
        // content-addressed, so a generous cache is safe and avoids re-fetches.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )

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
