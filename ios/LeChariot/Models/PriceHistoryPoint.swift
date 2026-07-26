import Foundation

/// Row of the Supabase `price_history` table: one recorded offer week for one
/// product at one market in one region. Written by the backend on every push
/// (see migration_v7), read here to show what the product cost before.
///
/// `recorded_at` is deliberately absent: it is a `timestamptz`, and
/// `JSONDecoder.supabase` only parses "yyyy-MM-dd" — decoding it would fail
/// the whole row. The repository selects columns explicitly so a later
/// `select=*` can never quietly reintroduce it.
struct PriceHistoryPoint: Codable, Equatable, Identifiable {
    let market: String
    let product: String
    /// Country-wide instead of at one branch — same meaning as
    /// `Offer.nationwide`, and written by the same push.
    var nationwide: Bool? = nil
    let price: Double?
    let regularPrice: Double?
    /// Non-optional although the column is nullable: the query filters
    /// `not.is.null`, and `FailableElement` drops whatever still slips through.
    let validFrom: Date
    let validUntil: Date

    var id: String { "\(market)|\(product)|\(validFrom.timeIntervalSince1970)" }

    /// Calendar week of the offer window, for the row label.
    var weekOfYear: Int {
        Calendar.supabase.component(.weekOfYear, from: validFrom)
    }

    var windowText: String {
        let from = DateFormatter.offerDay.string(from: validFrom)
        let until = DateFormatter.offerDay.string(from: validUntil)
        return "\(from) – \(until)"
    }

    enum CodingKeys: String, CodingKey {
        case market, product, nationwide, price
        case regularPrice = "regular_price"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
    }
}
