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
    /// Die Frage nach den Filialen am Ende des Assistenten. Lebt hier, weil sie
    /// beide Hälften betrifft: Der Assistent löst sie aus, die Tabs zeigen sie.
    @State private var marketPrompt = MarketPromptStore()
    /// Die vier Einmal-Schilder — seit dem Abriss des Rundgangs die ganze
    /// Erklärschicht. Lebt hier, weil beide Inhalts-Tabs ihm Momente melden
    /// und die Einstellungen ihn zurücksetzen.
    @State private var tips = ContextTipStore()
    /// Die zwei ersten Male (Artikel, Treffer) und die Einrichtungs-Checkliste.
    /// Hier statt in der Liste, weil auch die Einstellungen ihn brauchen
    /// (`AppReset`).
    @State private var setup = SetupProgressStore()
    /// Die Filialauswahl über der Liste. Erreichbar aus dem Leerzustand der
    /// Liste; die Markt-Frage nach dem Onboarding bringt ihre eigene Fassung
    /// mit (`MarketPromptSheet`).
    @State private var showsMarketPicker = false
    /// Die Postleitzahl über den Tabs — aus dem Zustand ohne Region heraus.
    /// Ohne sie zeigte dieser Bildschirm auf die Einstellungen und überließ
    /// dem Menschen den Weg.
    @State private var showsRegionSetup = false
    /// Ob die eben geschlossene Region-Eingabe eine Region hinterlassen hat.
    @State private var regionAdded = false
    @Environment(\.scenePhase) private var scenePhase

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
        .environment(marketPrompt)
        .environment(tips)
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
            .tabItem {
                Label("Liste", systemImage: "checklist")
            }
            .tag(Tab.liste)

            offersTab
                .tabItem {
                    Label("Angebote", systemImage: "tag")
                }
                .tag(Tab.angebote)

            SettingsView(marketRepository: marketRepository, onShowList: { selectedTab = .liste })
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(Tab.einstellungen)
        }
        .environment(shoppingList)
        .environment(rejections)
        .environment(feedback)
        .environment(setup)
        .tint(Theme.accent)
        // Über den Tabs, nicht in einem davon: Der Lauf ist minuten- bis
        // tagelang her, der Nutzer kann überall stehen.
        .safeAreaInset(edge: .top) {
            if areaRequests.areaJustCompleted {
                areaCompletedNotice
            }
        }
        // Der alte Rundgang hat auf manchen Geräten drei geliehene Artikel
        // hinterlassen; sie kommen hier ein letztes Mal herunter. Siehe
        // `TourResidue`.
        .task { TourResidue.sweep(from: shoppingList) }
        // **Die Lebensdauer des Erledigten**, siehe
        // `ShoppingListStore.sweepChecked`. Beim Start und bei jeder Rückkehr,
        // nicht über einen Zeitgeber: Ein Artikel, der verschwindet, während
        // niemand hinsieht, ist dasselbe Ergebnis für mehr Aufwand — und ein
        // Artikel, der unter dem Daumen verschwindet, wäre schlechter.
        .task { shoppingList.sweepChecked() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { shoppingList.sweepChecked() }
        }
        // **Ein Sheet statt eines System-Alerts** (05.08.). Die Frage nach den
        // Filialen ist der Moment, an dem hängt, ob die App je etwas
        // vergleichen kann — und sie stand als nackter Alert da. Siehe
        // `MarketPromptSheet`; die Filialauswahl liegt dort als
        // Navigationsziel im selben Sheet.
        .sheet(isPresented: marketQuestion) { marketPromptSheet }
        .sheet(isPresented: $showsMarketPicker) { marketPicker }
        // **Erst wenn das eine Blatt unten ist, fährt das nächste hoch.** Ein
        // `sheet`, das während der Auflösung des vorherigen gesetzt wird,
        // erscheint nicht — deshalb hängt die Auswahl an `onDismiss` und nicht
        // an der Zeile, die die Region meldet.
        .sheet(isPresented: $showsRegionSetup, onDismiss: {
            if regionAdded {
                regionAdded = false
                showsMarketPicker = true
            }
        }) {
            NavigationStack {
                RegionSetupView(onPLZSubmitted: { _ in
                    // Eine frische Region ohne Filialen ist der halbe Weg; die
                    // Auswahl steht direkt dahinter, statt den Menschen auf
                    // demselben leeren Bildschirm abzusetzen.
                    regionAdded = true
                    showsRegionSetup = false
                })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showsRegionSetup = false }
                    }
                }
            }
        }
    }

    /// **Der Weg ohne Filialen aus dem Onboarding fragt — einmal.**
    ///
    /// Die Bedingung steht im Store (`MarketPromptStore.asksForMarkets`), damit
    /// die Ansicht sie nicht ein zweites Mal formuliert. Jede Art des
    /// Schließens — Knopf wie Wegwischen — läuft durch den Setter und zählt
    /// damit als Antwort.
    private var marketQuestion: Binding<Bool> {
        Binding(
            get: { marketPrompt.asksForMarkets },
            set: { if !$0 { marketPrompt.dismissMarketQuestion() } }
        )
    }

    /// Das Markt-Sheet nach dem Onboarding. Die PLZ-Herleitung ist dieselbe
    /// wie beim Picker darunter; ohne Region gibt es nichts zu wählen — der
    /// Fall ist theoretisch, das Onboarding lässt niemanden ohne durch.
    @ViewBuilder
    private var marketPromptSheet: some View {
        if let plz = store.orderedReadyRegions.first ?? store.regions.first {
            MarketPromptSheet(
                plz: plz,
                marketRepository: marketRepository,
                onDone: { marketPrompt.dismissMarketQuestion() }
            )
        }
    }

    /// Die Filialauswahl über der Liste, nicht in den Einstellungen: Wer sie
    /// hier öffnet, ist auf halbem Weg zu seiner Liste und soll dorthin
    /// zurückkommen, wo er losgegangen ist.
    @ViewBuilder
    private var marketPicker: some View {
        NavigationStack {
            if let plz = store.orderedReadyRegions.first ?? store.regions.first {
                MarketPickerView(
                    plz: plz,
                    marketRepository: marketRepository,
                    onDone: { showsMarketPicker = false }
                )
                // „Fertig" ist gesperrt, solange nichts gewählt ist — ohne
                // Abbruch wäre der Bildschirm für jemanden, der es sich anders
                // überlegt, eine Sackgasse. Im Onboarding war das richtig, hier
                // ist es keine Pflichtstation mehr.
                //
                // **Am Bildschirm, nicht am `NavigationStack`:** Kurz am 06.08.
                // nach oben gewandert, damit der leere Fall ihn erbt — aber
                // dann gehört „Abbrechen" dem Stapel und nicht mehr der Wurzel,
                // und nach einem Weg in eine Kette und zurück war es weg. Eine
                // Journey hat es gemeldet. Beide Fälle tragen ihn jetzt selbst.
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showsMarketPicker = false }
                    }
                }
            } else {
                // **Ein Blatt, das nichts zeigt, ist schlimmer als keins.**
                //
                // Bis zum 06.08. stand hier `if let plz = …` **um das ganze
                // Blatt**: Ohne Region baute der Zweig nichts, das Blatt fuhr
                // trotzdem hoch, und man sah eine **weiße Fläche ohne einen
                // einzigen Knopf** — nicht einmal „Abbrechen". Aus dem
                // Leerzustand der Liste heraus war das eine Sackgasse, aus der
                // nur die Wischgeste half.
                //
                // Gefunden über eine Journey, die genau hier hängenblieb, und
                // sichtbar erst im Video des Testlaufs: Der Bildschirm war weiß,
                // nicht creme — also gar kein Inhalt, keine Ansicht mit Fehler.
                //
                // **Merksatz: Ein `if let` um einen ganzen Bildschirm braucht
                // immer ein `else`.** Was fehlt, muss die Ansicht sagen, sonst
                // sagt sie nichts.
                ContentUnavailableView {
                    Label("Noch keine Region", systemImage: "mappin.slash")
                } description: {
                    Text("Ohne Postleitzahl weiß \(AppBrand.name) nicht, welche Filialen in Frage kommen. In den Einstellungen kannst du eine hinzufügen.")
                } actions: {
                    Button("Zu den Einstellungen") {
                        showsMarketPicker = false
                        selectedTab = .einstellungen
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Theme.onAccent)
                }
                .themedScreen()
                .accessibilityIdentifier("picker.noRegion")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showsMarketPicker = false }
                    }
                }
            }
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
                message: "Ohne Postleitzahl weiß \(AppBrand.name) nicht, welche Angebote in Frage kommen.",
                actionTitle: "Postleitzahl hinzufügen",
                identifier: "tab.noRegion",
                action: { showsRegionSetup = true }
            )
        } else if requiresFavorites, !store.hasFavorites {
            setupNeeded(
                title: "Keine Filiale gewählt",
                symbol: "storefront",
                message: "\(AppBrand.name) vergleicht nur die Läden, in die du wirklich gehst. Wähle mindestens eine Filiale aus.",
                actionTitle: "Filialen wählen",
                identifier: "tab.noMarkets",
                action: { showsMarketPicker = true }
            )
        } else {
            // All favorites, unfiltered: the picker offers branches from
            // neighbouring postcodes, so a favorite's `plz` need not be one
            // of the user's regions.
            content(store.favoriteMarkets)
        }
    }

    /// **Der Knopf führt dorthin, wo das Fehlende entsteht** (#107).
    ///
    /// Bis zum 12.08. stand hier für jeden Fall „Zu den Einstellungen" — von
    /// den Angeboten aus drei Tipps bis zur Filialauswahl, und der Mensch
    /// musste den Weg selbst finden. Die Auswahl liegt als Blatt über den Tabs
    /// (dieselbe, die die Liste aus ihrer Karte heraus öffnet), also kann der
    /// Zustand sie ebenso gut selbst aufmachen.
    private func setupNeeded(
        title: String,
        symbol: String,
        message: String,
        actionTitle: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
        }
        .themedScreen()
        .accessibilityIdentifier(identifier)
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
