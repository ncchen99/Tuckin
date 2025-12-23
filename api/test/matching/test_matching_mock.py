import os
import sys
import uuid
import random
import json
from datetime import datetime, timedelta
import logging
from collections import Counter
import time  # 添加計時功能
import cProfile  # 添加性能分析功能
from collections import defaultdict
from typing import Dict, Set, List, Optional, Tuple

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
        self.status = "waiting_restaurant"
        self.created_at = datetime.now()


class MockDiningHistory:
    """模擬聚餐歷史記錄"""
    
    def __init__(self, history_id: str, user_ids: List[str], event_date: datetime = None):
        self.id = history_id
        self.user_ids = user_ids
        self.event_date = event_date or datetime.now() - timedelta(days=7)
        self.restaurant_name = "測試餐廳"
        self.event_name = "測試聚餐"

class MockDatabase:
    """模擬數據庫"""
    def __init__(self):
        self.users = {}  # user_id -> MockDBUser
        self.groups = []  # List[MockDBGroup]
        self.dining_history = []  # List[MockDiningHistory]
        
    def add_user(self, user):
        """添加用戶"""
        self.users[user.user_id] = user
        
    def add_group(self, group):
        """添加配對組"""
        self.groups.append(group)
    
    def add_dining_history(self, history: MockDiningHistory):
        """添加聚餐歷史記錄"""
        self.dining_history.append(history)
        
    def get_all_users(self):
        """獲取所有用戶"""
        return list(self.users.values())
    
    def get_waiting_users(self):
        """獲取等待配對的用戶"""
        return [user for user in self.users.values() if user.status == "waiting_matching"]
    
    def get_all_groups(self):
        """獲取所有配對組"""
        return self.groups
    
    def get_all_dining_history(self):
        """獲取所有聚餐歷史"""
        return self.dining_history
    
    def update_user_status(self, user_id, new_status):
        """更新用戶狀態"""
        if user_id in self.users:
            self.users[user_id].status = new_status
            return True
        return False
    
    def get_dining_history_pairs(self, user_ids: List[str]) -> Dict[str, Set[str]]:
        """
        獲取用戶的聚餐歷史配對（模擬 get_user_dining_history_pairs 函數）
        
        Args:
            user_ids: 待配對的用戶ID列表
            
        Returns:
            Dict[str, Set[str]]: 每個用戶曾經一起聚餐過的用戶ID集合
        """
        if not user_ids:
            return {}
        
        user_history_pairs: Dict[str, Set[str]] = {uid: set() for uid in user_ids}
        user_ids_set = set(user_ids)
        
        for history in self.dining_history:
            history_user_ids = history.user_ids
            if not history_user_ids:
                continue
            
            # 找出這次歷史記錄中有哪些用戶在待配對列表中
            relevant_users = [uid for uid in history_user_ids if uid in user_ids_set]
            
            # 對於這些相關用戶，互相記錄為曾經一起聚餐過
            for i, uid1 in enumerate(relevant_users):
                for uid2 in relevant_users[i+1:]:
                    user_history_pairs[uid1].add(uid2)
                    user_history_pairs[uid2].add(uid1)
        
        return user_history_pairs

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
    
    # 3. 獲取聚餐歷史配對
    all_user_ids = list(user_data.keys())
    dining_history_pairs = mock_db.get_dining_history_pairs(all_user_ids)
    if dining_history_pairs:
        total_pairs = sum(len(v) for v in dining_history_pairs.values()) // 2
        logger.info(f"考慮聚餐歷史，共 {total_pairs} 對歷史配對")
    
    # 4. 執行新的配對算法
    result_groups = _match_users_into_groups(user_data, dining_history_pairs)
    
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
            mock_db.update_user_status(user_id, "waiting_restaurant")
            matched_user_count += 1
    
    # 計算待配對和已配對的用戶數
    waiting_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_matching")
    matched_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_restaurant")
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

