//
//  StarterAppTests.swift
//  StarterAppTests
//

import Foundation
import Testing
@testable import StarterApp

// MARK: - BackendAPIService.ServiceError

@Suite("BackendAPIService.ServiceError")
struct ServiceErrorTests {

    @Test("noAccessToken has a descriptive message")
    func noAccessTokenDescription() {
        let error = BackendAPIService.ServiceError.noAccessToken
        #expect(error.errorDescription == "Not signed in (no access token).")
    }

    @Test("unexpectedStatus includes status code and body in message")
    func unexpectedStatusWithBody() {
        let error = BackendAPIService.ServiceError.unexpectedStatus(404, "not found")
        #expect(error.errorDescription?.contains("404") == true)
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test("unexpectedStatus with nil body omits body text")
    func unexpectedStatusWithoutBody() {
        let error = BackendAPIService.ServiceError.unexpectedStatus(500, nil)
        #expect(error.errorDescription == "Server returned status 500.")
    }

    @Test("unexpectedStatus with empty body omits body text")
    func unexpectedStatusWithEmptyBody() {
        let error = BackendAPIService.ServiceError.unexpectedStatus(503, "")
        #expect(error.errorDescription == "Server returned status 503.")
    }
}

// MARK: - GeneratedModels encoding

@Suite("GeneratedModels — Encoding")
struct GeneratedModelsEncodingTests {

    private let encoder: JSONEncoder = {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        return jsonEncoder
    }()

    @Test("NoteIn encodes title and body with the expected keys")
    func noteInEncoding() throws {
        let note = NoteIn(title: "Hello", body: "World")
        let data = try encoder.encode(note)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["title"] as? String == "Hello")
        #expect(json?["body"] as? String == "World")
    }

    @Test("NoteIn with nil body omits body key (JSONEncoder synthesised encoding)")
    func noteInNilBodyEncoding() throws {
        let note = NoteIn(title: "No body", body: nil)
        let data = try encoder.encode(note)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["title"] as? String == "No body")
        // Swift omits nil optionals; FastAPI/Pydantic still treats missing `body` as None.
        #expect(json?["body"] == nil)
    }

    @Test("NoteUpdate encodes only non-nil fields")
    func noteUpdatePartialEncoding() throws {
        let update = NoteUpdate(title: "New title", body: nil)
        let data = try encoder.encode(update)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["title"] as? String == "New title")
    }

    @Test("ProfileUpdate uses snake_case keys")
    func profileUpdateSnakeCaseKeys() throws {
        let update = ProfileUpdate(displayName: "Alice", avatarUrl: nil)
        let data = try encoder.encode(update)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // Key must be snake_case to match the FastAPI schema
        #expect(json?["display_name"] as? String == "Alice")
        #expect(json?.keys.contains("camelCase") == false)
    }
}

// MARK: - GeneratedModels decoding

@Suite("GeneratedModels — Decoding")
struct GeneratedModelsDecodingTests {

    private let decoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        return jsonDecoder
    }()

    @Test("NoteOut decodes snake_case JSON to camelCase Swift properties")
    func noteOutDecoding() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "user_id": "00000000-0000-0000-0000-000000000002",
            "title": "My note",
            "body": null,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-02T00:00:00Z"
        }
        """

        let note = try decoder.decode(NoteOut.self, from: Data(json.utf8))

        #expect(note.title == "My note")
        #expect(note.body == nil)
        #expect(note.id.uuidString.lowercased() == "00000000-0000-0000-0000-000000000001")
        #expect(note.userId.uuidString.lowercased() == "00000000-0000-0000-0000-000000000002")
        // createdAt and updatedAt should be distinct dates
        #expect(note.createdAt != note.updatedAt)
    }

    @Test("NoteOut with body string decodes correctly")
    func noteOutWithBody() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "user_id": "00000000-0000-0000-0000-000000000002",
            "title": "With body",
            "body": "Some content",
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }
        """

        let note = try decoder.decode(NoteOut.self, from: Data(json.utf8))
        #expect(note.body == "Some content")
    }

    @Test("ProfileOut decodes snake_case JSON and maps nullable fields")
    func profileOutDecoding() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "display_name": "Alice",
            "avatar_url": null,
            "created_at": "2026-01-01T00:00:00Z"
        }
        """

        let profile = try decoder.decode(ProfileOut.self, from: Data(json.utf8))
        #expect(profile.displayName == "Alice")
        #expect(profile.avatarUrl == nil)
        #expect(profile.id.uuidString.lowercased() == "00000000-0000-0000-0000-000000000001")
    }

    @Test("ProfileOut with null display_name decodes to nil")
    func profileOutNullDisplayName() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "display_name": null,
            "avatar_url": null,
            "created_at": "2026-01-01T00:00:00Z"
        }
        """

        let profile = try decoder.decode(ProfileOut.self, from: Data(json.utf8))
        #expect(profile.displayName == nil)
    }
}

// MARK: - ContentViewModel state management

@Suite("ContentViewModel")
struct ContentViewModelTests {

    @Test("Initial state has no data loaded")
    func initialState() {
        let vm = ContentViewModel()
        #expect(vm.notes.isEmpty)
        #expect(vm.profile == nil)
        #expect(vm.secureTestResult == nil)
        #expect(vm.secureTestError == nil)
        #expect(vm.profileError == nil)
        #expect(vm.notesError == nil)
        #expect(!vm.isLoadingNotes)
        #expect(!vm.isLoadingProfile)
        #expect(!vm.isCallingSecureTest)
        #expect(!vm.isCreatingNote)
        #expect(!vm.isUpdatingProfile)
    }

    @Test("Notes array mutation — insert at front")
    func insertNoteAtFront() {
        let vm = ContentViewModel()
        let date = Date()
        let existingNote = NoteOut(
            id: UUID(), userId: UUID(), title: "Existing",
            body: nil, createdAt: date, updatedAt: date
        )
        vm.notes = [existingNote]

        let newNote = NoteOut(
            id: UUID(), userId: UUID(), title: "New",
            body: nil, createdAt: date, updatedAt: date
        )
        vm.notes.insert(newNote, at: 0)

        #expect(vm.notes.first?.title == "New")
        #expect(vm.notes.last?.title == "Existing")
        #expect(vm.notes.count == 2)
    }

    @Test("Notes array mutation — removeAll matching id")
    func removeNoteById() {
        let vm = ContentViewModel()
        let date = Date()
        let id1 = UUID()
        let id2 = UUID()
        vm.notes = [
            NoteOut(id: id1, userId: UUID(), title: "First",
                    body: nil, createdAt: date, updatedAt: date),
            NoteOut(id: id2, userId: UUID(), title: "Second",
                    body: nil, createdAt: date, updatedAt: date)
        ]

        vm.notes.removeAll { $0.id == id1 }

        #expect(vm.notes.count == 1)
        #expect(vm.notes.first?.id == id2)
    }

    @Test("Updating profile replaces the stored profile")
    func updateProfileReplacesValue() {
        let vm = ContentViewModel()
        let date = Date()
        let original = ProfileOut(
            id: UUID(), displayName: "Old Name",
            avatarUrl: nil, createdAt: date
        )
        vm.profile = original

        let updated = ProfileOut(
            id: original.id, displayName: "New Name",
            avatarUrl: nil, createdAt: date
        )
        vm.profile = updated

        #expect(vm.profile?.displayName == "New Name")
        #expect(vm.profile?.id == original.id)
    }
}
