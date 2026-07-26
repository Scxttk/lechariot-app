import XCTest
@testable import LeChariot

@MainActor
final class ProfileStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "profile.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: Persistence

    func testAnswersSurviveStoreRecreation() {
        let store = ProfileStore(defaults: defaults)
        store.setFirstName("  Scott  ")
        store.setHousehold(size: 3)
        store.setRhythm(.once)
        store.setBudget(.upTo60)
        store.toggleDietTag(.vegetarisch)
        store.toggleDietTag(.bio)

        let reopened = ProfileStore(defaults: defaults)
        XCTAssertEqual(reopened.profile.firstName, "Scott", "Whitespace must be trimmed on save")
        XCTAssertEqual(reopened.profile.householdSize, 3)
        XCTAssertEqual(reopened.profile.rhythm, .once)
        XCTAssertEqual(reopened.profile.budget, .upTo60)
        XCTAssertEqual(reopened.profile.dietTags, [.vegetarisch, .bio])
    }

    /// The install id is the only key the backend rows hang on — a new one on
    /// every launch would make every profile look like a new user.
    func testInstallIdIsStableAcrossRecreation() {
        let first = ProfileStore(defaults: defaults).profile.installId
        let second = ProfileStore(defaults: defaults).profile.installId
        XCTAssertEqual(first, second)
    }

    func testHouseholdSizeIsClamped() {
        let store = ProfileStore(defaults: defaults)
        store.setHousehold(size: 0)
        XCTAssertEqual(store.profile.householdSize, 1)
        store.setHousehold(size: 99)
        XCTAssertEqual(store.profile.householdSize, 10)
    }

    func testDietTagTogglesOff() {
        let store = ProfileStore(defaults: defaults)
        store.toggleDietTag(.vegan)
        XCTAssertTrue(store.profile.dietTags.contains(.vegan))
        store.toggleDietTag(.vegan)
        XCTAssertFalse(store.profile.dietTags.contains(.vegan))
    }

    // MARK: Consent gate

    func testWithoutConsentNothingIsUploaded() async {
        let repository = MockProfileRepository()
        let store = ProfileStore(repository: repository, defaults: defaults)
        store.setHousehold(size: 4)

        await store.sync(plz: "01219")

        XCTAssertTrue(repository.uploaded.isEmpty, "No consent must mean no network call at all")
    }

    func testWithConsentTheAnswersAreUploaded() async {
        let repository = MockProfileRepository()
        let store = ProfileStore(repository: repository, defaults: defaults)
        store.setHousehold(size: 4)
        store.setRhythm(.often)
        store.setBudget(.upTo100)
        store.toggleDietTag(.vegan)
        store.setConsent(true)

        await store.sync(plz: "01219")

        XCTAssertEqual(repository.uploaded.count, 1)
        let sent = repository.uploaded[0]
        XCTAssertEqual(sent.householdSize, 4)
        XCTAssertEqual(sent.tripsPerWeek, 3)
        XCTAssertEqual(sent.weeklyBudget, 100)
        XCTAssertEqual(sent.dietTags, ["vegan"])
        XCTAssertEqual(sent.plz, "01219")
        XCTAssertEqual(sent.installId, store.profile.installId)
    }

    /// The first name is the only directly identifying answer and must never be
    /// part of the payload — that is what keeps the stored rows pseudonymous.
    func testFirstNameNeverLeavesTheDevice() throws {
        var profile = UserProfile()
        profile.firstName = "Scott"
        let payload = SyncedProfile(profile: profile, plz: "01219")

        let json = try JSONEncoder().encode(payload)
        let text = try XCTUnwrap(String(data: json, encoding: .utf8))
        XCTAssertFalse(text.contains("Scott"))
        XCTAssertFalse(text.lowercased().contains("name"))
    }

    func testSkippedBudgetEncodesAsNull() throws {
        var profile = UserProfile()
        profile.budget = nil
        let payload = SyncedProfile(profile: profile, plz: nil)
        XCTAssertNil(payload.weeklyBudget)
        XCTAssertNil(payload.plz)
    }

    func testDietTagsAreSortedForStablePayloads() {
        var profile = UserProfile()
        profile.dietTags = [.vegan, .bio, .glutenfrei]
        let first = SyncedProfile(profile: profile, plz: nil).dietTags
        let second = SyncedProfile(profile: profile, plz: nil).dietTags
        XCTAssertEqual(first, second)
        XCTAssertEqual(first, first.sorted())
    }
}
