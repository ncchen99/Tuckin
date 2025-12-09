from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from supabase import Client
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta, timezone
from uuid import UUID
import asyncio
import logging
import random
import secrets

from schemas.dining import (
    ConfirmAttendanceRequest, ConfirmAttendanceResponse,
    GroupStatusResponse, RatingRequest, RatingResponse,
    TableAttendanceConfirmation, DiningUserStatus,
    ConfirmRestaurantResponse, ChangeRestaurantResponse,
    ConfirmRestaurantRequest, GetRatingFormRequest, GetRatingFormResponse,
    SubmitRatingRequest
)
from dependencies import get_supabase_service, get_current_user, verify_cron_api_key
from services.notification_service import NotificationService
from utils.cloudflare import delete_folder_from_private_r2

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
                try:
                    # 使用更穩健的方法處理ISO格式時間字符串
                    time_str = event_data["status_change_time"]
                    
                    # 解析基本部分
                    if "T" in time_str:
                        date_part, time_part = time_str.split("T")
                    else:
                        date_part, time_part = time_str.split(" ")
                    
                    # 處理時區部分
                    time_zone = "+00:00"  # 預設UTC
                    if "Z" in time_part:
                        time_part = time_part.replace("Z", "")
                    elif "+" in time_part:
                        time_part, time_zone = time_part.split("+")
                        time_zone = f"+{time_zone}"
                    elif "-" in time_part and time_part.rindex("-") > 2:  # 確保是時區的"-"而不是日期的"-"
                        time_part, time_zone = time_part.rsplit("-", 1)
                        time_zone = f"-{time_zone}"
                    
                    # 處理微秒部分
                    if "." in time_part:
                        time_base, microseconds = time_part.split(".")
                        # 限制微秒為6位
                        if len(microseconds) > 6:
                            microseconds = microseconds[:6]
                        time_part = f"{time_base}.{microseconds}"
                    
                    # 重建ISO格式時間字符串
                    clean_time_str = f"{date_part}T{time_part}{time_zone}"
                    
                    # 嘗試使用標準庫解析
                    try:
                        status_change_time = datetime.fromisoformat(clean_time_str)
                    except ValueError:
                        # 如果標準庫解析失敗，使用手動方法
                        if "." in time_part:
                            time_base, microseconds = time_part.split(".")
                            seconds = int(microseconds) / (10 ** len(microseconds))
                        else:
                            time_base = time_part
                            seconds = 0
                        
                        hour, minute, second = map(int, time_base.split(":"))
                        year, month, day = map(int, date_part.split("-"))
                        
                        # 手動構建datetime對象
                        status_change_time = datetime(year, month, day, hour, minute, int(second), 
                                                     int(seconds * 1000000), tzinfo=timezone.utc)
                    
                except Exception as e:
                    # 如果解析失敗，使用當前時間減去9分鐘作為fallback
                    logger.warning(f"無法解析時間字符串 '{event_data['status_change_time']}': {str(e)}，使用當前時間減去9分鐘")
                    status_change_time = datetime.now(timezone.utc) - timedelta(minutes=9)
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
    request: ConfirmRestaurantRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    確認餐廳預訂成功
    - 檢查dining_events的status是否為'confirming'
    - 如果是，將status更新為'confirmed'，並保存訂位人資訊
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
            
        # 準備更新資料
        update_data = {
            "status": "confirmed", 
            "reservation_name": request.reservation_name,
            "reservation_phone": request.reservation_phone,
            "updated_at": datetime.utcnow().isoformat()
        }
        
        # 如果預訂姓名和電話都是空值，表示餐廳無法訂位，生成密語
        if not request.reservation_name.strip() and not request.reservation_phone.strip():
            import random
            passphrases = [
                '不好意思，你可以幫我拍照嗎',
                '不好意思，可以跟你借衛生紙嗎',
                '不好意思，請問火車站怎麼走',
                '不好意思，你有在排隊嗎',
                '想問你有吃過這家店嗎',
                '你好，你也在等朋友嗎',
            ]
            passphrase = random.choice(passphrases)
            update_data["description"] = passphrase
            
        # 更新狀態為confirmed並保存訂位人資訊
        updated_event = supabase.table("dining_events") \
            .update(update_data) \
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

