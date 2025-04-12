from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from uuid import UUID
from enum import Enum

class DiningEventStatus(str, Enum):
    PLANNED = "planned"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"

class DiningUserStatus(str, Enum):
    WAITING_MATCHING = "waiting_matching"
    WAITING_CONFIRMATION = "waiting_confirmation"
    WAITING_OTHER_USERS = "waiting_other_users"
    WAITING_ATTENDANCE = "waiting_attendance"
    CONFIRMATION_TIMEOUT = "confirmation_timeout"
    MATCHING_FAILED = "matching_failed"
    LOW_ATTENDANCE = "low_attendance"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class TableAttendanceConfirmation(str, Enum):
    ATTEND = "attend"
    NOT_ATTEND = "not_attend"
    PENDING = "pending"

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

# 新增的聚餐配對流程相關模型
class MatchingUserBase(BaseModel):
    user_id: str
    status: DiningUserStatus = DiningUserStatus.WAITING_MATCHING
    group_id: Optional[str] = None
    confirmation_deadline: Optional[datetime] = None

class MatchingUserCreate(MatchingUserBase):
    pass

class MatchingUser(MatchingUserBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class MatchingGroupBase(BaseModel):
    status: str
    meeting_time: Optional[datetime] = None
    restaurant_id: Optional[str] = None
    min_required_users: int = 3
    max_users: int = 4

class MatchingGroupCreate(MatchingGroupBase):
    pass

class MatchingGroup(MatchingGroupBase):
    id: UUID
    created_at: datetime
    updated_at: datetime
    members: List[Dict[str, Any]] = []

    class Config:
        orm_mode = True

class ConfirmAttendanceRequest(BaseModel):
    user_id: str
    table_id: str
    status: TableAttendanceConfirmation

class ConfirmAttendanceResponse(BaseModel):
    success: bool
    message: str
    confirmed_status: TableAttendanceConfirmation

class GroupStatusResponse(BaseModel):
    group_id: str
    status: str
    members: List[Dict[str, Any]]

class JoinMatchingRequest(BaseModel):
    user_id: str

class MatchingResponse(BaseModel):
    status: str
    message: str
    group_id: Optional[str] = None
    deadline: Optional[datetime] = None

class RatingRequest(BaseModel):
    user_id: str
    table_id: str
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=500)

class RatingResponse(BaseModel):
    success: bool
    message: str

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