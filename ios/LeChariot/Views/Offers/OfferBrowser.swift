import SwiftUI

/// Suche, Filter, Sortierung und Markt-Leiste — einmal gebaut, von der
/// laufenden Woche **und** von der Vorschau benutzt.
///
/// **Warum geteilt und nicht kopiert.** Die Vorschau sollte am 2026-08-02
/// können, was die Angebotsliste kann. Der billige Weg wäre gewesen, die
/// hundert Zeilen aus `OffersView` daneben noch einmal hinzuschreiben. Der
/// teure Teil daran kommt später: Jede Änderung an der Suche müsste ab dann an
/// zwei Stellen ankommen, und die zweite wird irgendwann vergessen — das ist
/// dieselbe Klasse Fehler wie das Kommando, das der Workflow zweimal führte.
///
/// **Die Trennung der Wochen steckt in der Bauart, nicht in einer Prüfung.**
/// Dieser Typ hält *keine* Angebote. Er bekommt sie bei jedem Aufruf übergeben
/// und holt sich nirgends welche. Wer ihn mit `store.offers` füttert, kann
/// keine Zeile der Folgewoche aus ihm herausbekommen, und wer ihn mit
/// `store.upcomingOffers` füttert, keine der laufenden — nicht weil ein Test
/// darüber wacht, sondern weil es keinen Weg dorthin gibt. Die Journeys
/// bewachen trotzdem beide Richtungen; eine Bauart, auf die sich niemand
/// verlässt, ist eine, die still umgebaut wird.
struct OfferBrowser: Equatable {
    var search = ""
    var grouping: OfferGrouping = .market
    var sort: OfferSort = .standard
    var category: String?
    var market: String?

    var trimmedSearch: String { search.trimmingCharacters(in: .whitespaces) }
    var isSearching: Bool { !trimmedSearch.isEmpty }
    var hasActiveFilter: Bool { category != nil || market != nil || sort == .deals }
    /// Weder gesucht noch gefiltert — nur dann sind Top-Deals und die Fußnote
    /// der leeren Filialen am Platz.
    var isBrowsing: Bool { !isSearching && !hasActiveFilter }

    /// Die sichtbaren Zeilen. **Aus dem übergebenen Topf und nur aus ihm.**
    func visible(in offers: [Offer]) -> [Offer] {
        OfferQuery.apply(
            offers, search: search, category: category, market: market, sort: sort
        )
    }

    /// Die Ketten, für die die Leiste einen Chip zeigt.
    ///
    /// Gerechnet aus den **geladenen Zeilen**, nicht aus den gewählten
    /// Filialen. Ein Chip für eine Kette, die hier nichts hat, wäre ein Tipp in
    /// die Sackgasse „Nichts für diesen Filter"; dass eine gewählte Filiale
    /// leer ist, erklärt der Abschnitt am Ende der Liste, und zwar mit dem
    /// Grund.
    ///
    /// Die aktive Kette bleibt drin, auch wenn sie gerade aus den Zeilen fällt
    /// (eine Aktualisierung kann das). Sonst verschwände mit dem Chip der
    /// einzige sichtbare Hinweis darauf, warum die Liste leer ist.
    func chipChains(in offers: [Offer]) -> [String] {
        var ketten = Set(offers.map(\.market))
        if let market { ketten.insert(market) }
        return ketten.sorted()
    }

    mutating func resetFilters() {
        category = nil
        market = nil
        sort = .standard
    }

    /// Ein Marktfilter kann die Kette überleben, die ihn benannt hat: Netto in
    /// den Einstellungen abwählen, und der Bildschirm filterte weiter auf eine
    /// Kette ohne Zeilen — dauerhaft leer, ohne sichtbare Ursache.
    mutating func dropMarketFilterIfGone(from chains: [String]) {
        if let market, !chains.contains(market) { self.market = nil }
    }
}

// MARK: - Wovon die Rede ist

/// Ob ein Bildschirm die laufende oder die kommende Woche zeigt.
///
/// Steuert **nur Wörter**, keine Daten: „diese Woche" gegen „nächste Woche" in
/// den Leertexten. Ein gemeinsamer Satz für beide wäre auf einem der zwei
/// Bildschirme gelogen — und die Vorschau lebt davon, dass niemand ihre Preise
/// für die heutigen hält.
enum OfferWeekScope {
    case current, upcoming

    var week: String {
        switch self {
        case .current: "diese Woche"
        case .upcoming: "nächste Woche"
        }
    }
}

// MARK: - Markt-Leiste

/// Ein Tipp statt einer Scroll-Lotterie.
///
/// Den Marktfilter gab es schon, aber als vierten Picker in einem Menü der
/// Werkzeugleiste — wer zu Lidl wollte, scrollte trotzdem. Die Leiste steht
/// deshalb **über** der Liste und scrollt nicht mit ihr weg.
///
/// Bei genau einer Kette filtert sie nichts und wäre reine Höhe; dann bleibt
/// sie weg. Dieselbe Regel wie bei der Konsum-Zeile im Picker: Was fast
/// niemandem hilft, darf nicht jeder bezahlen.
struct MarketChipBar: View {
    let chains: [String]
    @Binding var selection: String?
    /// Eigener Griff je Bildschirm — die Journeys müssen die Leiste der
    /// Vorschau von der der laufenden Woche unterscheiden können.
    let identifier: String

