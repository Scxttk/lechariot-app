import Foundation

/// Dietary preferences a user can flag during onboarding. Raw values are the
/// strings that land in the Supabase `diet_tags` column — never rename one
/// without a data migration.
enum DietTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case vegetarisch, vegan, keinSchwein, bio, laktosefrei, glutenfrei

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vegetarisch: "Vegetarisch"
        case .vegan: "Vegan"
        case .keinSchwein: "Kein Schwein"
        case .bio: "Bio ist mir wichtig"
        case .laktosefrei: "Laktosefrei"
        case .glutenfrei: "Glutenfrei"
        }
    }

    /// Das Zeichen des Chips im Ernährungsprofil.
    ///
    /// **Jeder Name hier muss ein echtes SF Symbol sein.** `Image(systemName:)`
    /// zeichnet bei einem unbekannten Namen **nichts** und sagt nichts — der
    /// Chip steht dann ohne Bild da, und niemandem fällt auf, warum. Genau das
    /// ist mit `glutenfrei` passiert: Dort stand `wheat`, und ein solches
    /// Symbol gibt es nicht (Scott, 08.08.: „glutenfrei has no drawing??" —
    /// nachgezählt: 0 von 8302 Namen des Katalogs). Der Wächter dagegen ist
    /// `DietSymbolTests`.
    ///
    /// `allergens` statt einer Ähre: Eine Ähre gibt der Katalog nicht her, und
    /// „Allergene" ist die Sache, um die es bei glutenfrei geht.
    var symbol: String {
        switch self {
        case .vegetarisch: "carrot"
        case .vegan: "leaf"
        case .keinSchwein: "xmark.circle"
        case .bio: "sparkles"
        case .laktosefrei: "drop"
        case .glutenfrei: "allergens"
        }
    }
}

/// How often someone shops in a normal week. Coarse buckets on purpose — nobody
/// counts, and the exact number would not change anything we do with it.
enum ShoppingRhythm: Int, Codable, CaseIterable, Identifiable, Sendable {
    case once = 1, twice = 2, often = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .once: "1×"
        case .twice: "2×"
        case .often: "3× oder öfter"
        }
    }
}

/// Weekly grocery budget as a bucket. Stored as the bucket's upper bound in
/// euros; `nil` means the user skipped the question.
enum BudgetBracket: Int, Codable, CaseIterable, Identifiable, Sendable {
    case upTo30 = 30, upTo60 = 60, upTo100 = 100, above100 = 101

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .upTo30: "bis 30 €"
        case .upTo60: "30–60 €"
        case .upTo100: "60–100 €"
        case .above100: "über 100 €"
        }
    }
}

/// What the user told us during onboarding.
///
/// `firstName` is deliberately **not** part of `SyncedProfile` below: it is the
/// only directly identifying field, it exists purely to greet the user on the
/// list screen, and keeping it on the device is what makes everything that does
/// leave the phone pseudonymous.
struct UserProfile: Codable, Equatable, Sendable {
    /// Random per-installation id. Not derived from any device identifier, so
    /// it cannot be correlated with anything outside this app.
    var installId: UUID = UUID()
    var firstName: String = ""
    var householdSize: Int = 1
    var rhythm: ShoppingRhythm = .twice
    var budget: BudgetBracket?
    var dietTags: Set<DietTag> = []
    /// True only after the user actively opted in on the consent step.
    var hasConsentedToSync = false
    /// Set once the onboarding questionnaire has been walked through, so a
    /// later re-entry (e.g. user removed their last branch) skips it.
    var hasCompletedQuestions = false
}

/// The subset that is allowed to leave the device, shaped for the Supabase
/// `user_profiles` table. Insert-only: each save appends a row, the newest row
/// per `install_id` wins. See supabase/migration_user_profiles.sql.
struct SyncedProfile: Encodable, Equatable, Sendable {
    let installId: UUID
    let householdSize: Int
    let tripsPerWeek: Int
    let weeklyBudget: Int?
    let dietTags: [String]
    let plz: String?
    /// Ids of the branches the user picked (migration v15). Sorted, so two
    /// identical profiles serialize identically. Empty when nothing is picked.
    ///
    /// This reverses the original "never transmitted" rule for branches, and
    /// only for branches — first name and shopping list stay on the device.
    /// A branch id is more precise than a PLZ, but `plz` has been in this
    /// table from the start and three branches in one postcode say little
    /// more than the postcode does.
    let branchIds: [String]

    enum CodingKeys: String, CodingKey {
        case installId = "install_id"
        case householdSize = "household_size"
        case tripsPerWeek = "trips_per_week"
        case weeklyBudget = "weekly_budget"
        case dietTags = "diet_tags"
        case plz
        case branchIds = "branch_ids"
    }

    init(profile: UserProfile, plz: String?, branchIds: [String] = []) {
        self.installId = profile.installId
        self.householdSize = profile.householdSize
        self.tripsPerWeek = profile.rhythm.rawValue
        self.weeklyBudget = profile.budget?.rawValue
        // Sorted so two identical profiles serialize identically.
        self.dietTags = profile.dietTags.map(\.rawValue).sorted()
        self.plz = plz
        self.branchIds = branchIds.sorted()
    }
}
