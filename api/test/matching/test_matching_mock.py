import os
import sys
import uuid
import random
import json
from datetime import datetime
import logging
from collections import Counter

# 添加父級目錄到路徑，以便導入模組
current_dir = os.path.dirname(os.path.abspath(__file__))
api_dir = os.path.dirname(os.path.dirname(current_dir))
sys.path.append(api_dir)

# 配置日誌
log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "matching_mock_test.log")
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 測試配置
TEST_USER_COUNT = 40  # 測試用戶數量
PERSONALITY_TYPES = ["分析型", "功能型", "直覺型", "個人型"]
GENDERS = ["male", "female"]

class MockDBUser:
    """模擬數據庫用戶"""
    def __init__(self, user_id, gender, personality_type, nickname=None):
        self.user_id = user_id
        self.gender = gender
        self.personality_type = personality_type
        self.nickname = nickname or f"用戶_{self.personality_type}_{self.gender}"
        self.status = "waiting_matching"
        self.created_at = datetime.now()

class MockDBGroup:
    """模擬數據庫中的配對組"""
    
    def __init__(self, group_id, user_ids, male_count, female_count):
        self.id = group_id
        self.user_ids = user_ids
        self.male_count = male_count
        self.female_count = female_count
        self.is_complete = len(user_ids) == 4
        self.status = "waiting_confirmation"
        self.created_at = datetime.now()

class MockDatabase:
    """模擬數據庫"""
    def __init__(self):
        self.users = {}  # user_id -> MockDBUser
        self.groups = []  # List[MockDBGroup]
        
    def add_user(self, user):
        """添加用戶"""
        self.users[user.user_id] = user
        
    def add_group(self, group):
        """添加配對組"""
        self.groups.append(group)
        
    def get_all_users(self):
        """獲取所有用戶"""
        return list(self.users.values())
    
    def get_waiting_users(self):
        """獲取等待配對的用戶"""
        return [user for user in self.users.values() if user.status == "waiting_matching"]
    
    def get_all_groups(self):
        """獲取所有配對組"""
        return self.groups
    
    def update_user_status(self, user_id, new_status):
        """更新用戶狀態"""
        if user_id in self.users:
            self.users[user_id].status = new_status
            return True
        return False

# 創建模擬數據庫實例
mock_db = MockDatabase()

def generate_test_users(count):
    """生成測試用戶數據"""
    users = []
    
    # 創建均衡分佈的用戶（各個類型和性別都有）
    for i in range(count):
        user_id = str(uuid.uuid4())
        personality_type = PERSONALITY_TYPES[i % len(PERSONALITY_TYPES)]
        # 確保性別大致平衡
        gender = GENDERS[i % 2]
        
        user = MockDBUser(
            user_id=user_id,
            gender=gender,
            personality_type=personality_type,
            nickname=f"測試用戶{i+1}"
        )
        users.append(user)
    
    return users

def populate_mock_db(users):
    """將測試用戶添加到模擬數據庫"""
    logger.info(f"正在添加{len(users)}個測試用戶到模擬數據庫...")
    
    for user in users:
        mock_db.add_user(user)
    
    logger.info("模擬數據庫填充完成")

