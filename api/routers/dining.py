from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from supabase import Client
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta, timezone
from uuid import UUID
import asyncio
import logging

from schemas.dining import (
    ConfirmAttendanceRequest, ConfirmAttendanceResponse,
    GroupStatusResponse, RatingRequest, RatingResponse,
    TableAttendanceConfirmation, DiningUserStatus,
    ConfirmRestaurantResponse, ChangeRestaurantResponse
)
from dependencies import get_supabase_service, get_current_user, verify_cron_api_key
from services.notification_service import NotificationService

router = APIRouter()
logger = logging.getLogger(__name__)

# 定時重置confirming狀態的背景任務
async def reset_confirming_status_task(event_id: str, supabase: Client):
    try:
        # 等待20秒進行測試 (實際使用時改回10分鐘 = 600秒)
        await asyncio.sleep(600)
        
        # 獲取聚餐事件詳細信息
        current_event = supabase.table("dining_events") \
            .select("status, status_change_time") \
            .eq("id", event_id) \
            .execute()
            
        if not current_event.data or len(current_event.data) == 0:
            logger.warning(f"無法找到聚餐事件 {event_id} 進行狀態重置")
            return
        
        event_data = current_event.data[0]    
        
        # 檢查當前狀態，只有當狀態仍為confirming時才繼續
        if event_data["status"] != "confirming":
            logger.info(f"聚餐事件 {event_id} 狀態已不是confirming，無需重置")
            return
            
        # 檢查status_change_time是否已超過9.9分鐘
        if event_data.get("status_change_time"):
            # 確保從資料庫獲取的時間是帶時區的
            if isinstance(event_data["status_change_time"], str):
                # 處理字符串格式的時間
                if "Z" in event_data["status_change_time"]:
                    status_change_time = datetime.fromisoformat(event_data["status_change_time"].replace("Z", "+00:00"))
                elif "+" in event_data["status_change_time"] or "-" in event_data["status_change_time"]:
                    # 已經有時區信息
                    status_change_time = datetime.fromisoformat(event_data["status_change_time"])
                else:
                    # 沒有時區信息，假設為UTC
                    status_change_time = datetime.fromisoformat(event_data["status_change_time"]).replace(tzinfo=timezone.utc)
            else:
                # 如果已經是datetime對象，確保有時區信息
                status_change_time = event_data["status_change_time"]
                if status_change_time.tzinfo is None:
                    status_change_time = status_change_time.replace(tzinfo=timezone.utc)
            
            # 使用帶時區的當前時間
            current_time = datetime.now(timezone.utc)
            
            # 計算時間差
            time_diff = current_time - status_change_time
            
            # 如果還沒到9.9分鐘，計算剩餘時間並再次等待
            if time_diff.total_seconds() < 9.9 * 60:
                remaining_seconds = 9.9 * 60 - time_diff.total_seconds()
                logger.info(f"聚餐事件 {event_id} 的confirming狀態還未到時間，還需等待 {remaining_seconds:.1f} 秒")
                await asyncio.sleep(remaining_seconds)
        
        # 再次檢查狀態，確保等待後狀態仍為confirming
        current_event = supabase.table("dining_events") \
            .select("status") \
            .eq("id", event_id) \
            .execute()
            
        if not current_event.data or len(current_event.data) == 0 or current_event.data[0]["status"] != "confirming":
            logger.info(f"聚餐事件 {event_id} 狀態已變更，無需重置")
            return
        
        # 重置狀態
        supabase.table("dining_events") \
            .update({
                "status": "pending_confirmation",
                "updated_at": datetime.now(timezone.utc).isoformat()
            }) \
            .eq("id", event_id) \
            .eq("status", "confirming") \
            .execute()
            
        logger.info(f"已重置聚餐事件 {event_id} 的confirming狀態")
        
    except Exception as e:
        logger.error(f"重置聚餐事件 {event_id} 狀態時出錯: {str(e)}")

