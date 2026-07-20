import Foundation
import Observation

/// Local source of truth for the user's onboarding answers.
///
/// Persistence: UserDefaults, same rationale as RegionStore and
/// ShoppingListStore — one small Codable value, no queries or relations.
///
/// The device copy is always complete. Only `SyncedProfile` goes to the
/// backend, and only after the user opted in on the consent step; without
/// consent `sync()` is a no-op and nothing ever leaves the phone.
@MainActor
@Observable
final class ProfileStore {
    private(set) var profile: UserProfile

    private let repository: ProfileRepositoryProtocol?
    private let defaults: UserDefaults
    private static let key = "profile.user"

    init(repository: ProfileRepositoryProtocol? = nil, defaults: UserDefaults = AppDefaults.shared) {
        self.repository = repository
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = stored
        } else {
            // First launch: mint the install id once and keep it from here on.
            self.profile = UserProfile()
            persist()
        }
    }

    // MARK: Derived

    /// Greeting name, empty when the user skipped the question.
    var greetingName: String { profile.firstName }

    var hasConsented: Bool { profile.hasConsentedToSync }

    // MARK: Edits

    func setFirstName(_ name: String) {
        profile.firstName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func setHousehold(size: Int) {
        profile.householdSize = max(1, min(size, 10))
        persist()
    }

    func setRhythm(_ rhythm: ShoppingRhythm) {
        profile.rhythm = rhythm
        persist()
    }

    func setBudget(_ budget: BudgetBracket?) {
        profile.budget = budget
        persist()
    }

    func toggleDietTag(_ tag: DietTag) {
        if profile.dietTags.contains(tag) {
            profile.dietTags.remove(tag)
        } else {
            profile.dietTags.insert(tag)
        }
        persist()
    }

    func setConsent(_ consented: Bool) {
        profile.hasConsentedToSync = consented
        persist()
    }

    func markQuestionsCompleted() {
        profile.hasCompletedQuestions = true
        persist()
    }

    // MARK: Sync

    /// Sends the non-identifying answers to the backend. Silent no-op without
    /// consent or without a configured repository. Failures are swallowed on
    /// purpose: a profile that did not upload must never block the user from
    /// getting into the app.
    func sync(plz: String?) async {
        guard profile.hasConsentedToSync, let repository else { return }
        try? await repository.upload(SyncedProfile(profile: profile, plz: plz))
    }

    // MARK: Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.key)
        }
    }

    #if DEBUG
    /// See `DebugReset`. Mints a **new** install id on purpose: a reset is meant
    /// to look like a different device, otherwise repeated test runs all land on
    /// the same `install_id` in Supabase and the rows are indistinguishable.
    func resetAllData() {
        defaults.removeObject(forKey: Self.key)
        profile = UserProfile()
        persist()
    }
    #endif
}