def process_batch_matching():
    """模擬批量配對處理流程，使用新的配對算法"""
    logger.info("開始批量配對處理...")
    
    # 1. 獲取所有等待配對的用戶
    waiting_users = mock_db.get_waiting_users()
    if not waiting_users:
        logger.warning("沒有等待配對的用戶")
        return {
            "success": True,
            "message": "沒有需要配對的用戶",
            "matched_groups": 0,
            "total_users_processed": 0
        }
    
    total_users = len(waiting_users)
    logger.info(f"待配對用戶數: {total_users}")
    
    # 檢查人數是否少於3，如果是則將其狀態更新為 matching_failed
    if total_users < 3:
        logger.warning(f"等待用戶不足 3 人 ({total_users} 人)，無法進行配對。")
        # 更新這些用戶的狀態為 matching_failed
        failed_update_count = 0
        for user in waiting_users:
            user.status = "matching_failed"
            failed_update_count += 1
        
        return {
            "success": False,
            "message": f"等待用戶不足 3 人 ({total_users} 人)，配對失敗。已更新 {failed_update_count} 位用戶狀態。",
            "matched_groups": 0,
            "total_users_processed": total_users
        }
    
    # 2. 轉換數據格式，準備配對
    user_data = {}  # 將用戶數據轉換為與路由器中相同的格式
    for user in waiting_users:
        user_data[user.user_id] = {
            "gender": user.gender,
            "personality_type": user.personality_type,
            "prefer_school_only": False  # 模擬測試中忽略校內限制
        }
    
    # 人數統計
    male_count = sum(1 for user in waiting_users if user.gender == 'male')
    female_count = sum(1 for user in waiting_users if user.gender == 'female')
    logger.info(f"待配對男性用戶: {male_count}人")
    logger.info(f"待配對女性用戶: {female_count}人")
    
    # 各類型人數統計
    personality_counts = {'分析型': 0, '功能型': 0, '直覺型': 0, '個人型': 0}
    for user in waiting_users:
        if user.personality_type in personality_counts:
            personality_counts[user.personality_type] += 1
    
    for p_type, count in personality_counts.items():
        logger.info(f"{p_type}: {count}人")
    
    # 3. 執行新的配對算法
    result_groups = _match_users_into_groups(user_data)
    
    logger.info(f"配對結果: 共形成 {len(result_groups)} 個組別")
    
    # 4. 將配對結果保存到模擬數據庫中
    matched_user_count = 0
    
    for group in result_groups:
        user_ids = group["user_ids"]
        male_count = group["male_count"]
        female_count = group["female_count"]
        is_complete = group["is_complete"]
        
        # 記錄組別信息
        logger.info(f"形成{'完整' if is_complete else '不完整'}組：{len(user_ids)}人，{male_count}男{female_count}女")
        
        # 統計組內各人格類型數量
        p_type_counts = {}
        for uid in user_ids:
            p_type = mock_db.users[uid].personality_type
            p_type_counts[p_type] = p_type_counts.get(p_type, 0) + 1
        
        logger.info(f"組內人格類型分佈: {p_type_counts}")
        
        # 創建組別
        group_obj = MockDBGroup(
                group_id=str(uuid.uuid4()),
            user_ids=user_ids,
            male_count=male_count,
            female_count=female_count
        )
        mock_db.add_group(group_obj)
            
            # 更新用戶狀態
        for user_id in user_ids:
            mock_db.update_user_status(user_id, "waiting_confirmation")
            matched_user_count += 1
    
    # 計算待配對和已配對的用戶數
    waiting_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_matching")
    matched_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_confirmation")
    failed_count = sum(1 for user in mock_db.users.values() if user.status == "matching_failed")
    
    logger.info(f"配對後狀態: 待配對用戶: {waiting_count}, 已配對用戶: {matched_count}, 配對失敗: {failed_count}")
    
    if matched_user_count != total_users:
        logger.error(f"配對錯誤：處理了 {total_users} 個用戶，但只匹配了 {matched_user_count} 個")
    
    return {
        "success": True,
        "message": f"批量配對完成：共創建 {len(result_groups)} 個組別",
        "matched_groups": len(result_groups),
        "total_users_processed": matched_user_count
    }

