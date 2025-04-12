from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from supabase import Client
from typing import List, Optional, Dict, Any

from schemas.matching import (
    JoinMatchingRequest, JoinMatchingResponse, 
    BatchMatchingResponse, AutoFormGroupsResponse
)
from schemas.dining import DiningUserStatus
from dependencies import get_supabase, get_current_user

router = APIRouter()

@router.post("/batch", response_model=BatchMatchingResponse, status_code=status.HTTP_200_OK)
async def batch_matching(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase)
):
    """
    批量配對任務（週二 6:00 AM 觸發）
    將所有 waiting_matching 狀態的用戶按4人一組進行分組
    """
    # 實際實現會將此邏輯放入背景任務
    background_tasks.add_task(process_batch_matching, supabase)
    return {
        "success": True, 
        "message": "批量配對任務已啟動",
        "matched_groups": None,
        "remaining_users": None
    }

@router.post("/join", response_model=JoinMatchingResponse)
async def join_matching(
    request: JoinMatchingRequest,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    用戶參加聚餐配對
    嘗試將用戶補入不足4人的桌位或進入等待名單
    """
    # 檢查用戶是否已在等待或已配對
    # 查找不足4人的桌位，若有則補入
    # 若無可用桌位，加入等待名單
    
    # 模擬示例響應
    return {
        "status": DiningUserStatus.WAITING_MATCHING,
        "message": "您已加入聚餐配對等待名單",
        "group_id": None,
        "deadline": None
    }

@router.post("/auto-form", response_model=AutoFormGroupsResponse, status_code=status.HTTP_200_OK)
async def auto_form_groups(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase)
):
    """
    自動成桌任務（週三 06:00 AM 觸發）
    若等待名單中用戶數≥3人，自動組成新桌位
    """
    # 實際實現會將此邏輯放入背景任務
    background_tasks.add_task(process_auto_form_groups, supabase)
    return {
        "success": True, 
        "message": "自動成桌任務已啟動",
        "created_groups": None,
        "remaining_users": None
    }

# 背景任務處理函數
async def process_batch_matching(supabase: Client):
    """批量配對處理邏輯"""
    # 從數據庫獲取所有 waiting_matching 狀態的用戶
    # 按4人一組進行分組
    # 更新用戶狀態
    pass

async def process_auto_form_groups(supabase: Client):
    """自動成桌處理邏輯"""
    # 從數據庫獲取等待名單中的用戶
    # 若人數≥3，按3-4人一組組成新桌位
    # 更新用戶狀態
    pass 