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
    
    try:
        multicast_message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            data=data,
            tokens=tokens
        )
        
        response = messaging.send_multicast(multicast_message)
        return {"success": response.success_count, "failure": response.failure_count}
    except Exception as e:
        print(f"發送批量通知失敗: {e}")
        return {"success": 0, "failure": len(tokens)} 