def _match_users_into_groups(user_data):
    """
    根據用戶資料將用戶分組配對，確保所有用戶都被分配，優先4人組，
    剩餘分配至5人組，僅在 N=6,7,11 時允許3人組。
    
    Args:
        user_data: 格式 {user_id: {"gender": gender, "personality_type": personality_type}}
        
    Returns:
        List[Dict]: 結果組別列表
    """
    total_users = len(user_data)
    logger.info(f"開始配對，總人數: {total_users}")
    if total_users == 0:
        return []
    
    # 使用集合來跟踪剩餘用戶
    remaining_user_ids = set(user_data.keys())
    result_groups = []
    
    # 特殊情況處理 N=6, 7, 11
    if total_users == 6:
        logger.info(f"處理特殊情況 N=6：組成兩個 3 人組")
        group1, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 3)
        group2, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 3)
        
        if group1: result_groups.append(_create_group_dict(group1, user_data))
        if group2: result_groups.append(_create_group_dict(group2, user_data))
        return result_groups
        
    elif total_users == 7:
        logger.info(f"處理特殊情況 N=7：組成一個 4 人組和一個 3 人組")
        group4, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 4)
        group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 3)
        
        if group4: result_groups.append(_create_group_dict(group4, user_data))
        if group3: result_groups.append(_create_group_dict(group3, user_data))
        return result_groups
        
    elif total_users == 11:
        logger.info(f"處理特殊情況 N=11：組成兩個 4 人組和一個 3 人組")
        group1, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 4)
        group2, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 4)
        group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 3)
        
        if group1: result_groups.append(_create_group_dict(group1, user_data))
        if group2: result_groups.append(_create_group_dict(group2, user_data))
        if group3: result_groups.append(_create_group_dict(group3, user_data))
        return result_groups
    
    # 一般情況處理: 計算需要的 4 人和 5 人組數量
    num_groups_of_4 = 0
    num_groups_of_5 = 0
    
    if total_users % 4 == 0:
        num_groups_of_4 = total_users // 4
    elif total_users % 4 == 1:  # N = 4k + 1 => N = 4(k-1) + 5
        if total_users >= 5:
            num_groups_of_4 = (total_users - 5) // 4
            num_groups_of_5 = 1
    elif total_users % 4 == 2:  # N = 4k + 2 => N = 4(k-2) + 10 = 4(k-2) + 2*5
        if total_users >= 10:
            num_groups_of_4 = (total_users - 10) // 4
            num_groups_of_5 = 2
        elif total_users == 6:  # 已處理
            pass
        elif total_users == 2:  # 會在 process_batch_matching 處理
            return []
    elif total_users % 4 == 3:  # N = 4k + 3 => N = 4(k-3) + 15 = 4(k-3) + 3*5
        if total_users >= 15:
            num_groups_of_4 = (total_users - 15) // 4
            num_groups_of_5 = 3
        elif total_users == 11:  # 已處理
            pass
        elif total_users == 7:  # 已處理
            pass
        elif total_users == 3:  # 如果總數恰好是3, 需要組成一個3人組
            group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 3)
            if group3: result_groups.append(_create_group_dict(group3, user_data))
            return result_groups
    else:
        logger.warning(f"用戶數 {total_users} 過少，無法正常分組")
        return []
    
    logger.info(f"計劃組成 {num_groups_of_4} 個 4 人組和 {num_groups_of_5} 個 5 人組")
    
    # 組建 4 人組
    for _ in range(num_groups_of_4):
        if len(remaining_user_ids) < 4:
            logger.error("邏輯錯誤：剩餘用戶不足以組成計劃的 4 人組")
            break
            
        group4, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 4)
        
        if group4:
            result_groups.append(_create_group_dict(group4, user_data))
        else:
            logger.error("無法找到合適的 4 人組，即使人數足夠")
            # 備用邏輯：隨機選4人
            if len(remaining_user_ids) >= 4:
                group4 = random.sample(list(remaining_user_ids), 4)
                remaining_user_ids -= set(group4)
                result_groups.append(_create_group_dict(group4, user_data))
                logger.warning("找不到優化的4人組，已隨機選擇4人")
            else:  # 人數不足，跳出 (理論上不應發生)
                break
    
    # 組建 5 人組
    for _ in range(num_groups_of_5):
        if len(remaining_user_ids) < 5:
            logger.error("邏輯錯誤：剩餘用戶不足以組成計劃的 5 人組")
            break
            
        group5, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, 5)
        
        if group5:
            result_groups.append(_create_group_dict(group5, user_data))
        else:
            logger.error("無法找到合適的 5 人組，即使人數足夠")
            if len(remaining_user_ids) >= 5:
                group5 = random.sample(list(remaining_user_ids), 5)
                remaining_user_ids -= set(group5)
                result_groups.append(_create_group_dict(group5, user_data))
                logger.warning("找不到優化的5人組，已隨機選擇5人")
            else:  # 人數不足，跳出 (理論上不應發生)
                break
    
    if remaining_user_ids:
        logger.warning(f"配對完成後仍有 {len(remaining_user_ids)} 個用戶剩餘，這不應該發生。剩餘用戶ID: {remaining_user_ids}")
    
    return result_groups

