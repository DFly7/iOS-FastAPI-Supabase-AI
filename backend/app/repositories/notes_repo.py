# Repository for the `notes` table.
# Pattern: accept a Supabase Client as the first argument so the caller controls
# the security context (user-scoped JWT client vs server-side service-role client).
# Each function maps 1-to-1 to a database operation; business logic lives in the service.

from uuid import UUID

from supabase import Client

from app.schemas.notes import NoteIn, NoteOut, NoteUpdate

_SELECT = "id, user_id, title, body, created_at, updated_at"


def list_notes(client: Client, user_id: UUID) -> list[NoteOut]:
    res = (
        client.table("notes")
        .select(_SELECT)
        .eq("user_id", str(user_id))
        .order("created_at", desc=True)
        .execute()
    )
    return [NoteOut.model_validate(row) for row in (res.data or [])]


def get_note(client: Client, note_id: UUID, user_id: UUID) -> NoteOut | None:
    res = (
        client.table("notes")
        .select(_SELECT)
        .eq("id", str(note_id))
        .eq("user_id", str(user_id))
        .limit(1)
        .execute()
    )
    rows = res.data or []
    return NoteOut.model_validate(rows[0]) if rows else None


def create_note(client: Client, user_id: UUID, payload: NoteIn) -> NoteOut:
    res = (
        client.table("notes")
        .insert({"user_id": str(user_id), "title": payload.title, "body": payload.body})
        .execute()
    )
    return NoteOut.model_validate(res.data[0])


def update_note(
    client: Client, note_id: UUID, user_id: UUID, payload: NoteUpdate
) -> NoteOut | None:
    changes = payload.model_dump(exclude_none=True)
    if not changes:
        return get_note(client, note_id, user_id)
    res = (
        client.table("notes")
        .update(changes)
        .eq("id", str(note_id))
        .eq("user_id", str(user_id))
        .execute()
    )
    rows = res.data or []
    return NoteOut.model_validate(rows[0]) if rows else None


def delete_note(client: Client, note_id: UUID, user_id: UUID) -> bool:
    res = (
        client.table("notes")
        .delete()
        .eq("id", str(note_id))
        .eq("user_id", str(user_id))
        .execute()
    )
    return bool(res.data)
