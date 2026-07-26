import XCTest
@testable import LeChariot

@MainActor
final class MatchFeedbackStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var repository: MockMatchFeedbackRepository!

    override func setUp() {
        super.setUp()
        suiteName = "feedback.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        repository = MockMatchFeedbackRepository()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        repository = nil
        super.tearDown()
    }

    private func makeStore() -> MatchFeedbackStore {
        MatchFeedbackStore(repository: repository, defaults: defaults)
    }

    private func makeReport(reason: RejectionReason = .wrongProduct, comment: String = "") -> MatchFeedbackReport {
        MatchFeedbackReport(
            installId: UUID(),
            query: "Käse",
            offer: MockFixtures.offers[0],
            kind: .category,
            reason: reason,
            comment: comment
        )
    }

    // MARK: The switch

    /// The question is the only channel through which a wrong match is ever
    /// reported, so a fresh install has it on.
    func testAskingIsOnByDefault() {
        XCTAssertTrue(makeStore().isAskingEnabled)
    }

    func testTheChoiceSurvivesStoreRecreation() {
        let store = makeStore()
        store.isAskingEnabled = false

        XCTAssertFalse(makeStore().isAskingEnabled,
                       "'off' must not read back as the 'on' default")
    }

    /// The whole promise of the switch: off means nothing leaves the device,
    /// not merely that no sheet is shown.
    func testNothingIsUploadedWhileAskingIsOff() async {
        let store = makeStore()
        store.isAskingEnabled = false

        await store.submit(makeReport())

        XCTAssertTrue(repository.submitted.isEmpty)
    }

    func testSubmittingWhileOnUploadsExactlyOneReport() async {
        let store = makeStore()

        await store.submit(makeReport(reason: .wrongVariant))

        XCTAssertEqual(repository.submitted.count, 1)
        XCTAssertEqual(repository.submitted.first?.reason, "wrong_variant")
    }

    /// Without a configured backend (mock runs, missing API key) submitting is
    /// a no-op rather than a crash.
    func testSubmittingWithoutARepositoryIsSilent() async {
        let store = MatchFeedbackStore(repository: nil, defaults: defaults)
        await store.submit(makeReport())
        XCTAssertFalse(store.lastUploadFailed)
    }

    func testDebugResetTurnsAskingBackOn() {
        let store = makeStore()
        store.isAskingEnabled = false

        store.resetAllData()

        XCTAssertTrue(store.isAskingEnabled)
        XCTAssertNil(defaults.object(forKey: "feedback.askOnReject"),
                     "reset must leave no key of ours behind")
    }

    // MARK: The report

    /// The free-text field is optional; an empty or whitespace-only comment
    /// must not travel as an empty string.
    func testBlankCommentBecomesNil() {
        XCTAssertNil(makeReport(comment: "   \n ").comment)
        XCTAssertEqual(makeReport(comment: "  Schinken!  ").comment, "Schinken!")
    }

    /// The insert policy caps the comment server-side; truncating here means a
    /// long text loses its tail instead of the whole report being rejected.
    func testOverlongCommentIsTruncatedNotDropped() {
        let report = makeReport(comment: String(repeating: "a", count: 900))
        XCTAssertEqual(report.comment?.count, MatchFeedbackReport.maxCommentLength)
    }

    /// The reason strings are a database contract — the insert policy lists
    /// them literally and the evaluation groups by them.
    func testReasonRawValuesAreTheAgreedStrings() {
        XCTAssertEqual(
            RejectionReason.allCases.map(\.rawValue),
            ["wrong_product", "wrong_variant", "wrong_size", "personal_taste", "other"]
        )
    }

    func testMatchKindTravelsAsAStableString() {
        let direct = MatchFeedbackReport(
            installId: UUID(), query: "Käse", offer: MockFixtures.offers[0],
            kind: .direct, reason: .wrongSize, comment: ""
        )
        XCTAssertEqual(direct.matchKind, "direct")
        XCTAssertEqual(makeReport().matchKind, "category")
    }
}
