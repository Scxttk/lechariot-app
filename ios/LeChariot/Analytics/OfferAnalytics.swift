import Foundation

/// Pure computation over loaded offers, no side effects (pattern: OfferQuery).
///
/// This used to back an Analyse tab full of bar charts (offers per market,
/// average discount, category breakdown). Those answered questions about the
/// dataset, not about the user's week, so the tab and its aggregates are gone —
/// `git log` has them if a future dashboard needs them back. What survived is
/// the one aggregate a shopper actually uses.
enum OfferAnalytics {
    /// The biggest discounts of the week, deepest first — **ohne die
    /// Aktionsware in der Mitte des Ladens.**
    ///
    /// Bis zum 06.08. stand hier nur „nach Rabatt sortieren", und der
    /// Bildschirm eröffnete mit Kindersessel, Auflaufform und Werkstattfeilen:
    /// Die ersten dreißig Plätze trugen kein einziges Lebensmittel. Nach
    /// Prozent gewinnt ein Artikel, der von 24,99 € auf 2,99 € fällt, immer
    /// gegen einen Joghurt. Welche Kategorien das sind und woran das gemessen
    /// wurde, steht bei `Categories.middleAisle`.
    ///
    /// **Der Filter sitzt hier und nicht in der Sortierung.** Wer im
    /// Angebote-Tab bewusst auf „Deals" umschaltet oder nach „Bohrmaschine"
    /// sucht, bekommt weiter alles — `OfferQuery` bleibt unverändert. Was hier
    /// entschieden wird, ist nur, womit der Bildschirm **von sich aus**
    /// anfängt.
    static func topDeals(_ offers: [Offer], limit: Int = 10) -> [Offer] {
        offers
            .filter { $0.discountPercent != nil }
            .filter { !Categories.middleAisle.contains($0.category.trimmingCharacters(in: .whitespaces)) }
            .sorted { ($0.discountPercent ?? 0, $1.product) > ($1.discountPercent ?? 0, $0.product) }
            .prefix(limit)
            .map { $0 }
    }
}
