from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from supabase import Client
from typing import List, Optional, Dict, Any, Tuple
import random
from datetime import datetime, timedelta
import logging
from collections import Counter
import itertools
from collections import defaultdict
import json

from schemas.matching import (
    JoinMatchingRequest, JoinMatchingResponse, 
    BatchMatchingResponse, AutoFormGroupsResponse,
    MatchingGroup, MatchingUser, UserMatchingInfo, UserStatusExtended
)
from schemas.dining import DiningUserStatus
from dependencies import get_supabase, get_current_user, get_supabase_service, verify_cron_api_key
from services.notification_service import NotificationService
from utils.dinner_time_utils import DinnerTimeUtils

router = APIRouter()
logger = logging.getLogger(__name__)

# 新增輔助函數，提取重複邏輯
async def update_user_status_to_restaurant(
    supabase: Client, 
    user_id: str, 
    group_id: str, 
    confirmation_deadline: datetime
) -> bool:
    """
    將用戶狀態更新為等待選擇餐廳，並創建或更新配對信息
    """
    try:
        # 更新用戶狀態為等待選擇餐廳
        status_update_resp = supabase.table("user_status").update({
            "status": "waiting_restaurant",
            "updated_at": datetime.now().isoformat()
        }).eq("user_id", user_id).execute()
        
        if not status_update_resp.data:
            logger.warning(f"更新用戶 {user_id} 狀態失敗或用戶狀態不存在")
            # 即使狀態更新失敗，仍嘗試更新配對信息
        
        # 創建或更新配對信息
        matching_info_resp = supabase.table("user_matching_info") \
            .select("id") \
            .eq("user_id", user_id) \
            .execute()
        
        if matching_info_resp.data:
            supabase.table("user_matching_info").update({
                "matching_group_id": group_id,
                "confirmation_deadline": confirmation_deadline.isoformat(),
                "updated_at": datetime.now().isoformat()
            }).eq("id", matching_info_resp.data[0]["id"]).execute()
        else:
            supabase.table("user_matching_info").insert({
                "user_id": user_id,
                "matching_group_id": group_id,
                "confirmation_deadline": confirmation_deadline.isoformat()
            }).execute()
        
        return True
    except Exception as e:
        logger.error(f"更新用戶 {user_id} 狀態或配對信息失敗: {str(e)}")
        return False

async def update_user_status_to_failed(supabase: Client, user_id: str) -> bool:
    """
    將用戶狀態更新為配對失敗。
    """
    try:
        status_update_resp = supabase.table("user_status").update({
            "status": "matching_failed",
            "updated_at": datetime.now().isoformat()
        }).eq("user_id", user_id).execute()
        
        if not status_update_resp.data:
            logger.warning(f"更新用戶 {user_id} 狀態為 matching_failed 失敗或用戶狀態不存在")
            return False
        
        # 清除可能存在的舊配對信息
        supabase.table("user_matching_info") \
            .delete() \
            .eq("user_id", user_id) \
            .execute()
            
        logger.info(f"成功更新用戶 {user_id} 狀態為 matching_failed")
        return True
    except Exception as e:
        logger.error(f"更新用戶 {user_id} 狀態為 matching_failed 失敗: {str(e)}")
        return False

async def send_matching_notification(
    notification_service: NotificationService,
    user_id: str,
    group_id: str,
    deadline: datetime
) -> bool:
    """
    發送配對成功通知
    """
    try:
        # 準備通知數據
        notification_data = {
            "type": "matching_restaurant",
            "group_id": group_id,
            "deadline": deadline.isoformat()
        }
                
        # 發送通知
        await notification_service.send_notification(
            user_id=user_id,
            title="找到了！",
            body=f"成功找到聚餐夥伴，請在明天 6:00 前選擇餐廳",
            data=notification_data
        )
        logger.info(f"成功發送配對通知到用戶 {user_id}")
        return True
    except Exception as ne:
        logger.error(f"發送通知給用戶 {user_id} 失敗: {str(ne)}")
        return False

async def create_matching_group(
    supabase: Client,
    user_group: Dict,
    is_school_only: bool = False
) -> Optional[str]:
    """
    創建配對組並返回組ID
    """
    try:
        logger.info(f"創建組別: {user_group}, 校內專屬: {is_school_only}")
        
        group_response = supabase.table("matching_groups").insert({
            "user_ids": user_group["user_ids"],
            "is_complete": user_group["is_complete"],
            "male_count": user_group["male_count"],
            "female_count": user_group["female_count"],
            "status": "waiting_restaurant",
            "school_only": is_school_only
        }).execute()
        
        if not group_response.data:
            logger.error(f"創建組別失敗: {group_response.error}")
            return None
            
        return group_response.data[0]["id"]
    except Exception as e:
        logger.error(f"創建配對組失敗: {str(e)}")
        return None

