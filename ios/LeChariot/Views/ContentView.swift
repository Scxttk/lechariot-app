import SwiftUI

struct ContentView: View {
    @Environment(RegionStore.self) private var store
    @Environment(AreaRequestStore.self) private var areaRequests
    let marketRepository: MarketRepositoryProtocol

    @State private var shoppingList = ShoppingListStore()
    @State private var rejections = MatchRejectionStore()
    @State private var feedback = MatchFeedbackStore(repository: AppRepositories.matchFeedback())
    /// One offer store for the whole app.
    ///
    /// Liste and Angebote used to build one each. Both then fetched the full
    /// weekly set over the network and both called `replaceAll` on the same
    /// SwiftData rows — twice the traffic for identical data, and two writers
    /// racing on one cache. They show the same offers, so they share the store.
    @State private var offerStore = OfferStore(
        repository: AppRepositories.offers,
        cache: OfferCache.shared
    )
    /// Every cold start lands on the shopping list — that is the screen the app
    /// exists for. Deliberately not persisted: reopening the app mid-week must
    /// not drop the user wherever they happened to leave off.
    @State private var selectedTab: Tab = .liste

    private enum Tab {
        case liste, angebote, einstellungen
    }

    var body: some View {
        if store.isOnboardingComplete {
            mainTabs
        } else {
            OnboardingFlowView(marketRepository: marketRepository)
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            allRegionScoped { markets in
                ShoppingListView(favoriteMarkets: markets, offerStore: offerStore)
            }
            .tabItem {
                Label("Liste", systemImage: "checklist")
            }
            .tag(Tab.liste)

            offersTab
                .tabItem {
                    Label("Angebote", systemImage: "tag")
                }
                .tag(Tab.angebote)

            SettingsView(marketRepository: marketRepository)
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(Tab.einstellungen)
        }
        .environment(shoppingList)
        .environment(rejections)
        .environment(feedback)
        .tint(Theme.accent)
        // Über den Tabs, nicht in einem davon: Der Lauf ist minuten- bis
        // tagelang her, der Nutzer kann überall stehen.
        .safeAreaInset(edge: .top) {
            if areaRequests.areaJustCompleted {
                areaCompletedNotice
            }
        }
    }

    /// Der Gebiets-Lauf dauert ~3 Minuten und überlebt die App. Wer ihn
    /// auslöst, ist längst weitergezogen — ohne diesen Hinweis erführe niemand,
    /// dass jetzt mehr zur Auswahl steht, und die kurze Liste vom Onboarding
    /// bliebe für immer die Wahrheit, die er kennt.
    private var areaCompletedNotice: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "storefront")
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Deine Gegend ist jetzt vollständig")
                    .font(.subheadline.bold())
                Text("Wir haben die übrigen Supermärkte in deiner Nähe nachgeladen. Schau nach, ob dein Markt jetzt dabei ist.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)

                Button("Filialen wählen") {
                    areaRequests.dismissCompletionNotice()
                    selectedTab = .einstellungen
                }
                .font(.footnote.bold())
                .padding(.top, Theme.Spacing.xs)
            }

            Spacer(minLength: 0)

            Button {
                areaRequests.dismissCompletionNotice()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.bold())
                    .foregroundStyle(Theme.secondaryText)
                    .padding(Theme.Spacing.sm)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Hinweis ausblenden")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.stroke)
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    /// Angebote spans all ready regions with their favorites, so PLZ-border
    /// users see offers from every region they added.
    @ViewBuilder
    private var offersTab: some View {
        allRegionScoped { markets in
            OffersView(favoriteMarkets: markets, store: offerStore)
        }
    }

    /// Both content tabs span all ready regions — the chosen branches are the
    /// filter, not a selected region.
    ///
    /// Since onboarding completion became sticky, a user can legitimately end up
    /// here with no region or no branch (they removed the last one in the
    /// settings). Neither is an error, and neither is a dead end any more: both
    /// states name the missing piece and hand over a button to the screen that
    /// restores it.
    @ViewBuilder
    private func allRegionScoped(
        @ViewBuilder content: ([Market]) -> some View
    ) -> some View {
        let regions = store.orderedReadyRegions
        if regions.isEmpty {
            setupNeeded(
                title: "Keine Region bereit",
                symbol: "mappin.slash",
                message: "Füge in den Einstellungen eine Postleitzahl hinzu — dann lädt Le Chariot die Angebote deiner Gegend."
            )
        } else if !store.hasFavorites {
            setupNeeded(
                title: "Keine Filiale gewählt",
                symbol: "storefront",
                message: "Le Chariot vergleicht nur die Läden, in die du wirklich gehst. Wähle mindestens eine Filiale aus."
            )
        } else {
            // All favorites, unfiltered: the picker offers branches from
            // neighbouring postcodes, so a favorite's `plz` need not be one
            // of the user's regions.
            content(store.favoriteMarkets)
        }
    }

    private func setupNeeded(title: String, symbol: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            Button("Zu den Einstellungen") { selectedTab = .einstellungen }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
        }
        .themedScreen()
    }
}

#Preview {
    ContentView(marketRepository: MockMarketRepository())
        .environment(RegionStore(repository: MockRegionRepository()))
        // Liste, Einstellungen und Onboarding lesen alle das Profil; im echten
        // Start kommt es aus `LeChariotApp`. Ohne das hier stürzt die Preview
        // beim Wechsel in die Einstellungen ab.
        .environment(ProfileStore())
        .environment(AreaRequestStore(repository: MockAreaRequestRepository()))
}
