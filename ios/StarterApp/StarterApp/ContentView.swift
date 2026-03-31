//
//  ContentView.swift
//  StarterApp
//
//  Created by Darragh Flynn on 30/03/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var secureTestResult: BackendAPIService.SecureTestResponse?
    @State private var secureTestError: String?
    @State private var profileResult: BackendAPIService.ProfileResponse?
    @State private var profileError: String?
    @State private var isCallingBackend = false
    @State private var isLoadingProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section("Backend (JWT)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            "Proves the app, Supabase session, and FastAPI `verify_jwt` share the same token. "
                                + "Backend: \(APIConfig.backendURL.host ?? APIConfig.backendURL.absoluteString)"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        Button {
                            Task { await callSecureTest() }
                        } label: {
                            if isCallingBackend {
                                HStack {
                                    ProgressView()
                                    Text("Calling /api/v1/secure-test…")
                                }
                            } else {
                                Text("Call /api/v1/secure-test")
                            }
                        }
                        .disabled(isCallingBackend)

                        if let secureTestResult {
                            Text(secureTestResult.message)
                                .font(.subheadline)
                            if let uid = secureTestResult.userId {
                                Text("user_id: \(uid)")
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                        if let secureTestError {
                            Text(secureTestError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Your profile (Supabase via backend)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            "FastAPI loads your `profiles` row with your JWT; Postgres RLS only allows your own id."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        Button {
                            Task { await fetchProfileFromBackend() }
                        } label: {
                            if isLoadingProfile {
                                HStack {
                                    ProgressView()
                                    Text("GET /api/v1/me/profile…")
                                }
                            } else {
                                Text("Fetch my profile")
                            }
                        }
                        .disabled(isLoadingProfile)

                        if let profileResult {
                            profileSummary(profileResult)
                        }
                        if let profileError {
                            Text(profileError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Starter")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let email = authService.userEmail {
                            Text(email)
                        }
                        Button("Sign Out", role: .destructive) {
                            authService.signOut()
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func profileSummary(_ profile: BackendAPIService.ProfileResponse) -> some View {
        HStack(alignment: .top, spacing: 12) {
            profileAvatar(urlString: profile.avatarUrl)
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if let name = profile.displayName, !name.isEmpty {
                        Text(name)
                    } else {
                        Text("No display name")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.headline)
                Text(profile.id.uuidString)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Text(profile.createdAt)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func profileAvatar(urlString: String?) -> some View {
        let size: CGFloat = 56
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    avatarPlaceholder(size: size)
                @unknown default:
                    avatarPlaceholder(size: size)
                }
            }
        } else {
            avatarPlaceholder(size: size)
        }
    }

    private func avatarPlaceholder(size: CGFloat) -> some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: size * 0.85))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
    }

    @MainActor
    private func callSecureTest() async {
        secureTestError = nil
        secureTestResult = nil
        isCallingBackend = true
        defer { isCallingBackend = false }

        do {
            let response = try await BackendAPIService.fetchSecureTest(accessToken: authService.accessToken)
            secureTestResult = response
        } catch {
            secureTestError = error.localizedDescription
        }
    }

    @MainActor
    private func fetchProfileFromBackend() async {
        profileError = nil
        profileResult = nil
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            profileResult = try await BackendAPIService.fetchMyProfile(accessToken: authService.accessToken)
        } catch {
            profileError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.previewAuthenticated)
}
