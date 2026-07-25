import Foundation

/// Fixture-backed repositories for previews and tests.
enum MockFixtures {
    static let day = DateFormatter.supabaseDay

    static let offers: [Offer] = [
        Offer(
            market: "Lidl",
            product: "Bio Vollmilch",
            price: 0.99,
            regularPrice: 1.29,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: day.date(from: "2026-07-13")!,
            validUntil: day.date(from: "2026-07-19")!,
            basePrice: 0.99,
            baseUnit: "1 l",
            region: "01219"
        ),
        Offer(
            market: "Aldi",
            product: "Spanische Orangen",
            price: 2.49,
            regularPrice: nil,
            unit: "je 2 kg Netz",
            category: "Obst & Gemüse",
            emoji: "🍊",
            validFrom: day.date(from: "2026-07-13")!,
            validUntil: day.date(from: "2026-07-19")!,
            basePrice: 1.25,
            baseUnit: "1 kg",
            region: "01219"
        ),
    ]

    /// Three recorded weeks for the first offer fixture — enough for the
    /// detail sheet's price history to show up in previews and UI tests.
    static let priceHistory: [PriceHistoryPoint] = [
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", region: "01219",
            price: 1.29, regularPrice: 1.29,
            validFrom: day.date(from: "2026-06-29")!,
            validUntil: day.date(from: "2026-07-05")!
        ),
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", region: "01219",
            price: 1.19, regularPrice: 1.29,
            validFrom: day.date(from: "2026-07-06")!,
            validUntil: day.date(from: "2026-07-12")!
        ),
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", region: "01219",
            price: 0.99, regularPrice: 1.29,
            validFrom: day.date(from: "2026-07-13")!,
            validUntil: day.date(from: "2026-07-19")!
        ),
    ]

    static let markets: [Market] = [
        Market(chain: "Aldi", branchName: "Dresden Prohlis", marketId: "aldi-01219-1", plz: "01219"),
        Market(chain: "Lidl", branchName: "Dresden Reick", marketId: "lidl-01219-1", plz: "01219"),
    ]

    static let region = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)
}

struct MockOfferRepository: OfferRepositoryProtocol {
    var fixtures: [Offer] = MockFixtures.offers

    func offers(regions: [String]) async throws -> [Offer] {
        fixtures.filter { regions.contains($0.region) }
    }
}

struct MockPriceHistoryRepository: PriceHistoryRepositoryProtocol {
    var fixtures: [PriceHistoryPoint] = MockFixtures.priceHistory

    func history(market: String, product: String, region: String) async throws -> [PriceHistoryPoint] {
        fixtures.filter { $0.market == market && $0.product == product && $0.region == region }
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

    func offerCount(plz: String) async throws -> Int {
        MockFixtures.offers.filter { $0.region == plz }.count
    }
}
