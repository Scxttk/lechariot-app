import SwiftUI

// MARK: - Was die Gegend hergibt

/// Was das Onboarding über die Gegend um die PLZ weiß: welche Ketten dort
/// Filialen haben, und wie viele. Kommt aus dem Verzeichnis (`branches`) —
/// derselben Quelle, aus der später der Filial-Picker liest.
struct NearbyMarkets: Equatable {
    let chains: [String]
    let branchCount: Int
}

/// Holt die Ketten der Gegend, ohne das Onboarding daran zu hängen.
///
/// **Das Netz darf hier nichts blockieren.** Die Abfrage bekommt zwei
/// Sekunden; wer offline ist oder eine lahme Leitung hat, sieht statt der
/// örtlichen Liste alle neun Ketten — eine richtige Antwort, nur eine
/// weniger genaue. Ein Onboarding, das auf einen Server wartet, wäre genau
/// die Sorte Wartebildschirm, die mit Migration v16 abgeschafft wurde.
enum NearbyMarketsLookup {
    /// Alle neun Ketten, die das Backend kennt — als Rückfallliste, wenn das
    /// Verzeichnis nicht rechtzeitig antwortet.
    ///
    /// Die Schreibweisen sind die der `branches`-Tabelle (siehe
    /// `Store::chain()` im Backend und docs/CONTRACTS.md) — nie umbenennen,
    /// die gemerkten Ketten werden später gegen `Branch.chain` verglichen.
    static let allChains: [String] = [
        "ALDI Nord", "ALDI SÜD", "EDEKA", "Kaufland", "Lidl",
        "NORMA", "Netto", "Penny", "REWE",
    ]

    /// Die Ketten eines Verzeichnis-Ergebnisses, jede einmal, alphabetisch —
    /// dieselbe Ordnung wie die Kettenseiten des Pickers.
    static func chains(in branches: [Branch]) -> [String] {
        Array(Set(branches.map(\.chain)))
            .sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    /// Ketten und Filialzahl um die PLZ, oder nil, wenn das Verzeichnis nicht
    /// innerhalb von `timeout` antwortet (offline, Funkloch, lahmer Server).
    ///
    /// `locate` ist einsetzbar, damit die Unit-Tests weder an Apples Geocoder
    /// noch daran hängen, ob auf der Maschine eine `APIKeys.plist` liegt.
    static func nearby(
        plz: String,
        repository: BranchRepositoryProtocol = AppRepositories.branches,
        locate: @escaping @Sendable (String) async throws -> (lat: Double, lon: Double) = defaultLocate,
        timeout: TimeInterval = 2
    ) async -> NearbyMarkets? {
        await withTaskGroup(of: NearbyMarkets?.self) { group in
            group.addTask { try? await fetch(plz: plz, repository: repository, locate: locate) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            // Wer zuerst fertig ist, gewinnt — die Uhr oder das Verzeichnis.
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func fetch(
        plz: String,
        repository: BranchRepositoryProtocol,
        locate: @Sendable (String) async throws -> (lat: Double, lon: Double)
    ) async throws -> NearbyMarkets? {
        let point = try await locate(plz)
        // Derselbe wachsende Radius wie im Picker — ein Dorf mit zwei Läden
        // ist keine fertige Liste, sondern ein zu kleiner Radius.
        let branches = try await MarketPickerView.nearbyWideningIfSparse(
            repository: repository, lat: point.lat, lon: point.lon
        )
        guard !branches.isEmpty else { return nil }
        return NearbyMarkets(chains: chains(in: branches), branchCount: branches.count)
    }

    /// PLZ → Koordinaten. Mock-Läufe nehmen die Fixture-Punkte — dieselbe
    /// Naht wie `MarketPickerView.locate`: Ein UI-Lauf darf nicht an Apples
    /// Geocoder hängen.
    static let defaultLocate: @Sendable (String) async throws -> (lat: Double, lon: Double) = { plz in
        guard !AppRepositories.usesMockData else { return MockFixtures.coordinates(forPLZ: plz) }
        return try await PLZLocator.coordinates(forPLZ: plz)
    }
}

// MARK: - Der Schritt

/// „Welche Märkte magst du?" — Ketten liken, keine Filialen wählen.
///
/// **Die Filialauswahl bleibt draußen** (Entscheidung vom 2026-07-31, siehe
/// `OnboardingFlowView`): Sie war der Schritt, an dem Scott am Gerät
/// hängen blieb. Eine Kette anzutippen ist keine Suche in einer langen
/// Liste — und die Filiale wählt man später dort, wo man sieht, wofür.
///
/// Alles optional: „Weiter" geht auch mit leeren Händen, „Später" sagt es
/// dazu. Die Auswahl bleibt auf dem Gerät (`ProfileStore.likedChains`).
struct ChainLikingStepView: View {
    @Environment(ProfileStore.self) private var profile
    /// PLZ aus dem Regionsschritt — bestimmt, welche Ketten gezeigt werden.
    var plz: String?
    /// Weiter, mit dem, was über die Gegend bekannt wurde — der
    /// Belohnungsschritt danach zeigt genau diese Zahlen.
    var onContinue: (NearbyMarkets?) -> Void

    @State private var nearby: NearbyMarkets?
    @State private var isLoading = true

    /// Örtliche Ketten, wenn das Verzeichnis geantwortet hat; sonst alle neun.
    private var shownChains: [String] {
        if let nearby, !nearby.chains.isEmpty { return nearby.chains }
        return NearbyMarketsLookup.allChains
    }

    var body: some View {
        OnboardingStepView(
            step: 4,
            totalSteps: OnboardingStep.total,
            title: "Welche Märkte magst du?",
            subtitle: "Tippe an, wo du gern einkaufst. Das hilft später beim Auswählen der Filialen — und bleibt auf deinem Gerät.",
            onPrimary: { onContinue(nearby) },
            skip: (title: "Später", action: { onContinue(nearby) })
        ) {
            if isLoading {
                // Höchstens die zwei Sekunden der Abfrage — dann steht hier
                // entweder die örtliche Liste oder die vollständige.
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Märkte in deiner Nähe werden gesucht …")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.sm)],
                    spacing: Theme.Spacing.sm
                ) {
                    ForEach(shownChains, id: \.self) { chain in
                        SelectableChip(
                            title: chain,
                            symbol: profile.isLikedChain(chain) ? "heart.fill" : "heart",
                            isSelected: profile.isLikedChain(chain)
                        ) {
                            profile.toggleLikedChain(chain)
                        }
                    }
                }
            }
        }
        .task {
            guard let plz else {
                isLoading = false
                return
            }
            nearby = await NearbyMarketsLookup.nearby(plz: plz)
            isLoading = false
        }
    }
}

#Preview {
    ChainLikingStepView(plz: "01219", onContinue: { _ in })
        .environment(ProfileStore())
}
