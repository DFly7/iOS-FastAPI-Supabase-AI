"""Tests for JWT-protected routes.

Uses FastAPI's dependency_overrides to bypass real JWKS verification so these
tests run without a live Supabase instance. Replace the mock payload with whatever
claims your route handlers actually read (sub, email, role, etc.).
"""

import uuid
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from app.core.auth import AuthenticatedClient, get_authenticated_client, verify_jwt
from app.main import app

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

FAKE_USER_ID = "00000000-0000-0000-0000-000000000001"
FAKE_TOKEN = "mock.jwt.token"

_MOCK_AUTH_DATA = {
    "token": FAKE_TOKEN,
    "payload": {
        "sub": FAKE_USER_ID,
        "email": "test@example.com",
        "aud": "authenticated",
        "role": "authenticated",
    },
}


def _override_verify_jwt() -> dict:
    return _MOCK_AUTH_DATA


# ---------------------------------------------------------------------------
# Tests — /api/v1/secure-test
# ---------------------------------------------------------------------------


def test_secure_test_requires_auth() -> None:
    """No Authorization header → 401."""
    with TestClient(app) as client:
        response = client.get("/api/v1/secure-test")
    assert response.status_code == 401


def test_secure_test_with_valid_jwt() -> None:
    """Valid (mocked) JWT → 200 with user_id from token payload."""
    app.dependency_overrides[verify_jwt] = _override_verify_jwt
    try:
        with TestClient(app) as client:
            response = client.get(
                "/api/v1/secure-test",
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(verify_jwt, None)

    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == FAKE_USER_ID
    assert body["message"] == "Token valid"


# ---------------------------------------------------------------------------
# Tests — /api/v1/me/profile
# ---------------------------------------------------------------------------


def test_get_profile_requires_auth() -> None:
    """No Authorization header → 401."""
    with TestClient(app) as client:
        response = client.get("/api/v1/me/profile")
    assert response.status_code == 401


def test_get_profile_not_found_when_no_row(monkeypatch: pytest.MonkeyPatch) -> None:
    """Profile route returns 404 when PostgREST returns no rows.

    We override get_authenticated_client so no real Supabase client is created,
    then mock the table query chain to return an empty data list.
    """
    mock_supabase = MagicMock()
    chain = mock_supabase.table.return_value.select.return_value
    chain = chain.eq.return_value.limit.return_value
    chain.execute.return_value.data = []

    def _override_authenticated_client() -> AuthenticatedClient:
        # model_construct skips Pydantic validation so MagicMock passes the Client type check.
        return AuthenticatedClient.model_construct(
            client=mock_supabase,
            payload=_MOCK_AUTH_DATA["payload"],
        )

    app.dependency_overrides[get_authenticated_client] = _override_authenticated_client
    try:
        with TestClient(app) as client:
            response = client.get(
                "/api/v1/me/profile",
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# Tests — PATCH /api/v1/me/profile
# ---------------------------------------------------------------------------

_PROFILE_ROW = {
    "id": FAKE_USER_ID,
    "display_name": "Alice",
    "avatar_url": None,
    "created_at": "2026-01-01T00:00:00+00:00",
}


def _make_profile_client(rows: list[dict]) -> MagicMock:
    """Mock Supabase client whose .table(...).update(...).eq(...).execute() returns rows."""
    mock = MagicMock()
    mock.table.return_value.update.return_value.eq.return_value.execute.return_value.data = rows
    return mock


def test_patch_profile_requires_auth() -> None:
    """No Authorization header → 401."""
    with TestClient(app) as client:
        response = client.patch("/api/v1/me/profile", json={"display_name": "Alice"})
    assert response.status_code == 401


def test_patch_profile_empty_body_returns_422() -> None:
    """Empty JSON body (no fields to update) → 422."""
    mock_supabase = MagicMock()

    def _override() -> AuthenticatedClient:
        return AuthenticatedClient.model_construct(
            client=mock_supabase, payload=_MOCK_AUTH_DATA["payload"]
        )

    app.dependency_overrides[get_authenticated_client] = _override
    try:
        with TestClient(app) as client:
            response = client.patch(
                "/api/v1/me/profile",
                json={},
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 422


def test_patch_profile_updates_display_name() -> None:
    """Valid PATCH with display_name → 200 and updated row returned."""
    mock_supabase = _make_profile_client([_PROFILE_ROW])

    def _override() -> AuthenticatedClient:
        return AuthenticatedClient.model_construct(
            client=mock_supabase, payload=_MOCK_AUTH_DATA["payload"]
        )

    app.dependency_overrides[get_authenticated_client] = _override
    try:
        with TestClient(app) as client:
            response = client.patch(
                "/api/v1/me/profile",
                json={"display_name": "Alice"},
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 200
    assert response.json()["display_name"] == "Alice"
    assert response.json()["id"] == FAKE_USER_ID


def test_patch_profile_returns_404_when_row_missing() -> None:
    """PATCH on a missing profile row → 404."""
    mock_supabase = _make_profile_client([])

    def _override() -> AuthenticatedClient:
        return AuthenticatedClient.model_construct(
            client=mock_supabase, payload=_MOCK_AUTH_DATA["payload"]
        )

    app.dependency_overrides[get_authenticated_client] = _override
    try:
        with TestClient(app) as client:
            response = client.patch(
                "/api/v1/me/profile",
                json={"display_name": "Ghost"},
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# Tests — /api/v1/me/notes
# ---------------------------------------------------------------------------

_NOTE_ID = str(uuid.uuid4())
_NOTE_ROW = {
    "id": _NOTE_ID,
    "user_id": FAKE_USER_ID,
    "title": "Test note",
    "body": None,
    "created_at": "2026-01-01T00:00:00+00:00",
    "updated_at": "2026-01-01T00:00:00+00:00",
}


def _notes_auth_override(mock_supabase: MagicMock):
    def _override() -> AuthenticatedClient:
        return AuthenticatedClient.model_construct(
            client=mock_supabase, payload=_MOCK_AUTH_DATA["payload"]
        )

    return _override


def test_list_notes_requires_auth() -> None:
    """No Authorization header → 401."""
    with TestClient(app) as client:
        response = client.get("/api/v1/me/notes")
    assert response.status_code == 401


def test_create_note_requires_auth() -> None:
    """No Authorization header → 401."""
    with TestClient(app) as client:
        response = client.post("/api/v1/me/notes", json={"title": "hi"})
    assert response.status_code == 401


def test_list_notes_returns_empty_list() -> None:
    """GET /me/notes returns [] when no notes exist."""
    mock_supabase = MagicMock()
    (
        mock_supabase.table.return_value.select.return_value.eq.return_value.order.return_value.execute.return_value.data
    ) = []

    app.dependency_overrides[get_authenticated_client] = _notes_auth_override(mock_supabase)
    try:
        with TestClient(app) as client:
            response = client.get(
                "/api/v1/me/notes",
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 200
    assert response.json() == []


def test_list_notes_returns_existing_notes() -> None:
    """GET /me/notes returns a list of the user's notes."""
    mock_supabase = MagicMock()
    (
        mock_supabase.table.return_value.select.return_value.eq.return_value.order.return_value.execute.return_value.data
    ) = [_NOTE_ROW]

    app.dependency_overrides[get_authenticated_client] = _notes_auth_override(mock_supabase)
    try:
        with TestClient(app) as client:
            response = client.get(
                "/api/v1/me/notes",
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["title"] == "Test note"
    assert data[0]["user_id"] == FAKE_USER_ID


def test_create_note_returns_201() -> None:
    """POST /me/notes with valid body → 201 with created row."""
    mock_supabase = MagicMock()
    mock_supabase.table.return_value.insert.return_value.execute.return_value.data = [_NOTE_ROW]

    app.dependency_overrides[get_authenticated_client] = _notes_auth_override(mock_supabase)
    try:
        with TestClient(app) as client:
            response = client.post(
                "/api/v1/me/notes",
                json={"title": "Test note"},
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 201
    assert response.json()["title"] == "Test note"
    assert response.json()["id"] == _NOTE_ID


def test_create_note_missing_title_returns_422() -> None:
    """POST /me/notes without title → 422 Unprocessable Entity."""
    app.dependency_overrides[verify_jwt] = _override_verify_jwt
    try:
        with TestClient(app) as client:
            response = client.post(
                "/api/v1/me/notes",
                json={"body": "no title here"},
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(verify_jwt, None)

    assert response.status_code == 422


def test_get_single_note_returns_404_when_missing() -> None:
    """GET /me/notes/{id} for a non-existent note → 404."""
    mock_supabase = MagicMock()
    (
        mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data
    ) = []

    app.dependency_overrides[get_authenticated_client] = _notes_auth_override(mock_supabase)
    try:
        with TestClient(app) as client:
            response = client.get(
                f"/api/v1/me/notes/{_NOTE_ID}",
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 404


def test_patch_note_returns_updated_note() -> None:
    """PATCH /me/notes/{id} with valid payload → 200 with updated note."""
    updated_row = {**_NOTE_ROW, "title": "Updated title"}
    mock_supabase = MagicMock()
    (
        mock_supabase.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data
    ) = [updated_row]

    app.dependency_overrides[get_authenticated_client] = _notes_auth_override(mock_supabase)
    try:
        with TestClient(app) as client:
            response = client.patch(
                f"/api/v1/me/notes/{_NOTE_ID}",
                json={"title": "Updated title"},
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 200
    assert response.json()["title"] == "Updated title"


def test_delete_note_requires_auth() -> None:
    """No Authorization header → 401."""
    with TestClient(app) as client:
        response = client.delete(f"/api/v1/me/notes/{_NOTE_ID}")
    assert response.status_code == 401


def test_delete_note_returns_204() -> None:
    """DELETE /me/notes/{id} for an existing note → 204 No Content."""
    mock_supabase = MagicMock()
    (
        mock_supabase.table.return_value.delete.return_value.eq.return_value.eq.return_value.execute.return_value.data
    ) = [_NOTE_ROW]

    app.dependency_overrides[get_authenticated_client] = _notes_auth_override(mock_supabase)
    try:
        with TestClient(app) as client:
            response = client.delete(
                f"/api/v1/me/notes/{_NOTE_ID}",
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 204


def test_delete_note_returns_404_when_missing() -> None:
    """DELETE /me/notes/{id} for a non-existent note → 404."""
    mock_supabase = MagicMock()
    (
        mock_supabase.table.return_value.delete.return_value.eq.return_value.eq.return_value.execute.return_value.data
    ) = []

    app.dependency_overrides[get_authenticated_client] = _notes_auth_override(mock_supabase)
    try:
        with TestClient(app) as client:
            response = client.delete(
                f"/api/v1/me/notes/{_NOTE_ID}",
                headers={"Authorization": f"Bearer {FAKE_TOKEN}"},
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_client, None)

    assert response.status_code == 404