@router.post("/batch", response_model=BatchMatchingResponse, status_code=status.HTTP_200_OK, dependencies=[Depends(verify_cron_api_key)])
async def batch_matching(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_service)
):
    """
    批量配對任務（週二 6:00 AM 觸發）
    將所有 waiting_matching 狀態的用戶按4人一組進行分組
    此API僅限授權的Cron任務調用
    """
    # 實際實現會將此邏輯放入背景任務
    background_tasks.add_task(process_batch_matching, supabase)
    return {
        "success": True, 
        "message": "批量配對任務已啟動",
        "matched_groups": None,
        "total_users_processed": None
    }

# 共用的配對邏輯函數
async def _match_users_into_groups(user_data: Dict[str, Dict[str, Any]], supabase: Client) -> List[Dict]:
    """
    根據用戶資料將用戶分組配對，確保所有用戶都被分配，優先4人組，
    剩餘分配至5人組，僅在 N=6,7,11 時允許3人組。

    Args:
        user_data: 格式 {user_id: {"gender": gender, "personality_type": personality_type, "prefer_school_only": bool}}
        supabase: Supabase客戶端實例

    Returns:
        List[Dict]: 結果組別列表
    """
    total_users = len(user_data)
    logger.info(f"開始配對，總人數: {total_users}")
    if total_users == 0:
        return []

    # 按校內偏好分組
    school_only_users = {uid: data for uid, data in user_data.items() if data.get("prefer_school_only", False)}
    mixed_users = {uid: data for uid, data in user_data.items() if not data.get("prefer_school_only", False)}

    # 處理校內專屬用戶
    logger.info(f"處理校內專屬用戶: {len(school_only_users)} 人")
    school_only_groups = await _form_groups_for_subset(school_only_users, is_school_only=True, supabase=supabase)

    # 處理混合配對用戶
    logger.info(f"處理混合配對用戶: {len(mixed_users)} 人")
    mixed_groups = await _form_groups_for_subset(mixed_users, is_school_only=False, supabase=supabase)

    # 合併結果
    all_groups = school_only_groups + mixed_groups
    logger.info(f"總共形成 {len(all_groups)} 個組別")
    return all_groups

