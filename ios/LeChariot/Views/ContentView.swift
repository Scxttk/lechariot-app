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
    /// Der Rundgang. Lebt hier, weil ihn beide Hälften brauchen: Das Onboarding
    /// bietet ihn an, die Tabs zeigen ihn.
    @State private var tutorial = TutorialStore()

    private enum Tab {
        case liste, angebote, einstellungen
    }

    var body: some View {
        // Dieselbe Regel wie zwischen den Onboarding-Schritten: Der letzte
        // Wechsel des Assistenten ist der hier — vom Assistenten in die App —,
        // und er sprang genauso. Behälter trägt die Kurve, die beiden
        // Hälften tragen den Übergang.
        ZStack {
            if store.isOnboardingComplete {
                mainTabs
                    .stateTransition(.screen)
            } else {
                OnboardingFlowView(marketRepository: marketRepository)
                    .stateTransition(.screen)
            }
        }
        .stateAnimation(.screen, value: store.isOnboardingComplete)
        .environment(tutorial)
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            allRegionScoped { markets in
                ShoppingListView(favoriteMarkets: markets, offerStore: offerStore)
            }
            // Nullhoher Marker auf der Unterkante der sicheren Fläche dieses
            // Tabs — also genau auf der Oberkante der Tab-Leiste. Die Leiste
            // selbst zeichnet UIKit und trägt keinen Anker; das hier ist der
            // einzige Griff, den SwiftUI darauf hergibt.
            .overlay(alignment: .bottom) {
                Color.clear
                    .frame(height: 0)
                    .allowsHitTesting(false)
                    .tutorialAnchor(.tabBarTop)
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
        // Die Tab-Leiste ist die eine Stelle, an der man aus dem Rundgang
        // herausspaziert: Sie zeichnet UIKit **über** dem Overlay, die
        // Sperrflächen darunter erreichen sie nicht. Am Simulator nachgestellt —
        // ein Tipp auf „Angebote" wechselte mitten in der Führung den Tab.
        // `disabled` greift dort, wo eine Ansicht darüber nicht hinkommt; die
        // Tab-Wechsel des Rundgangs selbst laufen über `selectedTab` und sind
        // davon unberührt.
        .disabled(tutorial.isRunning)
        .tint(Theme.accent)
        // Über den Tabs, nicht in einem davon: Der Lauf ist minuten- bis
        // tagelang her, der Nutzer kann überall stehen.
        .safeAreaInset(edge: .top) {
            if areaRequests.areaJustCompleted {
                areaCompletedNotice
            }
        }
        .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            if tutorial.isRunning {
                GeometryReader { proxy in
                    TutorialOverlay(
                        anchors: anchors,
                        proxy: proxy,
                        tutorial: tutorial,
                        list: shoppingList
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        // Der Rundgang spielt auf einem bestimmten Tab; der letzte Rahmen zeigt
        // die Einstellungen. Ohne das zeigte das Loch auf ein Bedienelement,
        // das gerade auf einem anderen Bildschirm liegt.
        .onChange(of: tutorial.index) { _, _ in
            selectedTab = tab(for: tutorial.step.tab)
        }
        .onChange(of: tutorial.isRunning) { _, running in
            if running {
                selectedTab = tab(for: tutorial.step.tab)
            } else {
                // Jeder Ausgang läuft hier durch — „Fertig“ wie „Tour beenden“.
                // Deshalb steht das Aufräumen hier und nicht an einem Knopf.
                tutorial.removeDemoItems(from: shoppingList)
                selectedTab = .liste
            }
        }
        .task {
            // Ein Rundgang, den der App-Tod unterbrochen hat, hat seine
            // Beispiel-Artikel nie abgeräumt. Das wird hier nachgeholt.
            if !tutorial.isRunning {
                tutorial.removeDemoItems(from: shoppingList)
            }
        }
    }

    private func tab(for tutorialTab: TutorialTab) -> Tab {
        switch tutorialTab {
        case .liste: return .liste
        case .einstellungen: return .einstellungen
        }
    }

    /// Der Gebiets-Lauf dauert ~3 Minuten und überlebt die App. Wer ihn
    /// auslöst, ist längst weitergezogen — ohne diesen Hinweis erführe niemand,
    /// dass jetzt mehr zur Auswahl steht, und die kurze Liste vom Onboarding
    /// bliebe für immer die Wahrheit, die er kennt.
    private var areaCompletedBody: String {
        let finished = areaRequests.completedAreaPLZs
        guard finished.count == 1, store.regions.count > 1 else {
            return "Wir haben die übrigen Supermärkte in deiner Nähe nachgeladen. Schau nach, ob dein Markt jetzt dabei ist."
        }
        return "Wir haben die übrigen Supermärkte um \(finished[0]) nachgeladen. Schau nach, ob dein Markt jetzt dabei ist."
    }

    private var areaCompletedNotice: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "storefront")
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Deine Gegend ist jetzt vollständig")
                    .font(.subheadline.bold())
                // Die PLZ steht hier, nicht in der Überschrift: Wer zwei
                // Regionen führt, muss wissen, welche von beiden gewachsen ist
                // — „in deiner Nähe" beantwortet das nicht.
                Text(areaCompletedBody)
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
        .environment(RegionStore())
        // Liste, Einstellungen und Onboarding lesen alle das Profil; im echten
        // Start kommt es aus `LeChariotApp`. Ohne das hier stürzt die Preview
        // beim Wechsel in die Einstellungen ab.
        .environment(ProfileStore())
        .environment(AreaRequestStore(repository: MockAreaRequestRepository()))
}
