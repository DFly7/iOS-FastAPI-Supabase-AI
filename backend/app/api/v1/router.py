# Aggregate v1 routes. Add feature routers with api_router.include_router(...).
# To protect all v1 routes: APIRouter(dependencies=[Depends(verify_jwt)])

from fastapi import APIRouter, Depends, HTTPException

from app.api.v1.notes import router as notes_router
from app.core.auth import AuthenticatedClient, get_authenticated_client, verify_jwt
from app.schemas.profile import ProfileOut, ProfileUpdate

api_router = APIRouter()

# Feature routers — add yours here as the app grows.
api_router.include_router(notes_router)


@api_router.get("/ping")
def ping() -> dict:
    return {"ok": True}


@api_router.get("/secure-test")
def secure_test(auth_data: dict = Depends(verify_jwt)) -> dict:
    return {
        "message": "Token valid",
        "user_id": auth_data["payload"].get("sub"),
    }


@api_router.get("/me/profile", response_model=ProfileOut)
def get_my_profile(auth: AuthenticatedClient = Depends(get_authenticated_client)) -> ProfileOut:
    """Load the signed-in user's row from `public.profiles`.

    RLS is enforced via the user's JWT on PostgREST.
    """
    user_id = auth.payload["sub"]
    res = (
        auth.client.table("profiles")
        .select("id, display_name, avatar_url, created_at")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    rows = res.data or []
    if not rows:
        raise HTTPException(
            status_code=404,
            detail=(
                "No profile row found. Run migrations and sign up again, or run "
                "supabase db reset locally."
            ),
        )
    return ProfileOut.model_validate(rows[0])


@api_router.patch("/me/profile", response_model=ProfileOut)
def update_my_profile(
    payload: ProfileUpdate,
    auth: AuthenticatedClient = Depends(get_authenticated_client),
) -> ProfileOut:
    """Partially update the signed-in user's profile (PATCH semantics).

    Only the fields included in the request body are changed. Omit a field to
    leave it unchanged. Returns the full updated profile row.
    """
    user_id = auth.payload["sub"]
    changes = payload.model_dump(exclude_none=True)
    if not changes:
        raise HTTPException(
            status_code=422,
            detail="Request body must include at least one field to update.",
        )
    res = (
        auth.client.table("profiles")
        .update(changes)
        .eq("id", user_id)
        .execute()
    )
    rows = res.data or []
    if not rows:
        raise HTTPException(status_code=404, detail="Profile not found.")
    return ProfileOut.model_validate(rows[0])


# Example of including another feature router:
# from app.api.v1.invoices import router as invoices_router
# api_router.include_router(invoices_router, prefix="/invoices", tags=["invoices"])