# 獲取評分表單API
@router.post("/ratings/form", response_model=GetRatingFormResponse, status_code=status.HTTP_200_OK)
async def get_rating_form(
    request: GetRatingFormRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    獲取評分表單，返回需要評分的參與者列表（不含用戶ID）
    只有聚餐事件狀態為 completed 時才允許評分
    """
    try:
        user_id = current_user.user.id
        logger.info(f"評分表單請求 - 用戶ID: {user_id}, 聚餐事件ID: {request.dining_event_id}")
        
        # 獲取聚餐事件信息
        dining_event = supabase.table("dining_events") \
            .select("matching_group_id, status") \
            .eq("id", str(request.dining_event_id)) \
            .execute()
            
        if not dining_event.data:
            logger.warning(f"找不到聚餐事件: {request.dining_event_id}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到指定的聚餐事件"
            )
            
        # 檢查聚餐事件狀態是否為 completed
        event_status = dining_event.data[0]["status"]
        group_id = dining_event.data[0]["matching_group_id"]
        logger.info(f"聚餐事件狀態: {event_status}, 群組ID: {group_id}")
        
        if event_status != "completed":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="只有在聚餐事件完成後才能進行評分"
            )
        
        # 驗證用戶是否參與了該聚餐群組
        logger.info(f"查詢用戶配對信息 - 用戶ID: {user_id}, 群組ID: {group_id}")
        user_group = supabase.table("user_matching_info") \
            .select("matching_group_id") \
            .eq("user_id", user_id) \
            .eq("matching_group_id", group_id) \
            .execute()
        
        logger.info(f"用戶配對查詢結果: {user_group.data}")
        
        if not user_group.data:
            # 額外查詢：檢查該用戶是否有任何配對信息
            all_user_groups = supabase.table("user_matching_info") \
                .select("matching_group_id") \
                .eq("user_id", user_id) \
                .execute()
            logger.warning(f"用戶 {user_id} 的所有配對信息: {all_user_groups.data}")
            
            # 檢查該群組的所有成員
            group_members = supabase.table("matching_groups") \
                .select("user_ids") \
                .eq("id", group_id) \
                .execute()
            logger.warning(f"群組 {group_id} 的成員: {group_members.data}")
            
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="您沒有參與此聚餐事件，無法提交評分"
            )
        
        # 檢查是否已有現有會話
        existing_session = supabase.table("rating_sessions") \
            .select("*") \
            .eq("dining_event_id", str(request.dining_event_id)) \
            .eq("from_user_id", user_id) \
            .execute()
            
        # 如果已有現有會話，更新有效期並直接返回
        if existing_session.data:
            logger.info(f"找到現有會話，返回現有評分表單")
            session_data = existing_session.data[0]
            
            # 設置新的過期時間（24小時後）
            expires_at = datetime.now(timezone.utc) + timedelta(hours=24)
            
            # 更新會話過期時間
            supabase.table("rating_sessions") \
                .update({
                    "expires_at": expires_at.isoformat()
                }) \
                .eq("id", session_data["id"]) \
                .execute()
                
            # 返回現有會話數據
            user_sequence = session_data.get("user_sequence", [])
            participants_response = [
                {
                    "index": item["index"], 
                    "nickname": item["nickname"],
                    "gender": item.get("gender", "male"),
                    "avatar_index": item.get("avatar_index", 1)
                } 
                for item in user_sequence
            ]
            
            return {
                "success": True,
                "message": "已返回現有評分表單",
                "session_token": session_data["session_token"],
                "participants": participants_response
            }
            
        # 沒有現有會話，創建新的評分表單
        logger.info(f"沒有找到現有會話，創建新的評分表單")
        
        # 獲取聚餐群組的所有參與者（排除當前用戶）
        group_info = supabase.table("matching_groups") \
            .select("user_ids") \
            .eq("id", group_id) \
            .execute()
            
        if not group_info.data or not group_info.data[0].get("user_ids"):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到聚餐群組成員資訊"
            )
            
        # 獲取群組成員ID
        all_user_ids = group_info.data[0]["user_ids"]
        
        # 排除當前用戶
        participant_ids = [uid for uid in all_user_ids if uid != user_id]
        
        if not participant_ids:
            return {
                "success": True,
                "message": "沒有其他參與者需要評分",
                "session_token": "",
                "participants": []
            }
        
        # 獲取參與者暱稱與性別
        profiles = supabase.table("user_profiles") \
            .select("user_id, nickname, gender") \
            .in_("user_id", participant_ids) \
            .execute()
        
        # 建立用戶映射
        id_to_profile = {p["user_id"]: {"nickname": p["nickname"], "gender": p["gender"]} for p in profiles.data}
        
        # 生成隨機順序的參與者列表
        random_order = participant_ids.copy()
        random.shuffle(random_order)
        
        # 創建前端顯示用的序列（包含索引、暱稱和性別）
        user_sequence = [
            {
                "index": i, 
                "nickname": id_to_profile.get(uid, {}).get("nickname", "未知用戶"),
                "gender": id_to_profile.get(uid, {}).get("gender", "male"),
                "avatar_index": (i % 6) + 1  # 可選：生成1-6範圍的隨機頭像索引
            }
            for i, uid in enumerate(random_order)
        ]
        
        # 創建後端映射用的對照表（索引到用戶ID）
        user_mapping = {
            str(i): uid for i, uid in enumerate(random_order)
        }
        
        # 生成安全的會話令牌
        session_token = secrets.token_urlsafe(32)
        
        # 設置過期時間（例如24小時後）使用帶時區的時間
        expires_at = datetime.now(timezone.utc) + timedelta(hours=24)
        
        # 保存評分會話
        supabase.table("rating_sessions").insert({
            "dining_event_id": str(request.dining_event_id),
            "from_user_id": user_id,
            "session_token": session_token,
            "user_sequence": user_sequence,
            "user_mapping": user_mapping,
            "expires_at": expires_at.isoformat()
        }).execute()
        
        # 轉換為API響應格式 - 包含必要的性別資訊和頭像索引
        participants_response = [
            {
                "index": item["index"], 
                "nickname": item["nickname"],
                "gender": item["gender"],
                "avatar_index": item["avatar_index"]
            } 
            for item in user_sequence
        ]
        
        return {
            "success": True,
            "message": "評分表單生成成功",
            "session_token": session_token,
            "participants": participants_response
        }
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"獲取評分表單時出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取評分表單時出錯: {str(e)}"
        )

# 提交評分API
@router.post("/ratings/submit", response_model=RatingResponse, status_code=status.HTTP_200_OK)
async def submit_rating(
    request: SubmitRatingRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    活動結束後用戶提交評分
    只有聚餐事件狀態為 completed 時才允許評分
    """
    try:
        user_id = current_user.user.id
        
        # 驗證會話令牌
        session = supabase.table("rating_sessions") \
            .select("*") \
            .eq("session_token", request.session_token) \
            .eq("from_user_id", user_id) \
            .execute()
        
        if not session.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="無效的評分會話"
            )
        
        session_data = session.data[0]
        dining_event_id = session_data["dining_event_id"]
        
        # 檢查聚餐事件狀態是否為 completed
        dining_event = supabase.table("dining_events") \
            .select("status") \
            .eq("id", dining_event_id) \
            .execute()
            
        if not dining_event.data or dining_event.data[0]["status"] != "completed":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="只有在聚餐事件完成後才能進行評分"
            )
        
        # 檢查會話是否過期，使用帶時區的datetime
        from datetime import datetime, timezone
        expires_at_str = session_data["expires_at"]
        
        # 確保expires_at字符串有時區信息
        try:
            # 使用更穩健的方法處理ISO格式時間字符串
            time_str = expires_at_str
            
            # 解析基本部分
            if "T" in time_str:
                date_part, time_part = time_str.split("T")
            else:
                date_part, time_part = time_str.split(" ")
            
            # 處理時區部分
            time_zone = "+00:00"  # 預設UTC
            if "Z" in time_part:
                time_part = time_part.replace("Z", "")
            elif "+" in time_part:
                time_part, time_zone = time_part.split("+")
                time_zone = f"+{time_zone}"
            elif "-" in time_part and time_part.rindex("-") > 2:  # 確保是時區的"-"而不是日期的"-"
                time_part, time_zone = time_part.rsplit("-", 1)
                time_zone = f"-{time_zone}"
            
            # 處理微秒部分
            if "." in time_part:
                time_base, microseconds = time_part.split(".")
                # 限制微秒為6位
                if len(microseconds) > 6:
                    microseconds = microseconds[:6]
                time_part = f"{time_base}.{microseconds}"
            
            # 重建ISO格式時間字符串
            clean_time_str = f"{date_part}T{time_part}{time_zone}"
            
            # 嘗試使用標準庫解析
            try:
                expires_at = datetime.fromisoformat(clean_time_str)
            except ValueError:
                # 如果標準庫解析失敗，使用手動方法
                if "." in time_part:
                    time_base, microseconds = time_part.split(".")
                    seconds = int(microseconds) / (10 ** len(microseconds))
                else:
                    time_base = time_part
                    seconds = 0
                
                hour, minute, second = map(int, time_base.split(":"))
                year, month, day = map(int, date_part.split("-"))
                
                # 手動構建datetime對象
                expires_at = datetime(year, month, day, hour, minute, int(second), 
                                     int(seconds * 1000000), tzinfo=timezone.utc)
            except Exception as e:
                # 如果解析失敗，設置為一個較早的過期時間（1小時前）
                logger.warning(f"無法解析時間字符串 '{expires_at_str}': {str(e)}，設置為一小時前")
                expires_at = datetime.now(timezone.utc) - timedelta(hours=1)
        except Exception as e:
            # 如果解析失敗，設置為一個較早的過期時間（1小時前）
            logger.warning(f"無法解析時間字符串 '{expires_at_str}': {str(e)}，設置為一小時前")
            expires_at = datetime.now(timezone.utc) - timedelta(hours=1)
        
        now = datetime.now(timezone.utc)
        
        if now > expires_at:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="評分會話已過期"
            )
        
        # 獲取用戶映射和聚餐事件ID
        user_mapping = session_data["user_mapping"]
        
        # 處理評分提交
        for rating in request.ratings:
            index = str(rating.index)
            rating_type = rating.rating_type
            
            # 驗證評分類型
            if rating_type not in ["like", "dislike", "no_show"]:
                continue
            
            # 從映射中獲取真實用戶ID
            if index not in user_mapping:
                continue
                
            to_user_id = user_mapping[index]
            
            # 保存評分
            supabase.table("user_ratings").upsert({
                "dining_event_id": dining_event_id,
                "from_user_id": user_id,
                "to_user_id": to_user_id,
                "rating_type": rating_type,
                "updated_at": datetime.now(timezone.utc).isoformat()
            }).execute()
        
        # 評分完成後刪除會話（可選）
        supabase.table("rating_sessions") \
            .delete() \
            .eq("session_token", request.session_token) \
            .execute()
        
        return {"success": True, "message": "評分提交成功"}
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"提交評分時出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"提交評分時出錯: {str(e)}"
        )

