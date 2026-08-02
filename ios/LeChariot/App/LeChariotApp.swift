import SwiftUI

@main
struct LeChariotApp: App {
    @State private var store: RegionStore
    @State private var profile: ProfileStore
    @State private var areaRequests: AreaRequestStore
    @State private var branchRequests: BranchRequestStore
    @State private var history = PurchaseHistoryStore()
    @State private var placeNames = PlaceNameStore()
    @AppStorage(Theme.appearanceKey, store: AppDefaults.shared)
    private var appearance: AppAppearance = .system
    @Environment(\.scenePhase) private var scenePhase
    private let marketRepository: MarketRepositoryProtocol

    init() {
        // Product thumbnails load via AsyncImage/URLCache; the storage URLs are
        // content-addressed, so a generous cache is safe and avoids re-fetches.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )

        let regionStore = RegionStore()
        let profileStore = ProfileStore(repository: AppRepositories.profiles())
        #if DEBUG
        // `-uiTestingOnboarded`: hinter dem Assistenten anfangen. Hier und
        // nicht in einer Ansicht, weil der Zustand stehen muss, bevor der erste
        // `body` entscheidet, ob er das Onboarding zeigt.
        UITestSupport.seedOnboardedState(regions: regionStore, profile: profileStore)
        #endif
        _store = State(initialValue: regionStore)
        _profile = State(initialValue: profileStore)
        _areaRequests = State(
            initialValue: AreaRequestStore(repository: AppRepositories.areaRequests())
        )
        _branchRequests = State(
            initialValue: BranchRequestStore(repository: AppRepositories.branchRequests())
        )
        marketRepository = AppRepositories.markets()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(marketRepository: marketRepository)
                .environment(store)
                .environment(profile)
                .environment(areaRequests)
                .environment(branchRequests)
                .environment(history)
                .environment(placeNames)
                // Beim Start und bei jeder Rückkehr prüfen, ob ein
                // angefordertes Gebiet inzwischen fertig ist. Der Lauf dauert
                // ~3 Minuten und überlebt die App — ohne diese Frage erführe
                // niemand, dass jetzt mehr zur Auswahl steht.
                .task { await areaRequests.checkPendingArea() }
                // Und dieselbe Frage eine Ebene tiefer, je gewählter Filiale.
                // Das holt auch die nach, die über die Einstellungen gewählt
                // wurden und deshalb nie eine Anforderung ausgelöst haben.
                .task {
                    await branchRequests.checkPendingBranches(
                        for: store.favoriteMarkets.map(\.marketId)
                    )
                }
                // **„Bei jeder Rückkehr" stand bis zum 02.08. nur im
                // Kommentar.** `.task` läuft genau einmal je Ansichtsleben —
                // wer die App währenddessen zur Seite legt (und das tut man
                // bei einem Lauf, der Minuten dauert, zwangsläufig), kam
                // zurück auf denselben leeren Bildschirm, den er verlassen
                // hatte. Die Abfrage kostet zwei GETs; der stille Stillstand
                // hat einen Feldtest gekostet.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await areaRequests.checkPendingArea() }
                    Task {
                        await branchRequests.checkPendingBranches(
                            for: store.favoriteMarkets.map(\.marketId)
                        )
                    }
                }
                // App-wide accent, so onboarding matches the tabs instead of
                // falling back to system blue.
                .tint(Theme.accent)
                // Not `preferredColorScheme` — that flips content and bars in
                // separate steps. See `AppearanceWindowBridge`.
                .appearanceOverride(appearance)
        }
    }
}
