from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    display_name: str | None
    avatar_url: str | None
    created_at: datetime