async def _form_groups_for_subset(user_data: Dict[str, Dict[str, Any]], is_school_only: bool, supabase: Client) -> List[Dict]:
    """
    為特定子集（校內專屬或混合）的用戶進行分組，加入個性類型匹配。
    """
    if not user_data:
        return []

    # 按性別和個性類型分類用戶
    categorized_users = defaultdict(lambda: defaultdict(list))
    all_user_ids = list(user_data.keys())
    random.shuffle(all_user_ids) # 初始隨機化

    for user_id in all_user_ids:
        data = user_data[user_id]
        gender = data.get('gender')
        p_type = data.get('personality_type')
        if gender and p_type:
            categorized_users[gender][p_type].append(user_id)
        else:
            logger.warning(f"用戶 {user_id} 缺少性別或個性類型，無法參與基於個性的匹配。")
            # 可以考慮將這些用戶放入一個特殊列表，最後隨機分配

    remaining_user_ids = set(all_user_ids) # 使用集合方便移除
    total_users = len(remaining_user_ids)
    result_groups = []

    logger.info(f"開始為 is_school_only={is_school_only} 的 {total_users} 位用戶分組 (考慮個性)")
    
    # 新增：檢查用戶子集數量，如果少於3人，將其狀態更新為 matching_failed
    if total_users < 3:
        logger.warning(f"用戶數 {total_users} 過少，無法在 _form_groups_for_subset 中正常分組 (is_school_only={is_school_only})")
        
        # 更新用戶狀態為 matching_failed
        for user_id in all_user_ids:
            await update_user_status_to_failed(supabase, user_id)
            logger.info(f"用戶 {user_id} 狀態已更新為 matching_failed (子集用戶不足)")
                
        return []

    # 特殊情況處理 N=6, 7, 11
    if total_users == 6:
        logger.info(f"處理特殊情況 N=6：組成兩個 3 人組")
        group1, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3)
        group2, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3)
        if group1: result_groups.append(_create_group_dict(group1, user_data, is_school_only))
        if group2: result_groups.append(_create_group_dict(group2, user_data, is_school_only))
        return result_groups
    elif total_users == 7:
        logger.info(f"處理特殊情況 N=7：組成一個 4 人組和一個 3 人組")
        group4, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 4)
        group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3)
        if group4: result_groups.append(_create_group_dict(group4, user_data, is_school_only))
        if group3: result_groups.append(_create_group_dict(group3, user_data, is_school_only))
        return result_groups
    elif total_users == 11:
        logger.info(f"處理特殊情況 N=11：組成兩個 4 人組和一個 3 人組")
        group1, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 4)
        group2, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 4)
        group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3)
        if group1: result_groups.append(_create_group_dict(group1, user_data, is_school_only))
        if group2: result_groups.append(_create_group_dict(group2, user_data, is_school_only))
        if group3: result_groups.append(_create_group_dict(group3, user_data, is_school_only))
        return result_groups

    # 一般情況處理: 計算需要的 4 人和 5 人組數量
    num_groups_of_4 = 0
    num_groups_of_5 = 0
    if total_users >= 3: # 確保至少3人才能開始計算
        if total_users % 4 == 0:
            num_groups_of_4 = total_users // 4
        elif total_users % 4 == 1:
            if total_users >= 5:
                num_groups_of_4 = (total_users - 5) // 4
                num_groups_of_5 = 1
        elif total_users % 4 == 2:
            if total_users >= 10:
                num_groups_of_4 = (total_users - 10) // 4
                num_groups_of_5 = 2
            elif total_users == 6: # 已處理
                pass
            elif total_users == 2: # 會在 process_batch_matching 處理
                pass
        elif total_users % 4 == 3:
            if total_users >= 15:
                num_groups_of_4 = (total_users - 15) // 4
                num_groups_of_5 = 3
            elif total_users == 11: # 已處理
                pass
            elif total_users == 7: # 已處理
                pass
            elif total_users == 3: # 如果總數恰好是3, 需要組成一個3人組 (雖然一般不期望走到這)
                group3, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 3)
                if group3: result_groups.append(_create_group_dict(group3, user_data, is_school_only))
                return result_groups
            else:
                logger.warning(f"用戶數 {total_users} 過少，無法在 _form_groups_for_subset 中正常分組 (is_school_only={is_school_only})")
                # 理論上 N<3 應在 process_batch_matching 攔截
                return []

    logger.info(f"計劃組成 {num_groups_of_4} 個 4 人組和 {num_groups_of_5} 個 5 人組 (is_school_only={is_school_only})")

    # 組建 4 人組
    for _ in range(num_groups_of_4):
        if len(remaining_user_ids) < 4:
            logger.error("邏輯錯誤：剩餘用戶不足以組成計劃的 4 人組")
            break
        group4, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 4)
        if group4:
            result_groups.append(_create_group_dict(group4, user_data, is_school_only))
        else:
            logger.error("無法找到合適的 4 人組，即使人數足夠")
            # 備用邏輯：隨機選4人？
            if len(remaining_user_ids) >= 4:
                group4 = random.sample(list(remaining_user_ids), 4)
                remaining_user_ids -= set(group4)
                result_groups.append(_create_group_dict(group4, user_data, is_school_only))
                logger.warning("找不到優化的4人組，已隨機選擇4人")
            else: # 人數不足，跳出 (理論上不應發生)
                break

    # 組建 5 人組
    for _ in range(num_groups_of_5):
        if len(remaining_user_ids) < 5:
            logger.error("邏輯錯誤：剩餘用戶不足以組成計劃的 5 人組")
            break
        group5, remaining_user_ids = _find_best_group(remaining_user_ids, user_data, categorized_users, 5)
        if group5:
            result_groups.append(_create_group_dict(group5, user_data, is_school_only))
        else:
            logger.error("無法找到合適的 5 人組，即使人數足夠")
            if len(remaining_user_ids) >= 5:
                group5 = random.sample(list(remaining_user_ids), 5)
                remaining_user_ids -= set(group5)
                result_groups.append(_create_group_dict(group5, user_data, is_school_only))
                logger.warning("找不到優化的5人組，已隨機選擇5人")
            else: # 人數不足，跳出 (理論上不應發生)
                break

    if remaining_user_ids:
        logger.warning(f"配對完成後仍有 {len(remaining_user_ids)} 個用戶剩餘，這不應該發生。剩餘用戶ID: {remaining_user_ids}")
        # 可以考慮將這些用戶強行加入最後一個組或創建新組

    return result_groups

def _calculate_group_score(group_ids: List[str], user_data: Dict[str, Dict[str, Any]]) -> Tuple[int, int, int]:
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

