import Foundation

/// Alles, was diese Installation auf dem Gerät hält.
///
/// Eigener Typ und nicht „die Stores durchreichen": Der Export ist eine
/// **Zusage** — was hier fehlt, bekommt der Nutzer nicht zu sehen, und das
/// fällt niemandem auf. Ein Typ mit benannten Feldern lässt sich gegen die
/// Stores prüfen; ein Wörterbuch, das irgendwo befüllt wird, nicht.
struct LocalDataExport: Codable, Equatable {
    let installId: UUID
    let firstName: String
    let householdSize: Int
    let tripsPerWeek: Int
    let weeklyBudget: Int?
    let dietTags: [String]
    /// Ketten aus „Welche Märkte magst du?" — liegen nur auf dem Gerät,
    /// gehören aber genau deshalb in diese Zusage.
    let likedChains: [String]
    let hasConsentedToSync: Bool
    let regions: [String]
    let branches: [Branch]
    let shoppingList: [Item]
    /// Was „Häufig gekauft" gelernt hat. Gewicht statt Zähler, weil die
    /// Käufe altern — siehe `PurchaseHistoryStore.halfLife`.
    let purchaseWeights: [String: Double]

    /// Ein Listeneintrag, wie er auf der Platte liegt.
    struct Branch: Codable, Equatable {
        let chain: String
        let name: String
        let marketId: String
        let plz: String
    }

    struct Item: Codable, Equatable {
        let text: String
        let isChecked: Bool
        let addedAt: Date
        let detail: [String]?
        let pinnedProducts: [String]
        let pinnedMarkets: [String]
    }
}

extension LocalDataExport {
    /// Sammelt den Gerätestand ein.
    ///
    /// **Diese Funktion ist die Zusage**, nicht der Knopf, der sie aufruft:
    /// Kommt später ein Speicherort dazu und wird hier nicht eingetragen,
    /// fehlt er im Export, ohne dass irgendwo etwas fehlschlägt. Der Test
    /// `DataExportTests` hält die Felder deshalb einzeln fest.
    @MainActor
    static func collect(
        profile: ProfileStore,
        regions: RegionStore,
        list: ShoppingListStore,
        history: PurchaseHistoryStore
    ) -> LocalDataExport {
        LocalDataExport(
            installId: profile.profile.installId,
            firstName: profile.profile.firstName,
            householdSize: profile.profile.householdSize,
            tripsPerWeek: profile.profile.rhythm.rawValue,
            weeklyBudget: profile.profile.budget?.rawValue,
            dietTags: profile.profile.dietTags.map(\.rawValue).sorted(),
            likedChains: profile.likedChains,
            hasConsentedToSync: profile.profile.hasConsentedToSync,
            regions: regions.regions,
            branches: regions.favoriteMarkets.map {
                Branch(chain: $0.chain, name: $0.branchName,
                       marketId: $0.marketId, plz: $0.plz)
            },
            shoppingList: list.items.map {
                Item(text: $0.text, isChecked: $0.isChecked, addedAt: $0.addedAt,
                     detail: $0.detail,
                     pinnedProducts: $0.pinnedOffers.map(\.product),
                     pinnedMarkets: $0.pinnedOffers.map(\.market))
            },
            purchaseWeights: history.entries.mapValues(\.weight)
        )
    }
}

/// Schreibt den Export als Datei, die sich teilen lässt.
enum DataExportFile {
    /// JSON und nicht PDF oder CSV: Es ist das Format, in dem die Daten
    /// ohnehin liegen, es ist maschinenlesbar (Art. 20 verlangt genau das)
    /// und es lügt nicht durch Formatierung.
    static func write(
        local: LocalDataExport, serverJSON: String?, serverNote: String?
    ) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let localData = try encoder.encode(local)
        let localText = String(data: localData, encoding: .utf8) ?? "{}"

        // Von Hand zusammengesetzt, weil der Serverteil roher JSON-Text vom
        // Server ist: Ihn zu dekodieren und neu zu kodieren gäbe dem Nutzer
        // eine Umschrift statt seiner Daten.
        var text = "{\n"
        text += "  \"hinweis\": \"Alles, was Le Chariot zu dieser Installation hält. "
        text += "Der Teil unter auf_dem_geraet hat den Server nie gesehen.\",\n"
        if let serverNote {
            text += "  \"hinweis_server\": \(quoted(serverNote)),\n"
        }
        text += "  \"auf_dem_geraet\": \(indent(localText)),\n"
        text += "  \"auf_dem_server\": \(serverJSON.map(indent) ?? "null")\n"
        text += "}\n"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("le-chariot-daten.json")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func quoted(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// Rückt einen fertigen JSON-Block um zwei Stellen ein, damit die Datei
    /// als Ganzes lesbar bleibt.
    private static func indent(_ json: String) -> String {
        json.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { $0.offset == 0 ? String($0.element) : "  " + $0.element }
            .joined(separator: "\n")
    }
}
