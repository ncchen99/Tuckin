import json
from typing import List, Dict, Any, Optional
from supabase import Client, create_client

from config import SUPABASE_URL, SUPABASE_KEY, SUPABASE_SERVICE_KEY
from utils.firebase import send_notification_to_device, send_notification_to_devices, initialize_firebase

class NotificationService:
    def __init__(self, use_service_role=False):
        # 使用服務角色金鑰以獲得更高權限
        key = SUPABASE_SERVICE_KEY if use_service_role else SUPABASE_KEY
        self.supabase = create_client(SUPABASE_URL, key)
        
        # 確保 Firebase 已初始化
        import firebase_admin
        if not firebase_admin._apps:
            initialize_firebase()
    
    async def send_notification(self, user_id: str, title: str, body: str, data: Optional[Dict[str, Any]] = None) -> Dict:
        """
        向指定用戶發送通知
        """
        # 存儲通知記錄到數據庫
        notification_data = {
            "user_id": user_id,
            "title": title,
            "body": body,
            "data": data
        }
        
        result = self.supabase.table("user_notifications").insert(notification_data).execute()
        if not result.data:
            raise Exception("創建通知失敗")
        
        created_notification = result.data[0]
        
        # 獲取用戶設備令牌
        tokens_result = self.supabase.table("user_device_tokens").select("token").eq("user_id", user_id).execute()
        device_tokens = [item["token"] for item in tokens_result.data] if tokens_result.data else []
        
        # 發送推送通知
        if device_tokens:
            data_dict = data if data else {}
            await send_notification_to_devices(
                tokens=device_tokens,
                title=title,
                body=body,
                data=data_dict
            )
        
        return created_notification
    
    async def send_notification_to_group(self, group_id: str, title: str, body: str, data: Optional[Dict[str, Any]] = None) -> Dict:
        """
        向群組所有成員發送通知
        """
        # 獲取群組成員
        members_result = self.supabase.table("group_uuid_mapping").select("user_id").eq("group_id", group_id).execute()
        member_ids = [item["user_id"] for item in members_result.data] if members_result.data else []
        
        if not member_ids:
            raise Exception("找不到群組成員")
        
        # 為每個成員獲取設備令牌
        all_tokens = []
        notification_records = []
        
        for user_id in member_ids:
            # 準備通知記錄
            notification_records.append({
                "user_id": user_id,
                "title": title,
                "body": body,
                "data": data
            })
            
            # 獲取用戶設備令牌
            tokens_result = self.supabase.table("user_device_tokens").select("token").eq("user_id", user_id).execute()
            user_tokens = [item["token"] for item in tokens_result.data] if tokens_result.data else []
            all_tokens.extend(user_tokens)
        
        # 儲存所有通知記錄
        if notification_records:
            self.supabase.table("user_notifications").insert(notification_records).execute()
        
        # 發送批量推送通知
        result = {"success": 0, "failure": 0}
        if all_tokens:
            data_dict = data if data else {}
            result = await send_notification_to_devices(
                tokens=all_tokens,
                title=title,
                body=body,
                data=data_dict
            )
        
        return {
            "members_count": len(member_ids),
            "notification_sent": result
        }
    
    def get_user_notifications(self, user_id: str, unread_only: bool = False) -> List[Dict]:
        """
        獲取用戶通知列表
        """
        query = self.supabase.table("user_notifications").select("*").eq("user_id", user_id)
        
        if unread_only:
            query = query.is_("read_at", None)
        
        query = query.order("created_at", desc=True)
        result = query.execute()
        
        return result.data
    
    def mark_notification_as_read(self, notification_id: str, user_id: str) -> bool:
        """
        標記通知為已讀
        """
        # 檢查通知是否存在且屬於當前用戶
        notification = self.supabase.table("user_notifications").select("*").eq("id", notification_id).eq("user_id", user_id).execute()
        
        if not notification.data:
            raise Exception("通知不存在或無權訪問")
        
        # 更新為已讀
        result = self.supabase.table("user_notifications").update({"read_at": "now()"}).eq("id", notification_id).execute()
        
        return True