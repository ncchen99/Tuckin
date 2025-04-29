import logging
import httpx
import json
from typing import Dict, List, Any, Optional
from tenacity import retry, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

# Google Places API 基礎URL
PLACES_BASE_URL = "https://maps.googleapis.com/maps/api/place"
PLACES_API_KEY = None  # 將在使用時通過環境變量注入

def set_api_key(api_key: str) -> None:
    """
    設置用於Places API請求的Google API金鑰
    
    Args:
        api_key: Google API金鑰
    """
    global PLACES_API_KEY
    PLACES_API_KEY = api_key

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def find_place(place_name: str, location: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """
    使用Google Places API尋找特定名稱的場所
    
    Args:
        place_name: 要搜索的場所名稱
        location: 可選的位置坐標 (lat,lng) 和半徑 (meters)，例如 "25.0330,121.5654,1000"
    
    Returns:
        找到的場所詳情，如果未找到或出錯則返回None
    """
    if not PLACES_API_KEY:
        logger.error("Google Places API金鑰未設置")
        return None
    
    # 構建基本參數
    params = {
        "input": place_name,
        "inputtype": "textquery",
        "fields": "place_id,name,formatted_address,geometry,types,opening_hours,price_level,rating",
        "key": PLACES_API_KEY
    }
    
    # 如果提供了位置，添加位置偏置
    if location:
        try:
            lat, lng, radius = location.split(",")
            params["locationbias"] = f"circle:{radius}@{lat},{lng}"
        except ValueError:
            logger.warning("無效的位置格式，應為 'lat,lng,radius'")
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{PLACES_BASE_URL}/findplacefromtext/json", params=params)
            response.raise_for_status()
            data = response.json()
            
            if data["status"] == "OK" and data["candidates"]:
                # 返回第一個結果
                return data["candidates"][0]
            else:
                logger.warning(f"尋找場所失敗: {data['status']} - {place_name}")
                return None
    
    except Exception as e:
        logger.error(f"尋找場所請求出錯: {str(e)}")
        return None

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def get_place_details(place_id: str) -> Optional[Dict[str, Any]]:
    """
    使用Google Places API獲取場所詳細信息
    
    Args:
        place_id: Google Places API的場所ID
    
    Returns:
        場所詳細信息，如果未找到或出錯則返回None
    """
    if not PLACES_API_KEY:
        logger.error("Google Places API金鑰未設置")
        return None
    
    fields = [
        "place_id", "name", "formatted_address", "formatted_phone_number",
        "international_phone_number", "website", "rating", "user_ratings_total",
        "price_level", "opening_hours", "geometry", "types", "photos", 
        "address_components", "editorial_summary", "reviews", "url"
    ]
    
    params = {
        "place_id": place_id,
        "fields": ",".join(fields),
        "key": PLACES_API_KEY
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{PLACES_BASE_URL}/details/json", params=params)
            response.raise_for_status()
            data = response.json()
            
            if data["status"] == "OK":
                return data["result"]
            else:
                logger.warning(f"獲取場所詳情失敗: {data['status']} - {place_id}")
                return None
    
    except Exception as e:
        logger.error(f"獲取場所詳情請求出錯: {str(e)}")
        return None

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def nearby_search(
    location: str, 
    radius: int = 1000, 
    type: str = "restaurant", 
    keyword: Optional[str] = None,
    page_token: Optional[str] = None
) -> Optional[Dict[str, Any]]:
    """
    使用Google Places API進行附近地點搜索
    
    Args:
        location: 位置坐標 (lat,lng)，例如 "25.0330,121.5654"
        radius: 搜索半徑，以米為單位
        type: 場所類型，例如 "restaurant"
        keyword: 可選的關鍵字
        page_token: 可選的下一頁令牌
    
    Returns:
        附近場所列表，如果出錯則返回None
    """
    if not PLACES_API_KEY:
        logger.error("Google Places API金鑰未設置")
        return None
    
    params = {
        "key": PLACES_API_KEY
    }
    
    # 如果有頁面令牌，使用頁面令牌
    if page_token:
        params["pagetoken"] = page_token
    # 否則使用正常搜索參數
    else:
        params.update({
            "location": location,
            "radius": radius,
            "type": type
        })
        
        if keyword:
            params["keyword"] = keyword
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{PLACES_BASE_URL}/nearbysearch/json", params=params)
            response.raise_for_status()
            return response.json()
    
    except Exception as e:
        logger.error(f"附近搜索請求出錯: {str(e)}")
        return None

async def get_photo(photo_reference: str, max_width: int = 800) -> Optional[bytes]:
    """
    使用Google Places API獲取場所照片
    
    Args:
        photo_reference: 照片參考ID
        max_width: 照片的最大寬度
    
    Returns:
        照片的二進制數據，如果出錯則返回None
    """
    if not PLACES_API_KEY:
        logger.error("Google Places API金鑰未設置")
        return None
    
    params = {
        "photoreference": photo_reference,
        "maxwidth": max_width,
        "key": PLACES_API_KEY
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{PLACES_BASE_URL}/photo", params=params, follow_redirects=True)
            response.raise_for_status()
            return response.content
    
    except Exception as e:
        logger.error(f"獲取照片出錯: {str(e)}")
        return None

async def search_by_text(
    query: str, 
    location: Optional[str] = None, 
    radius: int = 5000,
    language: str = "zh-TW"
) -> Optional[Dict[str, Any]]:
    """
    使用Google Places API進行文本搜索
    
    Args:
        query: 搜索查詢字符串
        location: 可選的位置坐標 (lat,lng)
        radius: 搜索半徑，以米為單位
        language: 響應語言
    
    Returns:
        搜索結果，如果出錯則返回None
    """
    if not PLACES_API_KEY:
        logger.error("Google Places API金鑰未設置")
        return None
    
    params = {
        "query": query,
        "key": PLACES_API_KEY,
        "language": language
    }
    
    if location:
        params["location"] = location
        params["radius"] = radius
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{PLACES_BASE_URL}/textsearch/json", params=params)
            response.raise_for_status()
            return response.json()
    
    except Exception as e:
        logger.error(f"文本搜索請求出錯: {str(e)}")
        return None

async def fetch_restaurant_data(place_id: str) -> Optional[Dict[str, Any]]:
    """
    獲取餐廳的完整數據，包括詳細信息和照片
    
    Args:
        place_id: Google Places API的場所ID
    
    Returns:
        餐廳數據字典，包括基本信息和照片URLs
    """
    # 獲取場所詳情
    place_details = await get_place_details(place_id)
    if not place_details:
        return None
    
    # 提取基本信息
    restaurant_data = {
        "place_id": place_details.get("place_id"),
        "name": place_details.get("name"),
        "address": place_details.get("formatted_address"),
        "phone": place_details.get("formatted_phone_number"),
        "website": place_details.get("website"),
        "google_maps_url": place_details.get("url"),
        "rating": place_details.get("rating"),
        "user_ratings_total": place_details.get("user_ratings_total"),
        "price_level": place_details.get("price_level"),
        "types": place_details.get("types", []),
        "latitude": place_details.get("geometry", {}).get("location", {}).get("lat"),
        "longitude": place_details.get("geometry", {}).get("location", {}).get("lng"),
    }
    
    # 提取營業時間
    if "opening_hours" in place_details:
        restaurant_data["opening_hours"] = place_details["opening_hours"].get("weekday_text", [])
        restaurant_data["is_open_now"] = place_details["opening_hours"].get("open_now", False)
    
    # 提取簡介
    if "editorial_summary" in place_details:
        restaurant_data["description"] = place_details["editorial_summary"].get("overview", "")
    
    # 添加照片參考
    if "photos" in place_details:
        restaurant_data["photo_references"] = [
            photo.get("photo_reference") for photo in place_details["photos"] if "photo_reference" in photo
        ]
    
    return restaurant_data 