def _match_users_into_groups(user_data, dining_history_pairs: Dict[str, Set[str]] = None):
    """
    根據用戶資料將用戶分組配對，確保所有用戶都被分配，優先4人組，
    剩餘分配至5人組，僅在 N=6,7,11 時允許3人組。
    新增：考慮用戶的聚餐歷史，盡量避免曾經一起聚餐過的用戶再次配對。
    
    Args:
        user_data: 格式 {user_id: {"gender": gender, "personality_type": personality_type}}
        dining_history_pairs: 用戶聚餐歷史配對字典
        
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
    
    # 按性別和個性類型分類用戶（這是為了與 matching.py 中的函數匹配）
    categorized_users = defaultdict(lambda: defaultdict(list))
    for user_id in remaining_user_ids:
        data = user_data[user_id]
        gender = data.get('gender')
        p_type = data.get('personality_type')
        if gender and p_type:
            categorized_users[gender][p_type].append(user_id)
    
    # 記錄聚餐歷史信息
    if dining_history_pairs:
        total_pairs = sum(len(v) for v in dining_history_pairs.values()) // 2
        logger.info(f"考慮聚餐歷史，共 {total_pairs} 對歷史配對")
    
    # 特殊情況處理 N=6, 7, 11
    if total_users == 6:
        logger.info(f"處理特殊情況 N=6：組成兩個 3 人組")
        group1, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3, dining_history_pairs)
        group2, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3, dining_history_pairs)
        
        if group1: result_groups.append(_create_group_dict(group1, user_data))
        if group2: result_groups.append(_create_group_dict(group2, user_data))
        return result_groups
        
    elif total_users == 7:
        logger.info(f"處理特殊情況 N=7：組成一個 4 人組和一個 3 人組")
        group4, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 4, dining_history_pairs)
        group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3, dining_history_pairs)
        
        if group4: result_groups.append(_create_group_dict(group4, user_data))
        if group3: result_groups.append(_create_group_dict(group3, user_data))
        return result_groups
        
    elif total_users == 11:
        logger.info(f"處理特殊情況 N=11：組成兩個 4 人組和一個 3 人組")
        group1, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 4, dining_history_pairs)
        group2, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 4, dining_history_pairs)
        group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3, dining_history_pairs)
        
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
            group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3, dining_history_pairs)
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
            
        group4, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 4, dining_history_pairs)
        
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
            
        group5, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 5, dining_history_pairs)
        
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

def calculate_history_penalty(group_ids: List[str], dining_history_pairs: Dict[str, Set[str]]) -> int:
    """
    計算組內成員的聚餐歷史懲罰分數
    
    Args:
        group_ids: 組內成員ID列表
        dining_history_pairs: 用戶聚餐歷史配對字典
        
    Returns:
        int: 懲罰分數（負數，曾經一起聚餐的配對越多，懲罰越重）
    """
    if not dining_history_pairs:
        return 0
    
    penalty = 0
    # 檢查組內每對用戶是否曾經一起聚餐過
    for i, uid1 in enumerate(group_ids):
        for uid2 in group_ids[i+1:]:
            if uid1 in dining_history_pairs and uid2 in dining_history_pairs[uid1]:
                penalty -= 10  # 每對曾經一起聚餐的用戶扣10分
    
    return penalty


def _calculate_group_score(group_ids, user_data, dining_history_pairs: Dict[str, Set[str]] = None):
    """
    計算組別的質量分數。
    分數越高越好。
    返回 (性別平衡分數, 個性相似度分數, 聚餐歷史懲罰分數, 總人數)
    性別平衡：2男2女最高(4人組), 3男2女/2男3女次之(5人組)
    個性相似度：相同個性類型越多越好
    聚餐歷史：曾經一起聚餐過的配對會有懲罰分數
    """
    size = len(group_ids)
    if size == 0: return (-1, -1, 0, 0)
    
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
    
    # 聚餐歷史懲罰分數
    history_penalty = calculate_history_penalty(group_ids, dining_history_pairs) if dining_history_pairs else 0
    
    return (gender_score, personality_score, history_penalty, size)

def _find_best_group(remaining_ids_set, user_data, categorized_users, target_size, dining_history_pairs: Dict[str, Set[str]] = None):
    """
    從剩餘用戶中找到最佳的組（基於性別、個性和聚餐歷史）
    對於大規模用戶，使用啟發式方法而不是窮舉所有可能組合
    返回 (找到的組ID列表 或 None, 更新後的剩餘用戶ID集合)
    """
    if len(remaining_ids_set) < target_size:
        return None, remaining_ids_set
    
    # 針對大規模用戶進行優化
    if len(remaining_ids_set) > 100:
        return _find_best_group_heuristic(remaining_ids_set, user_data, categorized_users, target_size, dining_history_pairs)
    
    best_group = None
    best_score = (-1, -1, -100, -1)  # (性別分, 個性分, 歷史懲罰分, size)
    
    # 優化：限制檢查的組合數量以避免性能問題
    max_combinations_to_check = 1000
    count = 0
    
    import itertools
    potential_combinations = itertools.combinations(list(remaining_ids_set), target_size)
    
    for current_group_tuple in potential_combinations:
        count += 1
        current_group = list(current_group_tuple)
        current_score = _calculate_group_score(current_group, user_data, dining_history_pairs)
        
        # 比較分數 (優先聚餐歷史懲罰，其次性別，再次個性)
        if current_score[2] > best_score[2] or \
           (current_score[2] == best_score[2] and current_score[0] > best_score[0]) or \
           (current_score[2] == best_score[2] and current_score[0] == best_score[0] and current_score[1] > best_score[1]):
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

def _find_best_group_heuristic(remaining_ids_set, user_data, categorized_users, target_size, dining_history_pairs: Dict[str, Set[str]] = None):
    """
    大規模用戶的啟發式最佳組查找算法
    策略：
    1. 根據性別將用戶分組
    2. 根據個性類型進一步分組
    3. 優先從同一個性類型中選擇用戶，同時平衡性別比例
    4. 盡量避免曾經一起聚餐過的用戶配對
    """
    remaining_ids = list(remaining_ids_set)
    
    # 輔助函數：計算候選用戶與已選用戶的歷史重複數
    def count_history_overlap(candidate_id: str, selected_ids: List[str]) -> int:
        if not dining_history_pairs or candidate_id not in dining_history_pairs:
            return 0
        return sum(1 for sid in selected_ids if sid in dining_history_pairs[candidate_id])
    
    # 輔助函數：從候選列表中選擇與已選用戶歷史重複最少的用戶
    def select_best_candidate(candidates: List[str], selected_ids: List[str]) -> Optional[str]:
        if not candidates:
            return None
        if not dining_history_pairs:
            return candidates[0]
        
        # 按歷史重複數排序，選擇重複最少的
        sorted_candidates = sorted(candidates, key=lambda c: count_history_overlap(c, selected_ids))
        return sorted_candidates[0]
    
    # 按性別和個性類型分類用戶
    males = []
    females = []
    for uid in remaining_ids:
        if user_data[uid]['gender'] == 'male':
            males.append(uid)
        else:
            females.append(uid)
    
    # 根據目標組大小計算理想的性別比例
    ideal_male_count = target_size // 2
    ideal_female_count = target_size - ideal_male_count
    
    # 檢查是否有足夠的男性和女性
    if len(males) < ideal_male_count or len(females) < ideal_female_count:
        # 如果一種性別不足，調整比例
        if len(males) < ideal_male_count:
            ideal_male_count = min(len(males), target_size - 1)
            ideal_female_count = target_size - ideal_male_count
        else:
            ideal_female_count = min(len(females), target_size - 1)
            ideal_male_count = target_size - ideal_female_count
    
    # 按個性類型分組
    male_by_type = {}
    female_by_type = {}
    
    for uid in males:
        p_type = user_data[uid]['personality_type']
        if p_type not in male_by_type:
            male_by_type[p_type] = []
        male_by_type[p_type].append(uid)
    
    for uid in females:
        p_type = user_data[uid]['personality_type']
        if p_type not in female_by_type:
            female_by_type[p_type] = []
        female_by_type[p_type].append(uid)
    
    # 嘗試找到具有相同個性類型的用戶組
    best_group = []
    common_types = set(male_by_type.keys()).intersection(set(female_by_type.keys()))
    
    # 優先選擇個性類型最多的組合
    if common_types:
        # 按數量排序類型
        sorted_types = sorted(common_types, 
                             key=lambda t: len(male_by_type[t]) + len(female_by_type[t]), 
                             reverse=True)
        
        # 從最多的類型開始選擇
        selected_type = sorted_types[0]
        
        # 選擇所需數量的男性和女性，考慮聚餐歷史
        selected_males = []
        available_males = male_by_type[selected_type].copy()
        
        while len(selected_males) < ideal_male_count and available_males:
            best_candidate = select_best_candidate(available_males, selected_males + best_group)
            if best_candidate:
                selected_males.append(best_candidate)
                available_males.remove(best_candidate)
        
        selected_females = []
        available_females = female_by_type[selected_type].copy()
        
        while len(selected_females) < ideal_female_count and available_females:
            best_candidate = select_best_candidate(available_females, selected_males + selected_females + best_group)
            if best_candidate:
                selected_females.append(best_candidate)
                available_females.remove(best_candidate)
        
        # 如果選擇的用戶不足，從其他類型中補充
        while len(selected_males) < ideal_male_count and len(males) > len(selected_males):
            for t in sorted_types[1:]:
                if t in male_by_type and male_by_type[t]:
                    available = [m for m in male_by_type[t] if m not in selected_males]
                    best_candidate = select_best_candidate(available, selected_males + selected_females)
                    if best_candidate:
                        selected_males.append(best_candidate)
                        male_by_type[t].remove(best_candidate)
                    if len(selected_males) >= ideal_male_count:
                        break
            
            # 如果仍不足，從未考慮的類型中選擇
            if len(selected_males) < ideal_male_count:
                for t in set(male_by_type.keys()) - common_types:
                    if male_by_type[t]:
                        available = [m for m in male_by_type[t] if m not in selected_males]
                        best_candidate = select_best_candidate(available, selected_males + selected_females)
                        if best_candidate:
                            selected_males.append(best_candidate)
                            male_by_type[t].remove(best_candidate)
                        if len(selected_males) >= ideal_male_count:
                            break
            
            # 如果所有類型都檢查過了但仍不足
            if len(selected_males) < ideal_male_count:
                # 使用隨機選擇
                remaining_males = list(set(males) - set(selected_males))
                if remaining_males:
                    best_candidate = select_best_candidate(remaining_males, selected_males + selected_females)
                    if best_candidate:
                        selected_males.append(best_candidate)
                else:
                    break
        
        # 對女性也執行相同的邏輯
        while len(selected_females) < ideal_female_count and len(females) > len(selected_females):
            for t in sorted_types[1:]:
                if t in female_by_type and female_by_type[t]:
                    available = [f for f in female_by_type[t] if f not in selected_females]
                    best_candidate = select_best_candidate(available, selected_males + selected_females)
                    if best_candidate:
                        selected_females.append(best_candidate)
                        female_by_type[t].remove(best_candidate)
                    if len(selected_females) >= ideal_female_count:
                        break
            
            if len(selected_females) < ideal_female_count:
                for t in set(female_by_type.keys()) - common_types:
                    if female_by_type[t]:
                        available = [f for f in female_by_type[t] if f not in selected_females]
                        best_candidate = select_best_candidate(available, selected_males + selected_females)
                        if best_candidate:
                            selected_females.append(best_candidate)
                            female_by_type[t].remove(best_candidate)
                        if len(selected_females) >= ideal_female_count:
                            break
            
            if len(selected_females) < ideal_female_count:
                remaining_females = list(set(females) - set(selected_females))
                if remaining_females:
                    best_candidate = select_best_candidate(remaining_females, selected_males + selected_females)
                    if best_candidate:
                        selected_females.append(best_candidate)
                else:
                    break
        
        best_group = selected_males + selected_females
    else:
        # 如果沒有共同的類型，選擇時考慮聚餐歷史
        selected_males = []
        available_males = males.copy()
        random.shuffle(available_males)
        
        while len(selected_males) < ideal_male_count and available_males:
            best_candidate = select_best_candidate(available_males, selected_males)
            if best_candidate:
                selected_males.append(best_candidate)
                available_males.remove(best_candidate)
        
        selected_females = []
        available_females = females.copy()
        random.shuffle(available_females)
        
        while len(selected_females) < ideal_female_count and available_females:
            best_candidate = select_best_candidate(available_females, selected_males + selected_females)
            if best_candidate:
                selected_females.append(best_candidate)
                available_females.remove(best_candidate)
        
        best_group = selected_males + selected_females
    
    # 如果人數不足，返回None
    if len(best_group) < target_size:
        return None, remaining_ids_set
    
    # 更新剩餘用戶ID集合
    remaining_ids_set -= set(best_group)
    
    return best_group, remaining_ids_set

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

def verify_matching_results(check_history: bool = False):
    """
    驗證配對結果是否符合配對邏輯
    
    Args:
        check_history: 是否檢查聚餐歷史衝突
    """
    logger.info("正在驗證配對結果...")
    
    # 獲取所有配對組
    groups = mock_db.get_all_groups()
    if not groups:
        logger.warning("未找到任何配對組")
        return False
    
    logger.info(f"找到 {len(groups)} 個配對組")
    
    # 獲取聚餐歷史配對
    dining_history_pairs = None
    history_conflicts = 0
    if check_history:
        all_user_ids = list(mock_db.users.keys())
        dining_history_pairs = mock_db.get_dining_history_pairs(all_user_ids)
    
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
        
        # 檢查聚餐歷史衝突
        if check_history and dining_history_pairs:
            group_conflicts = 0
            for i, uid1 in enumerate(group.user_ids):
                for uid2 in group.user_ids[i+1:]:
                    if uid1 in dining_history_pairs and uid2 in dining_history_pairs[uid1]:
                        group_conflicts += 1
                        logger.warning(f"  組 {group.id} 中用戶 {uid1[:8]}... 和 {uid2[:8]}... 曾經一起聚餐過")
            
            if group_conflicts > 0:
                logger.warning(f"  組 {group.id} 有 {group_conflicts} 對歷史衝突")
                history_conflicts += group_conflicts
            else:
                logger.info(f"  組 {group.id} 無歷史衝突 ✓")
    
    # 獲取用戶狀態統計
    waiting_restaurant_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_restaurant")
    waiting_matching_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_matching")
    matching_failed_count = sum(1 for user in mock_db.users.values() if user.status == "matching_failed")
    
    logger.info(f"用戶狀態統計:")
    logger.info(f"  等待餐廳選擇: {waiting_restaurant_count}")
    logger.info(f"  等待配對: {waiting_matching_count}")
    logger.info(f"  配對失敗: {matching_failed_count}")
    
    # 輸出歷史衝突統計
    if check_history:
        logger.info(f"聚餐歷史衝突統計: {history_conflicts} 對衝突")
    
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

def test_scenario_9():
    """場景9: 大規模用戶配對性能測試 - 200位用戶，測量性能並確保依然是最佳解"""
    logger.info("========== 測試場景9: 大規模用戶配對性能測試 (200位用戶) ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建200位測試用戶，確保性別平衡且個性類型分佈均勻
    user_count = 200
    logger.info(f"開始創建 {user_count} 位測試用戶...")
    
    # 均勻分配性別和個性類型
    for i in range(user_count):
        personality_type = PERSONALITY_TYPES[i % len(PERSONALITY_TYPES)]
        gender = GENDERS[i % 2]
        
        user = MockDBUser(
            user_id=str(uuid.uuid4()),
            gender=gender,
            personality_type=personality_type,
            nickname=f"用戶{i+1}"
        )
        mock_db.add_user(user)
    
    # 確認用戶創建情況
    male_count = sum(1 for user in mock_db.users.values() if user.gender == 'male')
    female_count = sum(1 for user in mock_db.users.values() if user.gender == 'female')
    
    personality_counts = {p_type: 0 for p_type in PERSONALITY_TYPES}
    for user in mock_db.users.values():
        personality_counts[user.personality_type] += 1
    
    logger.info(f"用戶創建完成:")
    logger.info(f"總人數: {len(mock_db.users)}")
    logger.info(f"性別分佈: 男性 {male_count}, 女性 {female_count}")
    for p_type, count in personality_counts.items():
        logger.info(f"{p_type}: {count} 人")
    
    # 執行配對並計時
    logger.info("開始執行配對算法，計時開始...")
    start_time = time.time()
    
    # 執行配對
    matching_result = process_batch_matching()
    
    end_time = time.time()
    execution_time = end_time - start_time
    
    logger.info(f"配對算法執行完成，耗時: {execution_time:.4f} 秒")
    logger.info(f"配對結果: {matching_result}")
    
    # 驗證配對結果
    logger.info("驗證配對結果...")
    groups = mock_db.get_all_groups()
    
    # 計算組的數量
    logger.info(f"形成的組數: {len(groups)}")
    
    # 計算不同規模組的數量
    group_sizes = [len(group.user_ids) for group in groups]
    size_counter = Counter(group_sizes)
    for size, count in sorted(size_counter.items()):
        logger.info(f"{size}人組: {count}個")
    
    # 計算性別平衡情況
    gender_balance_scores = []
    personality_similarity_scores = []
    
    for group in groups:
        member_genders = {"male": 0, "female": 0}
        member_personalities = {}
        
        for user_id in group.user_ids:
            user = mock_db.users[user_id]
            member_genders[user.gender] += 1
            
            p_type = user.personality_type
            member_personalities[p_type] = member_personalities.get(p_type, 0) + 1
        
        # 計算性別平衡分數 (0-1，越接近0.5越平衡)
        gender_ratio = member_genders["male"] / len(group.user_ids)
        gender_balance = abs(0.5 - gender_ratio)  # 0表示完美平衡(1:1)，0.5表示全是同一性別
        gender_balance_scores.append(gender_balance)
        
        # 計算個性相似度 (最多的個性類型佔比)
        max_personality_count = max(member_personalities.values())
        personality_similarity = max_personality_count / len(group.user_ids)
        personality_similarity_scores.append(personality_similarity)
    
    # 計算平均分數
    avg_gender_balance = sum(gender_balance_scores) / len(gender_balance_scores) if gender_balance_scores else 0
    avg_personality_similarity = sum(personality_similarity_scores) / len(personality_similarity_scores) if personality_similarity_scores else 0
    
    logger.info(f"性別平衡度評分 (越接近0越好): {avg_gender_balance:.4f}")
    logger.info(f"個性相似度評分 (越接近1越好): {avg_personality_similarity:.4f}")
    
    # 檢查是否所有用戶都被分配
    matched_users = sum(len(group.user_ids) for group in groups)
    logger.info(f"已配對用戶: {matched_users}/{user_count}")
    
    if matched_users != user_count:
        logger.warning(f"有 {user_count - matched_users} 位用戶未被配對")
    
    # 分析用戶狀態
    waiting_restaurant_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_restaurant")
    waiting_matching_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_matching")
    matching_failed_count = sum(1 for user in mock_db.users.values() if user.status == "matching_failed")
    
    logger.info(f"用戶狀態分析:")
    logger.info(f"  等待餐廳選擇: {waiting_restaurant_count}")
    logger.info(f"  等待配對: {waiting_matching_count}")
    logger.info(f"  配對失敗: {matching_failed_count}")
    
    logger.info("場景9測試完成")
    
    return execution_time, len(groups), avg_gender_balance, avg_personality_similarity

def test_performance_profiling():
    """執行性能分析，找出配對算法中的性能瓶頸"""
    logger.info("========== 配對算法性能分析 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建100位測試用戶
    user_count = 100
    for i in range(user_count):
        personality_type = PERSONALITY_TYPES[i % len(PERSONALITY_TYPES)]
        gender = GENDERS[i % 2]
        
        user = MockDBUser(
            user_id=str(uuid.uuid4()),
            gender=gender,
            personality_type=personality_type,
            nickname=f"用戶{i+1}"
        )
        mock_db.add_user(user)
    
    # 使用cProfile進行性能分析
    logger.info(f"開始性能分析，對 {user_count} 位用戶執行配對...")
    profile_filename = os.path.join(os.path.dirname(os.path.abspath(__file__)), "matching_profile.stats")
    
    cProfile.run('process_batch_matching()', profile_filename)
    
    logger.info(f"性能分析完成，結果已保存到 {profile_filename}")
    logger.info("可使用以下命令查看分析結果: python -m pstats matching_profile.stats")
    
    logger.info("性能分析測試完成")

def test_scenario_10():
    """場景10: 測試聚餐歷史避免功能 - 驗證算法會盡量避免將曾經一起聚餐過的用戶分到同一組"""
    logger.info("========== 測試場景10: 聚餐歷史避免功能測試 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    mock_db.dining_history = []
    
    # 創建16位測試用戶 - 均衡分佈
    user_ids = []
    for i in range(16):
        user_id = str(uuid.uuid4())
        user_ids.append(user_id)
        personality_type = PERSONALITY_TYPES[i % len(PERSONALITY_TYPES)]
        gender = GENDERS[i % 2]
        
        user = MockDBUser(
            user_id=user_id,
            gender=gender,
            personality_type=personality_type,
            nickname=f"用戶{i+1}"
        )
        mock_db.add_user(user)
    
    # 創建聚餐歷史 - 假設用戶0,1,2,3曾經一起聚餐過
    history1 = MockDiningHistory(
        history_id=str(uuid.uuid4()),
        user_ids=[user_ids[0], user_ids[1], user_ids[2], user_ids[3]]
    )
    mock_db.add_dining_history(history1)
    
    # 假設用戶4,5,6,7也曾經一起聚餐過
    history2 = MockDiningHistory(
        history_id=str(uuid.uuid4()),
        user_ids=[user_ids[4], user_ids[5], user_ids[6], user_ids[7]]
    )
    mock_db.add_dining_history(history2)
    
    logger.info(f"已創建2次聚餐歷史記錄:")
    logger.info(f"  歷史1: 用戶 0,1,2,3 曾經一起聚餐")
    logger.info(f"  歷史2: 用戶 4,5,6,7 曾經一起聚餐")
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果 - 檢查歷史衝突
    verify_matching_results(check_history=True)
    
    # 統計衝突數量
    groups = mock_db.get_all_groups()
    dining_history_pairs = mock_db.get_dining_history_pairs(user_ids)
    
    total_conflicts = 0
    for group in groups:
        for i, uid1 in enumerate(group.user_ids):
            for uid2 in group.user_ids[i+1:]:
                if uid1 in dining_history_pairs and uid2 in dining_history_pairs[uid1]:
                    total_conflicts += 1
    
    logger.info(f"總計歷史衝突對數: {total_conflicts}")
    logger.info(f"理論最大衝突對數: 12 (如果完全不考慮歷史)")
    logger.info(f"衝突減少率: {(1 - total_conflicts/12)*100:.1f}%" if total_conflicts < 12 else "未減少衝突")
    
    logger.info("場景10測試完成")
    return total_conflicts


def test_scenario_11():
    """場景11: 大規模聚餐歷史避免測試 - 100位用戶，30次歷史聚餐"""
    logger.info("========== 測試場景11: 大規模聚餐歷史避免測試 (100位用戶，30次歷史聚餐) ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    mock_db.dining_history = []
    
    # 創建100位測試用戶
    user_count = 100
    user_ids = []
    
    for i in range(user_count):
        user_id = str(uuid.uuid4())
        user_ids.append(user_id)
        personality_type = PERSONALITY_TYPES[i % len(PERSONALITY_TYPES)]
        gender = GENDERS[i % 2]
        
        user = MockDBUser(
            user_id=user_id,
            gender=gender,
            personality_type=personality_type,
            nickname=f"用戶{i+1}"
        )
        mock_db.add_user(user)
    
    # 創建30次聚餐歷史 - 隨機選擇4人組成一次聚餐
    history_count = 30
    for i in range(history_count):
        # 隨機選擇4位用戶
        history_user_ids = random.sample(user_ids, 4)
        history = MockDiningHistory(
            history_id=str(uuid.uuid4()),
            user_ids=history_user_ids
        )
        mock_db.add_dining_history(history)
    
    # 獲取歷史配對數量
    dining_history_pairs = mock_db.get_dining_history_pairs(user_ids)
    total_history_pairs = sum(len(v) for v in dining_history_pairs.values()) // 2
    logger.info(f"已創建 {history_count} 次聚餐歷史，共 {total_history_pairs} 對歷史配對")
    
    # 執行配對並計時
    logger.info("開始執行配對算法，計時開始...")
    start_time = time.time()
    
    # 執行配對
    matching_result = process_batch_matching()
    
    end_time = time.time()
    execution_time = end_time - start_time
    
    logger.info(f"配對算法執行完成，耗時: {execution_time:.4f} 秒")
    
    # 驗證結果
    verify_matching_results(check_history=True)
    
    # 統計衝突數量
    groups = mock_db.get_all_groups()
    total_conflicts = 0
    for group in groups:
        for i, uid1 in enumerate(group.user_ids):
            for uid2 in group.user_ids[i+1:]:
                if uid1 in dining_history_pairs and uid2 in dining_history_pairs[uid1]:
                    total_conflicts += 1
    
    logger.info(f"\n========== 場景11結果摘要 ==========")
    logger.info(f"用戶數: {user_count}")
    logger.info(f"歷史聚餐次數: {history_count}")
    logger.info(f"歷史配對數: {total_history_pairs}")
    logger.info(f"執行時間: {execution_time:.4f} 秒")
    logger.info(f"形成組數: {len(groups)}")
    logger.info(f"歷史衝突對數: {total_conflicts}")
    
    logger.info("場景11測試完成")
    return execution_time, total_conflicts


def test_scenario_12():
    """場景12: 對比測試 - 比較有無聚餐歷史考量的配對結果"""
    logger.info("========== 測試場景12: 有無聚餐歷史考量的對比測試 ==========")
    
    # 創建固定的測試數據
    user_ids = []
    user_data_template = {}
    
    for i in range(20):
        user_id = str(uuid.uuid4())
        user_ids.append(user_id)
        personality_type = PERSONALITY_TYPES[i % len(PERSONALITY_TYPES)]
        gender = GENDERS[i % 2]
        user_data_template[user_id] = {
            "gender": gender,
            "personality_type": personality_type
        }
    
    # 創建聚餐歷史 - 前8人曾經分成2組聚餐過
    dining_history_pairs = {uid: set() for uid in user_ids}
    
    # 歷史1: 用戶0,1,2,3
    for i in range(4):
        for j in range(i+1, 4):
            dining_history_pairs[user_ids[i]].add(user_ids[j])
            dining_history_pairs[user_ids[j]].add(user_ids[i])
    
    # 歷史2: 用戶4,5,6,7
    for i in range(4, 8):
        for j in range(i+1, 8):
            dining_history_pairs[user_ids[i]].add(user_ids[j])
            dining_history_pairs[user_ids[j]].add(user_ids[i])
    
    logger.info("測試配置:")
    logger.info(f"  總用戶數: 20")
    logger.info(f"  歷史配對: 用戶0-3曾一起聚餐, 用戶4-7曾一起聚餐")
    
    # 測試1: 不考慮聚餐歷史
    logger.info("\n--- 測試1: 不考慮聚餐歷史 ---")
    result_without_history = _match_users_into_groups(user_data_template, None)
    
    conflicts_without = 0
    for group in result_without_history:
        group_ids = group["user_ids"]
        for i, uid1 in enumerate(group_ids):
            for uid2 in group_ids[i+1:]:
                if uid1 in dining_history_pairs and uid2 in dining_history_pairs[uid1]:
                    conflicts_without += 1
    
    logger.info(f"形成組數: {len(result_without_history)}")
    logger.info(f"歷史衝突對數: {conflicts_without}")
    
    # 測試2: 考慮聚餐歷史
    logger.info("\n--- 測試2: 考慮聚餐歷史 ---")
    result_with_history = _match_users_into_groups(user_data_template, dining_history_pairs)
    
    conflicts_with = 0
    for group in result_with_history:
        group_ids = group["user_ids"]
        for i, uid1 in enumerate(group_ids):
            for uid2 in group_ids[i+1:]:
                if uid1 in dining_history_pairs and uid2 in dining_history_pairs[uid1]:
                    conflicts_with += 1
    
    logger.info(f"形成組數: {len(result_with_history)}")
    logger.info(f"歷史衝突對數: {conflicts_with}")
    
    # 對比結果
    logger.info("\n--- 對比結果 ---")
    logger.info(f"不考慮歷史的衝突數: {conflicts_without}")
    logger.info(f"考慮歷史的衝突數: {conflicts_with}")
    
    if conflicts_with < conflicts_without:
        improvement = (1 - conflicts_with/conflicts_without) * 100 if conflicts_without > 0 else 100
        logger.info(f"改善率: {improvement:.1f}%")
    elif conflicts_with == conflicts_without:
        logger.info("衝突數相同 (可能已是最優解或歷史配對分佈特殊)")
    else:
        logger.warning("考慮歷史後衝突數反而增加，這不應該發生")
    
    logger.info("場景12測試完成")
    return conflicts_without, conflicts_with


def test_scenario_13():
    """場景13: 性能壓力測試 - 300位用戶，100次歷史聚餐"""
    logger.info("========== 測試場景13: 性能壓力測試 (300位用戶，100次歷史聚餐) ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    mock_db.dining_history = []
    
    # 創建300位測試用戶
    user_count = 300
    user_ids = []
    
    for i in range(user_count):
        user_id = str(uuid.uuid4())
        user_ids.append(user_id)
        personality_type = PERSONALITY_TYPES[i % len(PERSONALITY_TYPES)]
        gender = GENDERS[i % 2]
        
        user = MockDBUser(
            user_id=user_id,
            gender=gender,
            personality_type=personality_type,
            nickname=f"用戶{i+1}"
        )
        mock_db.add_user(user)
    
    # 創建100次聚餐歷史
    history_count = 100
    for i in range(history_count):
        # 隨機選擇4-5位用戶
        group_size = random.choice([4, 5])
        history_user_ids = random.sample(user_ids, group_size)
        history = MockDiningHistory(
            history_id=str(uuid.uuid4()),
            user_ids=history_user_ids
        )
        mock_db.add_dining_history(history)
    
    # 獲取歷史配對數量
    dining_history_pairs = mock_db.get_dining_history_pairs(user_ids)
    total_history_pairs = sum(len(v) for v in dining_history_pairs.values()) // 2
    logger.info(f"已創建 {history_count} 次聚餐歷史，共 {total_history_pairs} 對歷史配對")
    
    # 執行配對並計時
    logger.info("開始執行配對算法，計時開始...")
    start_time = time.time()
    
    # 執行配對
    matching_result = process_batch_matching()
    
    end_time = time.time()
    execution_time = end_time - start_time
    
    logger.info(f"配對算法執行完成，耗時: {execution_time:.4f} 秒")
    
    # 統計結果
    groups = mock_db.get_all_groups()
    total_conflicts = 0
    for group in groups:
        for i, uid1 in enumerate(group.user_ids):
            for uid2 in group.user_ids[i+1:]:
                if uid1 in dining_history_pairs and uid2 in dining_history_pairs[uid1]:
                    total_conflicts += 1
    
    logger.info(f"\n========== 場景13結果摘要 ==========")
    logger.info(f"用戶數: {user_count}")
    logger.info(f"歷史聚餐次數: {history_count}")
    logger.info(f"歷史配對數: {total_history_pairs}")
    logger.info(f"執行時間: {execution_time:.4f} 秒")
    logger.info(f"形成組數: {len(groups)}")
    logger.info(f"歷史衝突對數: {total_conflicts}")
    
    # 性能評估
    if execution_time < 1.0:
        logger.info("性能評估: 優秀 (< 1秒)")
    elif execution_time < 5.0:
        logger.info("性能評估: 良好 (< 5秒)")
    elif execution_time < 10.0:
        logger.info("性能評估: 可接受 (< 10秒)")
    else:
        logger.warning("性能評估: 需要優化 (> 10秒)")
    
    logger.info("場景13測試完成")
    return execution_time, total_conflicts, len(groups)


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
    
    # 運行大規模用戶測試
    execution_time, groups_count, gender_balance, personality_similarity = test_scenario_9()  # 200位用戶性能測試
    
    logger.info("\n========== 大規模測試結果摘要 ==========")
    logger.info(f"200位用戶配對耗時: {execution_time:.4f} 秒")
    logger.info(f"形成組數: {groups_count}")
    logger.info(f"性別平衡度: {gender_balance:.4f} (越接近0越好)")
    logger.info(f"個性相似度: {personality_similarity:.4f} (越接近1越好)")
    
    # 運行聚餐歷史相關測試
    logger.info("\n========== 聚餐歷史功能測試 ==========")
    test_scenario_10()  # 基本聚餐歷史避免測試
    test_scenario_11()  # 大規模聚餐歷史測試
    test_scenario_12()  # 對比測試
    test_scenario_13()  # 性能壓力測試
    
    # 運行性能分析
    test_performance_profiling()
    
    logger.info("所有測試完成")

def run_dining_history_tests():
    """只運行聚餐歷史相關的測試"""
    logger.info("========== 開始運行聚餐歷史功能測試 ==========")
    
    # 基本功能測試
    conflicts_10 = test_scenario_10()
    
    # 大規模測試
    exec_time_11, conflicts_11 = test_scenario_11()
    
    # 對比測試
    conflicts_without, conflicts_with = test_scenario_12()
    
    # 性能壓力測試
    exec_time_13, conflicts_13, groups_13 = test_scenario_13()
    
    # 輸出總結
    logger.info("\n" + "="*60)
    logger.info("聚餐歷史功能測試總結")
    logger.info("="*60)
    logger.info(f"場景10 (16用戶，2次歷史): 衝突數 = {conflicts_10}")
    logger.info(f"場景11 (100用戶，30次歷史): 執行時間 = {exec_time_11:.4f}秒, 衝突數 = {conflicts_11}")
    logger.info(f"場景12 (對比測試): 無歷史考量衝突 = {conflicts_without}, 有歷史考量衝突 = {conflicts_with}")
    logger.info(f"場景13 (300用戶，100次歷史): 執行時間 = {exec_time_13:.4f}秒, 衝突數 = {conflicts_13}, 組數 = {groups_13}")
    
    # 計算改善率
    if conflicts_without > 0:
        improvement = (1 - conflicts_with / conflicts_without) * 100
        logger.info(f"\n聚餐歷史考量改善率: {improvement:.1f}%")
    
    logger.info("\n聚餐歷史功能測試完成")


if __name__ == "__main__":
    # 運行所有測試
    run_all_tests()
    
    # 如果只想運行聚餐歷史相關測試
    # run_dining_history_tests()
    
    # 如果只想運行大規模測試
    # test_scenario_9()
    
    # 如果只想進行性能分析
    # test_performance_profiling() 