import Foundation

/// Why a matched offer was rejected.
///
/// The whole point of asking is this distinction: a rejection can mean *the
/// match is wrong* (a dictionary error — "Käse" matching a ham-and-cheese
/// croissant) or *the match is right but I don't want it* (taste, brand,
/// quantity). Only the first kind may ever reach the dictionary; feeding the
/// second kind back would poison it with one person's preferences.
///
/// Raw values land in the Supabase `reason` column — never rename one without
/// a data migration.
enum RejectionReason: String, CaseIterable, Identifiable, Sendable {
    /// Dictionary error: the product is not the thing the user asked for.
    /// → the offending token belongs on the term's block list.
    case wrongProduct = "wrong_product"
    /// Right family, wrong kind. → block, or a new finer term of its own.
    case wrongVariant = "wrong_variant"
    /// Right product, useless amount. → no dictionary change; a quantity
    /// problem, tracked separately in the backlog.
    case wrongSize = "wrong_size"
    /// Right product, personal preference. → no dictionary change ever.
    case personalTaste = "personal_taste"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wrongProduct: "Passt gar nicht zum Artikel"
        case .wrongVariant: "Falsche Sorte oder Variante"
        case .wrongSize: "Falsche Menge oder Größe"
        case .personalTaste: "Mag ich einfach nicht"
        case .other: "Anderes"
        }
    }

    /// One line telling the user what the option means, so the two kinds of
    /// rejection are actually distinguishable while tapping.
    var hint: String {
        switch self {
        case .wrongProduct: "Ein ganz anderes Produkt"
        case .wrongVariant: "Richtige Warengruppe, falsches Produkt"
        case .wrongSize: "Zu groß, zu klein, falsche Packung"
        case .personalTaste: "Passt schon, will ich aber nicht"
        case .other: "Sag uns gern, was los ist"
        }
    }

    var symbol: String {
        switch self {
        case .wrongProduct: "xmark.circle"
        case .wrongVariant: "arrow.triangle.branch"
        case .wrongSize: "ruler"
        case .personalTaste: "hand.thumbsdown"
        case .other: "ellipsis.circle"
        }
    }
}

/// One rejection, shaped for the Supabase `match_feedback` table. Insert-only,
/// like `SyncedProfile` — see supabase/migration_match_feedback.sql.
///
/// Carries no personal data beyond the random `install_id`: the search word is
/// what the user typed on their list, the rest describes the offer. `comment`
/// is free text the user wrote, which is why the sheet says out loud that it
/// gets sent.
struct MatchFeedbackReport: Encodable, Equatable, Sendable {
    let installId: UUID
    /// The word from the shopping list that produced the match.
    let query: String
    let productTitle: String
    let market: String
    /// "direct" or "category" — a wrong category hit points at a different
    /// dictionary entry than a wrong direct hit.
    let matchKind: String
    let reason: String
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case installId = "install_id"
        case query
        case productTitle = "product_title"
        case market
        case matchKind = "match_kind"
        case reason
        case comment
    }

    /// Longer text is truncated rather than rejected: the insert policy caps it
    /// server-side, and losing the tail beats losing the whole report.
    static let maxCommentLength = 500

    init(
        installId: UUID,
        query: String,
        offer: Offer,
        kind: MatchKind,
        reason: RejectionReason,
        comment: String
    ) {
        self.installId = installId
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.productTitle = offer.product
        self.market = offer.market
        self.matchKind = kind == .direct ? "direct" : "category"
        self.reason = reason.rawValue
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        self.comment = trimmed.isEmpty ? nil : String(trimmed.prefix(Self.maxCommentLength))
    }
}
