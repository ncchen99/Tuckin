from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from supabase import Client
from typing import List, Optional, Dict, Any

from schemas.dining import (
    ConfirmAttendanceRequest, ConfirmAttendanceResponse,
    GroupStatusResponse, RatingRequest, RatingResponse,
    TableAttendanceConfirmation, DiningUserStatus
)
from dependencies import get_supabase, get_supabase_service, get_current_user, verify_cron_api_key

router = APIRouter()

@router.post("/confirm", response_model=ConfirmAttendanceResponse, status_code=status.HTTP_200_OK)
async def confirm_attendance(
    request: ConfirmAttendanceRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    用戶確認聚餐出席狀態
    """
    # 檢查用戶是否在該桌位
    # 更新確認狀態
    # 若不出席，嘗試補位
    
    return {
        "success": True, 
        "message": "已成功更新您的出席狀態",
        "confirmed_status": request.status
    }

# 查詢桌位中所有用戶的確認狀態，應該不需要
@router.get("/groups/{group_id}/status", response_model=GroupStatusResponse)
async def get_group_status(
    group_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    查詢桌位中所有用戶的確認狀態
    """
    # 從數據庫獲取該桌位所有成員的確認狀態
    
    # 模擬示例響應
    return {
        "group_id": group_id,
        "status": DiningUserStatus.WAITING_CONFIRMATION,
        "members": [
            {"user_id": "user1", "status": TableAttendanceConfirmation.ATTEND},
            {"user_id": "user2", "status": TableAttendanceConfirmation.ATTEND},
            {"user_id": "user3", "status": TableAttendanceConfirmation.PENDING},
            {"user_id": "user4", "status": TableAttendanceConfirmation.PENDING}
        ]
    }

@router.post("/confirmation-timeout", status_code=status.HTTP_200_OK)
async def handle_confirmation_timeout(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase)
):
    """
    處理確認超時（後台定時任務）
    確認截止後，處理未確認用戶並嘗試補位
    """
    # 實際實現會將此邏輯放入背景任務
    background_tasks.add_task(process_confirmation_timeout, supabase)
    return {"success": True, "message": "確認超時處理任務已啟動"}

@router.post("/matching-failed", status_code=status.HTTP_200_OK, dependencies=[Depends(verify_cron_api_key)])
async def handle_matching_failed(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase)
):
    """
    處理配對失敗（後台定時任務）
    將未配對成功的用戶標記為配對失敗
    此API僅限授權的Cron任務調用
    """
    # 實際實現會將此邏輯放入背景任務
    background_tasks.add_task(process_matching_failed, supabase)
    return {"success": True, "message": "配對失敗處理任務已啟動"}

@router.post("/low-attendance", status_code=status.HTTP_200_OK)
async def handle_low_attendance(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase)
):
    """
    處理低出席率（後台定時任務）
    確認階段結束後，若桌位出席人數<3，處理已確認用戶
    """
    # 實際實現會將此邏輯放入背景任務
    background_tasks.add_task(process_low_attendance, supabase)
    return {"success": True, "message": "低出席率處理任務已啟動"}

# 評分API
@router.post("/ratings/submit", response_model=RatingResponse, status_code=status.HTTP_200_OK)
async def submit_rating(
    request: RatingRequest,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    活動結束後用戶提交評分
    """
    # 檢查用戶是否參加了該桌位
    # 記錄評分和評論
    
    return {"success": True, "message": "評分提交成功"}

# 背景任務處理函數
async def process_confirmation_timeout(supabase: Client):
    """確認超時處理邏輯"""
    # 查找所有未確認的用戶
    # 更新狀態為 confirmation_timeout
    # 嘗試從等待名單補位
    # 若桌位出席人數<3，標記為 low_attendance
    pass

async def process_matching_failed(supabase: Client):
    """配對失敗處理邏輯"""
    # 查找所有 waiting_matching 狀態的用戶
    # 更新狀態為 matching_failed
    # 發送通知
    pass

async def process_low_attendance(supabase: Client):
    """低出席率處理邏輯"""
    # 查找所有出席人數<3的桌位
    # 更新已確認用戶狀態為 low_attendance
    # 發送通知
    pass 