def _find_best_group(remaining_ids_set: set, user_data: Dict[str, Dict[str, Any]], categorized_users: defaultdict, target_size: int) -> Tuple[Optional[List[str]], set]:
    """
    從剩餘用戶中找到最佳的組（基於性別和個性）
    返回 (找到的組ID列表 或 None, 更新後的剩餘用戶ID集合)
    """
    if len(remaining_ids_set) < target_size:
        return None, remaining_ids_set

    # 當用戶數量大於50時，使用啟發式算法
    if len(remaining_ids_set) > 50:
        return _find_best_group_heuristic(remaining_ids_set, user_data, categorized_users, target_size)

    best_group = None
    best_score = (-1, -1, -1) # (性別分, 個性分, size)

    # 迭代所有可能的組合 (如果人數過多，這裡需要優化，例如使用啟發式搜索)
    # 注意：itertools.combinations 對於大數量級非常慢！
    # 實際應用中可能需要限制搜索範圍或使用近似算法
    max_combinations_to_check = 1000 # 限制檢查的組合數量以避免性能問題
    count = 0

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

def _find_best_group_heuristic(remaining_ids_set: set, user_data: Dict[str, Dict[str, Any]], categorized_users: defaultdict, target_size: int) -> Tuple[Optional[List[str]], set]:
    """
    大規模用戶的啟發式最佳組查找算法
    策略：
    1. 根據性別將用戶分組
    2. 根據個性類型進一步分組
    3. 優先從同一個性類型中選擇用戶，同時平衡性別比例
    """
    remaining_ids = list(remaining_ids_set)
    
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
        
        # 選擇所需數量的男性和女性
        selected_males = male_by_type[selected_type][:ideal_male_count]
        selected_females = female_by_type[selected_type][:ideal_female_count]
        
        # 如果選擇的用戶不足，從其他類型中補充
        while len(selected_males) < ideal_male_count and len(males) > len(selected_males):
            for t in sorted_types[1:]:
                if t in male_by_type and male_by_type[t]:
                    selected_males.append(male_by_type[t].pop(0))
                    if len(selected_males) >= ideal_male_count:
                        break
            
            # 如果仍不足，從未考慮的類型中選擇
            if len(selected_males) < ideal_male_count:
                for t in set(male_by_type.keys()) - common_types:
                    if male_by_type[t]:
                        selected_males.append(male_by_type[t].pop(0))
                        if len(selected_males) >= ideal_male_count:
                            break
            
            # 如果所有類型都檢查過了但仍不足
            if len(selected_males) < ideal_male_count:
                # 使用隨機選擇
                remaining_males = list(set(males) - set(selected_males))
                if remaining_males:
                    selected_males.append(random.choice(remaining_males))
                else:
                    break
        
        # 對女性也執行相同的邏輯
        while len(selected_females) < ideal_female_count and len(females) > len(selected_females):
            for t in sorted_types[1:]:
                if t in female_by_type and female_by_type[t]:
                    selected_females.append(female_by_type[t].pop(0))
                    if len(selected_females) >= ideal_female_count:
                        break
            
            if len(selected_females) < ideal_female_count:
                for t in set(female_by_type.keys()) - common_types:
                    if female_by_type[t]:
                        selected_females.append(female_by_type[t].pop(0))
                        if len(selected_females) >= ideal_female_count:
                            break
            
            if len(selected_females) < ideal_female_count:
                remaining_females = list(set(females) - set(selected_females))
                if remaining_females:
                    selected_females.append(random.choice(remaining_females))
                else:
                    break
        
        best_group = selected_males + selected_females
    else:
        # 如果沒有共同的類型，隨機選擇
        random.shuffle(males)
        random.shuffle(females)
        best_group = males[:ideal_male_count] + females[:ideal_female_count]
    
    # 如果人數不足，返回None
    if len(best_group) < target_size:
        return None, remaining_ids_set
    
    # 更新剩餘用戶ID集合
    remaining_ids_set -= set(best_group)
    
    return best_group, remaining_ids_set

def _create_group_dict(user_ids: List[str], user_data: Dict[str, Dict[str, Any]], is_school_only: bool) -> Dict:
    """
    根據用戶ID列表和用戶數據創建組別字典
    """
    male_count = sum(1 for uid in user_ids if user_data[uid]['gender'] == 'male')
    female_count = len(user_ids) - male_count
    return {
        "user_ids": user_ids,
        "is_complete": len(user_ids) >= 4, # 3人組也標記為 incomplete?
        "male_count": male_count,
        "female_count": female_count,
        "school_only": is_school_only # 根據傳入參數設定
    }

