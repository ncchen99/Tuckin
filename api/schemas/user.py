from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class UserProfileBase(BaseModel):
    nickname: str = Field(..., min_length=1, max_length=50)
    gender: Optional[str] = Field(None, max_length=10)
    personal_desc: Optional[str] = Field(None, max_length=500)

class UserProfileCreate(UserProfileBase):
    user_id: str

class UserProfileUpdate(UserProfileBase):
    nickname: Optional[str] = Field(None, min_length=1, max_length=50)

class UserProfileResponse(UserProfileBase):
    user_id: str
    avatar_path: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True
        orm_mode = True

class AvatarUploadResponse(BaseModel):
    """頭像上傳響應，包含 Presigned PUT URL"""
    upload_url: str
    avatar_path: str
    expires_in: int = 3600
    
class AvatarUrlResponse(BaseModel):
    """頭像讀取響應，包含 Presigned GET URL"""
    url: str
    expires_in: int = 3600

class UserDeviceToken(BaseModel):
    user_id: str
    token: str
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True
        orm_mode = True 