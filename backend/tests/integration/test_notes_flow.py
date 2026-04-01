"""Integration tests for the notes CRUD endpoints.

What each test proves
---------------------
1. test_notes_list_empty_on_fresh_user
   A newly created user has no notes; GET /me/notes returns an empty list,
   confirming the notes table exists and RLS is configured correctly.

2. test_create_note_returns_201
   POST /me/notes with a valid title creates a note and returns 201 with the
   persisted row including server-assigned id, created_at, and updated_at.

3. test_list_notes_returns_created_note
   After creation, GET /me/notes includes the new note, proving the list
   endpoint reads through RLS and returns data scoped to the user.

4. test_get_single_note_returns_200
   GET /me/notes/{id} returns the individual note, proving the single-row
   path through the repo and RLS works correctly.

5. test_patch_note_updates_title
   PATCH /me/notes/{id} changes only the supplied field and returns the updated
   row. This is the PATCH-semantics end-to-end proof.

6. test_delete_note_returns_204
   DELETE /me/notes/{id} returns 204 and the note is gone from the list
   afterwards. Also proves the trigger-managed updated_at column did not
   cause an error on delete.

7. test_get_deleted_note_returns_404
   GET /me/notes/{id} after deletion returns 404 — confirming the "not found"
   branch in the router handler fires correctly.

Run locally (requires `supabase start` and the three env vars exported):

    export SUPABASE_URL=http://127.0.0.1:54321
    export SUPABASE_PUBLIC_ANON_KEY=<anon key from supabase status>
    export SUPABASE_SERVICE_ROLE_KEY=<service role key from supabase status>
    cd backend
    uv run pytest tests/integration/ -v -m integration
"""

import pytest

pytestmark = pytest.mark.integration


def test_notes_list_empty_on_fresh_user(integration_client, test_credentials: dict) -> None:
    """Fresh user → GET /me/notes returns an empty list."""
    resp = integration_client.get(
        "/api/v1/me/notes",
        headers={"Authorization": f"Bearer {test_credentials['access_token']}"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json() == []


def test_create_note_returns_201(integration_client, test_credentials: dict) -> None:
    """POST /me/notes with a valid body → 201 with the persisted note."""
    resp = integration_client.post(
        "/api/v1/me/notes",
        json={"title": "Integration test note", "body": "Hello from CI"},
        headers={"Authorization": f"Bearer {test_credentials['access_token']}"},
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["title"] == "Integration test note"
    assert data["body"] == "Hello from CI"
    assert data["user_id"] == test_credentials["user_id"]
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data
    # Store id for use in subsequent tests via shared credentials dict.
    test_credentials["note_id"] = data["id"]


def test_list_notes_returns_created_note(integration_client, test_credentials: dict) -> None:
    """GET /me/notes returns the note created in the previous test."""
    note_id = test_credentials.get("note_id")
    if not note_id:
        pytest.skip("Depends on test_create_note_returns_201 — run the full suite.")

    resp = integration_client.get(
        "/api/v1/me/notes",
        headers={"Authorization": f"Bearer {test_credentials['access_token']}"},
    )
    assert resp.status_code == 200, resp.text
    ids = [n["id"] for n in resp.json()]
    assert note_id in ids


def test_get_single_note_returns_200(integration_client, test_credentials: dict) -> None:
    """GET /me/notes/{id} returns the individual note."""
    note_id = test_credentials.get("note_id")
    if not note_id:
        pytest.skip("Depends on test_create_note_returns_201 — run the full suite.")

    resp = integration_client.get(
        f"/api/v1/me/notes/{note_id}",
        headers={"Authorization": f"Bearer {test_credentials['access_token']}"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == note_id


def test_patch_note_updates_title(integration_client, test_credentials: dict) -> None:
    """PATCH /me/notes/{id} changes the title and returns the updated row."""
    note_id = test_credentials.get("note_id")
    if not note_id:
        pytest.skip("Depends on test_create_note_returns_201 — run the full suite.")

    resp = integration_client.patch(
        f"/api/v1/me/notes/{note_id}",
        json={"title": "Patched title"},
        headers={"Authorization": f"Bearer {test_credentials['access_token']}"},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["title"] == "Patched title"
    # Body must be unchanged (PATCH semantics — only sent fields are modified).
    assert data["body"] == "Hello from CI"
    assert data["id"] == note_id


def test_delete_note_returns_204(integration_client, test_credentials: dict) -> None:
    """DELETE /me/notes/{id} → 204 No Content and note absent from list."""
    note_id = test_credentials.get("note_id")
    if not note_id:
        pytest.skip("Depends on test_create_note_returns_201 — run the full suite.")

    del_resp = integration_client.delete(
        f"/api/v1/me/notes/{note_id}",
        headers={"Authorization": f"Bearer {test_credentials['access_token']}"},
    )
    assert del_resp.status_code == 204, del_resp.text

    # Confirm the note no longer appears in the list.
    list_resp = integration_client.get(
        "/api/v1/me/notes",
        headers={"Authorization": f"Bearer {test_credentials['access_token']}"},
    )
    assert list_resp.status_code == 200
    ids = [n["id"] for n in list_resp.json()]
    assert note_id not in ids


def test_get_deleted_note_returns_404(integration_client, test_credentials: dict) -> None:
    """GET /me/notes/{id} after deletion → 404 Not Found."""
    note_id = test_credentials.get("note_id")
    if not note_id:
        pytest.skip("Depends on test_create_note_returns_201 — run the full suite.")

    resp = integration_client.get(
        f"/api/v1/me/notes/{note_id}",
        headers={"Authorization": f"Bearer {test_credentials['access_token']}"},
    )
    assert resp.status_code == 404, resp.text