async def _save_matching_groups_to_db(
    supabase: Client, 
    result_groups: List[Dict], 
    notification_service: NotificationService,
    confirm_deadline: datetime
) -> Tuple[int, int]:
    """
    將配對結果保存到數據庫，更新用戶狀態，發送通知 (已重構)
    """
    created_groups = 0
    total_matched_users = 0
    
    for group in result_groups:
        # 檢查組別是否為校內專屬組
        user_ids = group["user_ids"]
        is_school_only = False
        
        # 獲取組內用戶的配對偏好
        if user_ids:
            preference_response = supabase.table("user_matching_preferences") \
                .select("user_id, prefer_school_only") \
                .in_("user_id", user_ids) \
                .execute()
            
            # 如果所有用戶都是校內專屬配對，則設置群組為校內專屬
            if preference_response.data:
                all_school_only = True
                for pref in preference_response.data:
                    if not pref.get("prefer_school_only", False):
                        all_school_only = False
                        break
                
                is_school_only = all_school_only
        
        # 創建分組記錄 (使用輔助函數)
        group_id = await create_matching_group(supabase, group, is_school_only)
        
        if not group_id:
            logger.error(f"未能為用戶 {user_ids} 創建組別，跳過此組")
            continue
            
        created_groups += 1
        total_matched_users += len(group["user_ids"])
        
        # 更新用戶狀態和發送通知 (使用輔助函數)
        for user_id in group["user_ids"]:
            update_success = await update_user_status_to_restaurant(
                supabase, user_id, group_id, confirm_deadline
            )
            if update_success:
                await send_matching_notification(
                    notification_service, user_id, group_id, confirm_deadline
                )
            else:
                 logger.warning(f"更新用戶 {user_id} 加入組別 {group_id} 的狀態失敗")
        
        # 為群組推薦餐廳
        try:
            await recommend_restaurants_for_group(supabase, group_id, group["user_ids"])
        except Exception as e:
            logger.error(f"為群組 {group_id} 推薦餐廳時出錯: {str(e)}")
    
    return created_groups, total_matched_users

async def _get_waiting_users_data(supabase: Client, waiting_status: str = "waiting_matching") -> Tuple[List[str], Dict[str, Dict[str, str]], int]:
    """
    獲取等待配對的用戶資料
    
    Args:
        supabase: Supabase客戶端
        waiting_status: 查詢的等待狀態
        
    Returns:
        Tuple[List[str], Dict[str, Dict[str, str]], int]: 返回 (待配對用戶ID列表, 用戶詳細資料, 有效用戶數量)
    """
    # 獲取所有指定狀態的用戶
    logger.info(f"查詢{waiting_status}狀態的用戶")
    
    users_response = supabase.table("user_status") \
        .select("id, user_id, status") \
        .eq("status", waiting_status) \
        .execute()
    
    if not users_response.data or len(users_response.data) == 0:
        logger.warning(f"沒有{waiting_status}的用戶")
        return [], {}, 0
    
    waiting_user_ids = [user["user_id"] for user in users_response.data]
    logger.info(f"待配對用戶ID: {waiting_user_ids}")
    
    # 獲取這些用戶的個人資料（性別和人格類型）
    profiles_response = supabase.table("user_profiles") \
        .select("user_id, gender") \
        .in_("user_id", waiting_user_ids) \
        .execute()
    
    personality_response = supabase.table("user_personality_results") \
        .select("user_id, personality_type") \
        .in_("user_id", waiting_user_ids) \
        .execute()
    
    # 獲取用戶配對偏好 - 是否只想與校內同學配對
    preference_response = supabase.table("user_matching_preferences") \
        .select("user_id, prefer_school_only") \
        .in_("user_id", waiting_user_ids) \
        .execute()
    
    # 檢查是否找到用戶資料
    if not profiles_response.data or not personality_response.data:
        logger.warning("無法獲取用戶資料或人格類型")
        return waiting_user_ids, {}, 0
    
    # 合併用戶數據
    user_data = {}
    for profile in profiles_response.data:
        user_id = profile["user_id"]
        gender = profile["gender"]
        user_data[user_id] = {
            "gender": gender, 
            "personality_type": None,
            "prefer_school_only": False  # 默認值為False
        }
    
    for result in personality_response.data:
        user_id = result["user_id"]
        if user_id in user_data:
            user_data[user_id]["personality_type"] = result["personality_type"]
    
    # 添加配對偏好資料
    if preference_response.data:
        for pref in preference_response.data:
            user_id = pref["user_id"]
            if user_id in user_data:
                user_data[user_id]["prefer_school_only"] = pref["prefer_school_only"]
    
    # 記錄有效用戶數量
    valid_users = [uid for uid, data in user_data.items() 
                  if data["gender"] and data["personality_type"]]
    logger.info(f"有效用戶數: {len(valid_users)}/{len(waiting_user_ids)}")
    
    return waiting_user_ids, user_data, len(valid_users)

