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
    WAITING_RESTAURANT = "waiting_restaurant"
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
    matching_group_id: str
    restaurant_id: Optional[str] = None
    name: str = Field(..., min_length=1, max_length=100)
    date: datetime
    status: DiningEventStatus = DiningEventStatus.PLANNED
    description: Optional[str] = Field(None, max_length=500)

class DiningEventCreate(DiningEventBase):
    pass

class DiningEventResponse(DiningEventBase):
    id: UUID
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容

class DiningEventParticipantBase(BaseModel):
    event_id: str
    user_id: str
    attendance_status: str = "pending"  # 'pending', 'confirmed', 'declined'

class DiningEventParticipantCreate(DiningEventParticipantBase):
    pass

class DiningEventParticipant(DiningEventParticipantBase):
    id: UUID
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容

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
        from_attributes = True
        orm_mode = True  # 為了向後兼容

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
        from_attributes = True
        orm_mode = True  # 為了向後兼容

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
    pass  # 不需要手動輸入user_id，將從JWT令牌中獲取

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
        from_attributes = True
        orm_mode = True  # 為了向後兼容

# 新增確認餐廳和更換餐廳的響應模型
class ConfirmRestaurantRequest(BaseModel):
    reservation_name: str = Field(..., min_length=1, max_length=100)
    reservation_phone: str = Field(..., min_length=8, max_length=20)
    attendee_count: int = Field(..., ge=1, le=20)

class ConfirmRestaurantResponse(BaseModel):
    success: bool
    message: str
    event_id: str
    restaurant_id: str
    restaurant_name: str

class ChangeRestaurantResponse(BaseModel):
    success: bool
    message: str
    event_id: str
    restaurant: Dict[str, Any] 