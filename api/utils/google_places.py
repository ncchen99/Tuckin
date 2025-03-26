import requests
from typing import Dict, Any, List, Optional

from config import GOOGLE_PLACES_API_KEY

# 搜索附近餐廳
async def search_nearby_restaurants(
    query: str,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius: int = 1000
) -> List[Dict[str, Any]]:
    """
    使用 Google Places API 搜索附近餐廳
    """
    try:
        # 基本 URL
        url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
        
        # 請求參數
        params = {
            "query": query,
            "type": "restaurant",
            "key": GOOGLE_PLACES_API_KEY
        }
        
        # 添加位置參數如果提供
        if latitude and longitude:
            params["location"] = f"{latitude},{longitude}"
            params["radius"] = radius
        
        # 發送請求
        response = requests.get(url, params=params)
        data = response.json()
        
        # 檢查回應狀態
        if data.get("status") != "OK":
            print(f"Google Places API 請求失敗: {data.get('status')}")
            return []
        
        # 處理結果
        restaurants = []
        for place in data.get("results", []):
            photo_reference = None
            if place.get("photos") and len(place["photos"]) > 0:
                photo_reference = place["photos"][0].get("photo_reference")
            
            restaurants.append({
                "name": place.get("name"),
                "place_id": place.get("place_id"),
                "address": place.get("formatted_address"),
                "latitude": place.get("geometry", {}).get("location", {}).get("lat"),
                "longitude": place.get("geometry", {}).get("location", {}).get("lng"),
                "rating": place.get("rating"),
                "photo_reference": photo_reference,
                "types": place.get("types", [])
            })
        
        return restaurants
    except Exception as e:
        print(f"搜索餐廳時發生錯誤: {e}")
        return []

# 獲取餐廳詳細資訊
async def get_place_details(place_id: str) -> Dict[str, Any]:
    """
    獲取 Google Places 餐廳詳細資訊
    """
    try:
        url = "https://maps.googleapis.com/maps/api/place/details/json"
        params = {
            "place_id": place_id,
            "fields": "name,formatted_address,formatted_phone_number,opening_hours,website,rating,price_level,photos,geometry",
            "key": GOOGLE_PLACES_API_KEY
        }
        
        response = requests.get(url, params=params)
        data = response.json()
        
        if data.get("status") != "OK":
            print(f"獲取餐廳詳細資訊失敗: {data.get('status')}")
            return {}
        
        return data.get("result", {})
    except Exception as e:
        print(f"獲取餐廳詳細資訊時發生錯誤: {e}")
        return {}

# 獲取餐廳照片
async def get_place_photo(photo_reference: str, max_width: int = 400) -> Optional[bytes]:
    """
    獲取 Google Places 餐廳照片
    """
    try:
        url = "https://maps.googleapis.com/maps/api/place/photo"
        params = {
            "photoreference": photo_reference,
            "maxwidth": max_width,
            "key": GOOGLE_PLACES_API_KEY
        }
        
        response = requests.get(url, params=params, stream=True)
        
        if response.status_code != 200:
            print(f"獲取餐廳照片失敗，狀態碼: {response.status_code}")
            return None
        
        return response.content
    except Exception as e:
        print(f"獲取餐廳照片時發生錯誤: {e}")
        return None 