async def process_batch_matching(supabase: Client):
    """批量配對處理邏輯"""
    try:
        # 1. 獲取等待配對的用戶資料
        waiting_user_ids, user_data, valid_user_count = await _get_waiting_users_data(supabase)
        
        # 新增：處理人數不足的情況
        if valid_user_count < 3:
            logger.warning(f"等待用戶不足 3 人 ({valid_user_count} 人)，無法進行配對。")
            # 更新這些用戶的狀態為 matching_failed
            failed_update_count = 0
            for user_id in waiting_user_ids: # 使用 waiting_user_ids 而不是 valid_user_count 的 ID
                if user_id in user_data: # 確保是有效用戶才更新
                     if await update_user_status_to_failed(supabase, user_id):
                         failed_update_count += 1
            
            return {
                "success": False,
                "message": f"等待用戶不足 3 人 ({valid_user_count} 人)，配對失敗。已更新 {failed_update_count} 位用戶狀態。",
                "matched_groups": 0,
                "total_users_processed": valid_user_count
            }
        
        if valid_user_count == 0:
            logger.warning("沒有足夠的用戶資料進行配對")
            return {
                "success": False,
                "message": "沒有足夠的用戶資料進行配對",
                "matched_groups": 0,
                "total_users_processed": len(waiting_user_ids)
            }
        
        # 2. 執行配對算法 (確保所有人都被分組)
        result_groups = await _match_users_into_groups(user_data, supabase)
        
        logger.info(f"配對結果: 共形成 {len(result_groups)} 個組別")
        
        # 3. 將結果保存到數據庫
        notification_service = NotificationService(use_service_role=True)
        created_groups, total_matched_users = await _save_matching_groups_to_db(supabase, result_groups, notification_service, datetime.now() + timedelta(hours=24))
        
        result_message = f"批量配對完成：共創建 {created_groups} 個組別"
        logger.info(result_message)
        
        # 計算未配對用戶數量
        unmatched_user_ids = set(waiting_user_ids)
        for group in result_groups:
            for user_id in group["user_ids"]:
                if user_id in unmatched_user_ids:
                    unmatched_user_ids.remove(user_id)
        
        # 新增：更新未配對用戶的狀態為 matching_failed
        if unmatched_user_ids:
            logger.warning(f"有 {len(unmatched_user_ids)} 名用戶未能被配對，將更新為 matching_failed")
            failed_update_count = 0
            for user_id in unmatched_user_ids:
                if await update_user_status_to_failed(supabase, user_id):
                    failed_update_count += 1
            logger.info(f"已將 {failed_update_count}/{len(unmatched_user_ids)} 名未配對用戶的狀態更新為 matching_failed")
            
        # 更新訊息
        if unmatched_user_ids:
            result_message += f"，{len(unmatched_user_ids)} 名用戶因子集人數不足未能配對"
        
        # 返回配對結果
        return {
            "success": True,
            "message": result_message,
            "matched_groups": created_groups,
            "total_users_processed": total_matched_users
        }
        
    except Exception as e:
        error_message = f"批量配對處理錯誤: {str(e)}"
        logger.error(error_message)
        return {
            "success": False,
            "message": error_message,
            "matched_groups": 0,
            "total_users_processed": None
        }

# 在文件末尾添加餐廳推薦相關函數
async def recommend_restaurants_for_group(supabase: Client, group_id: str, user_ids: List[str]) -> bool:
    """
    為群組推薦餐廳並保存到restaurant_votes表
    
    基於群組成員的食物偏好和餐廳營業時間，推薦2家餐廳
    """
    try:
        logger.info(f"為群組 {group_id} 推薦餐廳")
        
        # 1. 獲取群組成員的食物偏好
        food_preferences = await get_group_food_preferences(supabase, user_ids)
        if not food_preferences:
            logger.warning(f"無法獲取群組 {group_id} 成員的食物偏好")
            return False
        
        # 2. 獲取聚餐時間資訊
        dinner_time_info = DinnerTimeUtils.calculate_dinner_time_info()
        dinner_time = dinner_time_info.next_dinner_time
        dinner_weekday = dinner_time.weekday()  # 0=星期一, 6=星期日
        dinner_hour = dinner_time.hour
        dinner_minute = dinner_time.minute
        
        logger.info(f"聚餐時間: {dinner_time.strftime('%Y-%m-%d %H:%M')}, 星期{dinner_weekday+1}, 時間: {dinner_hour}:{dinner_minute}")
            
        # 3. 根據偏好和營業時間選擇兩家餐廳
        recommended_restaurants = await select_recommended_restaurants(
            supabase, 
            food_preferences,
            dinner_weekday,
            dinner_hour,
            dinner_minute
        )
        
        if not recommended_restaurants or len(recommended_restaurants) == 0:
            logger.warning(f"無法為群組 {group_id} 推薦餐廳")
            return False
            
        # 4. 將推薦餐廳保存到restaurant_votes表
        for restaurant_id in recommended_restaurants:
            # 檢查是否已存在記錄
            existing_vote = supabase.table("restaurant_votes") \
                .select("id") \
                .eq("group_id", group_id) \
                .eq("restaurant_id", restaurant_id) \
                .is_("user_id", "null") \
                .eq("is_system_recommendation", True) \
                .execute()
                
            if existing_vote.data and len(existing_vote.data) > 0:
                logger.info(f"餐廳 {restaurant_id} 已經推薦給群組 {group_id}")
                continue
                
            # 插入推薦記錄
            supabase.table("restaurant_votes").insert({
                "restaurant_id": restaurant_id,
                "group_id": group_id,
                "user_id": None,  # 系統推薦不關聯用戶
                "is_system_recommendation": True,
                "created_at": datetime.now().isoformat()
            }).execute()
            
            logger.info(f"成功為群組 {group_id} 推薦餐廳 {restaurant_id}")
        
        return True
        
    except Exception as e:
        logger.error(f"推薦餐廳時出錯: {str(e)}")
        return False

