import Foundation

/// Fixture-backed repositories for previews and tests.
enum MockFixtures {
    static let day = DateFormatter.supabaseDay

    /// Validity of the CURRENT calendar week rather than a fixed date.
    ///
    /// The fixtures used to carry 13.–19.07.2026 hard-coded, so from 20.07.
    /// onwards every preview and UI-test run showed an offer that had expired
    /// — harmless for the assertions, misleading for anyone looking at the
    /// screen, and drifting further every week.
    static let weekStart: Date = {
        Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }()
    static let weekEnd: Date = weekStart.addingTimeInterval(6 * 24 * 60 * 60)

    /// `n` weeks before the current one — for the price history.
    static func weeksAgo(_ n: Int) -> (from: Date, until: Date) {
        let from = weekStart.addingTimeInterval(TimeInterval(-n * 7 * 24 * 60 * 60))
        return (from, from.addingTimeInterval(6 * 24 * 60 * 60))
    }

    static let offers: [Offer] = [
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Bio Vollmilch",
            price: 0.99,
            regularPrice: 1.29,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 0.99,
            baseUnit: "1 l",
            nationwide: false
        ),
        Offer(
            marketId: "aldi-01219-1",
            market: "Aldi",
            product: "Spanische Orangen",
            price: 2.49,
            regularPrice: nil,
            unit: "je 2 kg Netz",
            category: "Obst & Gemüse",
            emoji: "🍊",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 1.25,
            baseUnit: "1 kg",
            nationwide: false
        ),
        // **Die teurere Alternative bei derselben Kette.** Ohne sie gibt es zu
        // „Vollmilch" genau einen Treffer, und eine Wahl unter einem Angebot
        // ist keine — der Tester-Wunsch vom 2026-07-31 („ich will lieber den,
        // der nicht der billigste ist") wäre gar nicht nachstellbar.
        //
        // Zwei Entscheidungen an dieser Zeile, beide gegen stille Kollateralen:
        // Sie ist **teurer** als „Bio Vollmilch", sonst würde sie zum
        // vorgeschlagenen Angebot und drei bestehende Zusicherungen auf „Bio
        // Vollmilch" fielen um, ohne dass an ihnen etwas kaputt wäre. Und sie
        // steht **hinten**, weil `MockFixtures.offers[0]` und `[1]` quer durch
        // die Tests als feste Handgriffe benutzt werden.
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Landliebe Frische Vollmilch",
            price: 1.49,
            regularPrice: nil,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 1.49,
            baseUnit: "1 l",
            nationwide: false
        ),
        // **Das erste Fixture-Angebot, das nur über sein Tag zu finden ist.**
        // Ohne eines davon kommt jede Trefferliste im Mock-Lauf ausschließlich
        // über Stufe 1 zustande — die zweite Stufe, das Wörterbuch, war auf
        // keinem Bildschirm je zu sehen. Genau die Zeile, deren Herkunft die
        // Trefferliste seit dem 01.08. benennt („über Milch"), ließ sich also
        // nicht ansehen, nur ausrechnen.
        //
        // Der Titel trägt das Wort **nicht** — das ist der ganze Zweck. Und
        // der Preis ist der höchste der drei Milchzeilen, damit sie weder das
        // vorgeschlagene Angebot wird noch die Abdeckung einer zweiten Kette
        // verschiebt: Sie liegt bei derselben Filiale wie die billigste.
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Bärenmarke Die Frische",
            price: 1.79,
            regularPrice: nil,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 1.79,
            baseUnit: "1 l",
            nationwide: false,
            matchKey: ["milch"]
        ),
    ]

    /// Three recorded weeks for the first offer fixture — enough for the
    /// detail sheet's price history to show up in previews and UI tests.
    static let priceHistory: [PriceHistoryPoint] = [
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 1.29, regularPrice: 1.29,
            validFrom: weeksAgo(2).from,
            validUntil: weeksAgo(2).until
        ),
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 1.19, regularPrice: 1.29,
            validFrom: weeksAgo(1).from,
            validUntil: weeksAgo(1).until
        ),
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 0.99, regularPrice: 1.29,
            validFrom: weekStart,
            validUntil: weekEnd
        ),
    ]

    static let markets: [Market] = [
        Market(chain: "Aldi", branchName: "Dresden Prohlis", marketId: "aldi-01219-1", plz: "01219"),
        Market(chain: "Lidl", branchName: "Dresden Reick", marketId: "lidl-01219-1", plz: "01219"),
    ]


    /// Three real Dresden stores, two of them the ones the PLZ model could
    /// never reach: the second REWE in a postcode and the Netto in the
    /// Johannes-Paul-Thilman-Straße.
    static let branches: [Branch] = [
        // Dieselben beiden wie in `markets` — Mock-Läufe (UI-Journeys) müssen
        // dieselben Filialen sehen wie vorher, sonst zeigt der Picker über
        // Nacht andere Läden.
        Branch(marketId: "lidl-01219-1", chain: "Lidl", name: "Dresden Reick",
               street: "Reicker Str. 100", plz: "01219", city: "Dresden",
               lat: 51.0166, lon: 13.7727),
        Branch(marketId: "aldi-01219-1", chain: "Aldi", name: "Dresden Prohlis",
               street: "Prohliser Allee 10", plz: "01219", city: "Dresden",
               lat: 51.0011, lon: 13.7899),
        Branch(marketId: "1766063", chain: "REWE", name: "REWE Ketzscher oHG am Postplatz",
               street: "Wallstr. 2b", plz: "01067", city: "Dresden", lat: 51.0504, lon: 13.7317),
        Branch(marketId: "1766160", chain: "REWE", name: "REWE Friedrichstadt",
               street: "Friedrichstr. 7", plz: "01067", city: "Dresden", lat: 51.0561, lon: 13.7203),
        Branch(marketId: "4816", chain: "Netto", name: "Netto Marken-Discount Dresden-Strehlen",
               street: "Johannes-Paul-Thilman-Str. 3", plz: "01219", city: "Dresden",
               lat: 51.0155, lon: 13.7669),

        // Die zweite und dritte Region aus dem Fehlerbericht vom 2026-07-30.
        // Beide liegen ~450 km von Dresden entfernt, also weit außerhalb der
        // 40 km, auf die der Picker höchstens aufmacht — ein Lauf mit nur
        // 01219 sieht sie nie, und die bestehenden Journeys ändern sich nicht.
        //
        // Die Verteilung ist der eigentliche Punkt: Um 04626 steht ein Netto,
        // das Gebiet gilt damit als geholt. Um 17419 steht ausschließlich
        // Penny — bundesweit im Verzeichnis, also das Zeichen für „dieses
        // Gebiet hat nie jemand geholt". Zusammengeworfen verdeckt das Netto
        // genau dieses Zeichen, und das war der Fehler.
        Branch(marketId: "penny-04639-1", chain: "Penny", name: "Penny Gößnitz",
               street: "Altenburger Str. 13 A", plz: "04639", city: "Gößnitz",
               lat: 50.8875, lon: 12.4333),
        Branch(marketId: "netto-04626-1", chain: "Netto", name: "Netto Marken-Discount Schmölln",
               street: "Crimmitschauer Str. 2", plz: "04626", city: "Schmölln",
               lat: 50.8940, lon: 12.3600),
        Branch(marketId: "penny-17373-1", chain: "Penny", name: "Penny Am Haff",
               street: "Chausseestr. 41-43", plz: "17373", city: "Ueckermünde",
               lat: 53.7383, lon: 14.0511),
        Branch(marketId: "penny-17449-1", chain: "Penny", name: "Penny Karlshagen",
               street: "Hauptstr. 16", plz: "17449", city: "Karlshagen",
               lat: 54.0500, lon: 13.8167),
    ]

    /// Postcode centres for mock runs. Real geocoding talks to Apple's servers,
    /// which a test must never do.
    ///
    /// This used to be one hardcoded Dresden point for **every** postcode,
    /// which made multi-region behaviour untestable: three regions all landed
    /// on the same coordinates, so nothing that depends on them apart could
    /// ever be reproduced. Unknown postcodes still fall back to that point, so
    /// every existing journey keeps the list it had.
    static let dresden = (lat: 51.0504, lon: 13.7317)

    static func coordinates(forPLZ plz: String) -> (lat: Double, lon: Double) {
        switch plz {
        case "04626": return (50.8956, 12.3556)  // Schmölln
        case "17419": return (53.9440, 14.1830)  // Ahlbeck auf Usedom
        default: return dresden
        }
    }
}

