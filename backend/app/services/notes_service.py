# Service layer for notes.
# Pattern: one file per use-case / aggregate.
# Services orchestrate one or more repositories and contain business logic.
# Keep repository calls here so routers stay thin (validate input → call service → return schema).

from uuid import UUID

from supabase import Client

from app.repositories import notes_repo
from app.schemas.notes import NoteIn, NoteOut, NoteUpdate


def list_user_notes(client: Client, user_id: UUID) -> list[NoteOut]:
    return notes_repo.list_notes(client, user_id)


def get_user_note(client: Client, note_id: UUID, user_id: UUID) -> NoteOut | None:
    return notes_repo.get_note(client, note_id, user_id)


def create_user_note(client: Client, user_id: UUID, payload: NoteIn) -> NoteOut:
    return notes_repo.create_note(client, user_id, payload)


def update_user_note(
    client: Client, note_id: UUID, user_id: UUID, payload: NoteUpdate
) -> NoteOut | None:
    return notes_repo.update_note(client, note_id, user_id, payload)


def delete_user_note(client: Client, note_id: UUID, user_id: UUID) -> bool:
    return notes_repo.delete_note(client, note_id, user_id)
