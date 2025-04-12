from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from supabase import Client
from typing import List, Optional, Dict, Any
import random
from datetime import datetime, timedelta
import logging

from schemas.matching import (
    JoinMatchingRequest, JoinMatchingResponse, 
    BatchMatchingResponse, AutoFormGroupsResponse,
    MatchingGroup, MatchingUser, UserMatchingInfo, UserStatusExtended
)
from schemas.dining import DiningUserStatus
from dependencies import get_supabase, get_current_user, get_supabase_service

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/batch", response_model=BatchMatchingResponse, status_code=status.HTTP_200_OK)
async def batch_matching(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_service)
):
    """
    批量配對任務（週二 6:00 AM 觸發）
    將所有 waiting_matching 狀態的用戶按4人一組進行分組
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
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    用戶參加聚餐配對
    嘗試將用戶補入不足4人的桌位或進入等待名單
    """
    # 1. 檢查用戶是否已在等待或已配對
    status_response = supabase.table("user_status_extended") \
        .select("id, user_id, status, group_id, confirmation_deadline") \
        .eq("user_id", request.user_id) \
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
    
    # 2. 查找不足4人的桌位
    incomplete_groups_response = supabase.table("matching_groups") \
        .select("id, user_ids, personality_type, male_count, female_count, is_complete") \
        .eq("is_complete", False) \
        .eq("status", "waiting_confirmation") \
        .execute()
    
    # 3. 獲取用戶個人資料（性別和人格類型）
    profile_response = supabase.table("user_profiles") \
        .select("gender") \
        .eq("user_id", request.user_id) \
        .execute()
    
    personality_response = supabase.table("user_personality_results") \
        .select("personality_type") \
        .eq("user_id", request.user_id) \
        .execute()
    
    if not profile_response.data or not personality_response.data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="無法獲取用戶個人資料或人格測試結果"
        )
    
    gender = profile_response.data[0]["gender"]
    personality_type = personality_response.data[0]["personality_type"]
    
    # 4. 查找適合的不完整組別（優先同人格類型）
    joined_group = None
    joined_group_id = None
    
    if incomplete_groups_response.data:
        # 優先選擇相同人格類型的組別
        matching_groups = [g for g in incomplete_groups_response.data if g["personality_type"] == personality_type]
        
        # 如果沒有相同類型的，選擇任意類型
        if not matching_groups and incomplete_groups_response.data:
            matching_groups = incomplete_groups_response.data
        
        if matching_groups:
            # 選擇第一個組別加入
            group = matching_groups[0]
            group_id = group["id"]
            user_ids = group["user_ids"] or []  # 確保是列表
            
            # 檢查用戶是否已在該組
            if request.user_id in user_ids:
                return {
                    "status": "waiting_confirmation",
                    "message": "您已加入該聚餐小組",
                    "group_id": group_id,
                    "deadline": None  # 需要從資料庫查詢
                }
            
            # 更新組別信息
            user_ids.append(request.user_id)
            is_complete = len(user_ids) >= 4
            male_count = group["male_count"] + (1 if gender == "male" else 0)
            female_count = group["female_count"] + (1 if gender == "female" else 0)
            
            # 更新組別
            supabase.table("matching_groups").update({
                "user_ids": user_ids,
                "is_complete": is_complete,
                "male_count": male_count,
                "female_count": female_count,
                "updated_at": datetime.now().isoformat()
            }).eq("id", group_id).execute()
            
            joined_group = True
            joined_group_id = group_id
    
    # 5. 更新用戶狀態
    if joined_group:
        # 設置確認截止時間（24小時後）
        confirmation_deadline = datetime.now() + timedelta(hours=24)
        
        # 檢查或創建用戶狀態
        user_status_resp = supabase.table("user_status") \
            .select("id") \
            .eq("user_id", request.user_id) \
            .execute()
            
        # 更新用戶狀態為等待確認
        if user_status_resp.data:
            supabase.table("user_status").update({
                "status": "waiting_confirmation",
                "updated_at": datetime.now().isoformat()
            }).eq("id", user_status_resp.data[0]["id"]).execute()
        else:
            supabase.table("user_status").insert({
                "user_id": request.user_id,
                "status": "waiting_confirmation"
            }).execute()
        
        # 創建或更新配對信息
        matching_info_resp = supabase.table("user_matching_info") \
            .select("id") \
            .eq("user_id", request.user_id) \
            .execute()
            
        if matching_info_resp.data:
            supabase.table("user_matching_info").update({
                "matching_group_id": joined_group_id,
                "confirmation_deadline": confirmation_deadline.isoformat(),
                "updated_at": datetime.now().isoformat()
            }).eq("id", matching_info_resp.data[0]["id"]).execute()
        else:
            supabase.table("user_matching_info").insert({
                "user_id": request.user_id,
                "matching_group_id": joined_group_id,
                "confirmation_deadline": confirmation_deadline.isoformat()
            }).execute()
        
        # 返回成功加入組別的響應
        return {
            "status": "waiting_confirmation",
            "message": "您已被分配到桌位，請在24小時內確認參加",
            "group_id": joined_group_id,
            "deadline": confirmation_deadline
        }
    else:
        # 如果沒有適合的組別，加入等待名單
        
        # 檢查或創建用戶狀態
        user_status_resp = supabase.table("user_status") \
            .select("id") \
            .eq("user_id", request.user_id) \
            .execute()
        
        # 更新用戶狀態為等待配對
        if user_status_resp.data:
            supabase.table("user_status").update({
                "status": "waiting_matching",
                "updated_at": datetime.now().isoformat()
            }).eq("id", user_status_resp.data[0]["id"]).execute()
        else:
            supabase.table("user_status").insert({
                "user_id": request.user_id,
                "status": "waiting_matching"
            }).execute()
        
        # 清除任何之前的配對信息
        supabase.table("user_matching_info") \
            .delete() \
            .eq("user_id", request.user_id) \
            .execute()
        
        # 返回加入等待名單的響應
        return {
            "status": "waiting_matching",
            "message": "您已加入聚餐配對等待名單",
            "group_id": None,
            "deadline": None
        }

