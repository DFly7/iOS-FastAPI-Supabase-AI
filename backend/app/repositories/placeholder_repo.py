# Replace with repositories per aggregate (e.g. invoice_repo.py, user_repo.py).
# Pattern: accept a supabase Client as the first argument so the caller controls
# the security context (e.g. user-scoped vs server-side client).
from supabase import Client


def fetch_placeholder(client: Client) -> None:
    pass