# 重置所有超時的confirming狀態事件
async def reset_all_confirming_events(supabase: Client):
    try:
        # 計算10分鐘前的時間
        ten_minutes_ago = (datetime.utcnow() - timedelta(minutes=10)).isoformat()
        
        # 獲取所有需要重置的事件
        events_to_reset = supabase.table("dining_events") \
            .select("id") \
            .eq("status", "confirming") \
            .lt("status_change_time", ten_minutes_ago) \
            .execute()
            
        if not events_to_reset.data or len(events_to_reset.data) == 0:
            logger.info("沒有需要重置的confirming聚餐事件")
            return
            
        # 重置所有符合條件的事件
        event_ids = [event["id"] for event in events_to_reset.data]
        
        # 批量更新
        supabase.table("dining_events") \
            .update({
                "status": "pending_confirmation",
                "updated_at": datetime.utcnow().isoformat()
            }) \
            .in_("id", event_ids) \
            .execute()
            
        logger.info(f"已重置 {len(event_ids)} 個超時的confirming聚餐事件")
        
    except Exception as e:
        logger.error(f"重置所有confirming聚餐事件時出錯: {str(e)}")

# 設置聚餐事件狀態為confirming
@router.post("/start-confirming/{event_id}", response_model=Dict[str, Any])
async def start_confirming(
    event_id: UUID,
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    設置聚餐事件狀態為confirming，表示用戶開始聯繫餐廳進行預訂
    自動在9.9分鐘後檢查並重置未完成的確認狀態
    """
    try:
        # 獲取聚餐事件
        dining_event = supabase.table("dining_events") \
            .select("*") \
            .eq("id", str(event_id)) \
            .execute()
            
        if not dining_event.data or len(dining_event.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到指定的聚餐事件"
            )
            
        event_data = dining_event.data[0]
        
        # 檢查狀態是否為pending_confirmation
        if event_data["status"] != "pending_confirmation":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="聚餐事件狀態不是待確認，無法開始確認流程"
            )
            
        # 更新狀態為confirming
        updated_event = supabase.table("dining_events") \
            .update({
                "status": "confirming", 
                "updated_at": datetime.now(timezone.utc).isoformat()
                # status_change_time將由觸發器自動設置
            }) \
            .eq("id", str(event_id)) \
            .execute()
            
        if not updated_event.data or len(updated_event.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="更新聚餐事件狀態失敗"
            )
        
        # 添加背景任務，9.9分鐘後檢查並重置狀態
        background_tasks.add_task(reset_confirming_status_task, str(event_id), supabase)
        logger.info(f"已設置聚餐事件 {event_id} 的自動重置任務")
        
        return {
            "success": True,
            "message": "已開始確認餐廳預訂流程，9.9分鐘內未確認將自動重置",
            "event_id": str(event_id)
        }
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"設置聚餐事件狀態時發生錯誤: {str(e)}"
        )

# 添加一個管理員API，用於手動重置所有超時的confirming事件
@router.post("/reset-confirming-events", response_model=Dict[str, Any], dependencies=[Depends(verify_cron_api_key)])
async def admin_reset_confirming_events(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_service)
):
    """
    管理員或排程任務API，用於重置所有超時的confirming狀態事件
    """
    # 添加到背景任務執行，避免阻塞API響應
    background_tasks.add_task(reset_all_confirming_events, supabase)
    
    return {
        "success": True,
        "message": "已啟動重置超時confirming狀態的背景任務"
    }

# 確認餐廳API
@router.post("/confirm-restaurant/{event_id}", response_model=ConfirmRestaurantResponse)
async def confirm_restaurant(
    event_id: UUID,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    確認餐廳預訂成功
    - 檢查dining_events的status是否為'confirming'
    - 如果是，將status更新為'confirmed'
    """
    try:
        # 獲取聚餐事件
        dining_event = supabase.table("dining_events") \
            .select("*") \
            .eq("id", str(event_id)) \
            .execute()
            
        if not dining_event.data or len(dining_event.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到指定的聚餐事件"
            )
            
        event_data = dining_event.data[0]
        
        # 檢查狀態是否為confirming
        if event_data["status"] != "confirming":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="聚餐事件狀態不是正在確認中，無法進行確認操作"
            )
            
        # 更新狀態為confirmed
        updated_event = supabase.table("dining_events") \
            .update({
                "status": "confirmed", 
                "updated_at": datetime.utcnow().isoformat()
            }) \
            .eq("id", str(event_id)) \
            .execute()
            
        if not updated_event.data or len(updated_event.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="更新聚餐事件狀態失敗"
            )
            
        # 獲取餐廳資訊
        restaurant_id = event_data["restaurant_id"]
        restaurant = supabase.table("restaurants") \
            .select("*") \
            .eq("id", restaurant_id) \
            .execute()
            
        if not restaurant.data or len(restaurant.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到相關餐廳資訊"
            )
            
        restaurant_name = restaurant.data[0]["name"]
        
        return {
            "success": True,
            "message": "餐廳預訂已確認",
            "event_id": str(event_id),
            "restaurant_id": restaurant_id,
            "restaurant_name": restaurant_name
        }
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"確認餐廳時發生錯誤: {str(e)}"
        )