def _calculate_group_score(group_ids, user_data):
    """
    計算組別的質量分數。
    分數越高越好。
    返回 (性別平衡分數, 個性相似度分數, 總人數)
    性別平衡：2男2女最高(4人組), 3男2女/2男3女次之(5人組)
    個性相似度：相同個性類型越多越好
    """
    size = len(group_ids)
    if size == 0: return (-1, -1, 0)
    
    genders = [user_data[uid].get('gender') for uid in group_ids]
    p_types = [user_data[uid].get('personality_type') for uid in group_ids]
    
    male_count = genders.count('male')
    female_count = size - male_count
    
    # 性別平衡分數 (簡單示例)
    gender_score = 0
    if size == 4:
        if male_count == 2: gender_score = 10
        elif male_count == 3 or male_count == 1: gender_score = 5
        else: gender_score = 1
    elif size == 5:
        if male_count == 3 or male_count == 2: gender_score = 10
        elif male_count == 4 or male_count == 1: gender_score = 5
        else: gender_score = 1
    elif size == 3:
        if male_count == 2 or male_count == 1: gender_score = 10
        else: gender_score = 1
    
    # 個性相似度分數
    p_type_counts = Counter(p for p in p_types if p)
    # 分數 = (相同個性人數)^2 的總和 (鼓勵大群體)
    personality_score = sum(count ** 2 for count in p_type_counts.values())
    
    return (gender_score, personality_score, size)

def _find_best_group(remaining_ids_set, user_data, target_size):
    """
    從剩餘用戶中找到最佳的組（基於性別和個性）
    返回 (找到的組ID列表 或 None, 更新後的剩餘用戶ID集合)
    """
    if len(remaining_ids_set) < target_size:
        return None, remaining_ids_set
    
    best_group = None
    best_score = (-1, -1, -1)  # (性別分, 個性分, size)
    
    # 優化：限制檢查的組合數量以避免性能問題
    max_combinations_to_check = 1000
    count = 0
    
    import itertools
    potential_combinations = itertools.combinations(list(remaining_ids_set), target_size)
    
    for current_group_tuple in potential_combinations:
        count += 1
        current_group = list(current_group_tuple)
        current_score = _calculate_group_score(current_group, user_data)
        
        # 比較分數 (優先性別，其次個性)
        if current_score[0] > best_score[0] or \
           (current_score[0] == best_score[0] and current_score[1] > best_score[1]):
            best_score = current_score
            best_group = current_group
        
        if count >= max_combinations_to_check:
            logger.warning(f"檢查組合數達到上限 {max_combinations_to_check}，可能未找到全局最優解")
            break
    
    if best_group:
        remaining_ids_set -= set(best_group)
        return best_group, remaining_ids_set
    else:
        # 如果迭代完所有組合（或達到上限）都沒找到，返回 None
        # 這理論上只在人數不足時發生
        return None, remaining_ids_set

def _create_group_dict(user_ids, user_data):
    """
    根據用戶ID列表和用戶數據創建組別字典
    """
    male_count = sum(1 for uid in user_ids if user_data[uid]['gender'] == 'male')
    female_count = len(user_ids) - male_count
    return {
        "user_ids": user_ids,
        "is_complete": len(user_ids) >= 4,  # 3人組標記為 incomplete
        "male_count": male_count,
        "female_count": female_count,
    }

