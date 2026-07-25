import Foundation
import os

enum SupabaseError: Error {
    case notConfigured
    case invalidURL
    case httpError(statusCode: Int, body: String)
}

/// Thin async wrapper around the Supabase PostgREST endpoint. No third-party dependencies.
struct SupabaseClient {
    let baseURL: URL
    let apiKey: String
    var session: URLSession = .shared

    init(baseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    /// Client from APIKeys.plist, or nil if not configured.
    static func fromConfig() -> SupabaseClient? {
        guard let url = APIConfig.supabaseURL, let key = APIConfig.supabaseKey, !key.isEmpty else {
            return nil
        }
        return SupabaseClient(baseURL: url, apiKey: key)
    }

    /// GET /rest/v1/{path}?{query}, decoding the JSON response.
    func get<T: Decodable>(_ type: T.Type, path: String, query: String = "") async throws -> T {
        var urlString = baseURL.absoluteString + "/rest/v1/" + path
        if !query.isEmpty { urlString += "?" + query }
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        applyHeaders(&request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.supabase.decode(T.self, from: data)
    }

    /// POST /rest/v1/{path} with a JSON body and Prefer: return=minimal.
    /// `acceptedConflict` treats HTTP 409 as success (idempotent inserts).
    func post<Body: Encodable>(path: String, body: Body, acceptConflict: Bool = false) async throws {
        guard let url = URL(string: baseURL.absoluteString + "/rest/v1/" + path) else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        if acceptConflict, let http = response as? HTTPURLResponse, http.statusCode == 409 {
            return
        }
        try validate(response: response, data: data)
    }

    /// GET returning a JSON array, decoded per element: a single malformed
    /// row is skipped and logged instead of sinking the whole fetch.
    func getList<T: Decodable>(_ type: T.Type, path: String, query: String = "") async throws -> [T] {
        let rows = try await get([FailableElement<T>].self, path: path, query: query)
        let values = rows.compactMap(\.value)
        if values.count != rows.count {
            Logger(subsystem: "smartshop", category: "supabase")
                .warning("Skipped \(rows.count - values.count) malformed row(s) from \(path)")
        }
        return values
    }

    /// HEAD /rest/v1/{path}?{query} with `Prefer: count=exact`; returns the row
    /// count from the `content-range` header ("0-24/25" or "*/0") without
    /// transferring a body.
    func count(path: String, query: String = "") async throws -> Int {
        var urlString = baseURL.absoluteString + "/rest/v1/" + path
        if !query.isEmpty { urlString += "?" + query }
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        applyHeaders(&request)
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        guard let http = response as? HTTPURLResponse,
              let range = http.value(forHTTPHeaderField: "content-range"),
              let total = range.split(separator: "/").last.flatMap({ Int($0) }) else {
            return 0
        }
        return total
    }

    /// A value safe to paste into a PostgREST filter (`product=eq.<value>`).
    ///
    /// `get(_:path:query:)` builds its URL by string concatenation, so an
    /// unencoded product name ("Bio Vollmilch 3,5 %") makes `URL(string:)`
    /// return nil and the fetch throws `invalidURL` before it starts.
    /// `urlQueryAllowed` alone is not enough: it keeps `& = + , ( ) ? /`, and
    /// each of those is either a query separator or — for `+` — decoded back
    /// into a space server-side. Quoting the value instead of encoding it does
    /// NOT work; PostgREST then matches the quotes and returns [].
    static func filterValue(_ raw: String) -> String? {
        raw.addingPercentEncoding(withAllowedCharacters: filterAllowed)
    }

    private static let filterAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+,()?/#;:@$!*'")
        return set
    }()

    private func applyHeaders(_ request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.httpError(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
    }
}

/// Wraps an array element so a per-element decode failure yields nil instead
/// of failing the surrounding array.
struct FailableElement<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) {
        value = try? T(from: decoder)
    }
}

extension JSONDecoder {
    /// Decoder matching the Supabase contracts: dates are plain "yyyy-MM-dd" strings.
    static let supabase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(.supabaseDay)
        return decoder
    }()
}

extension DateFormatter {
    static let supabaseDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Calendar {
    /// Matches `DateFormatter.supabaseDay`: offer dates are Berlin midnights,
    /// so anything asking "is this valid today?" or "which calendar week?" has
    /// to ask in the same time zone the dates were parsed in.
    static let supabase: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar
    }()
}
