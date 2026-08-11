import Foundation

/// One place that decides whether the app talks to Supabase or to fixtures.
///
/// This decision used to live in two places — `LeChariotApp.init` and a static
/// in `ContentView`, the latter carrying a comment promising it "mirrors" the
/// former. Two copies of a rule is one copy too many, especially for a rule
/// that decides whether the app hits the network at all.
///
/// Mocks are used when no `APIKeys.plist` is configured (CI, a fresh clone) and,
/// in debug builds, when the app is launched for UI testing — those runs must
/// not depend on the backend being up or on which offers happen to be live this
/// week.
enum AppRepositories {
    static let usesMockData: Bool = {
        #if DEBUG
        if UITestSupport.isActive { return true }
        #endif
        return SupabaseClient.fromConfig() == nil
    }()

    private static let client: SupabaseClient? = usesMockData ? nil : SupabaseClient.fromConfig()

    static func markets() -> MarketRepositoryProtocol {
        guard let client else { return MockMarketRepository() }
        return LiveMarketRepository(client: client)
    }

    /// The store directory. Read-only and public, so there is nothing to gate
    /// beyond the usual mock/live decision.
    static let branches: BranchRepositoryProtocol = {
        guard let client else {
            #if DEBUG
            // Der Messlauf des Wählers braucht ein Verzeichnis in echter Größe
            // — neun Filialen rechnen nicht lange. Siehe
            // `MockFixtures.dichtesVerzeichnis`.
            if let n = UITestSupport.dichteVerzeichnisGroesse {
                return MockBranchRepository(fixtures: MockFixtures.dichtesVerzeichnis(n))
            }
            #endif
            return MockBranchRepository()
        }
        return LiveBranchRepository(client: client)
    }()

    static func branchRequests() -> BranchRequestRepositoryProtocol {
        guard let client else { return MockBranchRequestRepository() }
        return LiveBranchRequestRepository(client: client)
    }

    static func areaRequests() -> AreaRequestRepositoryProtocol {
        guard let client else {
            let mock = MockAreaRequestRepository()
            #if DEBUG
            // Der Gebiets-Lauf dauert ~3 Minuten und überspannt Sitzungen —
            // eine Journey kann darauf nicht warten. Also fängt sie mit dem
            // Zustand an, den ein früherer Start hinterlassen hätte.
            // Über `AppDefaults.shared`, nicht über einen selbst gebauten
            // Suite-Namen: Der Testlauf leert seine Suite beim Start, und ein
            // zweiter Zugriff auf denselben Namen könnte den Saatwert wieder
            // wegräumen, je nachdem was zuerst dran ist.
            if UITestSupport.seedsFinishedArea {
                mock.ready = [UITestSupport.seededAreaAnchor]
                AreaRequestStore.seedPendingArea(
                    UITestSupport.seededAreaAnchor, in: AppDefaults.shared
                )
            }
            #endif
            return mock
        }
        return LiveAreaRequestRepository(client: client)
    }

    static let offers: OfferRepositoryProtocol = {
        guard let client else {
            #if DEBUG
            // Der Messlauf braucht einen Prospekt in echter Größe — sieben
            // Zeilen ruckeln nicht. Siehe `MockFixtures.bulk`.
            if let count = UITestSupport.bulkOfferCount {
                return MockOfferRepository(fixtures:
                    MockFixtures.bulk(perChain: count)
                    + MockFixtures.bulk(perChain: count / 2, weeksAhead: 1))
            }
            // Der Sonntagszustand — siehe `MockFixtures.sunday`.
            if UITestSupport.servesSundayOffers {
                return MockOfferRepository(fixtures: MockFixtures.sunday)
            }
            #endif
            return MockOfferRepository()
        }
        return LiveOfferRepository(client: client)
    }()

    static let priceHistory: PriceHistoryRepositoryProtocol = {
        guard let client else { return MockPriceHistoryRepository() }
        return LivePriceHistoryRepository(client: client)
    }()

    /// nil disables profile sync entirely — `ProfileStore` then never uploads,
    /// which is what a mock run should do.
    static func profiles() -> ProfileRepositoryProtocol? {
        guard let client else { return nil }
        return LiveProfileRepository(client: client)
    }

    /// nil disables match feedback entirely — the sheet still appears and can
    /// be filled in, nothing is uploaded. Same rule as `profiles()`.
    static func matchFeedback() -> MatchFeedbackRepositoryProtocol? {
        guard let client else { return nil }
        return LiveMatchFeedbackRepository(client: client)
    }

    /// nil heißt hier: Es liegt nichts auf dem Server, weil nie etwas
    /// hochgeladen wurde. Die Einstellungen sagen dann genau das, statt einen
    /// Knopf anzubieten, der ins Leere greift.
    ///
    /// In UI-Läufen steht die Attrappe, damit die Journey den ganzen Weg
    /// sieht — sonst prüfte sie nur den Satz „nichts hochgeladen".
    static func privacy() -> PrivacyRepositoryProtocol? {
        #if DEBUG
        if UITestSupport.isActive { return MockPrivacyRepository() }
        #endif
        guard let client else { return nil }
        return LivePrivacyRepository(client: client)
    }
}
