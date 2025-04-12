from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from uuid import UUID
from enum import Enum

from schemas.dining import DiningUserStatus

class MatchingPreferenceBase(BaseModel):
    user_id: str
    preferred_days: List[int] = []  # 0-6 代表週日到週六
    preferred_times: List[str] = []  # 例如 "morning", "noon", "evening"
    preferred_cuisines: List[str] = []
    preferred_locations: List[str] = []
    preferred_price_range: Optional[str] = None
    other_preferences: Optional[Dict[str, Any]] = None

class MatchingPreferenceCreate(MatchingPreferenceBase):
    pass

class MatchingPreference(MatchingPreferenceBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class BatchMatchingRequest(BaseModel):
    matching_date: Optional[datetime] = None  # 可選，不提供則默認為當前日期

class BatchMatchingResponse(BaseModel):
    success: bool
    message: str
    matched_groups: Optional[int] = None
    remaining_users: Optional[int] = None

class JoinMatchingRequest(BaseModel):
    user_id: str

class JoinMatchingResponse(BaseModel):
    status: str
    message: str
    group_id: Optional[str] = None
    deadline: Optional[datetime] = None

class AutoFormGroupsRequest(BaseModel):
    min_group_size: int = 3
    max_group_size: int = 4

class AutoFormGroupsResponse(BaseModel):
    success: bool
    message: str
    created_groups: Optional[int] = None
    remaining_users: Optional[int] = None

class MatchingUserStatusUpdate(BaseModel):
    user_id: str
    status: DiningUserStatus
    group_id: Optional[str] = None
    confirmation_deadline: Optional[datetime] = None

class MatchingUserStatusUpdateResponse(BaseModel):
    success: bool
    message: str
    updated_status: DiningUserStatus 