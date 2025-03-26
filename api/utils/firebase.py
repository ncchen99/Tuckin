import json
import os
import firebase_admin
from firebase_admin import credentials, messaging
from typing import Dict, Any, List

from config import FIREBASE_CONFIG

def initialize_firebase():
    try:
        # 使用檔案路徑而不是環境變數
        service_account_path = os.path.join(os.path.dirname(__file__), '..', 'firebase-credentials.json')
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Firebase 初始化失敗: {e}")
        raise

# 發送推送通知給單個設備
async def send_notification_to_device(
    token: str,
    title: str,
    body: str,
    data: Dict[str, Any] = None
) -> bool:
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            data=data,
            token=token
        )
        
        response = messaging.send(message)
        return True
    except Exception as e:
        print(f"發送通知失敗: {e}")
        return False

# 發送推送通知給多個設備
async def send_notification_to_devices(
    tokens: List[str],
    title: str,
    body: str,
    data: Dict[str, Any] = None
) -> Dict[str, int]:
    if not tokens:
        return {"success": 0, "failure": 0}
    
    success_count = 0
    failure_count = 0
    
    # 改為逐個發送
    for token in tokens:
        try:
            # 確保每次調用前都檢查初始化狀態
            if not firebase_admin._apps:
                initialize_firebase()
                
            result = await send_notification_to_device(token, title, body, data)
            if result:
                success_count += 1
            else:
                failure_count += 1
        except Exception as e:
            print(f"單一設備通知發送失敗 (token: {token[:20]}...): {e}")
            failure_count += 1
    
    return {"success": success_count, "failure": failure_count}