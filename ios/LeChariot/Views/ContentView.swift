import SwiftUI

struct ContentView: View {
    @Environment(RegionStore.self) private var store
    @Environment(AreaRequestStore.self) private var areaRequests
    /// Übersetzt die PLZ in den Ort — siehe `PlaceNameStore`.
    @Environment(PlaceNameStore.self) private var placeNames
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
    /// Die Filialauswahl über der Liste. Erreichbar aus dem Leerzustand der
    /// Liste und aus der Frage am Ende des Rundgangs.
    @State private var showsMarketPicker = false
    /// Deckkraft der Überblendung beim Tab-Wechsel des Rundgangs — siehe
    /// `TourTabTransition`. 0, solange nicht gewechselt wird.
    @State private var tourVeil: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                // Ohne Repository: Der Assistent fragt keine Filialen mehr ab.
                OnboardingFlowView()
                    .stateTransition(.screen)
            }
        }
        .stateAnimation(.screen, value: store.isOnboardingComplete)
        .environment(tutorial)
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            // **Ohne Filialen-Tor.** Bis zum 2026-07-31 lag hier dieselbe
            // `ContentUnavailableView` wie über den Angeboten, und das
            // Onboarding musste deshalb in der Filialauswahl enden. Die Liste
            // funktioniert ohne Filialen (`OfferStore.load(branchIds: [])`
            // liefert sauber leer); was fehlt, sagt sie an den zwei Stellen, an
            // denen sonst Angebote stehen.
            allRegionScoped(requiresFavorites: false) { markets in
                ShoppingListView(
                    favoriteMarkets: markets,
                    offerStore: offerStore,
                    onChooseMarkets: { showsMarketPicker = true },
                    onShowOffers: { selectedTab = .angebote }
                )
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

            // Der Marker für `.navBarBottom` sitzt **in** `OffersView`, also
            // innerhalb ihres `NavigationStack` — von hier aus läge er über der
            // Leiste statt darunter. Siehe dort.
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
        //
        // **Aber nicht auf den Rahmen, die zum Anfassen einladen** — und das
        // ist der Fund vom 03.08.: `disabled` auf der `TabView` sperrt den
        // ganzen Baum darunter, also auch das Eingabefeld. Der erste Rahmen
        // sagt „Probier es gleich aus", und im Testlauf meldete XCUITest genau
        // dort `TextField … Disabled`. Die Zusage war seit dem Bau des
        // Rundgangs nicht einlösbar. Außerhalb des Lochs sperren weiter die
        // Sperrflächen des Overlays; für die Tab-Leiste steht der Riegel unten.
        .disabled(tutorial.isRunning && !tutorial.step.allowsInteraction)
        // Der Riegel für die Tab-Leiste auf den Mitmach-Rahmen: Wer sie dort
        // antippt, steht sofort wieder auf dem Tab des Rundgangs.
        .onChange(of: selectedTab) { _, chosen in
            guard tutorial.isRunning else { return }
            let belongs = tab(for: tutorial.step.tab)
            if chosen != belongs { selectedTab = belongs }
        }
        .tint(Theme.accent)
        // Über den Tabs, nicht in einem davon: Der Lauf ist minuten- bis
        // tagelang her, der Nutzer kann überall stehen.
        .safeAreaInset(edge: .top) {
            if areaRequests.areaJustCompleted {
                areaCompletedNotice
            }
        }
        // **Die Überblendung liegt über der App und unter dem Rundgang.**
        //
        // Bis zum 03.08. lag sie über allem, auch über der Karte — und damit
        // war der Wechsel vom vorletzten zum letzten Rahmen für eine knappe
        // halbe Sekunde ein **vollständig schwarzer Bildschirm**, Karte und
        // Statusleiste eingeschlossen. Am Simulator Bild für Bild belegt
        // (0,12 s nach dem Tipp: nichts als Schwarz). Scott am 03.08.:
        // „visuell desaströs".
        //
        // Was gewechselt werden muss, ist der Inhalt darunter; die Karte, die
        // man gerade liest, ist genau der Halt, den das Auge dabei braucht.
        // Sie bleibt jetzt stehen, hinter ihr tauscht der Tab. Siehe
        // `TourTabTransition`.
        .overlay {
            if tourVeil > 0 {
                Color.black
                    .opacity(tourVeil)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
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
            switchTourTab(to: tutorial.step.tab)
        }
        .onChange(of: tutorial.isRunning) { _, running in
            if running {
                // Der Start blendet nicht über: Das Overlay zieht ohnehin
                // gerade auf, und zwei Überblendungen übereinander sind eine
                // zu viel.
                selectedTab = tab(for: tutorial.step.tab)
            } else {
                tourVeil = 0
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
        .alert("Märkte jetzt auswählen?", isPresented: marketQuestion) {
            Button("Ja") {
                tutorial.dismissMarketQuestion()
                showsMarketPicker = true
            }
            Button("Nein", role: .cancel) { tutorial.dismissMarketQuestion() }
        } message: {
            Text("\(AppBrand.name) vergleicht die Wochenangebote der Läden, in die du wirklich gehst. Ohne Filiale bleibt deine Liste eine Liste — wählen kannst du sie jederzeit auch später in den Einstellungen.")
        }
        .sheet(isPresented: $showsMarketPicker) { marketPicker }
    }

    /// **Nur der Rundgang aus dem Onboarding fragt.**
    ///
    /// Wer ihn aus den Einstellungen noch einmal ansieht, hat seine Filialen
    /// längst — für bestehende Installationen ändert sich hier nichts. Die
    /// Bedingung steht im Store (`TutorialStore.asksForMarkets`), damit die
    /// Ansicht sie nicht ein zweites Mal formuliert.
    private var marketQuestion: Binding<Bool> {
        Binding(
            get: { tutorial.asksForMarkets },
            set: { if !$0 { tutorial.dismissMarketQuestion() } }
        )
    }

    /// Die Filialauswahl über der Liste, nicht in den Einstellungen: Wer sie
    /// hier öffnet, ist auf halbem Weg zu seiner Liste und soll dorthin
    /// zurückkommen, wo er losgegangen ist.
    @ViewBuilder
    private var marketPicker: some View {
        if let plz = store.orderedReadyRegions.first ?? store.regions.first {
            NavigationStack {
                MarketPickerView(
                    plz: plz,
                    marketRepository: marketRepository,
                    onDone: { showsMarketPicker = false }
                )
                // „Fertig" ist gesperrt, solange nichts gewählt ist — ohne
                // Abbruch wäre der Bildschirm für jemanden, der es sich anders
                // überlegt, eine Sackgasse. Im Onboarding war das richtig, hier
                // ist es keine Pflichtstation mehr.
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showsMarketPicker = false }
                    }
                }
            }
        }
    }

    private func tab(for tutorialTab: TutorialTab) -> Tab {
        switch tutorialTab {
        case .liste: return .liste
        case .angebote: return .angebote
        case .einstellungen: return .einstellungen
        }
    }

    /// Der Tab-Wechsel des Rundgangs — **hinter der Abdunklung, nicht davor.**
    ///
    /// Gemeldet am 03.08.: „Beim Wechsel von Tab zu Tab springt es hart um."
    /// Eine `TabView` blendet ihren Inhalt nicht über, sie tauscht ihn aus; das
    /// Warum und das Warum-nicht-`matchedGeometryEffect` steht in
    /// `TourTabTransition`.
    ///
    /// Der Zustandswechsel selbst passiert weiterhin sofort — nur eben in dem
    /// Moment, in dem niemand hinsieht.
    private func switchTourTab(to tutorialTab: TutorialTab) {
        let target = tab(for: tutorialTab)
        guard let plan = TourTabTransition.plan(
            from: tourTab(of: selectedTab), to: tutorialTab, reduceMotion: reduceMotion
        ) else {
            selectedTab = target
            return
        }
        withAnimation(.linear(duration: plan.fadeIn)) { tourVeil = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(plan.fadeIn))
            selectedTab = target
            try? await Task.sleep(for: .seconds(plan.hold))
            withAnimation(.linear(duration: plan.fadeOut)) { tourVeil = 0 }
        }
    }

    /// Die Rückrichtung von `tab(for:)`. Der Rundgang kennt die Angebote und
    /// die Einstellungen als eigene Ziele; alles andere ist die Liste.
    private func tourTab(of tab: Tab) -> TutorialTab {
        switch tab {
        case .liste: return .liste
        case .angebote: return .angebote
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
        // Ortsname statt Zahl, wo einer bekannt ist (02.08.) — „um Anklam"
        // liest sich wie ein Satz, „um 17389" wie eine Fehlermeldung.
        return "Wir haben die übrigen Supermärkte um \(placeNames.name(forPLZ: finished[0])) nachgeladen. Schau nach, ob dein Markt jetzt dabei ist."
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
    ///
    /// `requiresFavorites` trennt die beiden Tabs: Die **Angebote** sind ohne
    /// Filiale wirklich nichts — eine Liste, die es nicht gibt. Die **Liste**
    /// ist ohne Filiale eine Einkaufsliste ohne Preisvergleich, also der halbe
    /// Zweck der App und ein sinnvoller erster Bildschirm.
    @ViewBuilder
    private func allRegionScoped(
        requiresFavorites: Bool = true,
        @ViewBuilder content: ([Market]) -> some View
    ) -> some View {
        let regions = store.orderedReadyRegions
        if regions.isEmpty {
            setupNeeded(
                title: "Keine Region bereit",
                symbol: "mappin.slash",
                message: "Füge in den Einstellungen eine Postleitzahl hinzu — dann lädt \(AppBrand.name) die Angebote deiner Gegend."
            )
        } else if requiresFavorites, !store.hasFavorites {
            setupNeeded(
                title: "Keine Filiale gewählt",
                symbol: "storefront",
                message: "\(AppBrand.name) vergleicht nur die Läden, in die du wirklich gehst. Wähle mindestens eine Filiale aus."
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
        .environment(PlaceNameStore())
}
