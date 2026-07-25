import XCTest
@testable import Smartshop

/// The branch ids added to `user_profiles` in migration v15, and the one thing
/// that must never drift from them: the consent copy.
final class ProfileBranchTests: XCTestCase {
    private var profile: UserProfile {
        var profile = UserProfile()
        profile.firstName = "Scott"
        profile.householdSize = 2
        return profile
    }

    func testBranchIdsAreEncodedUnderTheColumnName() throws {
        let synced = SyncedProfile(
            profile: profile, plz: "01067", branchIds: ["1766063", "4816"]
        )
        let json = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(synced)
        ) as? [String: Any]
        XCTAssertEqual(json?["branch_ids"] as? [String], ["1766063", "4816"])
    }

    /// Sorted, so two identical profiles serialize identically — same rule the
    /// diet tags already follow.
    func testBranchIdsAreSorted() {
        let synced = SyncedProfile(profile: profile, plz: nil, branchIds: ["4816", "1766063"])
        XCTAssertEqual(synced.branchIds, ["1766063", "4816"])
    }

    func testWithoutBranchesTheListIsEmptyNotMissing() throws {
        let synced = SyncedProfile(profile: profile, plz: "01067")
        XCTAssertEqual(synced.branchIds, [])
    }

    /// The first name is the one directly identifying field and stays on the
    /// device — that is what keeps everything that does leave pseudonymous.
    /// Adding branches to the upload must not have loosened it.
    func testTheFirstNameStillNeverLeavesTheDevice() throws {
        let synced = SyncedProfile(profile: profile, plz: "01067", branchIds: ["1766063"])
        let data = try JSONEncoder().encode(synced)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("Scott"), "Vorname im Upload: \(text)")
        XCTAssertFalse(text.contains("first"), "Vorname-Feld im Upload: \(text)")
    }
}
