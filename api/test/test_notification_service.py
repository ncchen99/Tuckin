import asyncio
import sys
import os
import json

# 將 api 目錄添加到 Python 路徑
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.notification_service import NotificationService

async def test_send_notification():
    # 使用服務角色初始化通知服務
    notification_service = NotificationService(use_service_role=True)
    
    # 發送測試通知
    user_id = "b7d41439-206b-4dca-a09d-2a3d3f7b4202"  # 替換為實際用戶ID
    
    try:
        result = await notification_service.send_notification(
            user_id=user_id,
            title="測試通知",
            body="這是一條測試通知，檢查是否成功發送",
            data={"type": "test", "priority": "high"}
        )
        
        print(f"通知發送結果: {json.dumps(result, indent=2, ensure_ascii=False)}")
        return True
    except Exception as e:
        print(f"發送通知失敗: {str(e)}")
        return False

if __name__ == "__main__":
    asyncio.run(test_send_notification())