async def get_group_food_preferences(supabase: Client, user_ids: List[str]) -> Dict[str, int]:
    """
    獲取群組成員的食物偏好並匯總
    返回格式: {'台灣料理': 3, '日式料理': 2, ...}
    """
    try:
        # 查詢用戶的食物偏好
        preferences_response = supabase.table("user_food_preferences") \
            .select("user_id, preference_id") \
            .in_("user_id", user_ids) \
            .execute()
            
        if not preferences_response.data:
            return {}
            
        # 獲取偏好ID列表
        preference_ids = [pref["preference_id"] for pref in preferences_response.data]
        
        # 查詢偏好對應的類別
        categories_response = supabase.table("food_preferences") \
            .select("id, name") \
            .in_("id", preference_ids) \
            .execute()
            
        if not categories_response.data:
            return {}
            
        # 創建ID到類別名稱的映射
        id_to_category = {item["id"]: item["name"] for item in categories_response.data}
        
        # 統計每個類別的偏好計數
        preferences_counter = Counter()
        for pref in preferences_response.data:
            pref_id = pref["preference_id"]
            if pref_id in id_to_category:
                preferences_counter[id_to_category[pref_id]] += 1
                
        return dict(preferences_counter)
        
    except Exception as e:
        logger.error(f"獲取群組食物偏好時出錯: {str(e)}")
        return {}

async def select_recommended_restaurants(
    supabase: Client, 
    food_preferences: Dict[str, int],
    dinner_weekday: int,
    dinner_hour: int,
    dinner_minute: int,
    limit: int = 2
) -> List[str]:
    """
    基於食物偏好和營業時間選擇推薦餐廳
    
    策略:
    1. 過濾聚餐時間有營業的餐廳
    2. 如果有共同偏好，優先選擇符合最受歡迎類別的餐廳
    3. 如果偏好多樣化，選擇覆蓋多數用戶偏好的餐廳
    4. 如果沒有偏好資料，隨機選擇營業中的餐廳
    """
    try:
        # 調整星期幾的表示方式，使其與 Google Places API 一致 (0=星期日, 6=星期六)
        google_weekday = (dinner_weekday + 1) % 7
        logger.info(f"聚餐時間：星期 {google_weekday}，{dinner_hour}:{dinner_minute}")
        
        # 查詢所有餐廳並檢查營業時間
        all_restaurants = supabase.table("restaurants") \
            .select("id, name, category, business_hours") \
            .execute()
            
        if not all_restaurants.data:
            logger.warning("找不到任何餐廳")
            return []
            
        # 過濾出營業中的餐廳
        open_restaurants = []
        for restaurant in all_restaurants.data:
            restaurant_id = restaurant["id"]
            restaurant_name = restaurant["name"]
            business_hours = restaurant.get("business_hours")
            
            if is_restaurant_open(business_hours, google_weekday, dinner_hour, dinner_minute):
                open_restaurants.append(restaurant)
                logger.info(f"餐廳 {restaurant_name} 在聚餐時間營業")
            else:
                logger.info(f"餐廳 {restaurant_name} 在聚餐時間不營業")
                
        if not open_restaurants:
            logger.warning("找不到聚餐時間營業的餐廳")
            return []
            
        # 如果沒有偏好資料，隨機選擇營業中的餐廳
        if not food_preferences:
            random.shuffle(open_restaurants)
            return [r["id"] for r in open_restaurants[:limit]]
        
        # 按偏好度排序類別
        sorted_preferences = sorted(food_preferences.items(), key=lambda x: x[1], reverse=True)
        
        # 選擇排名前 limit*2 的類別，增加多樣性
        top_categories = [category for category, _ in sorted_preferences[:limit*2]]
        
        if not top_categories:
            # 如果沒有類別偏好，隨機選擇營業中的餐廳
            random.shuffle(open_restaurants)
            return [r["id"] for r in open_restaurants[:limit]]
            
        # 從營業中的餐廳和偏好類別中選擇推薦
        recommended_ids = []
        for category in top_categories:
            if len(recommended_ids) >= limit:
                break
                
            # 從營業中的餐廳中查找符合類別的餐廳
            category_restaurants = [r for r in open_restaurants if r.get("category") == category]
            
            if category_restaurants:
                # 隨機選擇一家符合條件的餐廳
                restaurant = random.choice(category_restaurants)
                restaurant_id = restaurant["id"]
                if restaurant_id not in recommended_ids:
                    recommended_ids.append(restaurant_id)
        
        # 如果推薦不足，從其他營業中的餐廳中隨機補充
        if len(recommended_ids) < limit:
            remaining = limit - len(recommended_ids)
            
            # 排除已選擇的餐廳
            remaining_restaurants = [r for r in open_restaurants if r["id"] not in recommended_ids]
            random.shuffle(remaining_restaurants)
            
            for i in range(min(remaining, len(remaining_restaurants))):
                recommended_ids.append(remaining_restaurants[i]["id"])
        
        return recommended_ids
        
    except Exception as e:
        logger.error(f"選擇推薦餐廳時出錯: {str(e)}")
        return []

