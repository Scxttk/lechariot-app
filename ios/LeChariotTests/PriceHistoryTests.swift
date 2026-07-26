import XCTest
@testable import LeChariot

private struct StubPriceHistoryRepository: PriceHistoryRepositoryProtocol {
    var result: Result<[PriceHistoryPoint], Error> = .success([])

    func history(market: String, product: String) async throws -> [PriceHistoryPoint] {
        try result.get()
    }
}

private struct StubError: LocalizedError {
    var errorDescription: String? { "kaputt" }
}

final class PriceHistoryDecodingTests: XCTestCase {
    private let decoder = JSONDecoder.supabase

    /// `recorded_at` is a timestamptz that `JSONDecoder.supabase` cannot parse.
    /// The query leaves it out — this pins that a row still decodes if someone
    /// widens the select, so the failure would be visible instead of silent.
    func testDecodeIgnoresRecordedAt() throws {
        let json = """
        [{
            "market": "Kaufland",
            "product": "SALZBURGMILCH Bergkäse",
            "region": "01219",
            "price": 1.99,
            "regular_price": 2.99,
            "valid_from": "2026-07-23",
            "valid_until": "2026-07-29",
            "recorded_at": "2026-07-23T06:26:17.675610+00:00"
        }]
        """.data(using: .utf8)!

        let points = try decoder.decode([PriceHistoryPoint].self, from: json)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].market, "Kaufland")
        XCTAssertEqual(points[0].price, 1.99)
        XCTAssertEqual(points[0].regularPrice, 2.99)
        XCTAssertEqual(DateFormatter.supabaseDay.string(from: points[0].validFrom), "2026-07-23")
        XCTAssertEqual(points[0].windowText, "23.7. – 29.7.")
        XCTAssertEqual(points[0].weekOfYear, 30)
    }

    func testDecodeAcceptsNullPrices() throws {
        let json = """
        {
            "market": "Lidl", "product": "Haltbare Milch", "region": "01219",
            "price": null, "regular_price": null,
            "valid_from": "2026-07-20", "valid_until": "2026-07-25"
        }
        """.data(using: .utf8)!

        let point = try decoder.decode(PriceHistoryPoint.self, from: json)

        XCTAssertNil(point.price)
        XCTAssertNil(point.regularPrice)
    }

    /// Every column of the table is nullable. A row without a validity window
    /// says nothing about a week, and must not sink the surrounding array.
    func testRowWithoutValidFromIsSkippedInsteadOfFailingTheFetch() throws {
        let json = """
        [
            {"market": "Lidl", "product": "Milch", "region": "01219", "price": 0.99,
             "regular_price": null, "valid_from": null, "valid_until": "2026-07-25"},
            {"market": "Lidl", "product": "Milch", "region": "01219", "price": 0.88,
             "regular_price": null, "valid_from": "2026-07-27", "valid_until": "2026-08-01"}
        ]
        """.data(using: .utf8)!

        let rows = try decoder.decode([FailableElement<PriceHistoryPoint>].self, from: json)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.compactMap(\.value).count, 1)
    }
}

final class SupabaseFilterValueTests: XCTestCase {
    /// The client concatenates its URLs, so an unencoded product name throws
    /// `invalidURL` before the request is even sent.
    func testFilterValueSurvivesInAURL() throws {
        for raw in [
            "Bio Vollmilch 3,5 % Fett & mehr +1",
            "Käse & Zwiebeln",
            "ESMARA® Damen Hose, Wide Leg",
            "K-CLASSIC Gouda jung",
        ] {
            let encoded = try XCTUnwrap(SupabaseClient.filterValue(raw), raw)
            XCTAssertNotNil(
                URL(string: "https://example.supabase.co/rest/v1/price_history?product=eq.\(encoded)"),
                "\(raw) must survive URL construction"
            )
            for forbidden in [" ", "&", "=", "+", ",", "(", ")", "/"] {
                XCTAssertFalse(encoded.contains(forbidden), "\(forbidden) must be encoded in \(raw)")
            }
        }
    }

    func testFilterValueLeavesHarmlessTextAlone() {
        XCTAssertEqual(SupabaseClient.filterValue("Kaufland"), "Kaufland")
        XCTAssertEqual(SupabaseClient.filterValue("01219"), "01219")
    }
}

