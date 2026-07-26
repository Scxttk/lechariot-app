import Foundation

/// Fixture-backed repositories for previews and tests.
enum MockFixtures {
    static let day = DateFormatter.supabaseDay

    /// Validity of the CURRENT calendar week rather than a fixed date.
    ///
    /// The fixtures used to carry 13.–19.07.2026 hard-coded, so from 20.07.
    /// onwards every preview and UI-test run showed an offer that had expired
    /// — harmless for the assertions, misleading for anyone looking at the
    /// screen, and drifting further every week.
    static let weekStart: Date = {
        Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }()
    static let weekEnd: Date = weekStart.addingTimeInterval(6 * 24 * 60 * 60)

    /// `n` weeks before the current one — for the price history.
    static func weeksAgo(_ n: Int) -> (from: Date, until: Date) {
        let from = weekStart.addingTimeInterval(TimeInterval(-n * 7 * 24 * 60 * 60))
        return (from, from.addingTimeInterval(6 * 24 * 60 * 60))
    }

    static let offers: [Offer] = [
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Bio Vollmilch",
            price: 0.99,
            regularPrice: 1.29,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 0.99,
            baseUnit: "1 l",
            nationwide: false
        ),
        Offer(
            marketId: "aldi-01219-1",
            market: "Aldi",
            product: "Spanische Orangen",
            price: 2.49,
            regularPrice: nil,
            unit: "je 2 kg Netz",
            category: "Obst & Gemüse",
            emoji: "🍊",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 1.25,
            baseUnit: "1 kg",
            nationwide: false
        ),
    ]

    /// Three recorded weeks for the first offer fixture — enough for the
    /// detail sheet's price history to show up in previews and UI tests.
    static let priceHistory: [PriceHistoryPoint] = [
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 1.29, regularPrice: 1.29,
            validFrom: weeksAgo(2).from,
            validUntil: weeksAgo(2).until
        ),
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 1.19, regularPrice: 1.29,
            validFrom: weeksAgo(1).from,
            validUntil: weeksAgo(1).until
        ),
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 0.99, regularPrice: 1.29,
            validFrom: weekStart,
            validUntil: weekEnd
        ),
    ]

    static let markets: [Market] = [
        Market(chain: "Aldi", branchName: "Dresden Prohlis", marketId: "aldi-01219-1", plz: "01219"),
        Market(chain: "Lidl", branchName: "Dresden Reick", marketId: "lidl-01219-1", plz: "01219"),
    ]

    static let region = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)

    /// Three real Dresden stores, two of them the ones the PLZ model could
    /// never reach: the second REWE in a postcode and the Netto in the
    /// Johannes-Paul-Thilman-Straße.
    static let branches: [Branch] = [
        // Dieselben beiden wie in `markets` — Mock-Läufe (UI-Journeys) müssen
        // dieselben Filialen sehen wie vorher, sonst zeigt der Picker über
        // Nacht andere Läden.
        Branch(marketId: "lidl-01219-1", chain: "Lidl", name: "Dresden Reick",
               street: "Reicker Str. 100", plz: "01219", city: "Dresden",
               lat: 51.0166, lon: 13.7727),
        Branch(marketId: "aldi-01219-1", chain: "Aldi", name: "Dresden Prohlis",
               street: "Prohliser Allee 10", plz: "01219", city: "Dresden",
               lat: 51.0011, lon: 13.7899),
        Branch(marketId: "1766063", chain: "REWE", name: "REWE Ketzscher oHG am Postplatz",
               street: "Wallstr. 2b", plz: "01067", city: "Dresden", lat: 51.0504, lon: 13.7317),
        Branch(marketId: "1766160", chain: "REWE", name: "REWE Friedrichstadt",
               street: "Friedrichstr. 7", plz: "01067", city: "Dresden", lat: 51.0561, lon: 13.7203),
        Branch(marketId: "4816", chain: "Netto", name: "Netto Marken-Discount Dresden-Strehlen",
               street: "Johannes-Paul-Thilman-Str. 3", plz: "01219", city: "Dresden",
               lat: 51.0155, lon: 13.7669),
    ]
}

struct MockOfferRepository: OfferRepositoryProtocol {
    var fixtures: [Offer] = MockFixtures.offers

