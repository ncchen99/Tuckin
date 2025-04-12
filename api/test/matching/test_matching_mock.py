import os
import sys
import uuid
import random
import json
from datetime import datetime
import logging

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
    """模擬批量配對處理流程"""
    logger.info("開始批量配對處理...")
    
    # 1. 獲取所有等待配對的用戶
    waiting_users = mock_db.get_waiting_users()
    if not waiting_users:
        logger.warning("沒有等待配對的用戶")
        return {
            "success": True,
            "message": "沒有需要配對的用戶",
            "matched_groups": 0,
            "remaining_users": 0
        }
    
    logger.info(f"待配對用戶數: {len(waiting_users)}")
    
    # 2. 將所有待配對用戶按性別和人格類型分組
    all_users = {
        'male': {'分析型': [], '功能型': [], '直覺型': [], '個人型': []},
        'female': {'分析型': [], '功能型': [], '直覺型': [], '個人型': []}
    }
    
    for user in waiting_users:
        gender = user.gender
        p_type = user.personality_type
        if p_type in all_users[gender]:
            all_users[gender][p_type].append(user.user_id)
    
    # 打亂用戶順序以確保隨機性
    for gender in all_users:
        for p_type in all_users[gender]:
            random.shuffle(all_users[gender][p_type])
    
    # 人數統計
    male_count = sum(len(users) for users in all_users['male'].values())
    female_count = sum(len(users) for users in all_users['female'].values())
    logger.info(f"待配對男性用戶: {male_count}人")
    logger.info(f"待配對女性用戶: {female_count}人")
    
    # 各類型人數統計
    for p_type in ['分析型', '功能型', '直覺型', '個人型']:
        m_count = len(all_users['male'][p_type])
        f_count = len(all_users['female'][p_type])
        logger.info(f"{p_type}: 男 {m_count}人, 女 {f_count}人")
    
    # 3. 執行配對算法
    result_groups = []
    
    # 步驟 1: 按人格類型優先分配 2男2女 組
    for p_type in ['分析型', '功能型', '直覺型', '個人型']:
        while len(all_users['male'][p_type]) >= 2 and len(all_users['female'][p_type]) >= 2:
            male_users = all_users['male'][p_type][:2]
            female_users = all_users['female'][p_type][:2]
            group_users = male_users + female_users
            
            # 只記錄人格類型，不再存儲到組對象中
            logger.info(f"形成2男2女組，人格類型: {p_type}")
            
            group = MockDBGroup(
                group_id=str(uuid.uuid4()),
                user_ids=group_users,
                male_count=2,
                female_count=2
            )
            result_groups.append(group)
            mock_db.add_group(group)
            
            # 更新用戶狀態
            for user_id in group_users:
                mock_db.update_user_status(user_id, "waiting_confirmation")
            
            all_users['male'][p_type] = all_users['male'][p_type][2:]
            all_users['female'][p_type] = all_users['female'][p_type][2:]
    
    # 步驟 2: 混合人格類型，但保持性別平衡 2男2女
    remaining_male = []
    remaining_female = []
    
    # 收集剩餘的用戶
    for p_type in ['分析型', '功能型', '直覺型', '個人型']:
        remaining_male.extend([(uid, p_type) for uid in all_users['male'][p_type]])
        remaining_female.extend([(uid, p_type) for uid in all_users['female'][p_type]])
    
    # 如果還能形成2男2女組，繼續配對
    while len(remaining_male) >= 2 and len(remaining_female) >= 2:
        # 選擇2名男性和2名女性
        selected_male = remaining_male[:2]
        selected_female = remaining_female[:2]
        
        # 提取用戶ID和人格類型
        male_users = [uid for uid, _ in selected_male]
        female_users = [uid for uid, _ in selected_female]
        group_users = male_users + female_users
        
        # 確定主導人格類型（僅用於記錄）
        personality_counts = {}
        for _, p_type in selected_male + selected_female:
            personality_counts[p_type] = personality_counts.get(p_type, 0) + 1
        
        dominant_personality = max(personality_counts.items(), key=lambda x: x[1])[0]
        logger.info(f"形成混合人格類型的2男2女組，主導人格類型: {dominant_personality}")
        
        group = MockDBGroup(
            group_id=str(uuid.uuid4()),
            user_ids=group_users,
            male_count=2,
            female_count=2
        )
        result_groups.append(group)
        mock_db.add_group(group)
        
        # 更新用戶狀態
        for user_id in group_users:
            mock_db.update_user_status(user_id, "waiting_confirmation")
        
        remaining_male = remaining_male[2:]
        remaining_female = remaining_female[2:]
    
    # 步驟 3: 處理剩餘用戶，按相同人格類型優先配對4人組
    remaining_users = []
    for gender in ['male', 'female']:
        for p_type in ['分析型', '功能型', '直覺型', '個人型']:
            if gender == 'male':
                remaining_users.extend([(uid, p_type, 'male') for uid in all_users[gender][p_type]])
            else:
                remaining_users.extend([(uid, p_type, 'female') for uid in all_users[gender][p_type]])
    
    # 按人格類型分組
    personality_groups = {'分析型': [], '功能型': [], '直覺型': [], '個人型': []}
    for uid, p_type, gender in remaining_users:
        personality_groups[p_type].append((uid, gender))
    
    # 處理每個人格類型組
    for p_type, users in personality_groups.items():
        while len(users) >= 4:
            group_users = [uid for uid, _ in users[:4]]
            
            # 計算性別比例
            genders = [gender for _, gender in users[:4]]
            male_count = genders.count('male')
            female_count = genders.count('female')
            
            logger.info(f"形成單一人格類型的4人組，人格類型: {p_type}，性別比例: {male_count}男{female_count}女")
            
            group = MockDBGroup(
                group_id=str(uuid.uuid4()),
                user_ids=group_users,
                male_count=male_count,
                female_count=female_count
            )
            result_groups.append(group)
            mock_db.add_group(group)
            
            # 更新用戶狀態
            for user_id in group_users:
                mock_db.update_user_status(user_id, "waiting_confirmation")
            
            users = users[4:]
        
        # 保存剩餘不足4人的用戶
        personality_groups[p_type] = users
    
    # 步驟 4: 將所有剩餘用戶混合配對
    all_remaining = []
    for p_type in personality_groups:
        all_remaining.extend([(uid, p_type, gender) for uid, gender in personality_groups[p_type]])
    
    while len(all_remaining) >= 4:
        # 提取用戶信息
        group_infos = all_remaining[:4]
        group_users = [uid for uid, _, _ in group_infos]
        
        # 計算性別比例
        genders = [gender for _, _, gender in group_infos]
        male_count = genders.count('male')
        female_count = genders.count('female')
        
        # 確定主導人格類型（僅用於記錄）
        personality_counts = {}
        for _, p_type, _ in group_infos:
            personality_counts[p_type] = personality_counts.get(p_type, 0) + 1
        
        dominant_personality = max(personality_counts.items(), key=lambda x: x[1])[0]
        logger.info(f"形成混合人格類型的4人組，主導人格類型: {dominant_personality}，性別比例: {male_count}男{female_count}女")
        
        group = MockDBGroup(
            group_id=str(uuid.uuid4()),
            user_ids=group_users,
            male_count=male_count,
            female_count=female_count
        )
        result_groups.append(group)
        mock_db.add_group(group)
        
        # 更新用戶狀態
        for user_id in group_users:
            mock_db.update_user_status(user_id, "waiting_confirmation")
        
        all_remaining = all_remaining[4:]
    
    # 步驟 5: 如果剩餘3人，形成一個不完整組
    if len(all_remaining) == 3:
        # 提取用戶信息
        group_infos = all_remaining
        group_users = [uid for uid, _, _ in group_infos]
        
        # 計算性別比例
        genders = [gender for _, _, gender in group_infos]
        male_count = genders.count('male')
        female_count = genders.count('female')
        
        # 確定主導人格類型（僅用於記錄）
        personality_counts = {}
        for _, p_type, _ in group_infos:
            personality_counts[p_type] = personality_counts.get(p_type, 0) + 1
        
        dominant_personality = max(personality_counts.items(), key=lambda x: x[1])[0]
        logger.info(f"形成3人不完整組，主導人格類型: {dominant_personality}，性別比例: {male_count}男{female_count}女")
        
        group = MockDBGroup(
            group_id=str(uuid.uuid4()),
            user_ids=group_users,
            male_count=male_count,
            female_count=female_count
        )
        result_groups.append(group)
        mock_db.add_group(group)
        
        # 更新用戶狀態
        for user_id in group_users:
            mock_db.update_user_status(user_id, "waiting_confirmation")
        
        all_remaining = []
    
    # 如果還有1-2人，保持等待狀態
    if all_remaining:
        logger.info(f"剩餘 {len(all_remaining)} 人無法配對成組，保持等待狀態")
    
    logger.info(f"配對結果: 共形成 {len(result_groups)} 個組別")
    
    # 計算待配對和已配對的用戶數
    waiting_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_matching")
    matched_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_confirmation")
    
    logger.info(f"配對後狀態: 待配對用戶: {waiting_count}, 已配對用戶: {matched_count}")
    
    return {
        "success": True,
        "message": f"批量配對完成：共創建 {len(result_groups)} 個組別",
        "matched_groups": len(result_groups),
        "remaining_users": waiting_count
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
        
        # 統計組內各人格類型數量（僅作為參考）
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
        
        # 驗證優先級：2男2女 > 同類型4人組 > 不完整組
        if group.male_count == 2 and group.female_count == 2:
            logger.info(f"  組 {group.id} 是理想的2男2女組")
        elif group.male_count + group.female_count == 4:
            logger.info(f"  組 {group.id} 是4人組但性別不均衡")
        else:
            logger.info(f"  組 {group.id} 是不完整組 ({group.male_count + group.female_count}人)")
    
    # 獲取用戶狀態統計
    waiting_confirmation_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_confirmation")
    waiting_matching_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_matching")
    
    logger.info(f"用戶狀態統計:")
    logger.info(f"  等待確認: {waiting_confirmation_count}")
    logger.info(f"  等待配對: {waiting_matching_count}")
    
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
    """場景1: 完美的2男2女同人格類型組合"""
    logger.info("========== 測試場景1: 完美的2男2女同人格類型組合 ==========")
    
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
    """場景2: 性別不平衡的情況"""
    logger.info("========== 測試場景2: 性別不平衡的情況 ==========")
    
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
    """場景3: 缺少某些人格類型的用戶"""
    logger.info("========== 測試場景3: 缺少某些人格類型的用戶 ==========")
    
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
    """場景4: 單一人格類型人數不足4人"""
    logger.info("========== 測試場景4: 單一人格類型人數不足4人 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶
    # 分析型: 1男2女
    user = MockDBUser(str(uuid.uuid4()), "male", "分析型", "分析型男1")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "female", "分析型", "分析型女1")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "female", "分析型", "分析型女2")
    mock_db.add_user(user)
    
    # 功能型: 2男1女
    user = MockDBUser(str(uuid.uuid4()), "male", "功能型", "功能型男1")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "male", "功能型", "功能型男2")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "female", "功能型", "功能型女1")
    mock_db.add_user(user)
    
    # 直覺型: 1男0女
    user = MockDBUser(str(uuid.uuid4()), "male", "直覺型", "直覺型男1")
    mock_db.add_user(user)
    
    # 個人型: 0男1女
    user = MockDBUser(str(uuid.uuid4()), "female", "個人型", "個人型女1")
    mock_db.add_user(user)
    
    # 執行配對
    process_batch_matching()
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景4測試完成")