# 將確認完成的聚餐事件更新為已完成
async def update_completed_dining_events(supabase: Client):
    try:
        # 獲取目前時間
        current_time = datetime.now(timezone.utc)
        
        # 獲取所有待確認/確認中/已確認且時間已過的事件
        events_to_complete = supabase.table("dining_events") \
            .select("id, matching_group_id") \
            .in_("status", ["pending_confirmation", "confirming", "confirmed"]) \
            .lt("date", current_time.isoformat()) \
            .execute()
            
        if not events_to_complete.data or len(events_to_complete.data) == 0:
            logger.info("沒有需要更新為已完成狀態的聚餐事件")
            return
            
        # 取得所有需要更新的事件ID和相關聚餐群組ID
        event_ids = [event["id"] for event in events_to_complete.data]
        group_ids = [event["matching_group_id"] for event in events_to_complete.data]
        
        # 批量更新聚餐事件狀態為completed
        supabase.table("dining_events") \
            .update({
                "status": "completed",
                "updated_at": current_time.isoformat()
            }) \
            .in_("id", event_ids) \
            .execute()
            
        # 獲取所有相關聚餐群組的用戶
        for group_id in group_ids:
            # 獲取群組中所有用戶
            group_info = supabase.table("matching_groups") \
                .select("user_ids") \
                .eq("id", group_id) \
                .execute()
                
            if not group_info.data or not group_info.data[0].get("user_ids"):
                logger.warning(f"找不到聚餐群組 {group_id} 的成員資訊")
                continue
                
            user_ids = group_info.data[0]["user_ids"]
            
            # 將這些用戶的狀態從waiting_attendance更新為rating
            supabase.table("user_status") \
                .update({
                    "status": "rating",
                    "updated_at": current_time.isoformat()
                }) \
                .in_("user_id", user_ids) \
                .eq("status", "waiting_attendance") \
                .execute()
        
        logger.info(f"已將 {len(event_ids)} 個聚餐事件更新為已完成狀態，並更新相關用戶狀態")
        
    except Exception as e:
        logger.error(f"更新已完成聚餐事件時出錯: {str(e)}")

