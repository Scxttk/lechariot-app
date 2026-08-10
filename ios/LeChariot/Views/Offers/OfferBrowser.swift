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
    ///
    /// **`resting` kehrt die Regel für einen benannten Fall um** (10.08.).
    /// Der Absatz oben bleibt richtig, solange „diese Kette hat hier nichts"
    /// alles ist, was wir wissen. Am Sonntag wissen wir mehr: Die Woche endete
    /// Samstag, die neue fängt Montag an — und dann ist der fehlende Chip
    /// keine ersparte Sackgasse mehr, sondern eine verschwiegene Auskunft.
    /// Es ist dieselbe Umkehrung wie bei den Vorschau-Chips am 03.08., aus
    /// demselben Grund: **Ein Reiter, der fehlt, beantwortet „wo ist mein
    /// Aldi" nicht.** Welche Ketten das sind, rechnet
    /// `OfferCoverage.restingChains` — und die verlangt ein Fenster, also
    /// einen Grund, der hinter dem Chip auch dasteht.
    func chipChains(in offers: [Offer], resting: Set<String> = []) -> [String] {
        var ketten = Set(offers.map(\.market)).union(resting)
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
    /// Ketten, die gerade **keine gültigen** Angebote haben und den Chip
    /// trotzdem behalten — siehe `OfferBrowser.chipChains`. Sie stehen zurück
    /// gezeichnet da, damit der Unterschied schon vor dem Tipp zu sehen ist:
    /// Ein Chip, der aussieht wie die anderen und dann in einen Leertext
    /// führt, ist die Sackgasse mit einem Umweg davor.
    var resting: Set<String> = []

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
        let ruht = chain.map(resting.contains) ?? false
        return Button {
            // Ein zweiter Tipp auf den aktiven Chip hebt ihn auf. „Alle" liegt
            // am anderen Ende der Leiste, und dorthin zurückzuscrollen wäre
            // wieder genau die Lotterie, gegen die die Leiste gebaut ist.
            selection = aktiv ? nil : chain
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if ruht {
                    // **Das Zeichen sagt es, nicht die Farbe.** Ein bloß
                    // blasserer Chip wäre für jemanden mit Farbschwäche
                    // dasselbe wie ein normaler — dieselbe Regel, die die
                    // Chips im Angaben-Panel `.isSelected` tragen lässt.
                    Image(systemName: "calendar")
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(chipVordergrund(aktiv: aktiv, ruht: ruht))
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(minHeight: 44)
                .background(aktiv ? Theme.accent : Theme.surface, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        aktiv ? Color.clear : Theme.stroke,
                        style: StrokeStyle(lineWidth: 1, dash: ruht && !aktiv ? [4, 3] : [])
                    )
                )
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(
            chain == nil
                ? "Alle Märkte"
                : (ruht ? "\(title), zurzeit ohne Angebote" : title)
        )
        .accessibilityAddTraits(aktiv ? [.isSelected] : [])
    }

    /// Aktiv schlägt ruhend: Wer den Chip gewählt hat, sieht die Auswahl, und
    /// der Grund steht dann ohnehin in ganzen Sätzen unter der Leiste.
    private func chipVordergrund(aktiv: Bool, ruht: Bool) -> Color {
        if aktiv { return Theme.onAccent }
        return ruht ? Theme.secondaryText : Color.primary
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
    /// Das Fenster der gefilterten Kette, wenn sie gerade **ruht** — siehe
    /// `OfferCoverage.ChainOfferWindow`. Gesetzt heißt: Der Filter ist nicht
    /// im Weg, die Woche ist es.
    var restingWindow: OfferCoverage.ChainOfferWindow?
    /// Der Weg in die Vorschau. `nil` auf der Vorschau selbst — dort wäre er
    /// ein Knopf auf den Bildschirm, auf dem man schon steht.
    var onShowNextWeek: (() -> Void)?

    var body: some View {
        if let restingWindow, let market = browser.market, !browser.isSearching {
            restingChain(market, window: restingWindow)
        } else if browser.isSearching {
            if let market = browser.market {
                noSearchHit(in: market)
            } else {
                ContentUnavailableView.search(text: browser.trimmedSearch)
            }
        } else {
            noFilterMatch
        }
    }

    /// **Die vierte Sackgasse, und die einzige, die keine ist.**
    ///
    /// Bis zum 10.08. gab es diesen Bildschirm nicht, weil es den Chip nicht
    /// gab: Eine Kette ohne gültige Zeilen verschwand aus der Leiste, und die
    /// Frage „wo ist mein Netto" blieb unbeantwortet (Scotts Feldtest 09.08.,
    /// acht Filialen gewählt, zwei sichtbar). „Nichts für diesen Filter" wäre
    /// hier dieselbe Halbwahrheit wie bei `noSearchHit`: Es liegt nicht am
    /// Filter, sondern daran, dass Prospektwochen Montag bis Samstag laufen.
    ///
    /// Beide Daten stehen ausgeschrieben da, weil „ab Montag" ohne Kalender
    /// niemand einordnet — dieselbe Begründung wie bei
    /// `NoOffersReason.dayFormatter`. Fehlt eins von beidem, fällt sein Satz
    /// weg; behauptet wird nur, was gemessen im Fenster steht.
    private func restingChain(
        _ chain: String, window: OfferCoverage.ChainOfferWindow
    ) -> some View {
        ContentUnavailableView {
            Label("Bei \(chain) läuft gerade kein Prospekt", systemImage: "calendar")
        } description: {
            // **Ohne die zwei Zeilen wird der Satz abgeschnitten**, am
            // gerenderten Bild gesehen: „Die Angebote endeten Sa. 8. August.
            // Die n…". In einer `List`-Zeile bekommt die Beschreibung sonst
            // genau eine Zeile — und ein Satz, der die Hälfte seiner Auskunft
            // verschluckt, ist schlimmer als keiner.
            Text(Self.restingText(window))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            if window.startsOn != nil, let onShowNextWeek {
                Button("Nächste Woche ansehen", action: onShowNextWeek)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Theme.onAccent)
            }
            Button("Alle Märkte zeigen", action: onClearMarket)
                .buttonStyle(.bordered)
        }
        .accessibilityIdentifier("offers.restingChain")
    }

    /// „Die Angebote endeten Sa. 8. August. Die neuen gelten ab Mo. 17.
    /// August." — als reine Rechnung, damit der Satz ohne eine Ansicht prüfbar
    /// ist. Dieselbe Bauart wie `NoOffersReason.text`, aus demselben Grund: An
    /// diesem Satz ist schon zweimal etwas behauptet worden, was niemand
    /// gemessen hatte.
    static func restingText(_ window: OfferCoverage.ChainOfferWindow) -> String {
        var teile: [String] = []
        if let ended = window.endedOn {
            teile.append("Die Angebote endeten \(dayFormatter.string(from: ended)).")
        }
        if let start = window.startsOn {
            teile.append("Die neuen gelten ab \(dayFormatter.string(from: start)).")
        }
        return teile.joined(separator: " ")
    }

    /// „Sa. 8. August" — der Wochentag gehört dazu, abgekürzt: Der Satz trägt
    /// zwei davon, und „Samstag, 8. August. … Montag, 17. August." liest sich
    /// wie ein Formular. (Die Beispiele sind aus dem gerenderten Bild
    /// abgeschrieben, nicht aus dem Kopf.)
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.setLocalizedDateFormatFromTemplate("EEE d. MMMM")
        return f
    }()

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
