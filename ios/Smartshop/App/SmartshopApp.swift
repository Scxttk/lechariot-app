import SwiftUI

@main
struct SmartshopApp: App {
    @State private var store: RegionStore
    @State private var profile: ProfileStore
    @AppStorage(Theme.appearanceKey) private var appearance: AppAppearance = .system
    private let marketRepository: MarketRepositoryProtocol

    init() {
        #if DEBUG
        // Before the stores below read UserDefaults for the first time.
        UITestSupport.prepareCleanLaunchIfNeeded()
        #endif

        // Product thumbnails load via AsyncImage/URLCache; the storage URLs are
        // content-addressed, so a generous cache is safe and avoids re-fetches.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )

        _store = State(initialValue: RegionStore(repository: AppRepositories.regions()))
        _profile = State(initialValue: ProfileStore(repository: AppRepositories.profiles()))
        marketRepository = AppRepositories.markets()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(marketRepository: marketRepository)
                .environment(store)
                .environment(profile)
                // App-wide accent, so onboarding matches the tabs instead of
                // falling back to system blue.
                .tint(Theme.accent)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
