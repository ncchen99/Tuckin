from fastapi import APIRouter, Depends, HTTPException, status, Query
from supabase import Client
from typing import List, Optional
import asyncio
from uuid import UUID, uuid4
from datetime import datetime
import logging

from schemas.restaurant import RestaurantCreate, RestaurantResponse, RestaurantVote, RestaurantVoteCreate
from dependencies import get_supabase, get_supabase_service, get_current_user
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
    process_and_update_image
)

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
            photo_reference = place_details.get("photos")[0].get("name", "")
            if photo_reference:
                # 使用異步任務處理圖片，不阻塞API響應
                process_image_task = asyncio.create_task(
                    process_and_update_image(photo_reference, restaurant_data["id"], supabase, request_id)
                )
        
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
    vote: RestaurantVoteCreate,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    對餐廳進行投票
    """
    pass

@router.get("/group/{group_id}/votes", response_model=List[RestaurantVote])
async def get_group_restaurant_votes(
    group_id: str,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    獲取群組中的餐廳投票
    """
    pass 