import XCTest
@testable import LeChariot

@MainActor
final class OfferCacheTests: XCTestCase {
    /// Seit die App ihre Filialen in EINER Abfrage holt, hält der Cache genau
    /// eine Antwort — die Regions-Eimer gab es nur, weil mehrere PLZ nachträglich
    /// aus einer Antwort herausgeschnitten wurden. `replaceAll` ersetzt deshalb
    /// alles; eine halb ersetzte Woche wäre eine Mischung aus zwei Läufen.
    func testReplaceAllReplacesTheWholeCache() throws {
        let cache = try OfferCache(inMemory: true)
        try cache.replaceAll(MockFixtures.offers)
        XCTAssertEqual(try cache.load().offers.count, MockFixtures.offers.count)

        try cache.replaceAll([MockFixtures.offers[0]])

        XCTAssertEqual(try cache.load().offers.count, 1)
        XCTAssertEqual(try cache.load().offers.first?.product, MockFixtures.offers[0].product)
    }

    func testLoadReturnsFetchedAt() throws {
        let cache = try OfferCache(inMemory: true)
        let stamp = Date(timeIntervalSince1970: 1_784_000_000)
        try cache.replaceAll(MockFixtures.offers, fetchedAt: stamp)

        let loaded = try cache.load()
        XCTAssertEqual(loaded.fetchedAt, stamp)
    }

    func testEmptyCacheLoadsEmptyWithNilFetchedAt() throws {
        let cache = try OfferCache(inMemory: true)
        let loaded = try cache.load()
        XCTAssertTrue(loaded.offers.isEmpty)
        XCTAssertNil(loaded.fetchedAt)
    }

    func testImageUrlSurvivesCacheRoundTrip() throws {
        let cache = try OfferCache(inMemory: true)
        var withImage = MockFixtures.offers[0]
        withImage.imageUrl = "https://example.supabase.co/storage/v1/object/public/offer-images/abc.jpg"
        var withoutImage = MockFixtures.offers[1]
        withoutImage.imageUrl = nil

        try cache.replaceAll([withImage, withoutImage])

        let loaded = try cache.load().offers
        XCTAssertEqual(Set(loaded.map(\.imageUrl)), [withImage.imageUrl, nil])
    }

    /// Fixed mid-week date: relative-to-now dates would cross the ISO week
    /// boundary on Mondays and make the 23h case flaky.
    func testStalenessThresholdIs24Hours() {
        let cal = Calendar(identifier: .iso8601)
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        XCTAssertTrue(OfferCache.isStale(fetchedAt: nil, now: now))
        XCTAssertTrue(OfferCache.isStale(fetchedAt: now.addingTimeInterval(-25 * 3600), now: now))
        XCTAssertFalse(OfferCache.isStale(fetchedAt: now.addingTimeInterval(-23 * 3600), now: now))
    }

    /// Cache key is Filialen+KW: a new ISO week invalidates even a young cache.
    func testWeekRolloverInvalidatesYoungCache() {
        let cal = Calendar(identifier: .iso8601)
        let sunday = cal.date(from: DateComponents(year: 2026, month: 7, day: 19, hour: 22))!
        let monday = cal.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 1))!
        XCTAssertTrue(OfferCache.isStale(fetchedAt: sunday, now: monday))
        XCTAssertFalse(OfferCache.isStale(fetchedAt: sunday.addingTimeInterval(-3600), now: sunday))
        XCTAssertEqual(OfferCache.weekKey(for: sunday), "2026-W29")
        XCTAssertEqual(OfferCache.weekKey(for: monday), "2026-W30")
    }
}