# 添加一個管理員API，用於更新已完成的聚餐事件
@router.post("/update-completed-events", response_model=Dict[str, Any], dependencies=[Depends(verify_cron_api_key)])
async def admin_update_completed_events(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_service)
):
    """
    管理員或排程任務API，用於將已過期的聚餐事件（狀態為 pending_confirmation、confirming、confirmed）更新為 completed，
    同時將相關用戶狀態從 waiting_attendance 更新為 rating
    """
    # 添加到背景任務執行，避免阻塞API響應
    background_tasks.add_task(update_completed_dining_events, supabase)
    
    return {
        "success": True,
        "message": "已啟動更新已完成聚餐事件的背景任務"
    }

# 將已評分的聚餐事件結束並移至歷史記錄表
async def finalize_dining_events(supabase: Client):
    try:
        # 獲取目前時間
        current_time = datetime.now(timezone.utc)
        
        # 計算2天前的時間
        two_days_ago = (current_time - timedelta(days=2)).isoformat()
        
        # 獲取所有已完成且時間已過2天的事件
        events_to_finalize = supabase.table("dining_events") \
            .select("id, matching_group_id, restaurant_id, name, date, attendee_count") \
            .eq("status", "completed") \
            .lt("date", two_days_ago) \
            .execute()
            
        if not events_to_finalize.data or len(events_to_finalize.data) == 0:
            logger.info("沒有需要結束的聚餐事件")
            return
        
        # 取得所有需要處理的事件ID和相關聚餐群組ID
        event_ids = [event["id"] for event in events_to_finalize.data]
        group_ids = [event["matching_group_id"] for event in events_to_finalize.data]

        # 獲取所有相關聚餐群組資訊
        groups_info = supabase.table("matching_groups") \
            .select("id, user_ids, school_only") \
            .in_("id", group_ids) \
            .execute()
        
        # 建立群組ID到群組資訊的映射
        group_map = {group["id"]: group for group in groups_info.data}
        
        # 獲取餐廳資訊
        restaurant_ids = [event["restaurant_id"] for event in events_to_finalize.data if event["restaurant_id"]]
        restaurants_info = supabase.table("restaurants") \
            .select("id, name") \
            .in_("id", restaurant_ids) \
            .execute()
        
        # 建立餐廳ID到餐廳名稱的映射
        restaurant_map = {restaurant["id"]: restaurant["name"] for restaurant in restaurants_info.data}
        
        # 準備歷史記錄插入數據
        history_records = []
        for event in events_to_finalize.data:
            if event["matching_group_id"] in group_map:
                group_info = group_map[event["matching_group_id"]]
                restaurant_id = event.get("restaurant_id")
                
                history_records.append({
                    "original_event_id": event["id"],  # 保存原始的dining_event_id
                    "restaurant_id": restaurant_id,
                    "restaurant_name": restaurant_map.get(restaurant_id) if restaurant_id else None,
                    "event_name": event["name"],
                    "event_date": event["date"],
                    "attendee_count": event.get("attendee_count"),
                    "user_ids": group_info["user_ids"],
                    "school_only": group_info.get("school_only", False)
                })
        
        # 批量插入歷史記錄
        if history_records:
            supabase.table("dining_history").insert(history_records).execute()
            logger.info(f"已將 {len(history_records)} 個聚餐事件移至歷史記錄")
        
        # 獲取所有相關用戶
        all_user_ids = set()
        for group_id in group_ids:
            if group_id in group_map and group_map[group_id].get("user_ids"):
                all_user_ids.update(group_map[group_id]["user_ids"])
        
        # 將這些用戶的狀態從rating更新為booking
        if all_user_ids:
            supabase.table("user_status") \
                .update({
                    "status": "booking",
                    "updated_at": current_time.isoformat()
                }) \
                .in_("user_id", list(all_user_ids)) \
                .eq("status", "rating") \
                .execute()
            
            logger.info(f"已將 {len(all_user_ids)} 個用戶狀態從rating更新為booking")
        
        # 刪除週期性數據
        # 1. 刪除rating_sessions
        supabase.table("rating_sessions") \
            .delete() \
            .in_("dining_event_id", event_ids) \
            .execute()
        
        # 2. 刪除restaurant_votes
        supabase.table("restaurant_votes") \
            .delete() \
            .in_("group_id", group_ids) \
            .execute()
        
        # 3. 刪除user_matching_info
        supabase.table("user_matching_info") \
            .delete() \
            .in_("matching_group_id", group_ids) \
            .execute()
        
        # 4. 刪除 chat_messages（會自動清除因為有外鍵約束，但先主動刪除以確保完整性）
        supabase.table("chat_messages") \
            .delete() \
            .in_("dining_event_id", event_ids) \
            .execute()
        logger.info(f"已清空 {len(event_ids)} 個聚餐事件的聊天訊息")
        
        # 5. 刪除 R2 上的聊天圖片資料夾
        # 由於聚餐周期是固定的，所有用戶同時開始並同時結束，直接刪除整個 chat_images/ 資料夾
        try:
            r2_result = await delete_folder_from_private_r2("chat_images/")
            logger.info(f"已刪除 R2 聊天圖片: 刪除 {r2_result['deleted_count']} 個檔案")
            if r2_result["errors"]:
                logger.warning(f"刪除 R2 聊天圖片時有錯誤: {r2_result['errors']}")
        except Exception as r2_error:
            logger.error(f"刪除 R2 聊天圖片時發生錯誤: {str(r2_error)}")
        
        # 6. 刪除dining_events
        supabase.table("dining_events") \
            .delete() \
            .in_("id", event_ids) \
            .execute()
        
        # 7. 最後刪除matching_groups
        supabase.table("matching_groups") \
            .delete() \
            .in_("id", group_ids) \
            .execute()
        
        logger.info(f"已清理與 {len(event_ids)} 個聚餐事件相關的週期性數據（包含聊天訊息和圖片）")
        
    except Exception as e:
        logger.error(f"結束聚餐事件時出錯: {str(e)}")

# 添加一個管理員API，用於結束已完成的聚餐事件
@router.post("/finalize-dining-events", response_model=Dict[str, Any], dependencies=[Depends(verify_cron_api_key)])
async def admin_finalize_dining_events(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_service)
):
    """
    管理員或排程任務API，用於結束已評分的聚餐事件(聚餐後2天)，
    將rating狀態的用戶更新為booking狀態，
    備份dining_events數據到歷史記錄表，
    並刪除週期性數據以提高資料庫效率
    """
    # 添加到背景任務執行，避免阻塞API響應
    background_tasks.add_task(finalize_dining_events, supabase)
    
    return {
        "success": True,
        "message": "已啟動結束聚餐事件的背景任務"
    }


