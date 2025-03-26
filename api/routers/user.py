from fastapi import APIRouter, Depends, HTTPException, status, Query
from supabase import Client
from typing import List, Optional

from schemas.user import UserProfileCreate, UserProfileResponse, UserProfileUpdate
from dependencies import get_supabase, get_current_user

router = APIRouter()

@router.get("/profile/{user_id}", response_model=UserProfileResponse)
async def get_user_profile(
    user_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取用戶個人資料
    """
    pass

@router.post("/profile", response_model=UserProfileResponse, status_code=status.HTTP_201_CREATED)
async def create_user_profile(
    profile: UserProfileCreate,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    創建用戶個人資料
    """
    pass

@router.put("/profile", response_model=UserProfileResponse)
async def update_user_profile(
    profile: UserProfileUpdate,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    更新用戶個人資料
    """
    pass

@router.get("/profile", response_model=UserProfileResponse)
async def get_my_profile(
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取當前用戶個人資料
    """
    pass

@router.get("/device-tokens", response_model=List[str])
async def get_user_device_tokens(
    user_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取用戶設備令牌列表（用於推送通知）
    """
    pass 