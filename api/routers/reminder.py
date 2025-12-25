from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from supabase import Client
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from pydantic import BaseModel
import logging

from dependencies import get_supabase_service, verify_cron_api_key
from services.reminder_service import (
    process_reminder_booking,
    process_reminder_attendance,
    REMINDER_TARGET_STATUSES
)


# ===== 請求模型 =====

class ReminderTestRequest(BaseModel):
    """測試提醒通知的請求模型"""
    reminder_type: str  # "reminder_booking" 或 "reminder_attendance"
    dry_run: bool = True  # 預設為 dry_run 模式
    test_user_ids: Optional[List[str]] = None  # 指定測試用戶


router = APIRouter()
logger = logging.getLogger(__name__)


# ===== 背景任務執行器 =====

async def execute_reminder_in_background(
    supabase: Client,
    task_id: str,
    task_type: str,
    dry_run: bool = False,
    test_user_ids: Optional[List[str]] = None
):
    """
    在背景執行提醒任務
    """
    try:
        now_utc = datetime.now(timezone.utc)
        
        if task_type == "reminder_booking":
            result = await process_reminder_booking(supabase, dry_run=dry_run, test_user_ids=test_user_ids)
        elif task_type == "reminder_attendance":
            result = await process_reminder_attendance(supabase, dry_run=dry_run, test_user_ids=test_user_ids)
        else:
            logger.error(f"[背景任務] 未知的任務類型: {task_type}")
            return
        
        # 更新任務狀態（僅在非測試模式下）
        if task_id and not dry_run and not test_user_ids:
            supabase.table("schedule_table").update({
                "status": "done",
                "updated_at": now_utc.isoformat(),
            }).eq("id", task_id).execute()
        
        logger.info(f"[背景任務] {task_type} 執行完成: {result}")
        
    except Exception as e:
        logger.error(f"[背景任務] {task_type} 執行失敗: {e}")
        
        # 更新任務狀態為失敗
        if task_id and not dry_run and not test_user_ids:
            try:
                supabase.table("schedule_table").update({
                    "status": "failed",
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }).eq("id", task_id).execute()
            except:
                pass


@router.post("/test", dependencies=[Depends(verify_cron_api_key)])
async def test_reminder(
    request: ReminderTestRequest,
    supabase: Client = Depends(get_supabase_service)
) -> Dict[str, Any]:
    """
    測試提醒通知功能
    
    支援功能：
    1. dry_run=True（預設）：僅模擬執行，不實際發送通知，會回傳將會發送的用戶列表
    2. test_user_ids：指定測試用戶 ID，只對這些用戶發送通知
    
    使用範例：
    ```json
    // 1. 完全模擬，不發送任何通知
    {
        "reminder_type": "reminder_booking",
        "dry_run": true
    }
    
    // 2. 只對指定用戶發送真實通知
    {
        "reminder_type": "reminder_booking",
        "dry_run": false,
        "test_user_ids": ["your-user-id-here"]
    }
    
    // 3. 模擬對指定用戶發送（查看該用戶會收到什麼）
    {
        "reminder_type": "reminder_attendance",
        "dry_run": true,
        "test_user_ids": ["your-user-id-here"]
    }
    ```
    """
    if request.reminder_type not in ["reminder_booking", "reminder_attendance"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"不支援的提醒類型: {request.reminder_type}，請使用 'reminder_booking' 或 'reminder_attendance'"
        )
    
    try:
        if request.reminder_type == "reminder_booking":
            result = await process_reminder_booking(
                supabase,
                dry_run=request.dry_run,
                test_user_ids=request.test_user_ids
            )
        else:
            result = await process_reminder_attendance(
                supabase,
                dry_run=request.dry_run,
                test_user_ids=request.test_user_ids
            )
        
        return {
            "success": True,
            "test_mode": True,
            "dry_run": request.dry_run,
            "result": result
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"測試提醒時發生錯誤: {str(e)}",
        )


@router.get("/preview", dependencies=[Depends(verify_cron_api_key)])
async def preview_reminder_recipients(
    reminder_type: str,
    supabase: Client = Depends(get_supabase_service)
) -> Dict[str, Any]:
    """
    預覽將會收到提醒的用戶列表（不發送任何通知）
    
    用於在發送前確認目標用戶
    
    Args:
        reminder_type: "reminder_booking" 或 "reminder_attendance"
    """
    if reminder_type not in REMINDER_TARGET_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"不支援的提醒類型: {reminder_type}"
        )
    
    try:
        target_statuses = REMINDER_TARGET_STATUSES[reminder_type]
        
        # 獲取符合條件的用戶
        result = (
            supabase.table("user_status")
            .select("user_id, status")
            .in_("status", target_statuses)
            .execute()
        )
        
        users = result.data or []
        
        # 獲取用戶的 nickname（可選）
        user_details = []
        for user in users:
            user_id = user["user_id"]
            profile = (
                supabase.table("user_profiles")
                .select("nickname")
                .eq("user_id", user_id)
                .maybe_single()
                .execute()
            )
            user_details.append({
                "user_id": user_id,
                "status": user["status"],
                "nickname": profile.data.get("nickname") if profile.data else None
            })
        
        return {
            "success": True,
            "reminder_type": reminder_type,
            "target_statuses": target_statuses,
            "total_recipients": len(user_details),
            "recipients": user_details
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"預覽時發生錯誤: {str(e)}",
        )

