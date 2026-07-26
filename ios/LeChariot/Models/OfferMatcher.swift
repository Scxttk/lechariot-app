import Foundation

/// How a shopping-list entry matched an offer.
enum MatchKind: Equatable {
    /// Stage 1: the query tokens appear in the product title (typo-tolerant).
    case direct
    /// Stage 2: the query names a dictionary term and the offer carries that
    /// `match_key` tag from the backend import.
    case category
}

struct OfferMatch: Equatable, Identifiable {
    let offer: Offer
    let kind: MatchKind
    var id: String { offer.id }
}

/// Two-stage matching of free-text list entries against the cached offers.
///
/// Stage 1 (direct): every query token must hit a product-title token —
/// exactly, or with Levenshtein distance ≤ 1 when both tokens have ≥ 5
/// characters and different lengths (catches dropped letters and
/// singular/plural, but keeps short words strict so "Käse" never
/// fuzzy-matches "Kekse", and same-length words exact so "Butter" never
/// hits "Bitter").
///
/// Stage 2 (category): query tokens are compared against the offer's
/// `match_key` tags with the same token rule. The tags come from the backend
/// dictionary, which already blocks false composites (Tomatenmark carries no
/// "tomaten" tag), so tag equality is safe without extra filtering.
enum OfferMatcher {
    /// Lowercase, drop ®*™, hyphens and any non-letter → space. Umlauts stay.
    static func normalize(_ text: String) -> String {
        String(
            text.lowercased().map { ch in
                ch.isLetter ? ch : " "
            }
        )
    }

    static func tokens(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init).filter { $0.count >= 2 }
    }

    /// Token equality with typo tolerance for longer tokens. Fuzziness only
    /// applies when the lengths differ (a dropped or doubled letter, or
    /// singular/plural) — a same-length substitution turns one word into
    /// another ("Butter" is not "Bitter", real user report 2026-07-21).
    static func tokensMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard a.count >= 5, b.count >= 5, a.count != b.count else { return false }
        return levenshtein(a, b) <= 1
    }

    /// Plain Levenshtein distance; early-outs when lengths differ by > 1
    /// because callers only care about distance ≤ 1.
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        if abs(s.count - t.count) > 1 { return abs(s.count - t.count) }
        var prev = Array(0...t.count)
        var curr = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            curr[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[t.count]
    }

    /// All matches for a query, direct hits first, each stage sorted by price
    /// (offers without a price last). An offer appears at most once — a direct
    /// hit is never repeated as a category hit.
    static func matches(for query: String, in offers: [Offer]) -> [OfferMatch] {
        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return [] }

        var direct: [Offer] = []
        var category: [Offer] = []
        for offer in offers {
            let productTokens = tokens(offer.product)
            let isDirect = queryTokens.allSatisfy { q in
                productTokens.contains { tokensMatch(q, $0) }
            }
            if isDirect {
                direct.append(offer)
            } else if queryTokens.contains(where: { q in
                offer.matchKeys.contains { tokensMatch(q, $0) }
            }) {
                category.append(offer)
            }
        }

        func byPrice(_ lhs: Offer, _ rhs: Offer) -> Bool {
            let l = lhs.price ?? .infinity, r = rhs.price ?? .infinity
            if l != r { return l < r }
            // Same price: prefer the better base price when known.
            return (lhs.basePrice ?? .infinity) < (rhs.basePrice ?? .infinity)
        }
        return direct.sorted(by: byPrice).map { OfferMatch(offer: $0, kind: .direct) }
            + category.sorted(by: byPrice).map { OfferMatch(offer: $0, kind: .category) }
    }
}
