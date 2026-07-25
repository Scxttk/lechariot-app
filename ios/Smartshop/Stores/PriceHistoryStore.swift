import Foundation
import Observation

/// Drives the Preisverlauf section of the offer detail sheet: one fetch per
/// opened offer, no cache. The rows are tiny and the sheet is short-lived —
/// `URLSession`'s own caching is enough.
@MainActor
@Observable
final class PriceHistoryStore {
    enum State: Equatable {
        case idle
        case loading
        case loaded([PriceHistoryPoint])
        case failed(String)
    }

    private(set) var state: State = .idle

    private let repository: PriceHistoryRepositoryProtocol

    init(repository: PriceHistoryRepositoryProtocol) {
        self.repository = repository
    }

    /// The points worth showing, or nil when there is nothing to compare.
    ///
    /// A history of one week is not a history: with only the current week on
    /// record, a "Preisverlauf" section would be a heading over a single number
    /// the user is already looking at. The table is young, so this is the
    /// common case today — the section simply stays away until it has something
    /// to say.
    var points: [PriceHistoryPoint]? {
        guard case .loaded(let points) = state, points.count >= 2 else { return nil }
        return points
    }

    func load(for offer: Offer) async {
        state = .loading
        do {
            let raw = try await repository.history(
                market: offer.market,
                product: offer.product,
                region: offer.region
            )
            try Task.checkCancellation()
            state = .loaded(Self.oneRowPerWeek(raw))
        } catch {
            // Same rule as OfferStore: a dismissed sheet cancels the fetch, and
            // that is not a failure worth reporting.
            guard !LoadFailure.isCancellation(error) else { return }
            state = .failed(LoadFailure.message(for: error, subject: "Die Preisdaten"))
        }
    }

    /// Collapses a calendar week to a single row, oldest first.
    ///
    /// Keyed on the week, not on `valid_from`: Kaufland & co. record the week's
    /// flyer row (23.–29.7.) *and* the one-day "Knüller" row (24.7.) for the
    /// same product. Both are the same week, and listing "KW 30" twice at the
    /// same price is not a price history. The wider window wins — it is the one
    /// the offer list shows too.
    static func oneRowPerWeek(_ points: [PriceHistoryPoint]) -> [PriceHistoryPoint] {
        var byWeek: [DateComponents: PriceHistoryPoint] = [:]
        for point in points {
            let week = Calendar.supabase.dateComponents(
                [.yearForWeekOfYear, .weekOfYear], from: point.validFrom
            )
            guard let incumbent = byWeek[week] else {
                byWeek[week] = point
                continue
            }
            byWeek[week] = preferred(incumbent, point)
        }
        return byWeek.values.sorted { $0.validFrom < $1.validFrom }
    }

    private static func preferred(_ lhs: PriceHistoryPoint, _ rhs: PriceHistoryPoint) -> PriceHistoryPoint {
        // A row without a price says nothing about what the week cost.
        if (lhs.price == nil) != (rhs.price == nil) {
            return lhs.price != nil ? lhs : rhs
        }
        let width = (
            lhs.validUntil.timeIntervalSince(lhs.validFrom),
            rhs.validUntil.timeIntervalSince(rhs.validFrom)
        )
        if width.0 != width.1 { return width.0 > width.1 ? lhs : rhs }
        return lhs.validFrom <= rhs.validFrom ? lhs : rhs
    }
}
