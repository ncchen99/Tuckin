from fastapi import APIRouter, Depends, HTTPException, status, Query
from supabase import Client
from typing import List, Optional
import re
import httpx
import logging
from uuid import UUID, uuid4
from datetime import datetime
import urllib.parse
import time

from schemas.restaurant import RestaurantCreate, RestaurantResponse, RestaurantVote, RestaurantVoteCreate
from dependencies import get_supabase, get_current_user
from config import GOOGLE_PLACES_API_KEY
from utils.place_types import get_category_from_types

router = APIRouter()
logger = logging.getLogger(__name__)

# 從Google Map連結中提取place_id
def extract_place_id_from_url(url: str) -> Optional[str]:
    """
    從Google Map連結中提取place_id
    支持的格式:
    - https://www.google.com/maps/place/...?...&place_id=...
    - https://www.google.com/maps/place/.../@...!/...!1s...
    - https://maps.app.goo.gl/...
    - https://goo.gl/maps/...
    """
    try:
        logger.info(f"嘗試從URL提取place_id: {url}")
        
        # 標準格式: place_id=ChIJ...
        if "place_id=" in url:
            match = re.search(r'place_id=([^&]+)', url)
            if match:
                return match.group(1)
        
        # Google Maps 位置格式: !1s0x...
        # 例如: https://www.google.com/maps/place/.../@...!/data=!...!1s0x346e7695d97d83a3:0xcbb0a8bc6649d6ae!...
        place_id_match = re.search(r'!1s([0-9a-zA-Z]+:[0-9a-zA-Z]+)', url)
        if place_id_match:
            # 從格式 0x346e7695d97d83a3:0xcbb0a8bc6649d6ae 中提取 place_id
            raw_place_id = place_id_match.group(1)
            logger.info(f"從URL提取到原始place_id: {raw_place_id}")
            # 格式轉換為 ChIJ... 格式
            # 注意：此處僅提取ID部分，並不進行實際轉換
            # 實際使用時這個ID可以直接使用
            return raw_place_id
        
        # 短網址格式
        if any(x in url for x in ['goo.gl/maps', 'maps.app.goo.gl']):
            logger.info(f"處理短網址: {url}")
            # 需要追蹤重定向，但這裡使用同步方式
            try:
                with httpx.Client(follow_redirects=True, timeout=10.0) as client:
                    response = client.get(url)
                    final_url = str(response.url)
                    logger.info(f"短網址重定向到: {final_url}")
                    
                    # 從最終URL提取place_id
                    if "place_id=" in final_url:
                        match = re.search(r'place_id=([^&]+)', final_url)
                        if match:
                            return match.group(1)
                    
                    # 嘗試從經典格式提取
                    place_id_match = re.search(r'!1s([0-9a-zA-Z]+:[0-9a-zA-Z]+)', final_url)
                    if place_id_match:
                        return place_id_match.group(1)
                    
                    # 嘗試從CID提取
                    cid_match = re.search(r'cid=(\d+)', final_url)
                    if cid_match:
                        # 注意：CID是Google自己的標識符，不是place_id
                        # 但在某些情況下可能可以映射到place_id
                        cid = cid_match.group(1)
                        logger.info(f"從URL提取到CID: {cid}")
                        # 這裡我們先返回CID，可能需要另外一個API來轉換為place_id
                        # 臨時方案：將cid格式化為類似place_id的格式
                        return f"cid:{cid}"
            except Exception as redirect_error:
                logger.error(f"追蹤短網址重定向出錯: {str(redirect_error)}")
        
        # 嘗試從URL中找出CID (即使不是短網址)
        cid_match = re.search(r'cid=(\d+)', url)
        if cid_match:
            cid = cid_match.group(1)
            logger.info(f"從URL提取到CID: {cid}")
            return f"cid:{cid}"
        
        # 無法提取place_id
        logger.warning(f"無法從URL提取place_id: {url}")
        return None
    except Exception as e:
        logger.error(f"從URL提取place_id出錯: {str(e)}")
        return None

