import XCTest
@testable import Smartshop

@MainActor
final class BranchRequestStoreTests: XCTestCase {
    private func store(
        _ repository: MockBranchRequestRepository,
        attempts: Int = 3
    ) -> BranchRequestStore {
        BranchRequestStore(
            repository: repository,
            pollInterval: .milliseconds(1),
            maxPollAttempts: attempts
        )
    }

    func testUnknownStoreIsRequestedAndThenPolled() async {
        let repo = MockBranchRequestRepository()
        let sut = store(repo)

        await sut.request("1763556")

        XCTAssertEqual(repo.requested, ["1763556"])
        // `.requested` = die Zeile ist geschrieben, gesehen hat der Poll sie
        // noch nicht. Erst der erste erfolgreiche Poll macht daraus `.syncing`.
        XCTAssertEqual(sut.state(for: "1763556"), .requested)
    }

    /// The trigger has a 10-minute cooldown per store: a second insert for the
    /// same id silently dispatches nothing. Asking first turns that into
    /// "already on its way" instead of waiting for a run that never started.
    func testAStoreThatIsAlreadyPendingIsNotRequestedAgain() async {
        let repo = MockBranchRequestRepository()
        repo.pending = ["1763556"]
        let sut = store(repo)

        await sut.request("1763556")

        XCTAssertTrue(repo.requested.isEmpty, "kein zweiter Insert für dieselbe Filiale")
        XCTAssertEqual(sut.state(for: "1763556"), .syncing)
    }

    func testAStoreTheBackendAlreadyHasNeedsNoWaiting() async {
        let repo = MockBranchRequestRepository()
        repo.ready = ["1766063"]
        let sut = store(repo)

        await sut.request("1766063")

        XCTAssertTrue(repo.requested.isEmpty)
        XCTAssertEqual(sut.state(for: "1766063"), .ready)
        XCTAssertTrue(sut.isReady("1766063"))
    }

    func testPollingReachesReadyOnceTheOffersArrive() async {
        let repo = MockBranchRequestRepository()
        let sut = store(repo, attempts: 20)

        await sut.request("1763556")
        // The backend finishes while the poll loop runs.
        repo.ready = ["1763556"]
        await sut.waitForPolling("1763556")

        XCTAssertEqual(sut.state(for: "1763556"), .ready)
    }

    func testPollingGivesUpInsteadOfSpinningForever() async {
        let repo = MockBranchRequestRepository()
        let sut = store(repo, attempts: 2)

        await sut.request("1763556")
        await sut.waitForPolling("1763556")

        XCTAssertEqual(sut.state(for: "1763556"), .failed(.timedOut))
    }

    func testANetworkFailureIsReportedInsteadOfLookingLikeProgress() async {
        struct Failing: BranchRequestRepositoryProtocol {
            struct Boom: Error {}
            func request(marketId: String) async throws -> BranchRequest? { throw Boom() }
            func requestBranch(marketId: String) async throws { throw Boom() }
        }
        let sut = BranchRequestStore(repository: Failing(), pollInterval: .milliseconds(1))

        await sut.request("1763556")

        XCTAssertEqual(sut.state(for: "1763556"), .failed(.network))
    }

    func testCancellingStopsThePolling() async {
        let repo = MockBranchRequestRepository()
        let sut = store(repo, attempts: 100)

        await sut.request("1763556")
        sut.cancelPolling(for: "1763556")
        await sut.waitForPolling("1763556")

        // Neither ready nor timed out — the loop was stopped, not exhausted.
        XCTAssertEqual(sut.state(for: "1763556"), .requested)
    }

    func testDecodesTheRequestRow() throws {
        let json = """
        {"market_id":"1763556","last_synced":null,"active":true}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(BranchRequest.self, from: json)
        XCTAssertEqual(row.marketId, "1763556")
        XCTAssertFalse(row.isReady)

        let done = """
        {"market_id":"1763556","last_synced":"2026-07-25T16:56:48Z","active":true}
        """.data(using: .utf8)!
        XCTAssertTrue(try JSONDecoder().decode(BranchRequest.self, from: done).isReady)
    }
}
