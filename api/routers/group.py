from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client
from typing import List, Optional

from schemas.group import GroupCreate, GroupResponse, GroupMember, GroupMemberCreate
from dependencies import get_supabase, get_current_user

router = APIRouter()

@router.post("/create", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
async def create_group(
    group: GroupCreate,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    創建新群組
    """
    pass

@router.get("/{group_id}", response_model=GroupResponse)
async def get_group(
    group_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取群組信息
    """
    pass

@router.post("/{group_id}/member", response_model=GroupMember)
async def add_group_member(
    group_id: str,
    member: GroupMemberCreate,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    新增群組成員
    """
    pass

@router.get("/{group_id}/members", response_model=List[GroupMember])
async def get_group_members(
    group_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取群組所有成員
    """
    pass

@router.delete("/{group_id}/member/{user_id}")
async def remove_group_member(
    group_id: str,
    user_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    移除群組成員
    """
    pass 