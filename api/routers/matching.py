from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from supabase import Client
from typing import List, Optional, Dict, Any, Tuple
import random
from datetime import datetime, timedelta
import logging
from collections import Counter

from schemas.matching import (
    JoinMatchingRequest, JoinMatchingResponse, 
    BatchMatchingResponse, AutoFormGroupsResponse,
    MatchingGroup, MatchingUser, UserMatchingInfo, UserStatusExtended
)
from schemas.dining import DiningUserStatus
from dependencies import get_supabase, get_current_user, get_supabase_service, verify_cron_api_key
from services.notification_service import NotificationService

router = APIRouter()
logger = logging.getLogger(__name__)

# 新增輔助函數，提取重複邏輯
async def update_user_status_to_confirmation(
    supabase: Client, 
    user_id: str, 
    group_id: str, 
    confirmation_deadline: datetime
) -> bool:
    """
    將用戶狀態更新為等待確認，並創建或更新配對信息
    """
    try:
        # 更新用戶狀態為等待確認
        status_update_resp = supabase.table("user_status").update({
            "status": "waiting_confirmation",
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
            "type": "matching_confirmation",
            "group_id": group_id,
            "deadline": deadline.isoformat()
        }
        
        # 格式化時間字符串
        confirmation_deadline_str = deadline.strftime('%a %H:%M')
        
        # 發送通知
        await notification_service.send_notification(
            user_id=user_id,
            title="找到了！",
            body=f"成功找到聚餐夥伴，請在 {confirmation_deadline_str} 前確認",
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
            "status": "waiting_confirmation",
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
        "remaining_users": None
    }

@router.post("/join", response_model=JoinMatchingResponse)
async def join_matching(
    request: JoinMatchingRequest,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    用戶參加聚餐配對
    嘗試將用戶補入不足4人的桌位或嘗試與等待中的用戶組成新桌位，否則進入等待名單
    """
    # 使用JWT令牌中的用戶ID
    user_id = current_user.user.id
    
    # 1. 檢查用戶是否已在等待或已配對
    status_response = supabase.table("user_status_extended") \
        .select("id, user_id, status, group_id, confirmation_deadline") \
        .eq("user_id", user_id) \
        .execute()
    
    # 如果用戶已有狀態記錄且正在進行中
    if status_response.data:
        user_status = status_response.data[0]
        current_status = user_status["status"]
        
        # 如果用戶已在等待或已配對，返回當前狀態
        if current_status in ["waiting_matching", "waiting_confirmation", "waiting_other_users"]:
            return {
                "status": current_status,
                "message": f"您已在{current_status}狀態中",
                "group_id": user_status.get("group_id"),
                "deadline": user_status.get("confirmation_deadline")
            }
    
    # 2. 獲取用戶的配對偏好
    preference_response = supabase.table("user_matching_preferences") \
        .select("prefer_school_only") \
        .eq("user_id", user_id) \
        .execute()
    
    prefer_school_only = False
    if preference_response.data and len(preference_response.data) > 0:
        prefer_school_only = preference_response.data[0].get("prefer_school_only", False)
    
    # 3. 查找不足4人的桌位
    incomplete_groups_query = supabase.table("matching_groups") \
        .select("id, user_ids, male_count, female_count, is_complete, school_only") \
        .eq("is_complete", False) \
        .eq("status", "waiting_confirmation")
    
    # 如果用戶只願意與校內同學配對，則只查找校內專屬的組別
    if prefer_school_only:
        incomplete_groups_query = incomplete_groups_query.eq("school_only", True)
    
    # 執行查詢
    incomplete_groups_response = incomplete_groups_query.execute()
    
    # 4. 獲取用戶個人資料（性別）
    profile_response = supabase.table("user_profiles") \
        .select("gender") \
        .eq("user_id", user_id) \
        .execute()
    
    if not profile_response.data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="無法獲取用戶個人資料"
        )
    
    gender = profile_response.data[0]["gender"]
    
    # 5. 查找適合的不完整組別
    joined_group = None
    joined_group_id = None
    
    if incomplete_groups_response.data:
        # 計算加入後性別比例最平衡的群組
        best_group = None
        best_balance_score = float('inf')  # 較小的分數表示更平衡
        
        for group in incomplete_groups_response.data:
            user_ids = group["user_ids"] or []
            group_id = group["id"]
            
            # 檢查用戶是否已在該組
            if user_id in user_ids:
                # 用戶已在此組，直接返回已加入的狀態
                return {
                    "status": "waiting_confirmation",
                    "message": "您已加入該聚餐小組",
                    "group_id": group_id,
                    "deadline": None  # 需要從資料庫查詢
                }
            
            # 計算加入後的性別比例
            male_count = group["male_count"] + (1 if gender == "male" else 0)
            female_count = group["female_count"] + (1 if gender == "female" else 0)
            total_count = len(user_ids) + 1
            
            # 計算性別平衡分數 (|男性比例-50%| 越接近0越平衡)
            if total_count > 0:
                male_percentage = (male_count / total_count) * 100
                balance_score = abs(male_percentage - 50)
                
                # 如果找到更平衡的群組，更新最佳選擇
                if balance_score < best_balance_score:
                    best_balance_score = balance_score
                    best_group = group
        
        # 使用選出的最佳群組
        if best_group:
            group = best_group
            group_id = group["id"]
            user_ids = group["user_ids"] or []  # 確保是列表
            
            # 更新組別信息
            user_ids.append(user_id)
            is_complete = len(user_ids) >= 4
            male_count = group["male_count"] + (1 if gender == "male" else 0)
            female_count = group["female_count"] + (1 if gender == "female" else 0)
            
            # 更新組別
            update_group_resp = supabase.table("matching_groups").update({
                "user_ids": user_ids,
                "is_complete": is_complete,
                "male_count": male_count,
                "female_count": female_count,
                "updated_at": datetime.now().isoformat()
            }).eq("id", group_id).execute()

            if update_group_resp.data:
                joined_group = True
                joined_group_id = group_id
            else:
                logger.error(f"更新組別 {group_id} 失敗: {update_group_resp.error}")
                # 可能需要處理更新失敗的情況，例如將用戶放入等待列表
    
    # 6. 更新用戶狀態
    if joined_group and joined_group_id:
        # 用戶需在七小時內確認
        confirmation_deadline = datetime.now() + timedelta(hours=7)
        
        # 更新用戶狀態和配對信息 (使用輔助函數)
        update_success = await update_user_status_to_confirmation(
            supabase, user_id, joined_group_id, confirmation_deadline
        )
        
        if not update_success:
            # 如果狀態更新失敗，可能需要一些回滾或錯誤處理邏輯
            logger.error(f"未能成功更新用戶 {user_id} 加入組別 {joined_group_id} 的狀態")
            # 暫時返回錯誤或讓用戶進入等待狀態？取決於業務需求
            # 此處暫時維持原流程，但記錄錯誤

        # 發送配對成功通知 (使用輔助函數)
        notification_service = NotificationService(use_service_role=True) # 使用服務角色
        await send_matching_notification(
            notification_service, user_id, joined_group_id, confirmation_deadline
        )
        
        # 返回成功加入組別的響應
        return {
            "status": "waiting_confirmation",
            "message": "您已被分配到桌位，請在七小時內確認參加",
            "group_id": joined_group_id,
            "deadline": confirmation_deadline
        }
    else:
        # 如果沒有適合的組別
        # 查找其他等待配對的用戶，嘗試組成新桌位
        waiting_user_ids, waiting_user_data, valid_waiting_count = await _get_waiting_users_data(supabase)
        
        # 將當前用戶添加到等待用戶數據中
        if valid_waiting_count > 0:
            waiting_user_data[user_id] = {
                "gender": gender,
                "personality_type": None,
                "prefer_school_only": prefer_school_only
            }
            
            # 獲取用戶的人格類型
            personality_response = supabase.table("user_personality_results") \
                .select("personality_type") \
                .eq("user_id", user_id) \
                .execute()
                
            if personality_response.data and len(personality_response.data) > 0:
                waiting_user_data[user_id]["personality_type"] = personality_response.data[0].get("personality_type")
                
            # 如果等待用戶數 >= 3 (包括當前用戶)
            if valid_waiting_count >= 2 and waiting_user_data[user_id]["personality_type"]:
                logger.info(f"嘗試與等待中的用戶組成新桌位，等待用戶數：{valid_waiting_count}")
                
                # 使用現有的配對算法將用戶分組
                matched_groups, remaining = await _match_users_into_groups(waiting_user_data)
                
                if matched_groups:
                    # 檢查當前用戶是否在任何一個組中
                    user_matched = False
                    user_group = None
                    
                    for group in matched_groups:
                        if user_id in group["user_ids"]:
                            user_matched = True
                            user_group = group
                            break
                    
                    if user_matched and user_group:
                        # 保存配對結果到數據庫
                        notification_service = NotificationService(use_service_role=True)
                        confirmation_deadline = datetime.now() + timedelta(hours=7)
                        
                        # 創建分組記錄
                        is_school_only = prefer_school_only
                        if user_group["user_ids"]:
                            preference_response = supabase.table("user_matching_preferences") \
                                .select("user_id, prefer_school_only") \
                                .in_("user_id", user_group["user_ids"]) \
                                .execute()
                            
                            # 如果所有用戶都是校內專屬配對，則設置群組為校內專屬
                            if preference_response.data:
                                all_school_only = True
                                for pref in preference_response.data:
                                    if not pref.get("prefer_school_only", False):
                                        all_school_only = False
                                        break
                                
                                is_school_only = all_school_only
                        
                        logger.info(f"與等待中的用戶成功配對，創建新組別：{user_group}")
                        
                        group_id = await create_matching_group(supabase, user_group, is_school_only)
                        
                        if group_id:
                            # 更新所有用戶的狀態
                            for uid in user_group["user_ids"]:
                                update_success = await update_user_status_to_confirmation(
                                    supabase, uid, group_id, confirmation_deadline
                                )
                                if update_success:
                                    # 發送配對成功通知
                                    await send_matching_notification(
                                        notification_service, uid, group_id, confirmation_deadline
                                    )
                                else:
                                    logger.warning(f"更新用戶 {uid} 加入新組別 {group_id} 的狀態失敗")
                            
                            # 嘗試為群組推薦餐廳
                            try:
                                await recommend_restaurants_for_group(supabase, group_id, user_group["user_ids"])
                            except Exception as e:
                                logger.error(f"為群組 {group_id} 推薦餐廳時出錯: {str(e)}")
                            
                            # 返回配對成功的響應
                            return {
                                "status": "waiting_confirmation",
                                "message": "您已被分配到桌位，請在七小時內確認參加",
                                "group_id": group_id,
                                "deadline": confirmation_deadline
                            }
                        else:
                            logger.error("創建新組別失敗，將用戶放入等待列表")
        
        # 如果無法立即配對，將用戶加入等待名單
        # 檢查或創建用戶狀態
        user_status_resp = supabase.table("user_status") \
            .select("id") \
            .eq("user_id", user_id) \
            .execute()
        
        # 更新用戶狀態為等待配對
        if user_status_resp.data:
            supabase.table("user_status").update({
                "status": "waiting_matching",
                "updated_at": datetime.now().isoformat()
            }).eq("id", user_status_resp.data[0]["id"]).execute()
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="用戶資料不存在"
            )
        
        # 清除任何之前的配對信息
        supabase.table("user_matching_info") \
            .delete() \
            .eq("user_id", user_id) \
            .execute()
        
        # 返回加入等待名單的響應
    return {
            "status": "waiting_matching",
        "message": "您已加入聚餐配對等待名單",
        "group_id": None,
        "deadline": None
    }

@router.post("/auto-form", response_model=AutoFormGroupsResponse, status_code=status.HTTP_200_OK, dependencies=[Depends(verify_cron_api_key)])
async def auto_form_groups(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_service)
):
    """
    自動成桌任務（週三 06:00 AM 觸發）
    若等待名單中用戶數≥3人，自動組成新桌位
    此API僅限授權的Cron任務調用
    [未來可能會視情況移除]
    """
    # 實際實現會將此邏輯放入背景任務
    background_tasks.add_task(process_auto_form_groups, supabase)
    return {
        "success": True, 
        "message": "自動成桌任務已啟動",
        "created_groups": None,
        "remaining_users": None
    }

# 共用的配對邏輯函數
async def _match_users_into_groups(user_data: Dict[str, Dict[str, str]]) -> Tuple[List[Dict], List[Tuple]]:
    """
    根據用戶資料將用戶分組配對
    
    Args:
        user_data: 格式 {user_id: {"gender": gender, "personality_type": personality_type, "prefer_school_only": bool}}
        
    Returns:
        Tuple[List[Dict], List[Tuple]]: 返回 (結果組別, 剩餘未配對用戶)
    """
    # 首先按照校內配對偏好將用戶分為兩組
    school_only_users = {}
    mixed_users = {}
    
    for user_id, data in user_data.items():
        if data.get("prefer_school_only", False):
            school_only_users[user_id] = data
        else:
            mixed_users[user_id] = data
    
    logger.info(f"僅校內配對用戶數: {len(school_only_users)}, 混合配對用戶數: {len(mixed_users)}")
    
    # 按性別和人格類型分組 - 對校內專屬配對用戶
    school_only_by_type = {
        'male': {'分析型': [], '功能型': [], '直覺型': [], '個人型': []},
        'female': {'分析型': [], '功能型': [], '直覺型': [], '個人型': []}
    }
    
    # 按性別和人格類型分組 - 對混合配對用戶
    mixed_by_type = {
        'male': {'分析型': [], '功能型': [], '直覺型': [], '個人型': []},
        'female': {'分析型': [], '功能型': [], '直覺型': [], '個人型': []}
    }
    
    # 將用戶分類到對應組別
    for user_id, data in school_only_users.items():
        p_type = data["personality_type"]
        gender = data["gender"]
        if p_type and gender and p_type in school_only_by_type[gender]:
            school_only_by_type[gender][p_type].append(user_id)
    
    for user_id, data in mixed_users.items():
        p_type = data["personality_type"]
        gender = data["gender"]
        if p_type and gender and p_type in mixed_by_type[gender]:
            mixed_by_type[gender][p_type].append(user_id)
    
    # 記錄各類型人數 - 校內專屬
    logger.info("校內專屬配對用戶分布:")
    for p_type in ['分析型', '功能型', '直覺型', '個人型']:
        m_count = len(school_only_by_type['male'][p_type])
        f_count = len(school_only_by_type['female'][p_type])
        logger.info(f"{p_type}: 男 {m_count}人, 女 {f_count}人")
    
    # 記錄各類型人數 - 混合配對
    logger.info("混合配對用戶分布:")
    for p_type in ['分析型', '功能型', '直覺型', '個人型']:
        m_count = len(mixed_by_type['male'][p_type])
        f_count = len(mixed_by_type['female'][p_type])
        logger.info(f"{p_type}: 男 {m_count}人, 女 {f_count}人")
    
    # 執行配對算法 - 分別處理兩組用戶
    result_groups = []
    
    # 先處理校內專屬配對用戶
    school_only_groups = await _match_user_group(school_only_by_type)
    result_groups.extend(school_only_groups)
    
    # 再處理混合配對用戶
    mixed_groups = await _match_user_group(mixed_by_type)
    result_groups.extend(mixed_groups)
    
    # 收集剩餘的用戶 - 這些用戶暫時無法被配對
    remaining_school_only = []
    for gender in ['male', 'female']:
        for p_type in ['分析型', '功能型', '直覺型', '個人型']:
            for uid in school_only_by_type[gender][p_type]:
                remaining_school_only.append((uid, p_type, gender, True))  # True表示校內專屬
    
    remaining_mixed = []
    for gender in ['male', 'female']:
        for p_type in ['分析型', '功能型', '直覺型', '個人型']:
            for uid in mixed_by_type[gender][p_type]:
                remaining_mixed.append((uid, p_type, gender, False))  # False表示混合配對
    
    all_remaining = remaining_school_only + remaining_mixed
    
    return result_groups, all_remaining

# 新增輔助函數來處理一組用戶的配對邏輯
async def _match_user_group(users_by_type):
    """處理一組用戶的配對邏輯"""
    result_groups = []
    
    # 步驟 1: 按人格類型優先分配 2男2女 組
    for p_type in ['分析型', '功能型', '直覺型', '個人型']:
        # 隨機打亂順序，避免固定順序選擇
        random.shuffle(users_by_type['male'][p_type])
        random.shuffle(users_by_type['female'][p_type])
        
        while len(users_by_type['male'][p_type]) >= 2 and len(users_by_type['female'][p_type]) >= 2:
            group = {
                "user_ids": users_by_type['male'][p_type][:2] + users_by_type['female'][p_type][:2],
                "is_complete": True,
                "male_count": 2,
                "female_count": 2
            }
            result_groups.append(group)
            users_by_type['male'][p_type] = users_by_type['male'][p_type][2:]
            users_by_type['female'][p_type] = users_by_type['female'][p_type][2:]
    
    # 步驟 2: 混合人格類型，但保持性別平衡 2男2女
    remaining_male = []
    remaining_female = []
    
    # 收集剩餘的用戶
    for p_type in ['分析型', '功能型', '直覺型', '個人型']:
        remaining_male.extend([(uid, p_type) for uid in users_by_type['male'][p_type]])
        remaining_female.extend([(uid, p_type) for uid in users_by_type['female'][p_type]])
    
    # 如果還能形成2男2女組，繼續配對
    while len(remaining_male) >= 2 and len(remaining_female) >= 2:
        # 選擇2名男性和2名女性
        selected_male = remaining_male[:2]
        selected_female = remaining_female[:2]
        
        # 提取用戶ID和人格類型
        male_users = [uid for uid, _ in selected_male]
        female_users = [uid for uid, _ in selected_female]
        
        # 確定主導人格類型
        personality_counts = {}
        for _, p_type in selected_male + selected_female:
            personality_counts[p_type] = personality_counts.get(p_type, 0) + 1
        
        dominant_personality = max(personality_counts.items(), key=lambda x: x[1])[0]
        
        group = {
            "user_ids": male_users + female_users,
            "is_complete": True,
            "male_count": 2,
            "female_count": 2
        }
        result_groups.append(group)
        remaining_male = remaining_male[2:]
        remaining_female = remaining_female[2:]
    
    # 步驟 3: 處理剩餘用戶，按相同人格類型優先配對4人組
    # 這部分邏輯與原來相同，確保完整處理所有剩餘用戶
    remaining_users = []
    for gender in ['male', 'female']:
        for p_type in ['分析型', '功能型', '直覺型', '個人型']:
            if gender == 'male':
                remaining_users.extend([(uid, p_type, 'male') for uid in users_by_type[gender][p_type]])
            else:
                remaining_users.extend([(uid, p_type, 'female') for uid in users_by_type[gender][p_type]])
    
    # 按人格類型分組
    personality_groups = {'分析型': [], '功能型': [], '直覺型': [], '個人型': []}
    for uid, p_type, gender in remaining_users:
        personality_groups[p_type].append((uid, gender))
    
    # 處理每個人格類型組
    for p_type, users in personality_groups.items():
        while len(users) >= 4:
            # 提取用戶ID
            group_users = [uid for uid, _ in users[:4]]
            
            # 計算性別比例
            genders = [gender for _, gender in users[:4]]
            male_count = genders.count('male')
            female_count = genders.count('female')
            
            group = {
                "user_ids": group_users,
                "is_complete": True,
                "male_count": male_count,
                "female_count": female_count
            }
            result_groups.append(group)
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
        
        # 確定主導人格類型
        personality_counts = {}
        for _, p_type, _ in group_infos:
            personality_counts[p_type] = personality_counts.get(p_type, 0) + 1
        
        dominant_personality = max(personality_counts.items(), key=lambda x: x[1])[0]
        
        group = {
            "user_ids": group_users,
            "is_complete": True,
            "male_count": male_count,
            "female_count": female_count
        }
        result_groups.append(group)
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
        
        # 確定主導人格類型
        personality_counts = {}
        for _, p_type, _ in group_infos:
            personality_counts[p_type] = personality_counts.get(p_type, 0) + 1
        
        dominant_personality = max(personality_counts.items(), key=lambda x: x[1])[0]
        
        group = {
            "user_ids": group_users,
            "is_complete": False,
            "male_count": male_count,
            "female_count": female_count
        }
        result_groups.append(group)
        all_remaining = []
    
    return result_groups

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
            update_success = await update_user_status_to_confirmation(
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
        
        if valid_user_count == 0:
            logger.warning("沒有足夠的用戶資料進行配對")
            return {
                "success": False,
                "message": "沒有足夠的用戶資料進行配對",
                "matched_groups": 0,
                "remaining_users": len(waiting_user_ids)
            }
        
        # 2. 執行配對算法
        result_groups, all_remaining = await _match_users_into_groups(user_data)
        
        # 如果還有1-2人，保持等待狀態
        remaining_count = len(all_remaining)
        if remaining_count > 0:
            logger.info(f"剩餘 {remaining_count} 人無法配對成組，保持等待狀態")
        
        logger.info(f"配對結果: 共形成 {len(result_groups)} 個組別")
        
        # 3. 將結果保存到數據庫
        notification_service = NotificationService(use_service_role=True)
        created_groups, total_matched_users = await _save_matching_groups_to_db(supabase, result_groups, notification_service, datetime.now() + timedelta(hours=24))
        
        result_message = f"批量配對完成：共創建 {created_groups} 個組別"
        logger.info(result_message)
        
        # 計算未配對用戶數量
        remaining_users = len(waiting_user_ids) - total_matched_users
        
        # 返回配對結果
        return {
            "success": True,
            "message": result_message,
            "matched_groups": created_groups,
            "remaining_users": remaining_users
        }
        
    except Exception as e:
        error_message = f"批量配對處理錯誤: {str(e)}"
        logger.error(error_message)
        return {
            "success": False,
            "message": error_message,
            "matched_groups": 0,
            "remaining_users": None
        }

async def process_auto_form_groups(supabase: Client):
    """自動成桌處理邏輯"""
    try:
        # 1. 獲取等待名單中的用戶資料
        waiting_user_ids, user_data, valid_user_count = await _get_waiting_users_data(supabase)
        
        if valid_user_count < 3:
            message = "等待名單中的用戶不足3人，無法自動成桌"
            logger.warning(message)
            return {
                "success": True,
                "message": message,
                "created_groups": 0,
                "remaining_users": len(waiting_user_ids) if waiting_user_ids else 0
            }
        
        # 2. 執行配對算法
        result_groups, all_remaining = await _match_users_into_groups(user_data)
        
        # 如果還有1-2人，保持等待狀態
        remaining_count = len(all_remaining)
        if remaining_count > 0:
            logger.info(f"剩餘 {remaining_count} 人無法配對成組，保持等待狀態")
        
        logger.info(f"配對結果: 共形成 {len(result_groups)} 個組別")
        
        # 3. 將結果保存到數據庫
        notification_service = NotificationService(use_service_role=True)
        created_groups, total_matched_users = await _save_matching_groups_to_db(supabase, result_groups, notification_service, datetime.now() + timedelta(hours=7))
        
        result_message = f"自動成桌完成：共創建 {created_groups} 個組別"
        logger.info(result_message)
        
        # 計算未配對用戶數量
        remaining_users = valid_user_count - total_matched_users
        
        return {
            "success": True,
            "message": result_message,
            "created_groups": created_groups,
            "remaining_users": remaining_users
        }
        
    except Exception as e:
        error_message = f"自動成桌處理錯誤: {str(e)}"
        logger.error(error_message)
        return {
            "success": False,
            "message": error_message,
            "created_groups": 0,
            "remaining_users": None
        }

# 在文件末尾添加餐廳推薦相關函數
async def recommend_restaurants_for_group(supabase: Client, group_id: str, user_ids: List[str]) -> bool:
    """
    為群組推薦餐廳並保存到restaurant_votes表
    
    基於群組成員的食物偏好，推薦2家餐廳
    """
    try:
        logger.info(f"為群組 {group_id} 推薦餐廳")
        
        # 1. 獲取群組成員的食物偏好
        food_preferences = await get_group_food_preferences(supabase, user_ids)
        if not food_preferences:
            logger.warning(f"無法獲取群組 {group_id} 成員的食物偏好")
            return False
            
        # 2. 根據偏好選擇兩家餐廳
        recommended_restaurants = await select_recommended_restaurants(supabase, food_preferences)
        if not recommended_restaurants or len(recommended_restaurants) == 0:
            logger.warning(f"無法為群組 {group_id} 推薦餐廳")
            return False
            
        # 3. 將推薦餐廳保存到restaurant_votes表
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
    limit: int = 2
) -> List[str]:
    """
    基於食物偏好選擇推薦餐廳
    
    策略:
    1. 如果有共同偏好，優先選擇符合最受歡迎類別的餐廳
    2. 如果偏好多樣化，選擇覆蓋多數用戶偏好的餐廳
    3. 如果沒有偏好資料，隨機選擇餐廳
    """
    try:
        if not food_preferences:
            # 如果沒有偏好資料，隨機選擇餐廳
            random_restaurants = supabase.table("restaurants") \
                .select("id") \
                .limit(limit) \
                .order("created_at") \
                .execute()
                
            return [r["id"] for r in random_restaurants.data] if random_restaurants.data else []
        
        # 按偏好度排序類別
        sorted_preferences = sorted(food_preferences.items(), key=lambda x: x[1], reverse=True)
        
        # 選擇排名前 limit*2 的類別，增加多樣性
        top_categories = [category for category, _ in sorted_preferences[:limit*2]]
        
        if not top_categories:
            return []
            
        # 從這些類別中查詢餐廳
        recommended_ids = []
        for category in top_categories:
            if len(recommended_ids) >= limit:
                break
                
            # 查詢指定類別的餐廳
            category_restaurants = supabase.table("restaurants") \
                .select("id") \
                .eq("category", category) \
                .limit(1) \
                .order("created_at") \
                .execute()
                
            if category_restaurants.data:
                restaurant_id = category_restaurants.data[0]["id"]
                if restaurant_id not in recommended_ids:
                    recommended_ids.append(restaurant_id)
        
        # 如果推薦不足，使用隨機餐廳補充
        if len(recommended_ids) < limit:
            remaining = limit - len(recommended_ids)
            
            # 排除已選擇的餐廳
            random_restaurants = supabase.table("restaurants") \
                .select("id") \
                .not_("id", "in", f"({','.join(recommended_ids)})") \
                .limit(remaining) \
                .order("created_at") \
                .execute()
                
            if random_restaurants.data:
                for r in random_restaurants.data:
                    recommended_ids.append(r["id"])
        
        return recommended_ids
        
    except Exception as e:
        logger.error(f"選擇推薦餐廳時出錯: {str(e)}")
        return [] 