def verify_matching_results():
    """驗證配對結果是否符合配對邏輯"""
    logger.info("正在驗證配對結果...")
    
    # 獲取所有配對組
    groups = mock_db.get_all_groups()
    if not groups:
        logger.warning("未找到任何配對組")
        return False
    
    logger.info(f"找到 {len(groups)} 個配對組")
    
    # 驗證每個組
    for group in groups:
        logger.info(f"組 {group.id}:")
        logger.info(f"  成員數: {len(group.user_ids)}")
        logger.info(f"  男性人數: {group.male_count}")
        logger.info(f"  女性人數: {group.female_count}")
        logger.info(f"  是否完整: {group.is_complete}")
        
        # 統計組內各人格類型數量
        member_personality_types = {}
        member_genders = {"male": 0, "female": 0}
        
        for user_id in group.user_ids:
            user = mock_db.users[user_id]
            user_personality = user.personality_type
            user_gender = user.gender
            
            member_personality_types[user_personality] = member_personality_types.get(user_personality, 0) + 1
            member_genders[user_gender] = member_genders.get(user_gender, 0) + 1
        
        # 記錄組內人格類型分佈
        logger.info(f"  組內人格類型分佈: {member_personality_types}")
        
        # 驗證性別計數
        if member_genders["male"] != group.male_count:
            logger.warning(f"  組 {group.id} 的男性計數 {member_genders['male']} 與記錄的 {group.male_count} 不一致")
        
        if member_genders["female"] != group.female_count:
            logger.warning(f"  組 {group.id} 的女性計數 {member_genders['female']} 與記錄的 {group.female_count} 不一致")
        
        # 驗證組完整性
        if group.is_complete and len(group.user_ids) < 4:
            logger.warning(f"  組 {group.id} 標記為完整但成員數小於4")
        
        # 驗證組大小規則
        group_size = len(group.user_ids)
        if group_size not in [3, 4, 5]:
            logger.warning(f"  組 {group.id} 的大小 {group_size} 不是 3,4,5 之一")
        
        # 評估性別平衡和個性匹配
        gender_ratio = member_genders["male"] / group_size if group_size > 0 else 0
        logger.info(f"  性別比例: 男性佔比 {gender_ratio:.2f}")
        
        # 個性相似度 (最多的個性類型佔比)
        max_personality_count = max(member_personality_types.values()) if member_personality_types else 0
        personality_similarity = max_personality_count / group_size if group_size > 0 else 0
        logger.info(f"  個性相似度: {personality_similarity:.2f} (最多的個性類型佔比)")
        
        # 根據組大小給出評價
        if group_size == 4:
            if member_genders["male"] == 2:
                logger.info(f"  組 {group.id} 是理想的2男2女組")
            else:
                logger.info(f"  組 {group.id} 是4人組但性別不均衡")
        elif group_size == 5:
            logger.info(f"  組 {group.id} 是5人組，男性{member_genders['male']}人，女性{member_genders['female']}人")
        elif group_size == 3:
            logger.info(f"  組 {group.id} 是3人組，男性{member_genders['male']}人，女性{member_genders['female']}人")
    
    # 獲取用戶狀態統計
    waiting_confirmation_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_confirmation")
    waiting_matching_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_matching")
    matching_failed_count = sum(1 for user in mock_db.users.values() if user.status == "matching_failed")
    
    logger.info(f"用戶狀態統計:")
    logger.info(f"  等待確認: {waiting_confirmation_count}")
    logger.info(f"  等待配對: {waiting_matching_count}")
    logger.info(f"  配對失敗: {matching_failed_count}")
    
    logger.info("配對結果驗證完成")
    return True

def run_test():
    """運行完整測試"""
    logger.info("開始運行配對測試...")
    
    # 生成測試用戶
    test_users = generate_test_users(TEST_USER_COUNT)
    
    # 填充模擬數據庫
    populate_mock_db(test_users)
    
    # 模擬批量配對
    matching_result = process_batch_matching()
    
    if matching_result["success"]:
        # 驗證配對結果
        verification_result = verify_matching_results()
        if verification_result:
            logger.info("測試成功完成，配對結果符合預期")
        else:
            logger.warning("測試完成，但配對結果存在問題")
    else:
        logger.error("配對流程處理失敗，測試未完成")
    
    logger.info("配對測試結束")

def test_scenario_1():
    """場景1: 完美的2男2女同人格類型組合 - 測試個性匹配"""
    logger.info("========== 測試場景1: 完美的2男2女同人格類型組合 - 測試個性匹配 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶
    # 分析型
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "分析型", f"分析型男{i+1}")
        mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "分析型", f"分析型女{i+1}")
        mock_db.add_user(user)
    
    # 功能型
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "功能型", f"功能型男{i+1}")
        mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "功能型", f"功能型女{i+1}")
        mock_db.add_user(user)
    
    # 直覺型
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "直覺型", f"直覺型男{i+1}")
        mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "直覺型", f"直覺型女{i+1}")
        mock_db.add_user(user)
    
    # 個人型
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "個人型", f"個人型男{i+1}")
        mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "個人型", f"個人型女{i+1}")
        mock_db.add_user(user)
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景1測試完成")

