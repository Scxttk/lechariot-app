import Foundation

/// Row of the Supabase `regions` table. See docs/CONTRACTS.md.
struct Region: Codable, Equatable, Identifiable {
    let plz: String
    let lastSynced: String?
    let active: Bool?

    var id: String { plz }

    enum CodingKeys: String, CodingKey {
        case plz, active
        case lastSynced = "last_synced"
    }
}
