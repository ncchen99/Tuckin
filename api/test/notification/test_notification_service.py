import asyncio
import sys
import os
import json
import logging

# 添加父級目錄到路徑，以便導入模組
current_dir = os.path.dirname(os.path.abspath(__file__))
api_dir = os.path.dirname(os.path.dirname(current_dir))
sys.path.append(api_dir)

from services.notification_service import NotificationService
from supabase import create_client
from config import SUPABASE_URL, SUPABASE_SERVICE_KEY

# 配置日誌
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(os.path.dirname(os.path.abspath(__file__)), "notification_test.log")),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

async def test_send_notification():
    # 使用服務角色初始化通知服務
    notification_service = NotificationService(use_service_role=True)
    
    # 發送測試通知
    user_id = "dc9d847a-5dec-48e9-9a1e-75320eb38e46"  # 替換為實際用戶ID
    
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

def test_notification_receipt():
    """測試通知接收功能"""
    logger.info("測試通知接收功能...")
    # 測試實現待添加
    logger.info("通知接收測試完成")

def run_tests():
    """運行所有通知服務測試"""
    logger.info("開始運行通知服務測試...")
    test_send_notification()
    test_notification_receipt()
    logger.info("通知服務測試完成")

if __name__ == "__main__":
    run_tests()