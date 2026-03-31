import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var showingAuth = false

    var body: some View {
        Group {
            if authService.isCheckingInitialSession {
                ProgressView("Loading…")
            } else if authService.isAuthenticated {
                ContentView()
            } else {
                signedOutPrompt
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthView()
                .environmentObject(authService)
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthed in
            if isAuthed { showingAuth = false }
        }
    }

    private var signedOutPrompt: some View {
        VStack(spacing: 24) {
            Text("Starter")
                .font(.largeTitle.bold())
            Text("Sign in to continue")
                .foregroundStyle(.secondary)
            Button("Sign In") { showingAuth = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview("Signed out") {
    RootView()
        .environmentObject(AuthService.previewSignedOut)
}

#Preview("Signed in") {
    RootView()
        .environmentObject(AuthService.previewAuthenticated)
}
