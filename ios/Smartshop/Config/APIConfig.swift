import Foundation

/// Reads Supabase credentials from the gitignored APIKeys.plist.
/// Copy APIKeys.example.plist to APIKeys.plist and fill in the publishable key.
enum APIConfig {
    private static let plist: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "APIKeys", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return dict
    }()

    static var supabaseURL: URL? {
        (plist["SupabaseURL"] as? String).flatMap(URL.init(string:))
    }

    static var supabaseKey: String? {
        plist["SupabaseKey"] as? String
    }

    static var isConfigured: Bool {
        supabaseURL != nil && !(supabaseKey ?? "").isEmpty
    }
}
