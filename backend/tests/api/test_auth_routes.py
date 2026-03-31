"""Tests for JWT-protected routes.

Uses FastAPI's dependency_overrides to bypass real JWKS verification so these
tests run without a live Supabase instance. Replace the mock payload with whatever
claims your route handlers actually read (sub, email, role, etc.).
"""

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
    from unittest.mock import MagicMock

    mock_supabase = MagicMock()
    mock_supabase.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = (
        []
    )

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