@router.post("/auto-form", response_model=AutoFormGroupsResponse, status_code=status.HTTP_200_OK)
async def auto_form_groups(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase)
):
    """
    自動成桌任務（週三 06:00 AM 觸發）
    若等待名單中用戶數≥3人，自動組成新桌位
    """
    # 實際實現會將此邏輯放入背景任務
    background_tasks.add_task(process_auto_form_groups, supabase)
    return {
        "success": True, 
        "message": "自動成桌任務已啟動",
        "created_groups": None,
        "remaining_users": None
    }

# 背景任務處理函數
async def process_batch_matching(supabase: Client):
    """批量配對處理邏輯"""
    try:
        # 1. 獲取所有 waiting_matching 狀態的用戶
        logger.info("開始批量配對處理: 查詢等待配對用戶")
        
        users_response = supabase.table("user_status") \
            .select("id, user_id, status") \
            .eq("status", "waiting_matching") \
            .execute()
        
        # 記錄原始響應以診斷
        logger.info(f"用戶查詢響應: {users_response}")
        
        if not users_response.data or len(users_response.data) == 0:
            logger.warning("沒有待配對的用戶")
            return {
                "success": True,
                "message": "沒有待配對的用戶",
                "matched_groups": 0,
                "remaining_users": 0
            }
        
        waiting_user_ids = [user["user_id"] for user in users_response.data]
        logger.info(f"待配對用戶ID: {waiting_user_ids}")
        
        # 2. 獲取這些用戶的個人資料（性別和人格類型）
        profiles_response = supabase.table("user_profiles") \
            .select("user_id, gender") \
            .in_("user_id", waiting_user_ids) \
            .execute()
        
        logger.info(f"用戶資料響應: {len(profiles_response.data) if profiles_response.data else 0} 筆記錄")
        
        personality_response = supabase.table("user_personality_results") \
            .select("user_id, personality_type") \
            .in_("user_id", waiting_user_ids) \
            .execute()
        
        logger.info(f"人格類型響應: {len(personality_response.data) if personality_response.data else 0} 筆記錄")
        
        # 檢查是否找到用戶資料
        if not profiles_response.data or not personality_response.data:
            logger.warning("無法獲取用戶資料或人格類型")
            return {
                "success": False,
                "message": "無法獲取用戶資料或人格類型",
                "matched_groups": 0,
                "remaining_users": len(waiting_user_ids)
            }
        
        # 3. 合併用戶數據
        user_data = {}
        for profile in profiles_response.data:
            user_id = profile["user_id"]
            gender = profile["gender"]
            user_data[user_id] = {"gender": gender, "personality_type": None}
        
        for result in personality_response.data:
            user_id = result["user_id"]
            if user_id in user_data:
                user_data[user_id]["personality_type"] = result["personality_type"]
        
        # 記錄有效用戶數量
        valid_users = [uid for uid, data in user_data.items() 
                       if data["gender"] and data["personality_type"]]
        logger.info(f"有效用戶數: {len(valid_users)}/{len(waiting_user_ids)}")
        
        if len(valid_users) == 0:
            logger.warning("沒有足夠的用戶資料進行配對")
            return {
                "success": False,
                "message": "沒有足夠的用戶資料進行配對",
                "matched_groups": 0,
                "remaining_users": len(waiting_user_ids)
            }
        
        # 4. 按人格類型和性別分組
        groups = {
            '分析型': {'male': [], 'female': []},
            '功能型': {'male': [], 'female': []},
            '直覺型': {'male': [], 'female': []},
            '個人型': {'male': [], 'female': []}
        }
        
        for user_id, data in user_data.items():
            p_type = data["personality_type"]
            gender = data["gender"]
            if p_type and gender and p_type in groups and gender in groups[p_type]:
                groups[p_type][gender].append(user_id)
        
        # 記錄各類型人數
        for p_type in groups:
            logger.info(f"{p_type}: 男 {len(groups[p_type]['male'])}人, 女 {len(groups[p_type]['female'])}人")
        
        # 5. 執行配對算法
        result_groups = []
        
        # 步驟 1: 優先分配 2男2女 組
        for p_type in ['分析型', '功能型', '直覺型', '個人型']:
            # 隨機打亂順序，避免固定順序選擇
            random.shuffle(groups[p_type]['male'])
            random.shuffle(groups[p_type]['female'])
            
            while len(groups[p_type]['male']) >= 2 and len(groups[p_type]['female']) >= 2:
                group = {
                    "user_ids": groups[p_type]['male'][:2] + groups[p_type]['female'][:2],
                    "personality_type": p_type,
                    "is_complete": True,
                    "male_count": 2,
                    "female_count": 2
                }
                result_groups.append(group)
                groups[p_type]['male'] = groups[p_type]['male'][2:]
                groups[p_type]['female'] = groups[p_type]['female'][2:]
        
        # 步驟 2: 處理剩餘用戶（4人組，不限性別）
        for p_type in ['分析型', '功能型', '直覺型', '個人型']:
            remaining = groups[p_type]['male'] + groups[p_type]['female']
            
            while len(remaining) >= 4:
                # 計算實際性別比例
                group_users = remaining[:4]
                group_male_count = sum(1 for uid in group_users if user_data[uid]["gender"] == 'male')
                group_female_count = 4 - group_male_count
                
                group = {
                    "user_ids": group_users,
                    "personality_type": p_type,
                    "is_complete": True,
                    "male_count": group_male_count,
                    "female_count": group_female_count
                }
                result_groups.append(group)
                remaining = remaining[4:]
        
        # 步驟 3: 處理不足4人的組
        remaining_users = []
        for p_type in ['分析型', '功能型', '直覺型', '個人型']:
            remaining = groups[p_type]['male'] + groups[p_type]['female']
            if remaining:
                remaining_users.extend([(user_id, p_type) for user_id in remaining])
        
        # 按人格類型分組（不足4人）
        grouped_remaining = {}
        for user_id, p_type in remaining_users:
            if p_type not in grouped_remaining:
                grouped_remaining[p_type] = []
            grouped_remaining[p_type].append(user_id)
        
        for p_type, users in grouped_remaining.items():
            while users:
                group_size = min(4, len(users))
                group_users = users[:group_size]
                
                # 計算性別比例
                male_count = sum(1 for uid in group_users if user_data[uid]["gender"] == 'male')
                female_count = group_size - male_count
                
                group = {
                    "user_ids": group_users,
                    "personality_type": p_type,
                    "is_complete": group_size == 4,
                    "male_count": male_count,
                    "female_count": female_count
                }
                result_groups.append(group)
                users = users[group_size:]
        
        logger.info(f"配對結果: 共形成 {len(result_groups)} 個組別")
        
        # 6. 將結果保存到數據庫
        created_groups = 0
        for group in result_groups:
            # 創建分組記錄
            logger.info(f"創建組別: {group}")
            
            group_response = supabase.table("matching_groups").insert({
                "user_ids": group["user_ids"],
                "personality_type": group["personality_type"],
                "is_complete": group["is_complete"],
                "male_count": group["male_count"],
                "female_count": group["female_count"],
                "status": "waiting_confirmation"
            }).execute()
            
            if not group_response.data:
                logger.error(f"創建組別失敗: {group_response.error}")
                continue
                
            group_id = group_response.data[0]["id"]
            created_groups += 1
            
            # 更新用戶狀態
            confirmation_deadline = datetime.now() + timedelta(hours=24)
            
            for user_id in group["user_ids"]:
                try:
                    # 更新用戶狀態為等待確認
                    user_status_update = supabase.table("user_status").update({
                        "status": "waiting_confirmation",
                        "updated_at": datetime.now().isoformat()
                    }).eq("user_id", user_id).eq("status", "waiting_matching").execute()
                    
                    logger.info(f"更新用戶狀態: {user_id} - {user_status_update}")
                    
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
                except Exception as e:
                    logger.error(f"更新用戶 {user_id} 狀態失敗: {str(e)}")
        
        result_message = f"批量配對完成：共創建 {created_groups} 個組別"
        logger.info(result_message)
        
        # 返回配對結果
        return {
            "success": True,
            "message": result_message,
            "matched_groups": created_groups,
            "remaining_users": len(waiting_user_ids) - sum(len(g["user_ids"]) for g in result_groups)
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
        # 獲取等待名單中的用戶
        logger.info("開始自動成桌處理: 查詢等待配對用戶")
        
        waiting_users_response = supabase.table("user_status") \
            .select("user_id") \
            .eq("status", "waiting_matching") \
            .execute()
        
        if not waiting_users_response.data or len(waiting_users_response.data) < 3:
            message = "等待名單中的用戶不足3人，無法自動成桌"
            logger.warning(message)
            return {
                "success": True,
                "message": message,
                "created_groups": 0,
                "remaining_users": len(waiting_users_response.data) if waiting_users_response.data else 0
            }
        
        # 獲取用戶ID列表
        waiting_user_ids = [user["user_id"] for user in waiting_users_response.data]
        logger.info(f"待成桌用戶ID: {waiting_user_ids}")
        
        # 獲取用戶資料
        profiles_response = supabase.table("user_profiles") \
            .select("user_id, gender") \
            .in_("user_id", waiting_user_ids) \
            .execute()
        
        personality_response = supabase.table("user_personality_results") \
            .select("user_id, personality_type") \
            .in_("user_id", waiting_user_ids) \
            .execute()
        
        # 檢查是否找到用戶資料
        if not profiles_response.data or not personality_response.data:
            logger.warning("無法獲取用戶資料或人格類型")
            return {
                "success": False,
                "message": "無法獲取用戶資料或人格類型",
                "created_groups": 0,
                "remaining_users": len(waiting_user_ids)
            }
        
        # 合併用戶數據
        user_data = {}
        for profile in profiles_response.data:
            user_id = profile["user_id"]
            gender = profile["gender"]
            user_data[user_id] = {"gender": gender, "personality_type": None}
        
        for result in personality_response.data:
            user_id = result["user_id"]
            if user_id in user_data:
                user_data[user_id]["personality_type"] = result["personality_type"]
        
        # 記錄有效用戶數量
        valid_users = [uid for uid, data in user_data.items() 
                       if data["gender"] and data["personality_type"]]
        logger.info(f"有效用戶數: {len(valid_users)}/{len(waiting_user_ids)}")
        
        if len(valid_users) < 3:
            logger.warning("沒有足夠的有效用戶進行成桌")
            return {
                "success": False,
                "message": "沒有足夠的有效用戶進行成桌",
                "created_groups": 0,
                "remaining_users": len(waiting_user_ids)
            }
        
        # 簡化的成桌邏輯：按3-4人一組分配
        result_groups = []
        available_users = valid_users
        random.shuffle(available_users)  # 隨機排序
        
        while len(available_users) >= 3:
            # 決定組大小，優先4人，若剩餘人數為3或7則選3人
            group_size = 3 if len(available_users) == 3 or len(available_users) == 7 else 4
            group_users = available_users[:group_size]
            
            # 獲取主導人格類型
            personality_counts = {}
            for uid in group_users:
                p_type = user_data[uid]["personality_type"]
                if p_type:
                    personality_counts[p_type] = personality_counts.get(p_type, 0) + 1
            
            dominant_personality = max(personality_counts.items(), key=lambda x: x[1])[0] if personality_counts else "分析型"
            
            # 計算性別比例
            male_count = sum(1 for uid in group_users if user_data[uid]["gender"] == 'male')
            female_count = group_size - male_count
            
            group = {
                "user_ids": group_users,
                "personality_type": dominant_personality,
                "is_complete": group_size == 4,
                "male_count": male_count,
                "female_count": female_count
            }
            result_groups.append(group)
            available_users = available_users[group_size:]
        
        logger.info(f"成桌結果: 共形成 {len(result_groups)} 個組別")
        
        # 保存到數據庫
        created_groups = 0
        for group in result_groups:
            # 創建分組記錄
            logger.info(f"創建組別: {group}")
            
            group_response = supabase.table("matching_groups").insert({
                "user_ids": group["user_ids"],
                "personality_type": group["personality_type"],
                "is_complete": group["is_complete"],
                "male_count": group["male_count"],
                "female_count": group["female_count"],
                "status": "waiting_confirmation"
            }).execute()
            
            if not group_response.data:
                logger.error(f"創建組別失敗: {group_response.error}")
                continue
                
            group_id = group_response.data[0]["id"]
            created_groups += 1
            
            # 更新用戶狀態
            confirmation_deadline = datetime.now() + timedelta(hours=24)
            
            for user_id in group["user_ids"]:
                try:
                    # 更新用戶狀態為等待確認
                    supabase.table("user_status").update({
                        "status": "waiting_confirmation",
                        "updated_at": datetime.now().isoformat()
                    }).eq("user_id", user_id).eq("status", "waiting_matching").execute()
                    
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
                except Exception as e:
                    logger.error(f"更新用戶 {user_id} 狀態失敗: {str(e)}")
        
        result_message = f"自動成桌完成：共創建 {created_groups} 個組別"
        logger.info(result_message)
        
        return {
            "success": True,
            "message": result_message,
            "created_groups": created_groups,
            "remaining_users": len(available_users)
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