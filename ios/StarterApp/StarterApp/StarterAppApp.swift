//
//  StarterAppApp.swift
//  StarterApp
//
//  Created by Darragh Flynn on 30/03/2026.
//

import PostHog
import SwiftUI

@main
struct StarterAppApp: App {
    @StateObject private var authService: AuthService

    init() {
        Self.configurePostHogIfNeeded()

        guard let url = URL(string: APIConfig.supabaseURL) else {
            fatalError("Invalid Supabase URL in config")
        }
        _authService = StateObject(
            wrappedValue: AuthService(supabaseURL: url, supabaseAnonKey: APIConfig.supabaseAnonKey)
        )
    }

    private static func configurePostHogIfNeeded() {
        guard APIConfig.isPostHogConfigured,
              let apiKey = Bundle.main.infoDictionary?["PostHogAPIKey"] as? String,
              !apiKey.isEmpty
        else {
            return
        }
        let hostString = (Bundle.main.infoDictionary?["PostHogHost"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let host = (hostString?.isEmpty == false ? hostString : nil) ?? "https://us.i.posthog.com"
        let config = PostHogConfig(apiKey: apiKey, host: host)
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .onOpenURL { url in
                    Task { @MainActor in
                        await authService.handleIncomingURL(url)
                    }
                }
        }
    }
}
