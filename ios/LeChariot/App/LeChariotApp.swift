import SwiftUI

@main
struct LeChariotApp: App {
    @State private var store: RegionStore
    @State private var profile: ProfileStore
    @State private var areaRequests: AreaRequestStore
    @AppStorage(Theme.appearanceKey, store: AppDefaults.shared)
    private var appearance: AppAppearance = .system
    private let marketRepository: MarketRepositoryProtocol

    init() {
        // Product thumbnails load via AsyncImage/URLCache; the storage URLs are
        // content-addressed, so a generous cache is safe and avoids re-fetches.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )

        _store = State(initialValue: RegionStore(repository: AppRepositories.regions()))
        _profile = State(initialValue: ProfileStore(repository: AppRepositories.profiles()))
        _areaRequests = State(
            initialValue: AreaRequestStore(repository: AppRepositories.areaRequests())
        )
        marketRepository = AppRepositories.markets()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(marketRepository: marketRepository)
                .environment(store)
                .environment(profile)
                .environment(areaRequests)
                // Beim Start und bei jeder Rückkehr prüfen, ob ein
                // angefordertes Gebiet inzwischen fertig ist. Der Lauf dauert
                // ~3 Minuten und überlebt die App — ohne diese Frage erführe
                // niemand, dass jetzt mehr zur Auswahl steht.
                .task { await areaRequests.checkPendingArea() }
                // App-wide accent, so onboarding matches the tabs instead of
                // falling back to system blue.
                .tint(Theme.accent)
                // Not `preferredColorScheme` — that flips content and bars in
                // separate steps. See `AppearanceWindowBridge`.
                .appearanceOverride(appearance)
        }
    }
}
