import os
import sys
import uuid
import time
import requests
from datetime import datetime

# 添加父級目錄到路徑，以便導入模組
current_dir = os.path.dirname(os.path.abspath(__file__))
api_dir = os.path.dirname(os.path.dirname(current_dir))
sys.path.append(api_dir)

from supabase import create_client
from config import SUPABASE_URL, SUPABASE_SERVICE_KEY

# 確保有服務密鑰
if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise ValueError("SUPABASE_URL 和 SUPABASE_SERVICE_KEY 環境變數必須設置")

# 初始化 Supabase 客戶端
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# API基礎URL
API_BASE_URL = "http://localhost:8000"

# 配置日誌
import logging
# 使用絕對路徑
log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "matching_scenarios.log")
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def clean_test_data():
    """清理之前的測試數據"""
    logger.info("清理之前的測試數據...")
    
    try:
        # 首先獲取所有測試用戶ID
        profiles_response = supabase.table("user_profiles").select("user_id").execute()
        user_ids = [profile["user_id"] for profile in profiles_response.data] if profiles_response.data else []
        
        if user_ids:
            # 使用IN運算符刪除多個用戶的相關數據
            logger.info(f"找到 {len(user_ids)} 個用戶記錄準備清理")
            
            # 刪除user_matching_info表中的測試數據
            supabase.table("user_matching_info").delete().in_("user_id", user_ids).execute()
            logger.info("已清理user_matching_info表")
            
            # 刪除user_status表中的測試數據
            supabase.table("user_status").delete().in_("user_id", user_ids).execute()
            logger.info("已清理user_status表")
            
            # 刪除user_personality_results表中的測試數據
            supabase.table("user_personality_results").delete().in_("user_id", user_ids).execute()
            logger.info("已清理user_personality_results表")
            
            # 刪除user_profiles表中的測試數據
            supabase.table("user_profiles").delete().in_("user_id", user_ids).execute()
            logger.info("已清理user_profiles表")
        else:
            logger.info("未找到用戶記錄，跳過用戶相關表的清理")
        
        # 刪除matching_groups表中的所有數據 - 添加一個始終為真的條件
        supabase.table("matching_groups").delete().not_("id", "is", None).execute()
        logger.info("已清理matching_groups表")
        
    except Exception as e:
        logger.error(f"清理測試數據時出錯: {e}")

def create_test_user(personality_type, gender, nickname=None):
    """創建測試用戶並返回用戶ID"""
    user_id = str(uuid.uuid4())
    
    try:
        # 先創建用戶記錄
        supabase.table("users").insert({
            "id": user_id,
            "email": f"test_{user_id}@example.com",  # 為測試用戶創建唯一郵箱
            "created_at": datetime.now().isoformat()
        }).execute()
        
        # 創建用戶個人資料
        profile_data = {
            "user_id": user_id,
            "nickname": nickname or f"用戶_{personality_type}_{gender}",
            "gender": gender,
            "personal_desc": f"這是一個{personality_type}的{gender}用戶"
        }
        supabase.table("user_profiles").insert(profile_data).execute()
        
        # 創建用戶個性類型記錄
        personality_data = {
            "user_id": user_id,
            "personality_type": personality_type
        }
        supabase.table("user_personality_results").insert(personality_data).execute()
        
        # 設置用戶狀態為等待配對
        status_data = {
            "user_id": user_id,
            "status": "waiting_matching"
        }
        supabase.table("user_status").insert(status_data).execute()
        
        return user_id
    except Exception as e:
        logger.error(f"創建測試用戶時出錯: {e}")
        return None

