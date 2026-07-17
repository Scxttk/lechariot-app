import XCTest
@testable import Smartshop

@MainActor
final class OfferCacheTests: XCTestCase {
    func testReplaceAllReplacesOnlyTheGivenRegion() throws {
        let cache = try OfferCache(inMemory: true)
        var otherRegion = MockFixtures.offers[0]
        otherRegion = Offer(
            market: otherRegion.market, product: "Berliner Ware", price: 1.0,
            regularPrice: nil, unit: nil, category: "Sonstiges", emoji: nil,
            validFrom: otherRegion.validFrom, validUntil: otherRegion.validUntil,
            basePrice: nil, baseUnit: nil, region: "10115"
        )
        try cache.replaceAll(MockFixtures.offers, region: "01219")
        try cache.replaceAll([otherRegion], region: "10115")

        // Replace 01219 with a single offer; 10115 must survive untouched.
        try cache.replaceAll([MockFixtures.offers[0]], region: "01219")

        XCTAssertEqual(try cache.load(region: "01219").offers.count, 1)
        XCTAssertEqual(try cache.load(region: "10115").offers.count, 1)
    }

    func testLoadReturnsFetchedAt() throws {
        let cache = try OfferCache(inMemory: true)
        let stamp = Date(timeIntervalSince1970: 1_784_000_000)
        try cache.replaceAll(MockFixtures.offers, region: "01219", fetchedAt: stamp)

        let loaded = try cache.load(region: "01219")
        XCTAssertEqual(loaded.fetchedAt, stamp)
    }

    func testEmptyRegionLoadsEmptyWithNilFetchedAt() throws {
        let cache = try OfferCache(inMemory: true)
        let loaded = try cache.load(region: "99999")
        XCTAssertTrue(loaded.offers.isEmpty)
        XCTAssertNil(loaded.fetchedAt)
    }

    func testImageUrlSurvivesCacheRoundTrip() throws {
        let cache = try OfferCache(inMemory: true)
        var withImage = MockFixtures.offers[0]
        withImage.imageUrl = "https://example.supabase.co/storage/v1/object/public/offer-images/abc.jpg"
        var withoutImage = MockFixtures.offers[1]
        withoutImage.imageUrl = nil

        try cache.replaceAll([withImage, withoutImage], region: "01219")

        let loaded = try cache.load(region: "01219").offers
        XCTAssertEqual(Set(loaded.map(\.imageUrl)), [withImage.imageUrl, nil])
    }

    func testStalenessThresholdIs24Hours() {
        let now = Date.now
        XCTAssertTrue(OfferCache.isStale(fetchedAt: nil, now: now))
        XCTAssertTrue(OfferCache.isStale(fetchedAt: now.addingTimeInterval(-25 * 3600), now: now))
        XCTAssertFalse(OfferCache.isStale(fetchedAt: now.addingTimeInterval(-23 * 3600), now: now))
    }
}