async def get_place_details(place_id: str) -> Optional[dict]:
    """
    使用Google Places API獲取地點詳細資訊，返回繁體中文內容
    """
    try:
        url = f"https://places.googleapis.com/v1/places/{place_id}?languageCode=zh-Hant"
        headers = {
            "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY,
            "X-Goog-FieldMask": "name,displayName,formattedAddress,location,businessStatus,types,rating,userRatingCount,photos,priceLevel,internationalPhoneNumber,websiteUri,regularOpeningHours"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            
            if response.status_code != 200:
                logger.error(f"Google Places API錯誤: {response.status_code} {response.text}")
                return None
                
            data = response.json()
            return data
    except Exception as e:
        logger.error(f"獲取地點詳細資訊出錯: {str(e)}")
        return None

async def search_place_by_text(text: str, lat: float = None, lng: float = None) -> Optional[str]:
    url = "https://places.googleapis.com/v1/places:searchText?languageCode=zh-Hant"
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY,
        "X-Goog-FieldMask": "places.id,places.displayName"
    }
    data = {
        "textQuery": text
    }
    if lat is not None and lng is not None:
        data["locationBias"] = {
            "circle": {
                "center": {"latitude": lat, "longitude": lng},
                "radius": 200.0  # 公尺
            }
        }
    async with httpx.AsyncClient(headers={"Cache-Control": "no-cache"}) as client:
        response = await client.post(url, headers=headers, json=data)
        if response.status_code != 200:
            logger.error(f"Google Places Text Search API錯誤: {response.status_code} {response.text}")
            return None
        result = response.json()
        if "places" in result and len(result["places"]) > 0:
            place_id = result["places"][0]["id"]
            logger.info(f"Text Search 找到地點: {result['places'][0].get('displayName', {}).get('text', '未知')}, ID: {place_id}")
            return place_id
        return None

async def search_place_by_location(lat: float, lng: float, name: Optional[str] = None) -> Optional[str]:
    """
    使用Google Places API的Nearby Search功能搜索指定位置附近的地點
    返回找到的第一個地點的place_id
    """
    try:
        # 如果有提供名稱，使用 Text Search 會更精確
        if name:
            logger.info(f"使用地點名稱搜尋優先: {name}")
            return await search_place_by_text(name)
        
        url = "https://places.googleapis.com/v1/places:searchNearby?languageCode=zh-Hant"
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY,
            "X-Goog-FieldMask": "places.id,places.displayName"
        }
        
        # 簡化請求正文
        data = {
            "locationRestriction": {
                "circle": {
                    "center": {
                        "latitude": lat,
                        "longitude": lng
                    },
                    "radius": 100.0
                }
            }
        }
        
        # 每次建立新的客戶端避免緩存問題
        async with httpx.AsyncClient(headers={"Cache-Control": "no-cache"}) as client:
            response = await client.post(url, headers=headers, json=data)
            if response.status_code != 200:
                logger.error(f"Google Places Nearby Search API錯誤: {response.status_code} {response.text}")
                return None
            
            result = response.json()
            if "places" in result and len(result["places"]) > 0:
                place_id = result["places"][0]["id"]
                logger.info(f"Nearby Search 找到地點: {result['places'][0].get('displayName', {}).get('text', '未知')}, ID: {place_id}")
                return place_id
            return None
    except Exception as e:
        logger.error(f"通過位置搜尋地點出錯: {str(e)}")
        return None

def extract_coordinates_from_url(url: str) -> Optional[tuple]:
    """
    從Google Maps URL提取經緯度
    支持的格式:
    - https://www.google.com/maps/place/.../@22.991359,120.2253762,17z/...
    """
    try:
        # 嘗試匹配 @緯度,經度,縮放級別z 的格式
        coords_match = re.search(r'@([-\d.]+),([-\d.]+)', url)
        if coords_match:
            lat = float(coords_match.group(1))
            lng = float(coords_match.group(2))
            logger.info(f"從URL提取到坐標: 緯度={lat}, 經度={lng}")
            return lat, lng
        return None
    except Exception as e:
        logger.error(f"從URL提取坐標出錯: {str(e)}")
        return None

def extract_place_name_from_url(url: str) -> Optional[str]:
    """
    從Google Maps URL提取地點名稱
    支持的格式:
    - https://www.google.com/maps/place/地點名稱/...
    """
    try:
        # 嘗試匹配 /place/地點名稱/ 的格式
        # 注意：這裡地點名稱可能是URL編碼的
        name_match = re.search(r'/place/([^/]+)/', url)
        if name_match:
            encoded_name = name_match.group(1)
            # URL解碼
            place_name = urllib.parse.unquote(encoded_name)
            logger.info(f"從URL提取到地點名稱: {place_name}")
            return place_name
        return None
    except Exception as e:
        logger.error(f"從URL提取地點名稱出錯: {str(e)}")
        return None

def expand_short_url_if_needed(url: str) -> str:
    """
    如果是短網址（goo.gl/maps 或 maps.app.goo.gl），展開取得完整 Google Maps URL。
    否則直接返回原始URL。
    """
    try:
        if any(x in url for x in ['goo.gl/maps', 'maps.app.goo.gl']):
            logger.info(f"開始展開短網址: {url}")
            # 設置隨機User-Agent避免緩存問題
            headers = {
                "User-Agent": f"Mozilla/5.0 TuckinApp/{uuid4().hex[:8]}",
                "Cache-Control": "no-cache, no-store, must-revalidate"
            }
            with httpx.Client(follow_redirects=True, timeout=10.0) as client:
                response = client.get(url, headers=headers)
                final_url = str(response.url)
                logger.info(f"短網址展開後的完整URL: {final_url}")
                return final_url
        return url
    except Exception as e:
        logger.error(f"展開短網址時出錯: {str(e)}")
        return url

