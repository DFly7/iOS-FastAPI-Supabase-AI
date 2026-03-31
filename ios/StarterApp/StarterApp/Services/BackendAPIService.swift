import Foundation

/// Calls the FastAPI backend using the same JWT Supabase issued to the app (`Authorization: Bearer …`).
enum BackendAPIService {
    struct SecureTestResponse: Decodable, Equatable {
        let message: String
        let userId: String?

        enum CodingKeys: String, CodingKey {
            case message
            case userId = "user_id"
        }
    }

    /// Row from `public.profiles` returned by `GET /api/v1/me/profile` (backend uses PostgREST + RLS).
    struct ProfileResponse: Decodable, Equatable {
        let id: UUID
        let displayName: String?
        let avatarUrl: String?
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case avatarUrl = "avatar_url"
            case createdAt = "created_at"
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
        return try JSONDecoder().decode(SecureTestResponse.self, from: data)
    }

    @MainActor
    static func fetchMyProfile(accessToken: String?) async throws -> ProfileResponse {
        let data = try await dataForAuthorizedGET(path: "api/v1/me/profile", accessToken: accessToken)
        return try JSONDecoder().decode(ProfileResponse.self, from: data)
    }
}
