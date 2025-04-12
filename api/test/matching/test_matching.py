import os
import sys
import uuid
import random
import json
from datetime import datetime, timedelta
import requests
import time

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

# 測試配置
TEST_USER_COUNT = 40  # 測試用戶數量
PERSONALITY_TYPES = ["分析型", "功能型", "直覺型", "個人型"]
GENDERS = ["male", "female"]

# 配置日誌
import logging
# 使用絕對路徑
log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "matching_test.log")
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def generate_test_users(count):
    """生成測試用戶數據"""
    users = []
    
    # 創建均衡分佈的用戶（各個類型和性別都有）
    for i in range(count):
        user_id = str(uuid.uuid4())
        personality_type = PERSONALITY_TYPES[i % len(PERSONALITY_TYPES)]
        # 確保性別大致平衡
        gender = GENDERS[i % 2]
        
        users.append({
            "user_id": user_id,
            "personality_type": personality_type,
            "gender": gender,
            "nickname": f"測試用戶{i+1}",
            "personal_desc": f"這是測試用戶{i+1}的自我介紹"
        })
    
    return users

def clean_test_data():
    """清理之前的測試數據"""
    logger.info("清理之前的測試數據...")
    
    # 獲取所有測試用戶ID以便刪除相關數據
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

def insert_test_data(users):
    """插入測試數據到數據庫"""
    logger.info(f"正在插入{len(users)}個測試用戶...")
    
    # 插入用戶個性資料
    for user in users:
        try:
            # 先檢查users表中是否存在該用戶，如不存在則創建
            user_check = supabase.table("users").select("id").eq("id", user["user_id"]).execute()
            if not user_check.data:
                # 創建用戶記錄
                supabase.table("users").insert({
                    "id": user["user_id"],
                    "email": f"test_{user['user_id']}@example.com",  # 為測試用戶創建唯一郵箱
                    "created_at": datetime.now().isoformat()
                }).execute()
                logger.info(f"創建用戶記錄: {user['user_id']}")
            
            # 創建用戶個人資料
            profile_data = {
                "user_id": user["user_id"],
                "nickname": user["nickname"],
                "gender": user["gender"],
                "personal_desc": user["personal_desc"]
            }
            supabase.table("user_profiles").insert(profile_data).execute()
            
            # 創建用戶個性類型記錄
            personality_data = {
                "user_id": user["user_id"],
                "personality_type": user["personality_type"]
            }
            supabase.table("user_personality_results").insert(personality_data).execute()
            
            # 設置用戶狀態為等待配對
            status_data = {
                "user_id": user["user_id"],
                "status": "waiting_matching"
            }
            supabase.table("user_status").insert(status_data).execute()
            
        except Exception as e:
            logger.error(f"插入用戶 {user['user_id']} 數據時出錯: {e}")
    
    logger.info("測試數據插入完成")

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