def is_restaurant_open(business_hours_json, weekday, hour, minute):
    """
    檢查餐廳在指定時間是否營業
    
    Args:
        business_hours_json: 餐廳營業時間的JSON字符串或物件
        weekday: 星期幾 (0=星期日, 6=星期六)
        hour: 小時 (0-23)
        minute: 分鐘 (0-59)
        
    Returns:
        bool: 餐廳是否營業
    """
    try:
        # 如果沒有營業時間數據，預設為營業
        if not business_hours_json:
            return True
            
        # 嘗試解析營業時間數據
        business_hours = None
        if isinstance(business_hours_json, str):
            # 檢查是否是已經使用單引號的dict字符串，這種情況在Python中不是有效的JSON
            if business_hours_json.startswith('{') and business_hours_json.endswith('}'):
                try:
                    # 嘗試通過eval安全地將字符串轉換為字典
                    # 注意：在生產環境中應謹慎使用eval
                    business_hours = eval(business_hours_json)
                except Exception:
                    # 如果eval失敗，嘗試將單引號替換為雙引號後解析JSON
                    try:
                        import re
                        # 將字符串中的單引號替換為雙引號，但忽略已在雙引號內的單引號
                        # 這是一個簡化的方法，可能不適用於所有情況
                        corrected_json = re.sub(r"(\w+):'([^']*)'", r'"\1":"\2"', business_hours_json)
                        corrected_json = corrected_json.replace("'", '"')
                        business_hours = json.loads(corrected_json)
                    except Exception:
                        logger.warning(f"無法解析營業時間數據: {business_hours_json}")
                        return True
            else:
                try:
                    business_hours = json.loads(business_hours_json)
                except json.JSONDecodeError:
                    logger.warning(f"無法解析營業時間數據: {business_hours_json}")
                    return True
        else:
            # 已經是字典或其他對象
            business_hours = business_hours_json
            
        # 如果沒有periods字段，預設為營業
        if not isinstance(business_hours, dict) or "periods" not in business_hours:
            return True
            
        # 檢查當天是否有營業時間安排
        for period in business_hours["periods"]:
            # 檢查是否為當天營業
            if "open" in period and "day" in period["open"] and period["open"]["day"] == weekday:
                opening_hour = period["open"].get("hour", 0)
                opening_minute = period["open"].get("minute", 0)
                
                # 確保close數據存在
                if "close" not in period:
                    continue
                    
                closing_hour = period["close"].get("hour", 23)
                closing_minute = period["close"].get("minute", 59)
                
                # 現在時間轉換為分鐘表示
                current_time_in_minutes = hour * 60 + minute
                opening_time_in_minutes = opening_hour * 60 + opening_minute
                closing_time_in_minutes = closing_hour * 60 + closing_minute
                
                # 檢查是否在營業時間內
                if opening_time_in_minutes <= current_time_in_minutes < closing_time_in_minutes:
                    return True
                    
        # 如果沒有找到匹配的營業時間段，則視為不營業
        return False
        
    except Exception as e:
        logger.error(f"檢查餐廳營業時間出錯: {str(e)}")
        # 出錯時預設為營業，避免篩選掉太多餐廳
        return True 