struct MockOfferRepository: OfferRepositoryProtocol {
    var fixtures: [Offer] = MockFixtures.offers

    func offers(branchIds: [String]) async throws -> [Offer] {
        // Nationwide rows belong to every branch of their chain.
        fixtures.filter { $0.isNationwide || branchIds.contains($0.marketId ?? "") }
    }
}

struct MockPriceHistoryRepository: PriceHistoryRepositoryProtocol {
    var fixtures: [PriceHistoryPoint] = MockFixtures.priceHistory

    func history(market: String, product: String) async throws -> [PriceHistoryPoint] {
        fixtures.filter { $0.market == market && $0.product == product }
    }
}

struct MockBranchRepository: BranchRepositoryProtocol {
    var fixtures: [Branch] = MockFixtures.branches

    func nearby(lat: Double, lon: Double, radiusKm: Double) async throws -> [Branch] {
        fixtures
            .compactMap { branch -> (Branch, Double)? in
                guard let distance = branch.distanceKm(from: lat, lon), distance <= radiusKm
                else { return nil }
                return (branch, distance)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    func branch(marketId: String) async throws -> Branch? {
        fixtures.first { $0.marketId == marketId }
    }
}

/// Records requests instead of sending them, and can be told which stores the
/// backend already has — so tests can drive the wait state without a network.
final class MockBranchRequestRepository: BranchRequestRepositoryProtocol, @unchecked Sendable {
    /// Stores that already carry a `last_synced`.
    var ready: Set<String> = []
    /// Stores whose row exists but is still pending.
    var pending: Set<String> = []
    private(set) var requested: [String] = []

    func request(marketId: String) async throws -> BranchRequest? {
        if ready.contains(marketId) {
            return BranchRequest(marketId: marketId, lastSynced: "2026-07-25T16:56:48Z", active: true)
        }
        if pending.contains(marketId) || requested.contains(marketId) {
            return BranchRequest(marketId: marketId, lastSynced: nil, active: true)
        }
        return nil
    }

    func requestBranch(marketId: String) async throws {
        requested.append(marketId)
    }
}

/// Same shape as `MockBranchRequestRepository`, one level up: the area, not
/// the single store.
final class MockAreaRequestRepository: AreaRequestRepositoryProtocol, @unchecked Sendable {
    /// Anchors whose area run has finished.
    var ready: Set<String> = []
    /// Anchors whose row exists but whose run is still going.
    var pending: Set<String> = []
    private(set) var requested: [String] = []

    /// Koordinaten, die eine schon vorhandene Zeile trägt — damit Tests die
    /// Übernahmeregel („nicht die Zeile einer anderen Stadt kapern") prüfen
    /// können.
    var coordinates: [String: (lat: Double, lon: Double)] = [:]
    /// Was die App tatsächlich mitgeschickt hat.
    private(set) var requestedCoordinates: [String: (lat: Double?, lon: Double?)] = [:]

    func request(marketId: String) async throws -> AreaRequest? {
        let point = coordinates[marketId]
        if ready.contains(marketId) {
            return AreaRequest(
                marketId: marketId, plz: "04639",
                lastSynced: "2026-07-26T08:36:50Z", active: true,
                areaKey: point.map { AreaRequestStore.areaKey(lat: $0.lat, lon: $0.lon) },
                lat: point?.lat, lon: point?.lon
            )
        }
        if pending.contains(marketId) || requested.contains(marketId) {
            return AreaRequest(
                marketId: marketId, plz: "04639", lastSynced: nil, active: true,
                areaKey: point.map { AreaRequestStore.areaKey(lat: $0.lat, lon: $0.lon) },
                lat: point?.lat, lon: point?.lon
            )
        }
        return nil
    }

    /// Zuordnung Gebietsschlüssel -> Filiale. Wird beim Anfordern automatisch
    /// gefüllt; Tests können sie für schon vorhandene Zeilen vorbelegen.
    var areaKeys: [String: String] = [:]

    func request(areaKey: String) async throws -> AreaRequest? {
        if let marketId = areaKeys[areaKey] {
            return try await request(marketId: marketId)
        }
        // Sonst die Zeile, deren Koordinaten in dieser Zelle liegen — so muss
        // ein Test nur `coordinates` setzen und nicht zusätzlich den Schlüssel.
        for (marketId, point) in coordinates
        where AreaRequestStore.areaKey(lat: point.lat, lon: point.lon) == areaKey {
            return try await request(marketId: marketId)
        }
        return nil
    }

    func requestArea(marketId: String, lat: Double?, lon: Double?) async throws {
        requested.append(marketId)
        requestedCoordinates[marketId] = (lat, lon)
        if let lat, let lon {
            areaKeys[AreaRequestStore.areaKey(lat: lat, lon: lon)] = marketId
        }
    }
}

struct MockMarketRepository: MarketRepositoryProtocol {
    var fixtures: [Market] = MockFixtures.markets

    func markets(plzs: [String]) async throws -> [Market] {
        fixtures.filter { plzs.contains($0.plz) }
    }
}

/// Records uploads instead of sending them, so tests can assert that a profile
/// without consent never reaches the network.
final class MockProfileRepository: ProfileRepositoryProtocol, @unchecked Sendable {
    private(set) var uploaded: [SyncedProfile] = []

    func upload(_ profile: SyncedProfile) async throws {
        uploaded.append(profile)
    }
}

/// Records reports instead of sending them, so tests can assert that skipping
/// the question — or switching it off — never reaches the network.
final class MockMatchFeedbackRepository: MatchFeedbackRepositoryProtocol, @unchecked Sendable {
    private(set) var submitted: [MatchFeedbackReport] = []

    func submit(_ report: MatchFeedbackReport) async throws {
        submitted.append(report)
    }
}


/// Zählt statt zu löschen. Der Ausgang ist einstellbar, damit die Journeys
/// beide Fälle sehen: etwas gelöscht — und gar nichts, weil nie etwas
/// hochgeladen wurde.
final class MockPrivacyRepository: PrivacyRepositoryProtocol, @unchecked Sendable {
    var rows = DeletedRows(profiles: 1, feedback: 3)
    var failure: Error?
    private(set) var deleted: [UUID] = []

    func deleteInstallation(_ installId: UUID) async throws -> DeletedRows {
        if let failure { throw failure }
        deleted.append(installId)
        return rows
    }

    func exportInstallation(_ installId: UUID) async throws -> String {
        if let failure { throw failure }
        return "{\"install_id\":\"\(installId.uuidString)\",\"user_profiles\":[],\"match_feedback\":[]}"
    }
}
