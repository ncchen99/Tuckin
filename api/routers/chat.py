from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client
import logging
from typing import List

from schemas.chat import (
    ChatImageUploadRequest,
    ChatImageUploadResponse,
    ChatImageUrlRequest,
    ChatImageUrlResponse,
    ChatNotifyRequest
)
from dependencies import get_supabase_service, get_current_user
from utils.cloudflare import (
    generate_presigned_put_url,
    generate_presigned_get_url
)
from services.notification_service import NotificationService

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/image/upload-url", response_model=ChatImageUploadResponse)
async def get_chat_image_upload_url(
    request: ChatImageUploadRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user=Depends(get_current_user)
):
    """
    獲取聊天圖片上傳的 Presigned PUT URL
    
    流程：
    1. 驗證用戶是否在該聚餐事件中
    2. 生成圖片路徑：chat_images/{dining_event_id}/{message_id}.webp
    3. 生成 Presigned PUT URL
    4. 返回 URL 和路徑供前端上傳
    """
    try:
        user_id = current_user.user.id
        
        # 驗證用戶是否在該聚餐事件中
        result = supabase.table('dining_events').select(
            'id, matching_group_id'
        ).eq('id', request.dining_event_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到該聚餐事件"
            )
        
        matching_group_id = result.data[0]['matching_group_id']
        
        # 檢查用戶是否在該配對組中
        member_check = supabase.table('user_matching_info').select('user_id').eq(
            'matching_group_id', matching_group_id
        ).eq('user_id', user_id).execute()
        
        if not member_check.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="您不在該聚餐事件中"
            )
        
        # 生成圖片路徑
        image_path = f"chat_images/{request.dining_event_id}/{request.message_id}.webp"
        
        logger.info(f"用戶 {user_id} 準備上傳聊天圖片: {image_path}")
        
        # 生成 Presigned PUT URL（有效期 1 小時）
        upload_url = generate_presigned_put_url(
            file_key=image_path,
            expiration=3600,
            content_type="image/webp"
        )
        
        if not upload_url:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="無法生成上傳 URL"
            )
        
        logger.info(f"已為用戶 {user_id} 生成聊天圖片上傳 URL")
        
        return ChatImageUploadResponse(
            upload_url=upload_url,
            image_path=image_path,
            expires_in=3600
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"獲取聊天圖片上傳 URL 時發生錯誤: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="獲取上傳 URL 時發生錯誤"
        )


@router.post("/image/url", response_model=ChatImageUrlResponse)
async def get_chat_image_url(
    request: ChatImageUrlRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user=Depends(get_current_user)
):
    """
    獲取聊天圖片的 Presigned GET URL
    
    流程：
    1. 從 image_path 解析 dining_event_id
    2. 驗證用戶是否有權限讀取（是否在該聚餐事件中）
    3. 生成 Presigned GET URL
    4. 返回 URL 供前端顯示
    """
    try:
        user_id = current_user.user.id
        
        # 從 image_path 解析 dining_event_id
        # 格式：chat_images/{dining_event_id}/{message_id}.webp
        path_parts = request.image_path.split('/')
        if len(path_parts) != 3 or path_parts[0] != 'chat_images':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="無效的圖片路徑格式"
            )
        
        dining_event_id = path_parts[1]
        
        # 驗證用戶是否在該聚餐事件中
        result = supabase.table('dining_events').select(
            'id, matching_group_id'
        ).eq('id', dining_event_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到該聚餐事件"
            )
        
        matching_group_id = result.data[0]['matching_group_id']
        
        # 檢查用戶是否在該配對組中
        member_check = supabase.table('user_matching_info').select('user_id').eq(
            'matching_group_id', matching_group_id
        ).eq('user_id', user_id).execute()
        
        if not member_check.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="您無權讀取該圖片"
            )
        
        # 生成 Presigned GET URL（有效期 1 小時）
        get_url = generate_presigned_get_url(
            file_key=request.image_path,
            expiration=3600
        )
        
        if not get_url:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="無法生成讀取 URL"
            )
        
        logger.info(f"已為用戶 {user_id} 生成聊天圖片讀取 URL")
        
        return ChatImageUrlResponse(
            url=get_url,
            expires_in=3600
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"獲取聊天圖片 URL 時發生錯誤: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="獲取圖片 URL 時發生錯誤"
        )