@MainActor
final class PriceHistoryStoreTests: XCTestCase {
    private func point(_ from: String, _ until: String, price: Double?) -> PriceHistoryPoint {
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: price, regularPrice: 1.29,
            validFrom: MockFixtures.day.date(from: from)!,
            validUntil: MockFixtures.day.date(from: until)!
        )
    }

    /// One recorded week is nothing to compare against — the section stays away
    /// rather than putting a heading over a number the user is already reading.
    func testASinglePointHidesTheSection() async {
        let store = PriceHistoryStore(
            repository: StubPriceHistoryRepository(
                result: .success([point("2026-07-13", "2026-07-19", price: 0.99)])
            )
        )

        await store.load(for: MockFixtures.offers[0])

        XCTAssertNil(store.points)
    }

    func testTwoPointsAreExposedOldestFirst() async {
        let store = PriceHistoryStore(
            repository: StubPriceHistoryRepository(result: .success([
                point("2026-07-13", "2026-07-19", price: 0.99),
                point("2026-07-06", "2026-07-12", price: 1.19),
            ]))
        )

        await store.load(for: MockFixtures.offers[0])

        XCTAssertEqual(store.points?.map(\.price), [1.19, 0.99])
    }

    /// Kaufland records the week's flyer row and the one-day "Knüller" row for
    /// the same product. They start on different days but are the same week —
    /// listing "KW 29" twice at the same price is not a price history.
    func testTheWeekRowAndTheOneDayRowOfAWeekCollapse() async {
        let store = PriceHistoryStore(
            repository: StubPriceHistoryRepository(result: .success([
                point("2026-07-13", "2026-07-19", price: 0.99),
                point("2026-07-16", "2026-07-16", price: 0.99),
                point("2026-07-06", "2026-07-12", price: 1.19),
            ]))
        )

        await store.load(for: MockFixtures.offers[0])

        XCTAssertEqual(store.points?.count, 2)
        // The week row survives — the same one the offer list shows.
        XCTAssertEqual(
            store.points?.last.map { DateFormatter.supabaseDay.string(from: $0.validUntil) },
            "2026-07-19"
        )
    }

    /// The rows of a week can arrive without a price; then the one that has a
    /// price is the one worth keeping.
    func testAWeekRowWithoutAPriceLosesToOneWithAPrice() {
        let result = PriceHistoryStore.oneRowPerWeek([
            point("2026-07-13", "2026-07-19", price: nil),
            point("2026-07-16", "2026-07-16", price: 0.99),
        ])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.price, 0.99)
    }

    func testEmptyHistoryIsLoadedButHidden() async {
        let store = PriceHistoryStore(repository: StubPriceHistoryRepository(result: .success([])))

        await store.load(for: MockFixtures.offers[0])

        XCTAssertEqual(store.state, .loaded([]))
        XCTAssertNil(store.points)
    }

    func testFailureProducesAGermanMessageWithoutInternals() async {
        let store = PriceHistoryStore(
            repository: StubPriceHistoryRepository(result: .failure(StubError()))
        )

        await store.load(for: MockFixtures.offers[0])

        guard case .failed(let message) = store.state else {
            return XCTFail("expected a failed state, got \(store.state)")
        }
        XCTAssertFalse(message.contains("kaputt"))
        XCTAssertTrue(message.contains("Preisdaten"))
    }

    /// Dismissing the sheet cancels the fetch. That is not a failure worth
    /// putting a warning on.
    func testCancellationDoesNotProduceAFailure() async {
        let store = PriceHistoryStore(
            repository: StubPriceHistoryRepository(result: .failure(CancellationError()))
        )

        await store.load(for: MockFixtures.offers[0])

        if case .failed = store.state {
            XCTFail("a cancelled load must not surface as an error")
        }
    }

    func testMockRepositoryOnlyAnswersForItsOwnProduct() async throws {
        let repository = MockPriceHistoryRepository()

        let hits = try await repository.history(
            market: "Lidl", product: "Bio Vollmilch"
        )
        let misses = try await repository.history(
            market: "Lidl", product: "Etwas anderes"
        )

        XCTAssertEqual(hits.count, 3)
        XCTAssertTrue(misses.isEmpty)
    }
}
