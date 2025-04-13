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
        from_attributes = True
        orm_mode = True  # 為了向後兼容

class BatchMatchingRequest(BaseModel):
    matching_date: Optional[datetime] = None  # 可選，不提供則默認為當前日期

class BatchMatchingResponse(BaseModel):
    success: bool
    message: str
    matched_groups: Optional[int] = None
    remaining_users: Optional[int] = None

class JoinMatchingRequest(BaseModel):
    pass  # 不需要手動輸入user_id，將從JWT令牌中獲取

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

# 新增配對算法所需的模型
class MatchingGroup(BaseModel):
    id: UUID
    user_ids: List[UUID]
    personality_type: str  # 分析型, 功能型, 直覺型, 個人型
    is_complete: bool = False  # 是否為完整的4人組
    male_count: int = 0
    female_count: int = 0
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: Optional[datetime] = None
    status: str = "waiting_confirmation"  # waiting_confirmation, confirmed, cancelled

    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容

class MatchingUser(BaseModel):
    id: UUID
    user_id: UUID
    gender: str  # male 或 female
    personality_type: str  # 分析型, 功能型, 直覺型, 個人型
    status: str = "waiting_matching"  # waiting_matching, matched, cancelled
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容

class UserMatchingInfo(BaseModel):
    id: UUID
    user_id: UUID
    matching_group_id: Optional[UUID] = None
    confirmation_deadline: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容

class UserStatusExtended(BaseModel):
    id: UUID
    user_id: UUID
    status: str
    group_id: Optional[UUID] = None
    confirmation_deadline: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容 