@router.post("/notify")
async def send_chat_notification(
    request: ChatNotifyRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user=Depends(get_current_user)
):
    """
    發送新訊息通知給聚餐事件的其他成員
    
    流程：
    1. 驗證用戶是否在該聚餐事件中
    2. 獲取發送者的暱稱
    3. 獲取聚餐事件的所有參與者（排除發送者）
    4. 使用 NotificationService 發送通知
    """
    try:
        user_id = current_user.user.id
        
        # 獲取聚餐事件的配對組 ID
        dining_event = supabase.table('dining_events').select(
            'id, matching_group_id'
        ).eq('id', request.dining_event_id).execute()
        
        if not dining_event.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到該聚餐事件"
            )
        
        matching_group_id = dining_event.data[0]['matching_group_id']
        
        # 檢查用戶是否在該配對組中
        member_check = supabase.table('user_matching_info').select('user_id').eq(
            'matching_group_id', matching_group_id
        ).eq('user_id', user_id).execute()
        
        if not member_check.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="您不在該聚餐事件中"
            )
        
        # 獲取發送者的暱稱
        sender_profile = supabase.table('user_profiles').select('nickname').eq(
            'user_id', user_id
        ).execute()
        
        sender_nickname = sender_profile.data[0]['nickname'] if sender_profile.data else '匿名用戶'
        
        # 獲取配對組的所有成員（排除發送者）
        members = supabase.table('user_matching_info').select('user_id').eq(
            'matching_group_id', matching_group_id
        ).neq('user_id', user_id).execute()
        
        if not members.data:
            # 沒有其他成員需要通知
            return {"message": "沒有其他成員需要通知", "notified_count": 0}
        
        member_ids = [member['user_id'] for member in members.data]
        
        # 準備通知內容
        if request.message_type == 'image':
            notification_body = f"{sender_nickname} 傳送了一張圖片"
        else:
            notification_body = f"{sender_nickname}: {request.message_preview}"
        
        # 使用 NotificationService 發送通知
        notification_service = NotificationService(use_service_role=True)
        
        notification_records = []
        all_tokens = []
        
        for member_id in member_ids:
            # 準備通知記錄
            notification_records.append({
                "user_id": member_id,
                "title": "新訊息",
                "body": notification_body,
                "data": {
                    "type": "chat_message",
                    "dining_event_id": request.dining_event_id,
                    "sender_id": user_id,
                    "sender_nickname": sender_nickname
                }
            })
            
            # 獲取用戶設備令牌
            tokens_result = supabase.table("user_device_tokens").select("token").eq(
                "user_id", member_id
            ).execute()
            user_tokens = [item["token"] for item in tokens_result.data] if tokens_result.data else []
            all_tokens.extend(user_tokens)
        
        # 儲存所有通知記錄
        if notification_records:
            supabase.table("user_notifications").insert(notification_records).execute()
        
        # 發送批量推送通知
        notification_result = {"success": 0, "failure": 0}
        if all_tokens:
            from utils.firebase import send_notification_to_devices
            notification_result = await send_notification_to_devices(
                tokens=all_tokens,
                title="新訊息",
                body=notification_body,
                data={
                    "type": "chat_message",
                    "dining_event_id": request.dining_event_id,
                    "sender_id": user_id,
                    "sender_nickname": sender_nickname
                }
            )
        
        logger.info(
            f"已向 {len(member_ids)} 位成員發送聊天通知，"
            f"成功: {notification_result.get('success', 0)}, "
            f"失敗: {notification_result.get('failure', 0)}"
        )
        
        return {
            "message": "通知已發送",
            "notified_count": len(member_ids),
            "notification_result": notification_result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"發送聊天通知時發生錯誤: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="發送通知時發生錯誤"
        )