    var body: some View {
        if chains.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    chip("Alle", chain: nil)
                    ForEach(chains, id: \.self) { chip($0, chain: $0) }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.background)
            .accessibilityIdentifier(identifier)
        }
    }

    /// Mindestens 44 pt hoch, nicht die hübscheren 36: `performAccessibilityAudit`
    /// misst Trefferflächen mit, und der Angebote-Bildschirm steht in
    /// `AccessibilityAuditTests` unter Gate.
    private func chip(_ title: String, chain: String?) -> some View {
        let aktiv = selection == chain
        return Button {
            // Ein zweiter Tipp auf den aktiven Chip hebt ihn auf. „Alle" liegt
            // am anderen Ende der Leiste, und dorthin zurückzuscrollen wäre
            // wieder genau die Lotterie, gegen die die Leiste gebaut ist.
            selection = aktiv ? nil : chain
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(aktiv ? Theme.onAccent : Color.primary)
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(minHeight: 44)
                .background(aktiv ? Theme.accent : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(aktiv ? Color.clear : Theme.stroke))
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(chain == nil ? "Alle Märkte" : title)
        .accessibilityAddTraits(aktiv ? [.isSelected] : [])
    }
}

// MARK: - Filter-Menü

/// Gruppierung, Sortierung und Kategorie.
///
/// **Kein „Markt"-Picker:** Das steht seit dem 2026-07-31 als Chip-Leiste über
/// der Liste, sichtbar statt vier Ebenen tief. Zwei Bedienelemente für denselben
/// Zustand sind die Sorte Ballast, die dieselbe Runde im Filial-Picker abgeräumt
/// hat.
struct OfferFilterMenu: View {
    @Binding var grouping: OfferGrouping
    @Binding var sort: OfferSort
    @Binding var category: String?
    let hasActiveFilter: Bool

    var body: some View {
        Menu {
            Picker("Gruppierung", selection: $grouping) {
                ForEach(OfferGrouping.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Sortierung", selection: $sort) {
                ForEach(OfferSort.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Kategorie", selection: $category) {
                Text("Alle Kategorien").tag(String?.none)
                ForEach(Categories.all, id: \.self) { Text($0).tag(String?.some($0)) }
            }
        } label: {
            Label("Filter", systemImage: hasActiveFilter
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
    }
}

// MARK: - Die drei Sackgassen

/// Was dasteht, wenn Suche und Filter alles weggenommen haben.
///
/// Drei Fälle, die einmal identisch aussahen — und die Unterscheidung ist der
/// ganze Punkt. Eine leere Suche zeigte die Suchleere („Keine Ergebnisse für
/// ‚'"), obwohl nur ein Filter im Weg stand; und eine Suche innerhalb einer
/// Kette verschwieg, dass sie eingeschränkt ist.
struct OfferEmptyResultView: View {
    let browser: OfferBrowser
    let scope: OfferWeekScope
    let onResetFilters: () -> Void
    let onClearMarket: () -> Void

    var body: some View {
        if browser.isSearching {
            if let market = browser.market {
                noSearchHit(in: market)
            } else {
                ContentUnavailableView.search(text: browser.trimmedSearch)
            }
        } else {
            noFilterMatch
        }
    }

    /// Der Filter ist im Weg, nicht die Datenlage. Der Unterschied: Hier ist
    /// die Behebung ein Tipp.
    private var noFilterMatch: some View {
        ContentUnavailableView {
            Label("Nichts für diesen Filter", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("Für die gewählte Kategorie oder den gewählten Markt gibt es \(scope.week) keine Angebote.")
        } actions: {
            Button("Filter zurücksetzen", action: onResetFilters)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
        }
    }

    /// Gesucht **innerhalb** einer Kette und nichts gefunden.
    ///
    /// `ContentUnavailableView.search` sagt an dieser Stelle nur „Keine
    /// Ergebnisse für ‚Butter'" — und verschweigt, dass die Suche gerade auf
    /// einen Markt eingeschränkt ist. Bei den anderen liegt vielleicht Butter.
    /// Dieselbe Halbwahrheit wie der Leertext, der EDEKA Böse ein „schau später
    /// noch einmal vorbei" mitgab: ein Satz, der eine Lage behauptet, die er
    /// nicht geprüft hat. Der Ausweg steht daneben und kostet einen Tipp.
    private func noSearchHit(in chain: String) -> some View {
        ContentUnavailableView {
            Label("Nichts bei \(chain)", systemImage: "magnifyingglass")
        } description: {
            Text("„\(browser.trimmedSearch)“ steht \(scope.week) nicht in den Angeboten von \(chain). Die anderen Märkte sind gerade ausgeblendet.")
        } actions: {
            Button("In allen Märkten suchen", action: onClearMarket)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
        }
    }
}
