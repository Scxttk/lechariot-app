import XCTest
@testable import Smartshop

final class ModelDecodingTests: XCTestCase {
    private let decoder = JSONDecoder.supabase

    func testDecodeOffer() throws {
        let json = """
        [{
            "market": "Lidl",
            "product": "Bio Vollmilch",
            "price": 0.99,
            "regular_price": 1.29,
            "unit": "je 12 x 1 l",
            "category": "Molkerei & Eier",
            "emoji": "🥛",
            "valid_from": "2026-07-13",
            "valid_until": "2026-07-19",
            "base_price": 0.99,
            "base_unit": "1 l",
            "region": "01219",
            "image_url": "https://cddubgdnasmzvcfhmrzj.supabase.co/storage/v1/object/public/offer-images/abc123.jpg"
        }]
        """.data(using: .utf8)!

        let offers = try decoder.decode([Offer].self, from: json)
        XCTAssertEqual(offers.count, 1)
        let offer = offers[0]
        XCTAssertEqual(offer.market, "Lidl")
        XCTAssertEqual(offer.product, "Bio Vollmilch")
        XCTAssertEqual(offer.price, 0.99)
        XCTAssertEqual(offer.regularPrice, 1.29)
        XCTAssertEqual(offer.unit, "je 12 x 1 l")
        XCTAssertEqual(offer.category, "Molkerei & Eier")
        XCTAssertEqual(offer.emoji, "🥛")
        XCTAssertEqual(offer.basePrice, 0.99)
        XCTAssertEqual(offer.baseUnit, "1 l")
        XCTAssertEqual(offer.region, "01219")
        XCTAssertEqual(
            offer.imageUrl,
            "https://cddubgdnasmzvcfhmrzj.supabase.co/storage/v1/object/public/offer-images/abc123.jpg"
        )
        XCTAssertEqual(DateFormatter.supabaseDay.string(from: offer.validFrom), "2026-07-13")
        XCTAssertEqual(DateFormatter.supabaseDay.string(from: offer.validUntil), "2026-07-19")
        XCTAssertTrue(Categories.all.contains(offer.category))
    }

    func testDecodeOfferWithNulls() throws {
        let json = """
        {
            "market": "Aldi",
            "product": "Orangen",
            "price": null,
            "regular_price": null,
            "unit": null,
            "category": "Obst & Gemüse",
            "emoji": null,
            "valid_from": "2026-07-13",
            "valid_until": "2026-07-19",
            "base_price": null,
            "base_unit": null,
            "region": "01219"
        }
        """.data(using: .utf8)!

        let offer = try decoder.decode(Offer.self, from: json)
        XCTAssertNil(offer.price)
        XCTAssertNil(offer.regularPrice)
        XCTAssertNil(offer.unit)
        XCTAssertNil(offer.emoji)
        XCTAssertNil(offer.basePrice)
        XCTAssertNil(offer.baseUnit)
        // image_url absent entirely (pre-migration rows) must also decode.
        XCTAssertNil(offer.imageUrl)
    }

    func testDecodeMarket() throws {
        let json = """
        {
            "chain": "Lidl",
            "branch_name": "Dresden Reick",
            "market_id": "lidl-01219-1",
            "plz": "01219"
        }
        """.data(using: .utf8)!

        let market = try decoder.decode(Market.self, from: json)
        XCTAssertEqual(market.chain, "Lidl")
        XCTAssertEqual(market.branchName, "Dresden Reick")
        XCTAssertEqual(market.marketId, "lidl-01219-1")
        XCTAssertEqual(market.plz, "01219")
        XCTAssertEqual(market.id, "lidl-01219-1")
    }

    func testDecodeRegion() throws {
        let json = """
        {"plz": "01219", "last_synced": "2026-07-16T05:00:00Z", "active": true}
        """.data(using: .utf8)!

        let region = try decoder.decode(Region.self, from: json)
        XCTAssertEqual(region.plz, "01219")
        XCTAssertEqual(region.lastSynced, "2026-07-16T05:00:00Z")
        XCTAssertEqual(region.active, true)
    }

    func testDecodeRegionWithNulls() throws {
        let json = """
        {"plz": "01219", "last_synced": null, "active": null}
        """.data(using: .utf8)!

        let region = try decoder.decode(Region.self, from: json)
        XCTAssertNil(region.lastSynced)
        XCTAssertNil(region.active)
    }

    // MARK: Decoding resilience

    /// One poisoned row (null valid_from) must not sink the whole fetch:
    /// per-element decoding keeps the good rows and drops the bad one.
    func testPoisonedRowIsSkippedNotFatal() throws {
        let json = """
        [
            {
                "market": "Lidl", "product": "Bio Vollmilch", "price": 0.99,
                "regular_price": 1.29, "unit": null, "category": "Molkerei & Eier",
                "emoji": null, "valid_from": "2026-07-13", "valid_until": "2026-07-19",
                "base_price": null, "base_unit": null, "region": "01219"
            },
            {
                "market": "Kaputt", "product": "Poisoned", "price": "NaN",
                "regular_price": null, "unit": null, "category": "Sonstiges",
                "emoji": null, "valid_from": null, "valid_until": null,
                "base_price": null, "base_unit": null, "region": "01219"
            },
            {
                "market": "Aldi", "product": "Orangen", "price": 1.99,
                "regular_price": null, "unit": null, "category": "Obst & Gemüse",
                "emoji": null, "valid_from": "2026-07-13", "valid_until": "2026-07-19",
                "base_price": null, "base_unit": null, "region": "01219"
            }
        ]
        """.data(using: .utf8)!

        let rows = try decoder.decode([FailableElement<Offer>].self, from: json)
        let offers = rows.compactMap(\.value)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(offers.map(\.product), ["Bio Vollmilch", "Orangen"])
    }
}
