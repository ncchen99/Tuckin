from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from uuid import UUID

class GroupMemberBase(BaseModel):
    user_id: str
    group_id: str

class GroupMemberCreate(GroupMemberBase):
    pass

class GroupMember(GroupMemberBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容

class GroupBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)

class GroupCreate(GroupBase):
    creator_id: str

class GroupResponse(GroupBase):
    id: UUID
    creator_id: str
    created_at: datetime
    members: Optional[List[GroupMember]] = None

    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容

class GroupUuidMapping(BaseModel):
    group_id: str
    user_id: str

    class Config:
        from_attributes = True
        orm_mode = True  # 為了向後兼容 