import json
import os
import firebase_admin
from firebase_admin import credentials, messaging
from typing import Dict, Any, List
from dotenv import load_dotenv

from config import FIREBASE_CONFIG

def initialize_firebase():
    # 載入環境變數
    load_dotenv()
    try:
        # 從環境變數讀取憑證 JSON 字串
        cred_json = os.getenv('GOOGLE_CREDENTIALS')
        if not cred_json:
            raise ValueError("環境變數 GOOGLE_CREDENTIALS 未設定或為空")

        cred_dict = json.loads(cred_json)
        cred = credentials.Certificate(cred_dict)
        
        # 檢查是否已經初始化過
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
            print("Firebase 初始化成功")
        else:
            print("Firebase 已初始化")

    except ValueError as ve:
        print(f"Firebase 初始化失敗: {ve}")
        raise
    except json.JSONDecodeError:
        print("Firebase 初始化失敗: GOOGLE_CREDENTIALS 環境變數中的 JSON 格式錯誤")
        raise
    except Exception as e:
        print(f"Firebase 初始化失敗: {e}")
        raise

# 確保在第一次調用時初始化
if not firebase_admin._apps:
    initialize_firebase()

# 發送推送通知給單個設備
async def send_notification_to_device(
    token: str,
    title: str,
    body: str,
    data: Dict[str, Any] = None
) -> bool:
    try:
        # 確保 Firebase 已初始化
        if not firebase_admin._apps:
            initialize_firebase()

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
    # 確保 Firebase 已初始化
    if not firebase_admin._apps:
        initialize_firebase()

    if not tokens:
        return {"success": 0, "failure": 0}
    
    success_count = 0
    failure_count = 0
    
    # 改為逐個發送
    for token in tokens:
        try:
            # 確保 Firebase 已初始化 (雖然前面已有檢查，但多一層保險)
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