import Foundation

/// Calls the FastAPI backend using the same JWT Supabase issued to the app (`Authorization: Bearer …`).
enum BackendAPIService {
    /// Shared decoder for all backend responses.
    /// - dateDecodingStrategy: FastAPI serialises `datetime` fields as ISO 8601 strings
    ///   (e.g. "2026-03-31T12:00:00Z"). Without this the decoder throws on any `Date` property.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    struct SecureTestResponse: Decodable, Equatable {
        let message: String
        let userId: String?

        enum CodingKeys: String, CodingKey {
            case message
            case userId = "user_id"
        }
    }

    enum ServiceError: LocalizedError {
        case noAccessToken
        case unexpectedStatus(Int, String?)

        var errorDescription: String? {
            switch self {
            case .noAccessToken:
                return "Not signed in (no access token)."
            case let .unexpectedStatus(code, body):
                if let body, !body.isEmpty {
                    return "Server returned \(code): \(body)"
                }
                return "Server returned status \(code)."
            }
        }
    }

    private static func dataForAuthorizedGET(path: String, accessToken: String?) async throws -> Data {
        guard let accessToken, !accessToken.isEmpty else {
            throw ServiceError.noAccessToken
        }

        var request = URLRequest(url: APIConfig.backendURL.appending(path: path))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200 ... 299).contains(status) else {
            let body = String(data: data, encoding: .utf8)
            throw ServiceError.unexpectedStatus(status, body)
        }
        return data
    }

    @MainActor
    static func fetchSecureTest(accessToken: String?) async throws -> SecureTestResponse {
        let data = try await dataForAuthorizedGET(path: "api/v1/secure-test", accessToken: accessToken)
        return try decoder.decode(SecureTestResponse.self, from: data)
    }

    @MainActor
    static func fetchMyProfile(accessToken: String?) async throws -> ProfileOut {
        let data = try await dataForAuthorizedGET(path: "api/v1/me/profile", accessToken: accessToken)
        return try decoder.decode(ProfileOut.self, from: data)
    }
}