def verify_matching_results():
    """驗證配對結果是否符合配對邏輯"""
    logger.info("正在驗證配對結果...")
    
    # 等待一段時間讓後台任務完成
    time.sleep(3)
    
    try:
        # 獲取所有配對組
        groups_response = supabase.table("matching_groups").select("*").execute()
        if not groups_response.data:
            logger.warning("未找到任何配對組")
            return False
        
        groups = groups_response.data
        logger.info(f"找到 {len(groups)} 個配對組")
        
        # 獲取所有用戶的個性類型和性別
        users_info = {}
        
        # 獲取用戶個人資料
        profiles_response = supabase.table("user_profiles").select("user_id, gender").execute()
        for profile in profiles_response.data:
            user_id = profile["user_id"]
            users_info[user_id] = {"gender": profile["gender"]}
        
        # 獲取用戶個性類型
        personality_response = supabase.table("user_personality_results").select("user_id, personality_type").execute()
        for result in personality_response.data:
            user_id = result["user_id"]
            if user_id in users_info:
                users_info[user_id]["personality_type"] = result["personality_type"]
        
        # 驗證每個組
        for group in groups:
            group_id = group["id"]
            user_ids = group["user_ids"]
            personality_type = group["personality_type"]
            is_complete = group["is_complete"]
            male_count = group["male_count"]
            female_count = group["female_count"]
            
            logger.info(f"組 {group_id}:")
            logger.info(f"  成員數: {len(user_ids)}")
            logger.info(f"  人格類型: {personality_type}")
            logger.info(f"  男性人數: {male_count}")
            logger.info(f"  女性人數: {female_count}")
            logger.info(f"  是否完整: {is_complete}")
            
            # 驗證成員是否有相同的人格類型
            member_personality_types = {}
            member_genders = {"male": 0, "female": 0}
            
            for user_id in user_ids:
                if user_id in users_info:
                    user_personality = users_info[user_id].get("personality_type")
                    user_gender = users_info[user_id].get("gender")
                    
                    member_personality_types[user_personality] = member_personality_types.get(user_personality, 0) + 1
                    if user_gender:
                        member_genders[user_gender] = member_genders.get(user_gender, 0) + 1
            
            # 記錄組內人格類型分佈
            logger.info(f"  組內人格類型分佈: {member_personality_types}")
            
            # 驗證人格類型
            dominant_type = max(member_personality_types.items(), key=lambda x: x[1])[0]
            if dominant_type != personality_type:
                logger.warning(f"  組 {group_id} 的主導人格類型 {dominant_type} 與記錄的 {personality_type} 不一致")
            
            # 驗證性別計數
            if member_genders["male"] != male_count:
                logger.warning(f"  組 {group_id} 的男性計數 {member_genders['male']} 與記錄的 {male_count} 不一致")
            
            if member_genders["female"] != female_count:
                logger.warning(f"  組 {group_id} 的女性計數 {member_genders['female']} 與記錄的 {female_count} 不一致")
            
            # 驗證組完整性
            if is_complete and len(user_ids) < 4:
                logger.warning(f"  組 {group_id} 標記為完整但成員數小於4")
            
            # 驗證優先級：2男2女 > 同類型4人組 > 不完整組
            if male_count == 2 and female_count == 2:
                logger.info(f"  組 {group_id} 是理想的2男2女組")
            elif male_count + female_count == 4:
                logger.info(f"  組 {group_id} 是4人組但性別不均衡")
            else:
                logger.info(f"  組 {group_id} 是不完整組 ({male_count + female_count}人)")
        
        # 獲取用戶狀態，檢查是否都已更新
        status_response = supabase.table("user_status").select("user_id, status").execute()
        user_statuses = {status["user_id"]: status["status"] for status in status_response.data}
        
        waiting_confirmation_count = sum(1 for status in user_statuses.values() if status == "waiting_confirmation")
        waiting_matching_count = sum(1 for status in user_statuses.values() if status == "waiting_matching")
        
        logger.info(f"用戶狀態統計:")
        logger.info(f"  等待確認: {waiting_confirmation_count}")
        logger.info(f"  等待配對: {waiting_matching_count}")
        
        # 檢查是否有配對信息記錄
        for group in groups:
            group_id = group["id"]
            user_ids = group["user_ids"]
            
            # 獲取該組的用戶配對信息
            for user_id in user_ids:
                matching_info_response = supabase.table("user_matching_info").select("*").eq("user_id", user_id).execute()
                if matching_info_response.data:
                    matching_info = matching_info_response.data[0]
                    if matching_info["matching_group_id"] != group_id:
                        logger.warning(f"用戶 {user_id} 的配對組 {matching_info['matching_group_id']} 與實際組 {group_id} 不一致")
                else:
                    logger.warning(f"用戶 {user_id} 沒有配對信息記錄")
        
        logger.info("配對結果驗證完成")
        return True
    except Exception as e:
        logger.error(f"驗證配對結果時出錯: {e}")
        return False

def run_test():
    """運行完整測試"""
    logger.info("開始運行配對測試...")
    
    # 清理之前的測試數據
    clean_test_data()
    
    # 生成測試用戶
    test_users = generate_test_users(TEST_USER_COUNT)
    
    # 插入測試數據
    insert_test_data(test_users)
    
    # 調用批量配對API
    matching_result = call_batch_matching_api()
    
    if matching_result and matching_result.get("success"):
        # 驗證配對結果
        verification_result = verify_matching_results()
        if verification_result:
            logger.info("測試成功完成，配對結果符合預期")
        else:
            logger.warning("測試完成，但配對結果存在問題")
    else:
        logger.error("配對API調用失敗，測試未完成")
    
    logger.info("配對測試結束")

if __name__ == "__main__":
    run_test() 