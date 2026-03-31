# Aggregate v1 routes. Add feature routers with api_router.include_router(...).
# To protect all v1 routes: APIRouter(dependencies=[Depends(verify_jwt)])

from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import AuthenticatedClient, get_authenticated_client, verify_jwt
from app.schemas.profile import ProfileOut

api_router = APIRouter()


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
    """Load the signed-in user's row from `public.profiles` (RLS enforced via user's JWT on PostgREST)."""
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
            detail="No profile row found. Run migrations and sign up again, or run supabase db reset locally.",
        )
    return ProfileOut.model_validate(rows[0])


# Example:
# from app.api.v1.transactions import router as transactions_router
# api_router.include_router(transactions_router, prefix="/transactions", tags=["transactions"])
