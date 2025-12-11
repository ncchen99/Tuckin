"""
提醒通知服務模組

負責發送各類提醒通知給符合條件的用戶：
- booking_reminder: 預約聚餐提醒（match 前一天 9:00）
  - 目標用戶狀態: booking, matching_failed, confirmation_timeout, low_attendance
- attendance_reminder: 參加聚餐提醒（聚餐當天 9:00）
  - 目標用戶狀態: waiting_attendance

支援功能：
- dry_run 模式：僅模擬執行，不實際發送通知
- test_user_ids：指定測試用戶，只對這些用戶發送通知
"""

import random
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
from supabase import Client

from services.notification_service import NotificationService

logger = logging.getLogger(__name__)


# 各提醒類型對應的目標用戶狀態
REMINDER_TARGET_STATUSES = {
    "reminder_booking": ["booking", "matching_failed", "confirmation_timeout", "low_attendance"],
    "reminder_attendance": ["waiting_attendance"],
}


class ReminderService:
    """提醒通知服務"""
    
    def __init__(
        self, 
        supabase: Client,
        dry_run: bool = False,
        test_user_ids: Optional[List[str]] = None
    ):
        """
        初始化提醒服務
        
        Args:
            supabase: Supabase 客戶端
            dry_run: 是否為模擬執行模式（不實際發送通知）
            test_user_ids: 測試用戶 ID 列表（若提供，只對這些用戶發送通知）
        """
        self.supabase = supabase
        self.notification_service = NotificationService(use_service_role=True)
        self.dry_run = dry_run
        self.test_user_ids = test_user_ids
    
    async def send_reminders(self, reminder_type: str) -> Dict[str, Any]:
        """
        發送指定類型的提醒通知
        
        Args:
            reminder_type: 提醒類型 ('reminder_booking' 或 'reminder_attendance')
        
        Returns:
            包含發送結果的字典
        """
        if reminder_type not in REMINDER_TARGET_STATUSES:
            raise ValueError(f"未知的提醒類型: {reminder_type}")
        
        target_statuses = REMINDER_TARGET_STATUSES[reminder_type]
        
        # 獲取符合條件的用戶
        eligible_users = await self._get_eligible_users(target_statuses)
        
        # 如果指定了測試用戶，只保留測試用戶
        if self.test_user_ids:
            eligible_users = [
                u for u in eligible_users 
                if u["user_id"] in self.test_user_ids
            ]
            logger.info(f"[{reminder_type}] 測試模式：篩選後剩餘 {len(eligible_users)} 位測試用戶")
        
        if not eligible_users:
            logger.info(f"[{reminder_type}] 沒有符合條件的用戶")
            return {
                "success": True,
                "reminder_type": reminder_type,
                "users_notified": 0,
                "dry_run": self.dry_run,
                "test_mode": bool(self.test_user_ids),
                "message": "沒有符合條件的用戶"
            }
        
        # 獲取提醒模板
        template = await self._get_random_template(reminder_type)
        
        if not template:
            logger.warning(f"[{reminder_type}] 找不到可用的提醒模板")
            return {
                "success": False,
                "reminder_type": reminder_type,
                "error": "找不到可用的提醒模板"
            }
        
        # 根據提醒類型準備訊息
        if reminder_type == "reminder_attendance":
            # 出席提醒需要額外獲取聚餐資訊
            return await self._send_attendance_reminders(eligible_users, template)
        else:
            # 預約提醒直接發送
            return await self._send_booking_reminders(eligible_users, template)
    
    async def _get_eligible_users(self, target_statuses: List[str]) -> List[Dict[str, Any]]:
        """獲取符合目標狀態的用戶列表"""
        try:
            result = (
                self.supabase.table("user_status")
                .select("user_id, status")
                .in_("status", target_statuses)
                .execute()
            )
            return result.data or []
        except Exception as e:
            logger.error(f"獲取符合條件的用戶時發生錯誤: {e}")
            return []
    
    async def _get_random_template(self, reminder_type: str) -> Optional[Dict[str, Any]]:
        """
        根據提醒類型隨機獲取一個模板（考慮權重）
        
        使用加權隨機選擇：權重越高，被選中的機率越大
        """
        try:
            # 將 reminder_type 轉換為資料庫中的類型名稱
            db_reminder_type = reminder_type.replace("reminder_", "") + "_reminder"
            
            result = (
                self.supabase.table("reminder_templates")
                .select("*")
                .eq("reminder_type", db_reminder_type)
                .eq("is_active", True)
                .execute()
            )
            
            templates = result.data or []
            
            if not templates:
                return None
            
            # 加權隨機選擇
            weights = [t.get("weight", 1) for t in templates]
            selected = random.choices(templates, weights=weights, k=1)[0]
            
            return selected
            
        except Exception as e:
            logger.error(f"獲取提醒模板時發生錯誤: {e}")
            return None
    
    async def _send_booking_reminders(
        self, 
        users: List[Dict[str, Any]], 
        template: Dict[str, Any]
    ) -> Dict[str, Any]:
        """發送預約聚餐提醒"""
        title = template["title"]
        body = template["body"]
        
        success_count = 0
        failed_count = 0
        skipped_count = 0
        errors = []
        dry_run_users = []
        
        for user in users:
            user_id = user["user_id"]
            
            # dry_run 模式：只記錄不發送
            if self.dry_run:
                dry_run_users.append({
                    "user_id": user_id,
                    "title": title,
                    "body": body
                })
                skipped_count += 1
                continue
            
            try:
                await self.notification_service.send_notification(
                    user_id=user_id,
                    title=title,
                    body=body,
                    data={
                        "type": "booking_reminder",
                        "action": "open_booking"
                    }
                )
                success_count += 1
            except Exception as e:
                failed_count += 1
                errors.append({"user_id": user_id, "error": str(e)})
                logger.error(f"發送預約提醒給用戶 {user_id} 時失敗: {e}")
        
        if self.dry_run:
            logger.info(f"[booking_reminder] DRY RUN 模式 - 模擬發送給 {skipped_count} 位用戶")
        else:
            logger.info(f"[booking_reminder] 發送完成 - 成功: {success_count}, 失敗: {failed_count}")
        
        return {
            "success": True,
            "reminder_type": "reminder_booking",
            "users_notified": success_count,
            "failed": failed_count,
            "skipped": skipped_count,
            "dry_run": self.dry_run,
            "test_mode": bool(self.test_user_ids),
            "template_used": template["id"],
            "template_title": title,
            "template_body": body,
            "dry_run_preview": dry_run_users if self.dry_run else None,
            "errors": errors if errors else None
        }
    
    async def _send_attendance_reminders(
        self, 
        users: List[Dict[str, Any]], 
        template: Dict[str, Any]
    ) -> Dict[str, Any]:
        """發送參加聚餐提醒（包含聚餐詳細資訊）"""
        success_count = 0
        failed_count = 0
        skipped_count = 0
        errors = []
        dry_run_users = []
        
        for user in users:
            user_id = user["user_id"]
            try:
                # 獲取用戶的聚餐資訊
                event_info = await self._get_user_dining_event(user_id)
                
                # 替換模板中的佔位符
                title = template["title"]
                body = self._format_template(template["body"], event_info)
                
                # dry_run 模式：只記錄不發送
                if self.dry_run:
                    dry_run_users.append({
                        "user_id": user_id,
                        "title": title,
                        "body": body,
                        "event_info": event_info
                    })
                    skipped_count += 1
                    continue
                
                await self.notification_service.send_notification(
                    user_id=user_id,
                    title=title,
                    body=body,
                    data={
                        "type": "attendance_reminder",
                        "action": "open_event",
                        "event_id": event_info.get("event_id") if event_info else None
                    }
                )
                success_count += 1
            except Exception as e:
                failed_count += 1
                errors.append({"user_id": user_id, "error": str(e)})
                logger.error(f"發送出席提醒給用戶 {user_id} 時失敗: {e}")
        
        if self.dry_run:
            logger.info(f"[attendance_reminder] DRY RUN 模式 - 模擬發送給 {skipped_count} 位用戶")
        else:
            logger.info(f"[attendance_reminder] 發送完成 - 成功: {success_count}, 失敗: {failed_count}")
        
        return {
            "success": True,
            "reminder_type": "reminder_attendance",
            "users_notified": success_count,
            "failed": failed_count,
            "skipped": skipped_count,
            "dry_run": self.dry_run,
            "test_mode": bool(self.test_user_ids),
            "template_used": template["id"],
            "template_title": template["title"],
            "dry_run_preview": dry_run_users if self.dry_run else None,
            "errors": errors if errors else None
        }
    
    async def _get_user_dining_event(self, user_id: str) -> Optional[Dict[str, Any]]:
        """獲取用戶當前的聚餐活動資訊"""
        try:
            # 先獲取用戶的 matching_group_id
            matching_info = (
                self.supabase.table("user_matching_info")
                .select("matching_group_id")
                .eq("user_id", user_id)
                .single()
                .execute()
            )
            
            if not matching_info.data or not matching_info.data.get("matching_group_id"):
                return None
            
            group_id = matching_info.data["matching_group_id"]
            
            # 獲取該群組的聚餐活動
            event_result = (
                self.supabase.table("dining_events")
                .select("id, name, date, restaurant_id, restaurants(name, address)")
                .eq("matching_group_id", group_id)
                .in_("status", ["confirmed", "pending_confirmation"])
                .order("date", desc=True)
                .limit(1)
                .execute()
            )
            
            if not event_result.data:
                return None
            
            event = event_result.data[0]
            restaurant = event.get("restaurants", {}) or {}
            
            # 格式化時間
            event_date = event.get("date")
            time_str = "18:00"  # 預設時間
            if event_date:
                try:
                    dt = datetime.fromisoformat(event_date.replace("Z", "+00:00"))
                    time_str = dt.strftime("%H:%M")
                except:
                    pass
            
            return {
                "event_id": event.get("id"),
                "event_name": event.get("name"),
                "time": time_str,
                "date": event_date,
                "restaurant_name": restaurant.get("name", "待定"),
                "location": restaurant.get("address", "")
            }
            
        except Exception as e:
            logger.error(f"獲取用戶 {user_id} 的聚餐資訊時發生錯誤: {e}")
            return None
    
    def _format_template(self, template_body: str, event_info: Optional[Dict[str, Any]]) -> str:
        """替換模板中的佔位符"""
        if not event_info:
            # 如果沒有活動資訊，移除佔位符
            return (
                template_body
                .replace("{time}", "18:00")
                .replace("{restaurant_name}", "指定餐廳")
                .replace("{location}", "")
                .replace("{date}", "今天")
            )
        
        return (
            template_body
            .replace("{time}", event_info.get("time", "18:00"))
            .replace("{restaurant_name}", event_info.get("restaurant_name", "指定餐廳"))
            .replace("{location}", event_info.get("location", ""))
            .replace("{date}", event_info.get("date", "今天"))
        )


async def process_reminder_booking(
    supabase: Client,
    dry_run: bool = False,
    test_user_ids: Optional[List[str]] = None
) -> Dict[str, Any]:
    """
    處理預約聚餐提醒任務
    
    目標用戶狀態: booking, matching_failed, confirmation_timeout, low_attendance
    
    Args:
        supabase: Supabase 客戶端
        dry_run: 是否為模擬執行模式
        test_user_ids: 測試用戶 ID 列表
    """
    service = ReminderService(supabase, dry_run=dry_run, test_user_ids=test_user_ids)
    return await service.send_reminders("reminder_booking")


async def process_reminder_attendance(
    supabase: Client,
    dry_run: bool = False,
    test_user_ids: Optional[List[str]] = None
) -> Dict[str, Any]:
    """
    處理參加聚餐提醒任務
    
    目標用戶狀態: waiting_attendance
    
    Args:
        supabase: Supabase 客戶端
        dry_run: 是否為模擬執行模式
        test_user_ids: 測試用戶 ID 列表
    """
    service = ReminderService(supabase, dry_run=dry_run, test_user_ids=test_user_ids)
    return await service.send_reminders("reminder_attendance")