def test_scenario_2():
    """場景2: 性別不平衡的情況 - 測試性別平衡與個性匹配的權衡"""
    logger.info("========== 測試場景2: 性別不平衡的情況 - 測試性別平衡與個性匹配的權衡 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶
    # 分析型: 6男2女
    for i in range(6):
        user = MockDBUser(str(uuid.uuid4()), "male", "分析型", f"分析型男{i+1}")
        mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "分析型", f"分析型女{i+1}")
        mock_db.add_user(user)
    
    # 功能型: 2男6女
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "功能型", f"功能型男{i+1}")
        mock_db.add_user(user)
    for i in range(6):
        user = MockDBUser(str(uuid.uuid4()), "female", "功能型", f"功能型女{i+1}")
        mock_db.add_user(user)
    
    # 直覺型: 4男4女
    for i in range(4):
        user = MockDBUser(str(uuid.uuid4()), "male", "直覺型", f"直覺型男{i+1}")
        mock_db.add_user(user)
    for i in range(4):
        user = MockDBUser(str(uuid.uuid4()), "female", "直覺型", f"直覺型女{i+1}")
        mock_db.add_user(user)
    
    # 個人型: 3男3女
    for i in range(3):
        user = MockDBUser(str(uuid.uuid4()), "male", "個人型", f"個人型男{i+1}")
        mock_db.add_user(user)
    for i in range(3):
        user = MockDBUser(str(uuid.uuid4()), "female", "個人型", f"個人型女{i+1}")
        mock_db.add_user(user)
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景2測試完成")

def test_scenario_3():
    """場景3: 缺少某些人格類型的用戶 - 測試個性類型不均勻分佈"""
    logger.info("========== 測試場景3: 缺少某些人格類型的用戶 - 測試個性類型不均勻分佈 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶
    # 分析型: 6男6女
    for i in range(6):
        user = MockDBUser(str(uuid.uuid4()), "male", "分析型", f"分析型男{i+1}")
        mock_db.add_user(user)
    for i in range(6):
        user = MockDBUser(str(uuid.uuid4()), "female", "分析型", f"分析型女{i+1}")
        mock_db.add_user(user)
    
    # 功能型: 0用戶
    
    # 直覺型: 2男1女
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "直覺型", f"直覺型男{i+1}")
        mock_db.add_user(user)
    for i in range(1):
        user = MockDBUser(str(uuid.uuid4()), "female", "直覺型", f"直覺型女{i+1}")
        mock_db.add_user(user)
    
    # 個人型: 1男2女
    for i in range(1):
        user = MockDBUser(str(uuid.uuid4()), "male", "個人型", f"個人型男{i+1}")
        mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "個人型", f"個人型女{i+1}")
        mock_db.add_user(user)
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景3測試完成")

def test_scenario_4():
    """場景4: 人數不足3人 - 測試配對失敗情況"""
    logger.info("========== 測試場景4: 人數不足3人 - 測試配對失敗情況 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶 - 僅2人
    user = MockDBUser(str(uuid.uuid4()), "male", "分析型", "分析型男1")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "female", "分析型", "分析型女1")
    mock_db.add_user(user)
    
    # 執行配對
    result = process_batch_matching()
    
    # 驗證配對失敗的結果
    logger.info(f"配對結果: {result}")
    # 檢查所有用戶的狀態是否為 matching_failed
    failed_users = sum(1 for user in mock_db.users.values() if user.status == "matching_failed")
    logger.info(f"配對失敗的用戶數: {failed_users}")
    assert failed_users == 2, "所有用戶狀態應設定為matching_failed"
    
    logger.info("場景4測試完成")

def test_scenario_5():
    """場景5: 測試7人特殊情況 - 4人組+3人組"""
    logger.info("========== 測試場景5: 測試7人特殊情況 - 4人組+3人組 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶 - 共7人
    # 分析型: 2男2女
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "分析型", f"分析型男{i+1}")
    mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "分析型", f"分析型女{i+1}")
    mock_db.add_user(user)
    
    # 功能型: 1男2女
    user = MockDBUser(str(uuid.uuid4()), "male", "功能型", "功能型男1")
    mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "功能型", f"功能型女{i+1}")
    mock_db.add_user(user)
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果
    groups = mock_db.get_all_groups()
    assert len(groups) == 2, f"應該形成2個組，但發現{len(groups)}個"
    
    # 確認有一個4人組和一個3人組
    group_sizes = [len(group.user_ids) for group in groups]
    group_sizes.sort()
    assert group_sizes == [3, 4], f"應該形成一個3人組和一個4人組，但實際是{group_sizes}"
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景5測試完成")