    func offers(branchIds: [String]) async throws -> [Offer] {
        // Nationwide rows belong to every branch of their chain.
        fixtures.filter { $0.isNationwide || branchIds.contains($0.marketId ?? "") }
    }
}

struct MockPriceHistoryRepository: PriceHistoryRepositoryProtocol {
    var fixtures: [PriceHistoryPoint] = MockFixtures.priceHistory

    func history(market: String, product: String) async throws -> [PriceHistoryPoint] {
        fixtures.filter { $0.market == market && $0.product == product }
    }
}

struct MockBranchRepository: BranchRepositoryProtocol {
    var fixtures: [Branch] = MockFixtures.branches

    func nearby(lat: Double, lon: Double, radiusKm: Double) async throws -> [Branch] {
        fixtures
            .compactMap { branch -> (Branch, Double)? in
                guard let distance = branch.distanceKm(from: lat, lon), distance <= radiusKm
                else { return nil }
                return (branch, distance)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    func branch(marketId: String) async throws -> Branch? {
        fixtures.first { $0.marketId == marketId }
    }
}

/// Records requests instead of sending them, and can be told which stores the
/// backend already has — so tests can drive the wait state without a network.
final class MockBranchRequestRepository: BranchRequestRepositoryProtocol, @unchecked Sendable {
    /// Stores that already carry a `last_synced`.
    var ready: Set<String> = []
    /// Stores whose row exists but is still pending.
    var pending: Set<String> = []
    private(set) var requested: [String] = []

    func request(marketId: String) async throws -> BranchRequest? {
        if ready.contains(marketId) {
            return BranchRequest(marketId: marketId, lastSynced: "2026-07-25T16:56:48Z", active: true)
        }
        if pending.contains(marketId) || requested.contains(marketId) {
            return BranchRequest(marketId: marketId, lastSynced: nil, active: true)
        }
        return nil
    }

    func requestBranch(marketId: String) async throws {
        requested.append(marketId)
    }
}

/// Same shape as `MockBranchRequestRepository`, one level up: the area, not
/// the single store.
final class MockAreaRequestRepository: AreaRequestRepositoryProtocol, @unchecked Sendable {
    /// Anchors whose area run has finished.
    var ready: Set<String> = []
    /// Anchors whose row exists but whose run is still going.
    var pending: Set<String> = []
    private(set) var requested: [String] = []

    func request(marketId: String) async throws -> AreaRequest? {
        if ready.contains(marketId) {
            return AreaRequest(
                marketId: marketId, plz: "04639",
                lastSynced: "2026-07-26T08:36:50Z", active: true
            )
        }
        if pending.contains(marketId) || requested.contains(marketId) {
            return AreaRequest(marketId: marketId, plz: "04639", lastSynced: nil, active: true)
        }
        return nil
    }

    func requestArea(marketId: String) async throws {
        requested.append(marketId)
    }
}

struct MockMarketRepository: MarketRepositoryProtocol {
    var fixtures: [Market] = MockFixtures.markets

    func markets(plzs: [String]) async throws -> [Market] {
        fixtures.filter { plzs.contains($0.plz) }
    }
}

/// Records uploads instead of sending them, so tests can assert that a profile
/// without consent never reaches the network.
final class MockProfileRepository: ProfileRepositoryProtocol, @unchecked Sendable {
    private(set) var uploaded: [SyncedProfile] = []

    func upload(_ profile: SyncedProfile) async throws {
        uploaded.append(profile)
    }
}

/// Records reports instead of sending them, so tests can assert that skipping
/// the question — or switching it off — never reaches the network.
final class MockMatchFeedbackRepository: MatchFeedbackRepositoryProtocol, @unchecked Sendable {
    private(set) var submitted: [MatchFeedbackReport] = []

    func submit(_ report: MatchFeedbackReport) async throws {
        submitted.append(report)
    }
}

struct MockRegionRepository: RegionRepositoryProtocol {
    var fixtures: [Region] = [MockFixtures.region]

    func region(plz: String) async throws -> Region? {
        fixtures.first { $0.plz == plz }
    }

    func registerRegion(plz: String) async throws {}

    func foundMarkets(plz: String) async throws -> [Market] {
        MockFixtures.markets.filter { $0.plz == plz }
    }

}