# 更換餐廳API
@router.post("/change-restaurant/{event_id}", response_model=ChangeRestaurantResponse)
async def change_restaurant(
    event_id: UUID,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    更換餐廳
    - 檢查dining_events的status是否為'confirming'
    - 從candidate_restaurant_ids中取出第一個餐廳ID
    - 更新restaurant_id為新餐廳ID
    - 返回新餐廳的資訊
    """
    try:
        # 獲取聚餐事件
        dining_event = supabase.table("dining_events") \
            .select("*") \
            .eq("id", str(event_id)) \
            .execute()
            
        if not dining_event.data or len(dining_event.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到指定的聚餐事件"
            )
            
        event_data = dining_event.data[0]
        
        # 檢查狀態是否為confirming
        if event_data["status"] != "confirming":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="聚餐事件狀態不是正在確認中，無法更換餐廳"
            )
            
        # 獲取候選餐廳列表
        candidate_ids = event_data.get("candidate_restaurant_ids", [])
        
        if not candidate_ids or len(candidate_ids) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="沒有可用的候選餐廳"
            )
            
        # 取出第一個候選餐廳
        new_restaurant_id = candidate_ids[0]
        remaining_candidates = candidate_ids[1:]
        
        # 獲取新餐廳的資訊
        restaurant = supabase.table("restaurants") \
            .select("*") \
            .eq("id", new_restaurant_id) \
            .execute()
            
        if not restaurant.data or len(restaurant.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到候選餐廳資訊"
            )
            
        restaurant_data = restaurant.data[0]
        
        # 更新聚餐事件，更換餐廳
        updated_event = supabase.table("dining_events") \
            .update({
                "restaurant_id": new_restaurant_id,
                "candidate_restaurant_ids": remaining_candidates,
                "updated_at": datetime.utcnow().isoformat(),
                # 重置狀態變更時間
                "status_change_time": datetime.utcnow().isoformat()
            }) \
            .eq("id", str(event_id)) \
            .execute()
            
        if not updated_event.data or len(updated_event.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="更新餐廳資訊失敗"
            )
        
        return {
            "success": True,
            "message": "餐廳已成功更換",
            "event_id": str(event_id),
            "restaurant": restaurant_data
        }
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更換餐廳時發生錯誤: {str(e)}"
        )

# 評分API
@router.post("/ratings/submit", response_model=RatingResponse, status_code=status.HTTP_200_OK)
async def submit_rating(
    request: RatingRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    活動結束後用戶提交評分
    """
    # 檢查用戶是否參加了該桌位
    # 記錄評分和評論
    
    return {"success": True, "message": "評分提交成功"}


