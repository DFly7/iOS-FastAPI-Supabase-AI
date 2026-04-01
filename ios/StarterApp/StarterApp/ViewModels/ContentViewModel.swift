import Foundation
import Observation

/// View model for `ContentView`.
///
/// Separating state and async calls from the view keeps SwiftUI previews fast,
/// makes unit testing straightforward, and keeps the view a pure rendering layer.
///
/// Usage in the view:
/// ```swift
/// @State private var viewModel = ContentViewModel()
/// ```
@Observable
final class ContentViewModel {

    // MARK: - Secure test

    var secureTestResult: BackendAPIService.SecureTestResponse?
    var secureTestError: String?
    var isCallingSecureTest = false

    // MARK: - Profile

    var profile: ProfileOut?
    var profileError: String?
    var isLoadingProfile = false

    // MARK: - Update profile

    var isUpdatingProfile = false
    var updateProfileError: String?

    // MARK: - Notes

    var notes: [NoteOut] = []
    var notesError: String?
    var isLoadingNotes = false
    var isCreatingNote = false

    // MARK: - Actions

    func callSecureTest(accessToken: String?) async {
        secureTestError = nil
        secureTestResult = nil
        isCallingSecureTest = true
        defer { isCallingSecureTest = false }
        do {
            secureTestResult = try await BackendAPIService.fetchSecureTest(accessToken: accessToken)
        } catch {
            secureTestError = error.localizedDescription
        }
    }

    func fetchProfile(accessToken: String?) async {
        profileError = nil
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            profile = try await BackendAPIService.fetchMyProfile(accessToken: accessToken)
        } catch {
            profileError = error.localizedDescription
        }
    }

    func updateProfile(displayName: String, accessToken: String?) async {
        updateProfileError = nil
        isUpdatingProfile = true
        defer { isUpdatingProfile = false }
        do {
            profile = try await BackendAPIService.updateMyProfile(
                displayName: displayName,
                accessToken: accessToken
            )
        } catch {
            updateProfileError = error.localizedDescription
        }
    }

    func fetchNotes(accessToken: String?) async {
        notesError = nil
        isLoadingNotes = true
        defer { isLoadingNotes = false }
        do {
            notes = try await BackendAPIService.fetchNotes(accessToken: accessToken)
        } catch {
            notesError = error.localizedDescription
        }
    }

    func createNote(title: String, body: String? = nil, accessToken: String?) async {
        isCreatingNote = true
        defer { isCreatingNote = false }
        do {
            let note = try await BackendAPIService.createNote(title: title, body: body, accessToken: accessToken)
            notes.insert(note, at: 0)
        } catch {
            notesError = error.localizedDescription
        }
    }

    func deleteNote(id: UUID, accessToken: String?) async {
        do {
            try await BackendAPIService.deleteNote(id: id, accessToken: accessToken)
            notes.removeAll { $0.id == id }
        } catch {
            notesError = error.localizedDescription
        }
    }
}
