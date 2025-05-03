from fastapi import APIRouter, Depends, HTTPException, status, Query, BackgroundTasks
from supabase import Client
from typing import List, Optional, Dict, Any
import asyncio
from uuid import UUID, uuid4
from datetime import datetime, timedelta
import logging
import random

from schemas.restaurant import RestaurantCreate, RestaurantResponse, RestaurantVote, RestaurantVoteCreate, UserVoteCreate
from dependencies import get_supabase, get_supabase_service, get_current_user, verify_cron_api_key
from utils.place_types import get_category_from_types
from utils.google_maps import (
    extract_place_id_from_url, 
    extract_coordinates_from_url,
    extract_place_name_from_url,
    expand_short_url_if_needed,
    get_place_details,
    search_place_by_text
)
from utils.restaurant_helper import (
    normalize_restaurant_name,
    process_place_details,
    format_phone_to_taiwan_format
)
from utils.image_processor import (
    process_and_update_image,
    download_and_upload_photo
)
from services.notification_service import NotificationService
from utils.dinner_time_utils import DinnerTimeUtils

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/search", response_model=List[RestaurantResponse])
async def search_restaurants(
    query: str,
    latitude: Optional[float] = Query(None),
    longitude: Optional[float] = Query(None),
    radius: Optional[int] = Query(1000),
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    搜索餐廳
    - 僅接受Google Map連結（短網址或完整網址）
    """
    try:
        # 標示請求的唯一ID，用於日誌追蹤
        request_id = uuid4().hex[:8]
        logger.info(f"[{request_id}] 開始搜尋餐廳: {query}")
        
        is_google_maps_link = any(x in query for x in ['maps.google.com', 'google.com/maps', 'goo.gl/maps', 'maps.app.goo.gl'])
        
        # 檢查是否為Google Map連結
        if not is_google_maps_link:
            logger.warning(f"[{request_id}] 不是有效的Google Map連結: {query}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="僅接受Google Map連結進行搜尋"
            )
        
        # Google Maps連結處理邏輯
        # 先展開短網址取得完整URL
        full_url = expand_short_url_if_needed(query)
        if full_url != query:
            logger.info(f"[{request_id}] 短網址已展開: {full_url}")
        
        # 先從連結中提取餐廳名稱和位置
        place_name = extract_place_name_from_url(full_url)
        coordinates = extract_coordinates_from_url(full_url)
        
        logger.info(f"[{request_id}] 從URL提取的資訊: 名稱={place_name}, 坐標={coordinates}")
        
        # 嘗試使用名稱在資料庫中搜尋，優先使用文字比對減少API呼叫
        if place_name:
            normalized_name = normalize_restaurant_name(place_name)
            logger.info(f"[{request_id}] 標準化後的搜尋關鍵字: {normalized_name}")
            
            # 從資料庫取得所有餐廳並在應用層過濾
            response = supabase.table("restaurants").select("*").execute()
            
            if response.data:
                # 在應用層比較標準化後的名稱
                matching_restaurants = []
                for restaurant in response.data:
                    restaurant_normalized_name = normalize_restaurant_name(restaurant.get("name", ""))
                    # 使用簡單的名稱匹配方式，避免錯誤匹配
                    if normalized_name == restaurant_normalized_name:
                        matching_restaurants.append(restaurant)
                
                if matching_restaurants:
                    logger.info(f"[{request_id}] 在資料庫中找到 {len(matching_restaurants)} 家相符餐廳")
                    return [RestaurantResponse(**restaurant) for restaurant in matching_restaurants]
        
        # 繼續處理Google連結提取place_id
        valid_place_id = None
        original_place_id = extract_place_id_from_url(full_url)
        logger.info(f"[{request_id}] 提取的ID: {original_place_id}")
        
        # 檢查是否有有效的place_id
        if original_place_id:
            is_nonstandard_id = (
                original_place_id.startswith("0x") or 
                ":" in original_place_id or 
                original_place_id.startswith("cid:") or
                not original_place_id.startswith("ChIJ")
            )
            if not is_nonstandard_id:
                logger.info(f"[{request_id}] 使用標準格式place_id: {original_place_id}")
                valid_place_id = original_place_id
                
                # 如果有有效的place_id，先檢查資料庫中是否已有該餐廳
                existing_restaurant = supabase.table("restaurants") \
                    .select("*") \
                    .eq("google_place_id", valid_place_id) \
                    .execute()
                
                if existing_restaurant.data and len(existing_restaurant.data) > 0:
                    logger.info(f"[{request_id}] 使用place_id在資料庫中找到餐廳: {valid_place_id}, 名稱: {existing_restaurant.data[0].get('name', '未知')}")
                    return [RestaurantResponse(**existing_restaurant.data[0])]
        
        # 如果仍未找到，嘗試使用名稱搜尋Google API
        if place_name and not valid_place_id:
            logger.info(f"[{request_id}] 使用 Text Search 名稱+經緯度 fallback")
            if coordinates:
                valid_place_id = await search_place_by_text(place_name, coordinates[0], coordinates[1])
            else:
                valid_place_id = await search_place_by_text(place_name)
            
            if valid_place_id:
                # 如果成功獲取place_id，再次檢查資料庫
                existing_restaurant = supabase.table("restaurants") \
                    .select("*") \
                    .eq("google_place_id", valid_place_id) \
                    .execute()
                
                if existing_restaurant.data and len(existing_restaurant.data) > 0:
                    logger.info(f"[{request_id}] 通過搜尋獲取place_id後在資料庫中找到餐廳: {valid_place_id}")
                    return [RestaurantResponse(**existing_restaurant.data[0])]
        
        if not valid_place_id:
            logger.warning(f"[{request_id}] 使用所有方法都無法獲取有效的地點ID。原始URL: {full_url}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="無法從Google Map連結提取地點ID"
            )
        
        logger.info(f"[{request_id}] 最終使用的有效place_id: {valid_place_id}")
        
        # 獲取餐廳詳細資訊
        place_details = await get_place_details(valid_place_id)
        if not place_details:
            logger.error(f"[{request_id}] 無法從Google Places API獲取地點詳情: {valid_place_id}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="無法獲取Google地點詳細資訊"
            )
        
        # 處理搜尋結果
        restaurant_data = await process_place_details(valid_place_id, place_details, request_id)
        
        # 先返回結果給用戶
        restaurant_response = RestaurantResponse(**restaurant_data)
        
        # 非同步處理圖片（在返回結果給用戶後進行）
        if restaurant_data.get("image_path") is None and place_details.get("photos") and len(place_details.get("photos")) > 0:
            # 提取第一張圖片的引用ID
            photo = place_details.get("photos")[0]
            # 從photo字典中提取名稱或引用ID
            photo_reference = None
            if "name" in photo:
                # 新版API格式
                photo_reference = photo.get("name")
            elif "photoReference" in photo:
                # 舊版API格式
                photo_reference = photo.get("photoReference")
                
            if photo_reference:
                # 使用異步任務處理圖片，不阻塞API響應
                process_image_task = asyncio.create_task(
                    process_and_update_image(photo_reference, restaurant_data["id"], supabase, request_id)
                )
                logger.info(f"[{request_id}] 已啟動非同步圖片處理任務")
        
        # 非同步儲存到資料庫
        try:
            # 最後一次確認資料庫中是否已存在此餐廳(透過place_id)
            existing = supabase.table("restaurants") \
                .select("*") \
                .eq("google_place_id", valid_place_id) \
                .execute()
            
            if not existing.data or len(existing.data) == 0:
                # 儲存到資料庫
                supabase.table("restaurants").insert(restaurant_data).execute()
                logger.info(f"[{request_id}] 餐廳保存到資料庫: {restaurant_data['name']}")
        except Exception as e:
            logger.error(f"[{request_id}] 保存餐廳到資料庫時出錯: {str(e)}")
        
        return [restaurant_response]
            
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"搜索餐廳時出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"搜索餐廳時出錯: {str(e)}"
        )

@router.post("/", response_model=RestaurantResponse, status_code=status.HTTP_201_CREATED)
async def create_restaurant(
    restaurant: RestaurantCreate,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    新增餐廳資訊到資料庫
    """
    try:
        # 先查看餐廳是否已存在
        if restaurant.google_place_id:
            existing = supabase.table("restaurants") \
                .select("*") \
                .eq("google_place_id", restaurant.google_place_id) \
                .execute()
            
            if existing.data and len(existing.data) > 0:
                # 餐廳已存在
                return RestaurantResponse(**existing.data[0])
        
        # 創建新餐廳
        restaurant_data = restaurant.dict()
        restaurant_id = str(uuid4())
        restaurant_data["id"] = restaurant_id
        restaurant_data["created_at"] = datetime.utcnow().isoformat()
        restaurant_data["is_user_added"] = True  # 標記為用戶添加的餐廳
        
        # 如果沒有提供網站，但有Google Place ID，則使用Google Map連結
        if not restaurant_data.get("website") and restaurant_data.get("google_place_id"):
            restaurant_data["website"] = f"https://www.google.com/maps/place/?q=place_id:{restaurant_data['google_place_id']}"
        
        # 將餐廳保存到資料庫
        result = supabase.table("restaurants") \
            .insert(restaurant_data) \
            .execute()
        
        if not result.data or len(result.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="創建餐廳時出錯"
            )
        
        return RestaurantResponse(**result.data[0])
    
    except HTTPException as e:
        # 重新拋出HTTP異常
        raise e
    except Exception as e:
        logger.error(f"創建餐廳時出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"創建餐廳時出錯: {str(e)}"
        )

@router.get("/{restaurant_id}", response_model=RestaurantResponse)
async def get_restaurant(
    restaurant_id: str,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    獲取餐廳詳細資訊
    """
    try:
        # 驗證UUID格式
        try:
            UUID(restaurant_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="無效的餐廳ID格式"
            )
        
        # 查詢餐廳
        result = supabase.table("restaurants") \
            .select("*") \
            .eq("id", restaurant_id) \
            .execute()
        
        if not result.data or len(result.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"找不到ID為 {restaurant_id} 的餐廳"
            )
        
        return RestaurantResponse(**result.data[0])
    
    except HTTPException as e:
        # 重新拋出HTTP異常
        raise e
    except Exception as e:
        logger.error(f"獲取餐廳詳細資訊時出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取餐廳詳細資訊時出錯: {str(e)}"
        )

@router.post("/vote", response_model=RestaurantVote)
async def vote_restaurant(
    vote: UserVoteCreate,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    使用 restaurant_id 對餐廳進行投票
    後端自動根據當前用戶ID查詢其所屬的matching_group_id
    不需要前端提供group_id
    投票後檢查是否所有用戶都已投票，若是則建立聚餐事件
    """
    try:
        user_id = current_user.user.id
        restaurant_id = vote.restaurant_id
        
        # 驗證餐廳存在
        restaurant = supabase.table("restaurants") \
            .select("*") \
            .eq("id", restaurant_id) \
            .execute()
            
        if not restaurant.data or len(restaurant.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"找不到ID為 {restaurant_id} 的餐廳"
            )
        restaurant_data = restaurant.data[0]
        
        # 獲取用戶所屬的群組ID和群組資訊
        user_group_response = supabase.table("user_matching_info") \
            .select("matching_group_id") \
            .eq("user_id", user_id) \
            .execute()
            
        if not user_group_response.data or len(user_group_response.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="您尚未加入任何配對群組"
            )
        
        group_id = user_group_response.data[0]["matching_group_id"]
        
        # 檢查用戶是否已經為這個餐廳投過票
        existing_vote = supabase.table("restaurant_votes") \
            .select("*") \
            .eq("restaurant_id", restaurant_id) \
            .eq("group_id", group_id) \
            .eq("user_id", user_id) \
            .execute()
            
        if existing_vote.data and len(existing_vote.data) > 0:
            # 用戶已經投過票，返回現有投票，但繼續檢查是否所有人都投票了
            vote_data = existing_vote.data[0]
        else:
            # 創建新的投票記錄
            vote_data = {
                "id": str(uuid4()),
                "restaurant_id": restaurant_id,
                "group_id": group_id,
                "user_id": user_id,
                "is_system_recommendation": vote.is_system_recommendation,
                "created_at": datetime.utcnow().isoformat()
            }
            
            result = supabase.table("restaurant_votes") \
                .insert(vote_data) \
                .execute()
            
            if not result.data or len(result.data) == 0:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="創建投票時出錯"
                )
            vote_data = result.data[0]
        
        # 獲取群組成員資訊和已投票的用戶
        group_and_votes = await _get_group_and_votes(supabase, group_id)
        
        group_members = group_and_votes["group_members"]
        voted_user_ids = group_and_votes["voted_user_ids"]
        
        # 計算投票結果
        result_data = {"is_voting_complete": False}
        
        # 如果所有成員都已投票
        if len(voted_user_ids) >= len(group_members):
            # 處理投票完成的情況
            result_data = await process_group_voting(supabase, group_id)
            result_data["is_voting_complete"] = True
        else:
            # 更新當前用戶狀態為等待其他用戶
            supabase.table("user_status") \
                .update({
                    "status": "waiting_other_users",
                    "updated_at": datetime.utcnow().isoformat()
                }) \
                .eq("user_id", user_id) \
                .execute()
        
        # 將投票結果和票數信息合併
        vote_response = RestaurantVote(**vote_data)
        vote_response.is_voting_complete = result_data.get("is_voting_complete", False)
        
        if result_data.get("is_voting_complete"):
            vote_response.dining_event_id = result_data.get("dining_event_id")
            vote_response.winning_restaurant = result_data.get("winning_restaurant")
        
        return vote_response
    
    except HTTPException as e:
        # 重新拋出HTTP異常
        raise e
    except Exception as e:
        logger.error(f"投票時出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"投票時出錯: {str(e)}"
        )

async def _get_group_and_votes(supabase: Client, group_id: str) -> Dict[str, Any]:
    """
    獲取群組成員和投票情況，減少重複數據庫查詢
    """
    # 獲取群組成員資訊
    group_info = supabase.table("matching_groups") \
        .select("user_ids") \
        .eq("id", group_id) \
        .execute()
    
    if not group_info.data or not group_info.data[0].get("user_ids"):
        raise ValueError(f"無法獲取群組 {group_id} 的成員信息")
    
    # 獲取群組成員ID
    group_members = group_info.data[0]["user_ids"]
    
    # 獲取已投票的用戶和餐廳
    restaurant_votes = supabase.table("restaurant_votes") \
        .select("user_id, restaurant_id, is_system_recommendation") \
        .eq("group_id", group_id) \
        .filter("user_id", "not.is", "null") \
        .execute()
    
    # 計算已投票的用戶ID
    voted_user_ids = set(vote["user_id"] for vote in restaurant_votes.data if vote.get("user_id"))
    
    return {
        "group_members": group_members,
        "voted_user_ids": voted_user_ids,
        "restaurant_votes": restaurant_votes.data
    }

async def process_group_voting(
    supabase: Client, 
    group_id: str, 
    is_forced: bool = False
) -> Dict[str, Any]:
    """
    處理群組餐廳投票的通用函數
    如果is_forced為True，則強制結束投票，即使不是所有成員都已投票
    如果沒有足夠投票，將從系統推薦中隨機選擇
    返回處理結果
    """
    try:
        logger.info(f"處理群組 {group_id} 的投票{' (強制模式)' if is_forced else ''}")
        
        # 1. 獲取群組成員和投票情況
        group_and_votes = await _get_group_and_votes(supabase, group_id)
        
        group_members = group_and_votes["group_members"]
        voted_user_ids = group_and_votes["voted_user_ids"]
        restaurant_votes = group_and_votes["restaurant_votes"]
        
        # 2. 決定如何選擇餐廳
        is_all_voted = len(voted_user_ids) >= len(group_members)
        has_user_votes = bool(restaurant_votes)
        
        # 計算用戶的有效投票（非系統推薦）
        valid_votes = []
        for vote in restaurant_votes:
            is_system_recommendation = vote.get("is_system_recommendation", False)
            if not is_system_recommendation:
                valid_votes.append(vote)
        
        has_valid_votes = bool(valid_votes)
        
        # 3. 統一處理餐廳選擇邏輯，優化效能
        restaurant_id = None
        restaurant_data = None
        selection_method = "無法確定"
        candidate_restaurant_ids = []
        
        # 獲取所有與此群組相關的餐廳投票（包括系統推薦和用戶投票）
        all_votes = supabase.table("restaurant_votes") \
            .select("restaurant_id, user_id, is_system_recommendation") \
            .eq("group_id", group_id) \
            .execute()
            
        if not all_votes.data:
            logger.warning(f"群組 {group_id} 沒有任何餐廳投票或推薦")
            return {
                "success": False,
                "message": "沒有可用的餐廳投票或推薦"
            }
            
        # 計算每家餐廳的得票數並收集系統推薦的餐廳
        vote_counts = {}
        system_recommended_ids = set()
        
        for vote in all_votes.data:
            rid = vote["restaurant_id"]
            is_system_recommendation = vote.get("is_system_recommendation", False)
            has_user_id = vote.get("user_id") is not None
            
            # 初始化餐廳投票計數（如果不存在）
            if rid not in vote_counts:
                vote_counts[rid] = 0
                
            # 系統推薦記為零票，但記錄為系統推薦
            if is_system_recommendation and not has_user_id:
                system_recommended_ids.add(rid)
            # 用戶投票增加計數（如果不是系統推薦）
            elif has_user_id and not is_system_recommendation:
                vote_counts[rid] += 1
        
        # 按票數從高到低排序餐廳
        sorted_restaurants = sorted(vote_counts.items(), key=lambda x: x[1], reverse=True)
        
        # 決定餐廳選擇方式
        if sorted_restaurants and sorted_restaurants[0][1] > 0:
            # 有效得票最高的餐廳獲勝
            restaurant_id = sorted_restaurants[0][0]
            selection_method = "用戶投票"
            logger.info(f"群組 {group_id} 根據用戶投票選出餐廳 {restaurant_id}，得票數: {sorted_restaurants[0][1]}")
        elif system_recommended_ids:
            # 如果沒有有效得票，從系統推薦中隨機選擇
            system_recommendations = list(system_recommended_ids)
            random.shuffle(system_recommendations)
            restaurant_id = system_recommendations[0]
            selection_method = "系統隨機推薦"
            logger.info(f"群組 {group_id} 從系統推薦中隨機選出餐廳 {restaurant_id}")
        else:
            # 如果沒有系統推薦，從所有餐廳中隨機選一個
            all_restaurant_ids = [rid for rid, _ in sorted_restaurants]
            if all_restaurant_ids:
                restaurant_id = random.choice(all_restaurant_ids)
                selection_method = "隨機選擇"
                logger.info(f"群組 {group_id} 從所有餐廳中隨機選出 {restaurant_id}")
            else:
                logger.error(f"群組 {group_id} 沒有可用的餐廳選擇")
                return {
                    "success": False,
                    "message": "沒有可用的餐廳"
                }
        
        # 構建候選餐廳列表
        # 首先添加所有得票的餐廳（除了獲勝餐廳）
        for rid, votes in sorted_restaurants:
            if rid != restaurant_id and rid not in candidate_restaurant_ids:
                candidate_restaurant_ids.append(rid)
                
        # 然後添加所有系統推薦的餐廳（如果尚未在列表中）
        for rid in system_recommended_ids:
            if rid != restaurant_id and rid not in candidate_restaurant_ids:
                candidate_restaurant_ids.append(rid)
                
        logger.info(f"最終選擇餐廳: {restaurant_id}，選擇方式: {selection_method}")
        logger.info(f"候選餐廳數量: {len(candidate_restaurant_ids)}")
        
        # 4. 獲取餐廳詳細資訊
        restaurant_info = supabase.table("restaurants") \
            .select("*") \
            .eq("id", restaurant_id) \
            .execute()
        
        if not restaurant_info.data:
            logger.error(f"無法獲取餐廳 {restaurant_id} 的資訊")
            return {
                "success": False, 
                "message": f"無法獲取餐廳資訊"
            }
            
        restaurant_data = restaurant_info.data[0]
        restaurant_name = restaurant_data["name"]
        
        # 5. 創建聚餐事件
        # 使用DinnerTimeUtils獲取下次聚餐時間
        dinner_time_info = DinnerTimeUtils.calculate_dinner_time_info()
        next_dinner_time = dinner_time_info.next_dinner_time
        
        # 格式化餐廳選擇說明
        if selection_method == "用戶投票":
            description = f"群組投票選出的餐廳: {restaurant_name}"
        else:
            description = f"系統選出的餐廳: {restaurant_name}"
            
        if is_forced:
            description += " (投票時間已到自動選出)"
        
        # 創建聚餐事件
        dining_event = {
            "id": str(uuid4()),
            "matching_group_id": group_id,
            "restaurant_id": restaurant_id,
            "name": f"{restaurant_name} 聚餐",
            "date": next_dinner_time.isoformat(),  # 使用計算出的聚餐時間
            "status": "pending_confirmation",  # 餐廳待確認
            "description": description,
            "candidate_restaurant_ids": candidate_restaurant_ids,  # 加入候選餐廳列表
            "attendee_count": len(group_members),  # 添加聚餐人數，預設為群組成員數量
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat()
        }
        
        event_result = supabase.table("dining_events") \
            .insert(dining_event) \
            .execute()
        
        if not event_result.data:
            logger.error(f"創建聚餐事件失敗: {event_result.error if hasattr(event_result, 'error') else '未知錯誤'}")
            return {
                "success": False,
                "message": "創建聚餐事件失敗"
            }
        
        event_id = event_result.data[0]["id"]
        
        # 6. 更新matching_groups表狀態為waiting_attendance
        supabase.table("matching_groups") \
            .update({
                "status": "waiting_attendance", 
                "updated_at": datetime.utcnow().isoformat()
            }) \
            .eq("id", group_id) \
            .execute()
        
        # 7. 更新所有成員狀態為等待參加聚餐
        status_updates = []
        current_time = datetime.utcnow().isoformat()
        
        for member_id in group_members:
            status_updates.append({
                "user_id": member_id,
                "status": "waiting_attendance",
                "updated_at": current_time
            })
        
        # 使用UPSERT批量更新用戶狀態
        if status_updates:
            supabase.table("user_status") \
                .upsert(status_updates, on_conflict="user_id") \
                .execute()
        
        # 8. 發送通知
        # 格式化聚餐時間顯示 - 跨平台解決方案
        try:
            # 嘗試使用Linux格式（沒有前導零）
            formatted_dinner_time = next_dinner_time.strftime("%-m月%-d日")
        except ValueError:
            # Windows平台回退方案
            month = next_dinner_time.month
            day = next_dinner_time.day
            formatted_dinner_time = f"{month}月{day}日"
        
        # 通知消息
        notification_title = "餐廳出爐！"
        if is_forced:
            notification_body = f"投票時間到！這次的餐廳是{restaurant_name}，期待{formatted_dinner_time}的聚餐歐！"
        else:
            notification_body = f"這次的餐廳是{restaurant_name}，期待{formatted_dinner_time}的聚餐歐！"
        
        notification_service = NotificationService(use_service_role=True)
        for member_id in group_members:
            try:
                await notification_service.send_notification(
                    user_id=member_id,
                    title=notification_title,
                    body=notification_body,
                    data={
                        "type": "dining_event_created",
                        "event_id": event_id,
                        "restaurant_id": restaurant_id
                    }
                )
            except Exception as ne:
                logger.error(f"發送通知給用戶 {member_id} 失敗: {str(ne)}")
        
        logger.info(f"群組 {group_id} 的聚餐事件 {event_id} 已成功創建")
        
        return {
            "success": True,
            "is_voting_complete": True,
            "dining_event_id": event_id,
            "winning_restaurant": restaurant_data,
            "selection_method": selection_method,
            "is_forced": is_forced
        }
        
    except Exception as e:
        logger.error(f"處理群組 {group_id} 投票時出錯: {str(e)}")
        return {
            "success": False,
            "message": f"處理出錯: {str(e)}"
        }

@router.get("/vote", response_model=List[RestaurantResponse])
async def get_group_restaurant_votes(
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    (應該會改成前端直接做)
    自動根據當前用戶ID查詢其所屬群組的餐廳投票
    返回所有被投票的餐廳完整資料列表
    按照票數多少排序，但不向前端返回票數信息
    只計算不是系統推薦(is_system_recommendation=false)的票數
    """
    try:
        user_id = current_user.user.id
        
        # 獲取用戶所屬的群組ID
        user_group = supabase.table("user_matching_info") \
            .select("matching_group_id") \
            .eq("user_id", user_id) \
            .execute()
            
        if not user_group.data or len(user_group.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="您尚未加入任何配對群組"
            )
        
        group_id = user_group.data[0]["matching_group_id"]
        
        # 獲取該群組的所有投票
        votes = supabase.table("restaurant_votes") \
            .select("restaurant_id, is_system_recommendation") \
            .eq("group_id", group_id) \
            .execute()
        
        if not votes.data:
            # 如果沒有投票，返回空列表
            return []
        
        # 計算每家餐廳的票數（僅計算非系統推薦的票數）
        restaurant_vote_counts = {}
        for vote in votes.data:
            # 只計算非系統推薦的投票
            is_system_recommendation = vote.get("is_system_recommendation", False)
            if is_system_recommendation is True:
                continue
                
            restaurant_id = vote["restaurant_id"]
            if restaurant_id not in restaurant_vote_counts:
                restaurant_vote_counts[restaurant_id] = 0
            restaurant_vote_counts[restaurant_id] += 1
        
        # 按票數排序餐廳ID
        sorted_restaurant_ids = sorted(
            restaurant_vote_counts.keys(),
            key=lambda rid: restaurant_vote_counts[rid],
            reverse=True
        )
        
        # 獲取所有餐廳的詳細信息
        restaurants = []
        for restaurant_id in sorted_restaurant_ids:
            restaurant = supabase.table("restaurants") \
                .select("*") \
                .eq("id", restaurant_id) \
                .execute()
            
            if restaurant.data and len(restaurant.data) > 0:
                restaurants.append(RestaurantResponse(**restaurant.data[0]))
        
        return restaurants
    
    except HTTPException as e:
        # 重新拋出HTTP異常
        raise e
    except Exception as e:
        logger.error(f"獲取群組餐廳投票時出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取群組餐廳投票時出錯: {str(e)}"
        )

@router.post("/finalize-votes", response_model=Dict[str, Any], status_code=status.HTTP_200_OK, dependencies=[Depends(verify_cron_api_key)])
async def finalize_restaurant_votes(
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_service)
):
    """
    定時觸發的API，用於處理未完成的餐廳投票階段
    - 檢查所有狀態為 waiting_restaurant 的群組
    - 對於每個群組，檢查投票是否已完成
    - 如果投票未完成，強制結束投票，使用現有投票或隨機選擇系統推薦的餐廳
    - 創建聚餐事件並發送通知
    """
    # 將任務放入背景執行，避免阻塞API響應
    background_tasks.add_task(process_finalize_votes, supabase)
    
    return {
        "success": True,
        "message": "餐廳投票強制結束任務已啟動"
    }

async def process_finalize_votes(supabase: Client):
    """處理強制結束餐廳投票的背景任務"""
    try:
        logger.info("開始執行餐廳投票強制結束任務")
        
        # 直接從matching_groups表中查詢狀態為waiting_restaurant的群組
        waiting_groups = supabase.table("matching_groups") \
            .select("id, user_ids") \
            .eq("status", "waiting_restaurant") \
            .execute()
            
        if not waiting_groups.data or len(waiting_groups.data) == 0:
            logger.info("沒有等待中的群組，任務結束")
            return
            
        group_ids = [group["id"] for group in waiting_groups.data]
        logger.info(f"找到 {len(group_ids)} 個需要處理的群組")
        
        # 處理每個群組的投票情況
        for group_id in group_ids:
            await process_group_voting(supabase, group_id, is_forced=True)
            
        logger.info("餐廳投票強制結束任務完成")
        
    except Exception as e:
        logger.error(f"處理餐廳投票強制結束任務時出錯: {str(e)}")