def test_scenario_6():
    """場景6: 測試6人特殊情況 - 兩個3人組"""
    logger.info("========== 測試場景6: 測試6人特殊情況 - 兩個3人組 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶 - 共6人
    # 分析型: 2男2女
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "分析型", f"分析型男{i+1}")
    mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "分析型", f"分析型女{i+1}")
    mock_db.add_user(user)
    
    # 功能型: 1男1女
    user = MockDBUser(str(uuid.uuid4()), "male", "功能型", "功能型男1")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "female", "功能型", "功能型女1")
    mock_db.add_user(user)
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果
    groups = mock_db.get_all_groups()
    assert len(groups) == 2, f"應該形成2個組，但發現{len(groups)}個"
    
    # 確認有兩個3人組
    group_sizes = [len(group.user_ids) for group in groups]
    group_sizes.sort()
    assert group_sizes == [3, 3], f"應該形成兩個3人組，但實際是{group_sizes}"
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景6測試完成")

def test_scenario_7():
    """場景7: 測試11人特殊情況 - 兩個4人組+一個3人組"""
    logger.info("========== 測試場景7: 測試11人特殊情況 - 兩個4人組+一個3人組 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶 - 共11人
    # 分析型: 3男3女
    for i in range(3):
        user = MockDBUser(str(uuid.uuid4()), "male", "分析型", f"分析型男{i+1}")
        mock_db.add_user(user)
    for i in range(3):
        user = MockDBUser(str(uuid.uuid4()), "female", "分析型", f"分析型女{i+1}")
        mock_db.add_user(user)
    
    # 功能型: 2男3女
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "功能型", f"功能型男{i+1}")
        mock_db.add_user(user)
    for i in range(3):
        user = MockDBUser(str(uuid.uuid4()), "female", "功能型", f"功能型女{i+1}")
        mock_db.add_user(user)
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果
    groups = mock_db.get_all_groups()
    assert len(groups) == 3, f"應該形成3個組，但發現{len(groups)}個"
    
    # 確認有兩個4人組和一個3人組
    group_sizes = [len(group.user_ids) for group in groups]
    group_sizes.sort()
    assert group_sizes == [3, 4, 4], f"應該形成一個3人組和兩個4人組，但實際是{group_sizes}"
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景7測試完成")

def test_scenario_8():
    """場景8: 測試5人組的情況 - 9人(一個4人組+一個5人組)"""
    logger.info("========== 測試場景8: 測試5人組的情況 - 9人(一個4人組+一個5人組) ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶 - 共9人
    # 分析型: 2男3女
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "分析型", f"分析型男{i+1}")
        mock_db.add_user(user)
    for i in range(3):
        user = MockDBUser(str(uuid.uuid4()), "female", "分析型", f"分析型女{i+1}")
        mock_db.add_user(user)
    
    # 功能型: 2男2女
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "male", "功能型", f"功能型男{i+1}")
    mock_db.add_user(user)
    for i in range(2):
        user = MockDBUser(str(uuid.uuid4()), "female", "功能型", f"功能型女{i+1}")
        mock_db.add_user(user)
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果
    groups = mock_db.get_all_groups()
    assert len(groups) == 2, f"應該形成2個組，但發現{len(groups)}個"
    
    # 確認有一個4人組和一個5人組
    group_sizes = [len(group.user_ids) for group in groups]
    group_sizes.sort()
    assert group_sizes == [4, 5], f"應該形成一個4人組和一個5人組，但實際是{group_sizes}"
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景8測試完成")

def run_all_tests():
    """運行所有測試"""
    logger.info("開始運行所有配對測試...")
    
    # 運行基本測試
    run_test()
    
    # 運行場景測試
    test_scenario_1()  # 完美的2男2女同人格類型組合
    test_scenario_2()  # 性別不平衡的情況
    test_scenario_3()  # 缺少某些人格類型的用戶
    test_scenario_4()  # 人數不足3人的情況
    test_scenario_5()  # 7人特殊情況
    test_scenario_6()  # 6人特殊情況
    test_scenario_7()  # 11人特殊情況
    test_scenario_8()  # 5人組的情況
    
    logger.info("所有測試完成")

if __name__ == "__main__":
    run_all_tests() 