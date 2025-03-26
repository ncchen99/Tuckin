from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from enum import Enum

class DiningEventStatus(str, Enum):
    PLANNED = "planned"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"

class DiningEventBase(BaseModel):
    group_id: str
    restaurant_id: Optional[str] = None
    name: str = Field(..., min_length=1, max_length=100)
    date: datetime
    status: DiningEventStatus = DiningEventStatus.PLANNED
    description: Optional[str] = Field(None, max_length=500)

class DiningEventCreate(DiningEventBase):
    creator_id: str

class DiningEventResponse(DiningEventBase):
    id: UUID
    creator_id: str
    created_at: datetime

    class Config:
        orm_mode = True

class DiningEventParticipantBase(BaseModel):
    event_id: str
    user_id: str
    is_attending: bool = True

class DiningEventParticipantCreate(DiningEventParticipantBase):
    pass

class DiningEventParticipant(DiningEventParticipantBase):
    id: UUID
    created_at: datetime

    class Config:
        orm_mode = True

class MatchingScoreBase(BaseModel):
    user_id: str
    target_user_id: str
    score: float = 0.0
    last_calculated: datetime

class MatchingScoreCreate(MatchingScoreBase):
    pass

class MatchingScore(MatchingScoreBase):
    id: UUID

    class Config:
        orm_mode = True 