def test_auto_form_groups():
    """場景5: 自動成桌 - 測試不足4人的情況"""
    logger.info("========== 測試場景5: 自動成桌 - 測試不足4人的情況 ==========")
    
    # 清空模擬數據庫
    mock_db.users = {}
    mock_db.groups = []
    
    # 創建測試用戶
    # 分析型: 1男1女
    user = MockDBUser(str(uuid.uuid4()), "male", "分析型", "分析型男1")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "female", "分析型", "分析型女1")
    mock_db.add_user(user)
    
    # 功能型: 1男1女
    user = MockDBUser(str(uuid.uuid4()), "male", "功能型", "功能型男1")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "female", "功能型", "功能型女1")
    mock_db.add_user(user)
    
    # 直覺型: 1男1女
    user = MockDBUser(str(uuid.uuid4()), "male", "直覺型", "直覺型男1")
    mock_db.add_user(user)
    user = MockDBUser(str(uuid.uuid4()), "female", "直覺型", "直覺型女1")
    mock_db.add_user(user)
    
    # 執行自動成桌配對
    process_auto_form_groups()
    
    # 驗證結果
    verify_matching_results()
    
    logger.info("場景5測試完成")

def process_auto_form_groups():
    """模擬自動成桌流程"""
    logger.info("開始自動成桌處理...")
    
    # 1. 獲取所有等待配對的用戶
    waiting_users = mock_db.get_waiting_users()
    if not waiting_users or len(waiting_users) < 3:
        logger.warning("等待名單中的用戶不足3人，無法自動成桌")
        return {
            "success": True,
            "message": "等待名單中的用戶不足3人，無法自動成桌",
            "created_groups": 0,
            "remaining_users": len(waiting_users) if waiting_users else 0
        }
    
    logger.info(f"待成桌用戶數: {len(waiting_users)}")
    
    # 簡化的成桌邏輯：按3-4人一組分配
    result_groups = []
    available_users = [user.user_id for user in waiting_users]
    random.shuffle(available_users)  # 隨機排序
    
    while len(available_users) >= 3:
        # 決定組大小，優先4人，若剩餘人數為3或7則選3人
        group_size = 3 if len(available_users) == 3 or len(available_users) == 7 else 4
        group_users = available_users[:group_size]
        
        # 獲取主導人格類型（僅用於記錄）
        personality_counts = {}
        for uid in group_users:
            p_type = mock_db.users[uid].personality_type
            personality_counts[p_type] = personality_counts.get(p_type, 0) + 1
        
        dominant_personality = max(personality_counts.items(), key=lambda x: x[1])[0] if personality_counts else "分析型"
        
        # 計算性別比例
        group_male_count = sum(1 for uid in group_users if mock_db.users[uid].gender == 'male')
        group_female_count = group_size - group_male_count
        
        logger.info(f"形成{group_size}人組，主導人格類型: {dominant_personality}，性別比例: {group_male_count}男{group_female_count}女")
        
        group = MockDBGroup(
            group_id=str(uuid.uuid4()),
            user_ids=group_users,
            male_count=group_male_count,
            female_count=group_female_count
        )
        result_groups.append(group)
        mock_db.add_group(group)
        
        # 更新用戶狀態
        for user_id in group_users:
            mock_db.update_user_status(user_id, "waiting_confirmation")
        
        available_users = available_users[group_size:]
    
    logger.info(f"成桌結果: 共形成 {len(result_groups)} 個組別")
    
    # 計算待配對和已配對的用戶數
    waiting_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_matching")
    matched_count = sum(1 for user in mock_db.users.values() if user.status == "waiting_confirmation")
    
    logger.info(f"成桌後狀態: 待配對用戶: {waiting_count}, 已配對用戶: {matched_count}")
    
    return {
        "success": True,
        "message": f"自動成桌完成：共創建 {len(result_groups)} 個組別",
        "created_groups": len(result_groups),
        "remaining_users": waiting_count
    }

def test_scenario_5():
    """場景5: 7個用戶配對 - 會形成一個完整組和一個不完整組"""
    logger.info("========== 測試場景5: 7個用戶配對形成完整組和不完整組 ==========")
    
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
    verify_matching_results()
    
    logger.info("場景5測試完成")

def run_all_tests():
    """運行所有測試"""
    logger.info("開始運行所有配對測試...")
    
    # 運行基本測試
    run_test()
    
    # 運行場景測試
    test_scenario_1()
    test_scenario_2()
    test_scenario_3()
    test_scenario_4()
    test_auto_form_groups()
    test_scenario_5()  # 添加新的測試場景
    
    logger.info("所有測試完成")

if __name__ == "__main__":
    run_all_tests() 