@router.get("/search", response_model=List[RestaurantResponse])
async def search_restaurants(
    query: str,
    latitude: Optional[float] = Query(None),
    longitude: Optional[float] = Query(None),
    radius: Optional[int] = Query(1000),
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    搜索餐廳
    - 可以是文字查詢
    - 可以是Google Map連結（短網址或完整網址）
    """
    try:
        is_google_maps_link = any(x in query for x in ['maps.google.com', 'google.com/maps', 'goo.gl/maps', 'maps.app.goo.gl'])
        
        if is_google_maps_link:
            # 每次都生成一個唯一請求ID，用於日誌追蹤
            request_id = uuid4().hex[:8]
            logger.info(f"[{request_id}] 開始處理Google Maps連結: {query}")
            
            # 先展開短網址取得完整URL
            full_url = expand_short_url_if_needed(query)
            if full_url != query:
                logger.info(f"[{request_id}] 短網址已展開: {full_url}")
            
            valid_place_id = None
            original_place_id = extract_place_id_from_url(full_url)
            logger.info(f"[{request_id}] 提取的ID: {original_place_id}")
            
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
            
            if not valid_place_id:
                logger.info(f"[{request_id}] 使用 Text Search 名稱+經緯度 fallback")
                coordinates = extract_coordinates_from_url(full_url)
                place_name = extract_place_name_from_url(full_url)
                if coordinates and place_name:
                    valid_place_id = await search_place_by_text(place_name, coordinates[0], coordinates[1])
                elif place_name:
                    valid_place_id = await search_place_by_text(place_name)
            
            if not valid_place_id:
                logger.warning(f"[{request_id}] 使用所有方法都無法獲取有效的地點ID。原始URL: {full_url}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="無法從Google Map連結提取地點ID，請嘗試使用餐廳名稱搜尋"
                )
            
            logger.info(f"[{request_id}] 最終使用的有效place_id: {valid_place_id}")
            
            # 先檢查資料庫中是否已有該餐廳
            existing_restaurant = supabase.table("restaurants") \
                .select("*") \
                .eq("google_place_id", valid_place_id) \
                .execute()
            
            if existing_restaurant.data and len(existing_restaurant.data) > 0:
                logger.info(f"[{request_id}] 餐廳已存在於資料庫: {valid_place_id}, 名稱: {existing_restaurant.data[0].get('name', '未知')}")
                return [RestaurantResponse(**existing_restaurant.data[0])]
            
            # 獲取餐廳詳細資訊
            place_details = await get_place_details(valid_place_id)
            if not place_details:
                logger.error(f"[{request_id}] 無法從Google Places API獲取地點詳情: {valid_place_id}")
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="無法獲取Google地點詳細資訊"
                )
            
            # 取繁體中文名稱、地址、主要類型
            zh_name = place_details.get("displayName", {}).get("text", "")
            zh_address = place_details.get("formattedAddress", "")
            types = place_details.get("types", [])
            category = get_category_from_types(types)
            
            restaurant_data = {
                "id": str(uuid4()),
                "name": zh_name,
                "category": category,
                "description": None,
                "address": zh_address,
                "latitude": place_details.get("location", {}).get("latitude"),
                "longitude": place_details.get("location", {}).get("longitude"),
                "image_path": place_details.get("photos", [{}])[0].get("name", "") if place_details.get("photos") else None,
                "business_hours": str(place_details.get("regularOpeningHours", {})) if place_details.get("regularOpeningHours") else None,
                "google_place_id": valid_place_id,
                "created_at": datetime.utcnow().isoformat()
            }
            
            logger.info(f"[{request_id}] 從Google Places API成功獲取餐廳資訊: {restaurant_data['name']}")
            return [RestaurantResponse(**restaurant_data)]
        else:
            response = supabase.table("restaurants") \
                .select("*") \
                .ilike("name", f"%{query}%") \
                .execute()
            if not response.data:
                return []
            return [RestaurantResponse(**restaurant) for restaurant in response.data]
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
    supabase: Client = Depends(get_supabase),
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
    supabase: Client = Depends(get_supabase),
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
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    對餐廳進行投票
    """
    pass

@router.get("/group/{group_id}/votes", response_model=List[RestaurantVote])
async def get_group_restaurant_votes(
    group_id: str,
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取群組中的餐廳投票
    """
    pass 