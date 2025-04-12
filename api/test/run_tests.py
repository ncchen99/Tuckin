import os
import sys
import argparse
import logging

# 添加目錄到路徑
current_dir = os.path.dirname(os.path.abspath(__file__))
api_dir = os.path.dirname(current_dir)
sys.path.append(api_dir)
sys.path.append(current_dir)
sys.path.append(os.path.join(current_dir, "matching"))
sys.path.append(os.path.join(current_dir, "notification"))

# 設置日誌
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_results.log")),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def run_basic_test():
    """運行基本批量配對測試"""
    logger.info("運行基本批量配對測試...")
    try:
        from matching.test_matching import run_test
        run_test()
        logger.info("基本批量配對測試完成")
    except Exception as e:
        logger.error(f"運行基本批量配對測試時出錯: {e}")

def run_scenario_tests():
    """運行不同場景的測試"""
    logger.info("運行場景測試...")
    try:
        from matching.test_matching_scenarios import run_all_scenarios
        run_all_scenarios()
        logger.info("場景測試完成")
    except Exception as e:
        logger.error(f"運行場景測試時出錯: {e}")

def run_mock_tests():
    """運行模擬數據庫的配對邏輯測試"""
    logger.info("運行模擬數據庫配對邏輯測試...")
    try:
        from matching.test_matching_mock import run_all_tests
        run_all_tests()
        logger.info("模擬數據庫配對邏輯測試完成")
    except Exception as e:
        logger.error(f"運行模擬數據庫配對邏輯測試時出錯: {e}")

def run_notification_tests():
    """運行通知服務測試"""
    logger.info("運行通知服務測試...")
    try:
        from notification.test_notification_service import run_tests
        run_tests()
        logger.info("通知服務測試完成")
    except Exception as e:
        logger.error(f"運行通知服務測試時出錯: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="測試工具")
    parser.add_argument("--all", action="store_true", help="運行所有測試")
    parser.add_argument("--matching", action="store_true", help="運行所有配對測試")
    parser.add_argument("--basic", action="store_true", help="運行基本批量配對測試")
    parser.add_argument("--scenarios", action="store_true", help="運行配對場景測試")
    parser.add_argument("--mock", action="store_true", help="運行模擬數據庫配對邏輯測試")
    parser.add_argument("--notification", action="store_true", help="運行通知服務測試")
    parser.add_argument("--no-db", action="store_true", help="只運行不需要數據庫的測試")
    
    args = parser.parse_args()
    
    # 如果沒有指定參數，則預設運行所有測試
    if not (args.all or args.matching or args.basic or args.scenarios or args.mock or args.notification or args.no_db):
        args.all = True
    
    logger.info("開始運行測試...")
    
    if args.no_db:
        # 只運行不需要數據庫的測試
        run_mock_tests()
    else:
        # 運行需要數據庫的測試
        if args.all or args.matching or args.basic:
            run_basic_test()
        
        if args.all or args.matching or args.scenarios:
            run_scenario_tests()
        
        if args.all or args.matching or args.mock:
            run_mock_tests()
        
        if args.all or args.notification:
            run_notification_tests()
    
    logger.info("所有測試執行完畢") 