def call_batch_matching_api():
    """調用批量配對API"""
    logger.info("調用批量配對API...")
    
    try:
        response = requests.post(f"{API_BASE_URL}/api/matching/batch")
        if response.status_code == 200:
            result = response.json()
            logger.info(f"配對API響應: {result}")
            return result
        else:
            logger.error(f"配對API錯誤: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        logger.error(f"調用配對API時出錯: {e}")
        return None

def get_matching_results():
    """獲取配對結果"""
    # 等待一段時間讓後台任務完成
    time.sleep(3)
    
    try:
        # 獲取所有配對組
        groups_response = supabase.table("matching_groups").select("*").execute()
        return groups_response.data
    except Exception as e:
        logger.error(f"獲取配對結果時出錯: {e}")
        return []

def print_group_details(groups):
    """打印組詳情"""
    if not groups:
        logger.info("沒有找到配對組")
        return
    
    logger.info(f"找到 {len(groups)} 個配對組")
    
    # 獲取所有用戶的個性類型和性別
    users_info = {}
    
    # 獲取用戶個人資料
    profiles_response = supabase.table("user_profiles").select("user_id, gender, nickname").execute()
    for profile in profiles_response.data:
        user_id = profile["user_id"]
        users_info[user_id] = {
            "gender": profile["gender"],
            "nickname": profile["nickname"]
        }
    
    # 獲取用戶個性類型
    personality_response = supabase.table("user_personality_results").select("user_id, personality_type").execute()
    for result in personality_response.data:
        user_id = result["user_id"]
        if user_id in users_info:
            users_info[user_id]["personality_type"] = result["personality_type"]
    
    # 打印每個組的詳情
    for i, group in enumerate(groups):
        group_id = group["id"]
        user_ids = group["user_ids"]
        personality_type = group["personality_type"]
        is_complete = group["is_complete"]
        male_count = group["male_count"]
        female_count = group["female_count"]
        
        logger.info(f"組 {i+1} (ID: {group_id}):")
        logger.info(f"  成員數: {len(user_ids)}")
        logger.info(f"  人格類型: {personality_type}")
        logger.info(f"  男性人數: {male_count}")
        logger.info(f"  女性人數: {female_count}")
        logger.info(f"  是否完整: {is_complete}")
        
        # 打印成員詳情
        logger.info("  成員:")
        for j, user_id in enumerate(user_ids):
            if user_id in users_info:
                user_info = users_info[user_id]
                logger.info(f"    {j+1}. {user_info.get('nickname')} - {user_info.get('personality_type')} - {user_info.get('gender')}")

def test_scenario_1():
    """場景1: 完美的2男2女同人格類型組合
    
    測試用戶:
    - 2男2女分析型
    - 2男2女功能型
    - 2男2女直覺型
    - 2男2女個人型
    
    預期結果: 
    - 4個完美的2男2女組，每個組內成員具有相同的人格類型
    """
    logger.info("========== 測試場景1: 完美的2男2女同人格類型組合 ==========")
    clean_test_data()
    
    # 創建測試用戶
    # 分析型
    for i in range(2):
        create_test_user("分析型", "male", f"分析型男{i+1}")
    for i in range(2):
        create_test_user("分析型", "female", f"分析型女{i+1}")
    
    # 功能型
    for i in range(2):
        create_test_user("功能型", "male", f"功能型男{i+1}")
    for i in range(2):
        create_test_user("功能型", "female", f"功能型女{i+1}")
    
    # 直覺型
    for i in range(2):
        create_test_user("直覺型", "male", f"直覺型男{i+1}")
    for i in range(2):
        create_test_user("直覺型", "female", f"直覺型女{i+1}")
    
    # 個人型
    for i in range(2):
        create_test_user("個人型", "male", f"個人型男{i+1}")
    for i in range(2):
        create_test_user("個人型", "female", f"個人型女{i+1}")
    
    # 調用配對API
    call_batch_matching_api()
    
    # 獲取並打印配對結果
    groups = get_matching_results()
    print_group_details(groups)
    
    logger.info("場景1測試完成")

def test_scenario_2():
    """場景2: 性別不平衡的情況
    
    測試用戶:
    - 分析型: 6男2女
    - 功能型: 2男6女
    - 直覺型: 4男4女
    - 個人型: 3男3女
    
    預期結果: 
    - 分析型: 1個2男2女組 + 1個4男組(或2個2男組)
    - 功能型: 1個2男2女組 + 1個4女組(或2個2女組)
    - 直覺型: 2個2男2女組
    - 個人型: 1個2男2女組 + 1個1男1女組
    """
    logger.info("========== 測試場景2: 性別不平衡的情況 ==========")
    clean_test_data()
    
    # 創建測試用戶
    # 分析型: 6男2女
    for i in range(6):
        create_test_user("分析型", "male", f"分析型男{i+1}")
    for i in range(2):
        create_test_user("分析型", "female", f"分析型女{i+1}")
    
    # 功能型: 2男6女
    for i in range(2):
        create_test_user("功能型", "male", f"功能型男{i+1}")
    for i in range(6):
        create_test_user("功能型", "female", f"功能型女{i+1}")
    
    # 直覺型: 4男4女
    for i in range(4):
        create_test_user("直覺型", "male", f"直覺型男{i+1}")
    for i in range(4):
        create_test_user("直覺型", "female", f"直覺型女{i+1}")
    
    # 個人型: 3男3女
    for i in range(3):
        create_test_user("個人型", "male", f"個人型男{i+1}")
    for i in range(3):
        create_test_user("個人型", "female", f"個人型女{i+1}")
    
    # 調用配對API
    call_batch_matching_api()
    
    # 獲取並打印配對結果
    groups = get_matching_results()
    print_group_details(groups)
    
    logger.info("場景2測試完成")

def test_scenario_3():
    """場景3: 缺少某些人格類型的用戶
    
    測試用戶:
    - 分析型: 6男6女
    - 功能型: 0用戶
    - 直覺型: 2男1女
    - 個人型: 1男2女
    
    預期結果: 
    - 分析型: 3個2男2女組
    - 直覺型: 1個不完整3人組
    - 個人型: 1個不完整3人組
    """
    logger.info("========== 測試場景3: 缺少某些人格類型的用戶 ==========")
    clean_test_data()
    
    # 創建測試用戶
    # 分析型: 6男6女
    for i in range(6):
        create_test_user("分析型", "male", f"分析型男{i+1}")
    for i in range(6):
        create_test_user("分析型", "female", f"分析型女{i+1}")
    
    # 功能型: 0用戶
    
    # 直覺型: 2男1女
    for i in range(2):
        create_test_user("直覺型", "male", f"直覺型男{i+1}")
    for i in range(1):
        create_test_user("直覺型", "female", f"直覺型女{i+1}")
    
    # 個人型: 1男2女
    for i in range(1):
        create_test_user("個人型", "male", f"個人型男{i+1}")
    for i in range(2):
        create_test_user("個人型", "female", f"個人型女{i+1}")
    
    # 調用配對API
    call_batch_matching_api()
    
    # 獲取並打印配對結果
    groups = get_matching_results()
    print_group_details(groups)
    
    logger.info("場景3測試完成")

def test_scenario_4():
    """場景4: 單一人格類型人數不足4人
    
    測試用戶:
    - 分析型: 1男2女
    - 功能型: 2男1女
    - 直覺型: 1男0女
    - 個人型: 0男1女
    
    預期結果: 
    - 一個混合人格類型的組(8人)，或2個混合組(每組4人)
    - 可能會按人格類型聚集，但組內有多種人格類型
    """
    logger.info("========== 測試場景4: 單一人格類型人數不足4人 ==========")
    clean_test_data()
    
    # 創建測試用戶
    # 分析型: 1男2女
    create_test_user("分析型", "male", "分析型男1")
    create_test_user("分析型", "female", "分析型女1")
    create_test_user("分析型", "female", "分析型女2")
    
    # 功能型: 2男1女
    create_test_user("功能型", "male", "功能型男1")
    create_test_user("功能型", "male", "功能型男2")
    create_test_user("功能型", "female", "功能型女1")
    
    # 直覺型: 1男0女
    create_test_user("直覺型", "male", "直覺型男1")
    
    # 個人型: 0男1女
    create_test_user("個人型", "female", "個人型女1")
    
    # 調用配對API
    call_batch_matching_api()
    
    # 獲取並打印配對結果
    groups = get_matching_results()
    print_group_details(groups)
    
    logger.info("場景4測試完成")

def test_scenario_5():
    """場景5: 自動成桌 - 測試不足4人的情況
    
    測試用戶:
    - 分析型: 1男1女
    - 功能型: 1男1女
    - 直覺型: 1男1女
    
    預期結果: 
    - 允許形成3人或更少的組
    """
    logger.info("========== 測試場景5: 自動成桌 - 測試不足4人的情況 ==========")
    clean_test_data()
    
    # 創建測試用戶
    # 分析型: 1男1女
    create_test_user("分析型", "male", "分析型男1")
    create_test_user("分析型", "female", "分析型女1")
    
    # 功能型: 1男1女
    create_test_user("功能型", "male", "功能型男1")
    create_test_user("功能型", "female", "功能型女1")
    
    # 直覺型: 1男1女
    create_test_user("直覺型", "male", "直覺型男1")
    create_test_user("直覺型", "female", "直覺型女1")
    
    # 調用自動成桌API
    try:
        response = requests.post(f"{API_BASE_URL}/api/matching/auto-form")
        if response.status_code == 200:
            result = response.json()
            logger.info(f"自動成桌API響應: {result}")
        else:
            logger.error(f"自動成桌API錯誤: {response.status_code} - {response.text}")
    except Exception as e:
        logger.error(f"調用自動成桌API時出錯: {e}")
    
    # 獲取並打印配對結果
    groups = get_matching_results()
    print_group_details(groups)
    
    logger.info("場景5測試完成")

def run_all_scenarios():
    """運行所有測試場景"""
    logger.info("開始運行所有配對測試場景...")
    
    test_scenario_1()
    test_scenario_2()
    test_scenario_3()
    test_scenario_4()
    test_scenario_5()
    
    logger.info("所有測試場景完成")

if __name__ == "__main__":
    run_all_scenarios() 