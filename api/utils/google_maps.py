import re
import httpx
import logging
from typing import Optional, Tuple
import urllib.parse
from config import GOOGLE_PLACES_API_KEY

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

def extract_coordinates_from_url(url: str) -> Optional[Tuple[float, float]]:
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
            from uuid import uuid4
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