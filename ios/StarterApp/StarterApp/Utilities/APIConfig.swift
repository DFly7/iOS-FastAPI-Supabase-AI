//
//  Reads Backend URL, Supabase URL, and Supabase anon key from Info.plist.
//  Values are supplied by Config-Debug / Config-Release .xcconfig at build time.
//

import Foundation

enum APIConfig {
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Info.plist not found")
        }
        return dict
    }()

    static let backendURL: URL = {
        guard let urlString = infoDictionary["BackendURL"] as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            fatalError(
                "BackendURL is invalid or missing. Set BACKEND_URL in Config-Debug.xcconfig / Config-Release.xcconfig and assign those files under the app target’s Debug / Release configurations."
            )
        }
        return url
    }()

    static let supabaseURL: String = {
        guard let url = infoDictionary["SupabaseURL"] as? String, !url.isEmpty else {
            fatalError("SupabaseURL is invalid or missing in Info.plist")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard let key = infoDictionary["SupabaseAnonKey"] as? String, !key.isEmpty else {
            fatalError("SupabaseAnonKey is invalid or missing in Info.plist")
        }
        return key
    }()

    /// Custom URL scheme for OAuth / magic-link redirects (must match Supabase redirect allow list).
    static let authRedirectScheme = "com.example.starter"

    /// True when `POSTHOG_API_KEY` is non-empty and PostHog is not explicitly turned off.
    ///
    /// Set `POSTHOG_ENABLED` to `TRUE` or `FALSE` in xcconfig. Leave `POSTHOG_API_KEY` empty to disable
    /// regardless. If the flag is missing or blank, PostHog runs when a key is present.
    static var isPostHogConfigured: Bool {
        guard let key = infoDictionary["PostHogAPIKey"] as? String, !key.isEmpty else {
            return false
        }
        if let raw = infoDictionary["PostHogEnabled"] as? String {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if ["0", "NO", "FALSE", "OFF"].contains(t) {
                return false
            }
        }
        return true
    }
}
