import Foundation

/// Where a price came from and when — one line, under every offer.
///
/// **Why this rather than a link to the chain's own flyer page.** That was the
/// first idea (2026-07-30) and it does not survive contact with the eight
/// scrapers: EDEKA and both ALDIs could carry a per-offer link today, Kaufland
/// has no stable target at all, REWE and Netto expose only an article number,
/// and Lidl's prices come out of an 83 MB PDF. Netto is worse than missing —
/// its branch binding rides on a cookie, so the link would show whichever
/// branch the browser last saw, quite possibly at a different price. **A
/// receipt that contradicts the price above it is worse than no receipt**, and
/// a link that appears under three chains of six reads as a bug rather than as
/// honesty. Scott's decision (2026-07-31): one line, every chain, same shape.
///
/// What the line can promise is bounded by what the row actually knows, and
/// that was measured against the live table rather than assumed:
///
/// - `created_at` is per **branch and week**: all 335 Lidl rows of branch
///   `LIDL_5745` for the week from 27.07. share one minute, `10:22`. It is the
///   run that wrote them, so "abgerufen" is a word the data supports.
/// - It can be **days** old. EDEKA's newest row on 2026-07-31 was written
///   2026-07-27 17:23 UTC, for offers still valid until 01.08. That is not a
///   fault — nothing re-fetched them — but it is the reason the bare
///   `abgerufen 06:30` from the backlog is not enough: a time with no date
///   reads as today. Older than today, the line says the day too.
/// - It is **UTC**. 10:22 in the row is 12:22 in Dresden. A line that prints
///   the raw hour is off by two in summer, which is exactly the kind of quiet
///   wrongness this line exists to avoid.
enum OfferProvenance {

    /// Berlin, because that is where the offers are and where the person
    /// reading the line is standing.
    static let zone = TimeZone(identifier: "Europe/Berlin") ?? .current

    /// The `created_at` string as an instant, or nil if it is missing or not a
    /// timestamp we understand.
    ///
    /// Two formats on purpose: PostgREST emits fractional seconds
    /// (`…T10:21:43.85504+00:00`), but a row written at a whole second has none
    /// (`…T10:21:43+00:00`), and `.withInternetDateTime` alone rejects the
    /// first while `.withFractionalSeconds` rejects the second.
    static func fetchedAt(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return withFraction.date(from: raw) ?? plain.date(from: raw)
    }

    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// "Netto · gültig bis Sa 02.08. · abgerufen 06:30"
    ///
    /// - Parameter now: the reference for "today". A parameter rather than
    ///   `.now` so the same line can be checked at a fixed date.
    static func line(
        market: String,
        validUntil: Date,
        fetchedAt: Date?,
        now: Date = .now
    ) -> String {
        var parts = [market, "gültig bis \(dayShort.string(from: validUntil))"]
        if let fetchedAt {
            parts.append("abgerufen \(fetchedText(fetchedAt, now: now))")
        }
        // Kein „abgerufen unbekannt" als dritter Teil: Eine Zeile, die ihre
        // eigene Unwissenheit ausstellt, ist für den Leser nutzlos und für den
        // Entwickler ein Grund, sie zu füllen — mit irgendetwas.
        return parts.joined(separator: " · ")
    }

    /// Time alone while it is still the same day, day and time otherwise.
    ///
    /// Der Vergleich läuft über den **Berliner** Kalendertag, nicht über
    /// „weniger als 24 Stunden her": Um 00:30 ist ein Abruf von gestern 23:50
    /// vierzig Minuten alt und trotzdem von gestern, und genau das soll die
    /// Zeile sagen.
    private static func fetchedText(_ date: Date, now: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        if calendar.isDate(date, inSameDayAs: now) {
            return clock.string(from: date)
        }
        return "\(dayShort.string(from: date)) \(clock.string(from: date))"
    }

    /// "Sa 02.08."
    private static let dayShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = zone
        f.dateFormat = "EE dd.MM."
        return f
    }()

    /// "06:30"
    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = zone
        f.dateFormat = "HH:mm"
        return f
    }()
}

extension Offer {
    /// When the run that wrote this row fetched it, if the row says so.
    var fetchedAt: Date? { OfferProvenance.fetchedAt(createdAt) }

    /// The origin line for this offer.
    func provenanceLine(now: Date = .now) -> String {
        OfferProvenance.line(
            market: market, validUntil: validUntil, fetchedAt: fetchedAt, now: now
        )
    }
}
