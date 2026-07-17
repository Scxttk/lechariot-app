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
