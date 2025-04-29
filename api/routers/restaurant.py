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
import boto3
import io
import hashlib
import asyncio
from PIL import Image
from config import GOOGLE_PLACES_API_KEY, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT_URL, R2_BUCKET_NAME, R2_PUBLIC_URL

from schemas.restaurant import RestaurantCreate, RestaurantResponse, RestaurantVote, RestaurantVoteCreate
from dependencies import get_supabase, get_supabase_service, get_current_user
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

def format_phone_to_taiwan_format(international_phone: Optional[str]) -> Optional[str]:
    """
    將國際電話號碼格式轉換為台灣本地格式
    例如: +886 2 1234 5678 -> 02-1234-5678
         +886 912 345 678 -> 0912-345-678
    """
    if not international_phone:
        return None
        
    # 去除所有空格
    phone = international_phone.replace(" ", "")
    
    # 檢查是否是台灣國際格式 (+886)
    if phone.startswith("+886"):
        # 移除+886前綴
        local_number = phone[4:]
        
        # 添加前導0
        local_number = "0" + local_number
        
        # 判斷是手機還是市話
        if local_number.startswith("09"):
            # 手機號碼格式化: 0912-345-678
            if len(local_number) >= 10:
                return f"{local_number[0:4]}-{local_number[4:7]}-{local_number[7:]}"
        else:
            # 市話格式化，區碼可能是2-3位
            # 先假設區碼是2位 (如台北02)
            if len(local_number) >= 9:
                area_code = local_number[0:2]
                remaining = local_number[2:]
                
                # 如果剩餘號碼長度是8位，則使用標準格式 XX-XXXX-XXXX
                if len(remaining) == 8:
                    return f"{area_code}-{remaining[0:4]}-{remaining[4:]}"
                # 如果不是8位，則簡單用連字符分隔區碼和號碼
                return f"{area_code}-{remaining}"
                
            # 假設區碼是3位 (如新竹03)
            elif len(local_number) >= 10:
                area_code = local_number[0:3]
                remaining = local_number[3:]
                
                # 如果剩餘號碼長度是7位，使用標準格式 XXX-XXX-XXXX
                if len(remaining) == 7:
                    return f"{area_code}-{remaining[0:3]}-{remaining[3:]}"
                # 其他情況
                return f"{area_code}-{remaining}"
    
    # 如果不是台灣國際格式或無法解析，則返回原始格式
    return international_phone

# 初始化R2客戶端
def get_r2_client():
    return boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT_URL,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY
    )

# 處理餐廳名稱用於比較
def normalize_restaurant_name(name: str) -> str:
    """
    標準化餐廳名稱以便比較：轉小寫、去除空格和標點符號
    """
    if not name:
        return ""
    # 轉小寫
    name = name.lower()
    # 去除空格和常見標點符號
    name = re.sub(r'[\s.,\-&\'"]', '', name)
    return name

# 從Google Places API下載圖片並上傳到R2
async def download_and_upload_photo(photo_reference: str) -> Optional[str]:
    """
    從Google Places API下載圖片並上傳到Cloudflare R2
    返回R2中的圖片URL
    """
    try:
        if not photo_reference:
            return None
            
        # 創建唯一的圖片ID
        photo_id = hashlib.md5(photo_reference.encode()).hexdigest()
        file_name = f"restaurants/{photo_id}.jpg"
        
        # 檢查R2中是否已存在此圖片
        r2_client = get_r2_client()
        try:
            r2_client.head_object(Bucket=R2_BUCKET_NAME, Key=file_name)
            # 如果沒有拋出異常，說明圖片已存在
            logger.info(f"圖片已存在於R2: {file_name}")
            # 使用公開URL而不是內部URL
            return f"{R2_PUBLIC_URL}/{file_name}"
        except Exception:
            # 圖片不存在，需要下載並上傳
            logger.info(f"圖片不存在於R2，將下載並上傳: {photo_reference}")
        
        # 從Google Places API下載圖片
        photo_url = f"https://places.googleapis.com/v1/{photo_reference}/media?maxHeightPx=1200&maxWidthPx=1200&key={GOOGLE_PLACES_API_KEY}"
        
        async with httpx.AsyncClient(follow_redirects=True) as client:
            response = await client.get(photo_url)
            
            if response.status_code != 200:
                # 檢查是否包含重定向URL
                try:
                    response_data = response.json()
                    if 'photoUri' in response_data:
                        # 使用返回的真實圖片URL
                        real_photo_url = response_data['photoUri']
                        logger.info(f"使用API返回的圖片URL: {real_photo_url}")
                        
                        # 使用返回的URL下載圖片
                        photo_response = await client.get(real_photo_url)
                        if photo_response.status_code == 200:
                            image_data = photo_response.content
                        else:
                            logger.error(f"從真實URL下載圖片失敗: {photo_response.status_code}")
                            return None
                    else:
                        logger.error(f"下載圖片失敗: {response.status_code} {response.text}")
                        return None
                except Exception as e:
                    logger.error(f"解析圖片API響應出錯: {str(e)}")
                    return None
            else:
                image_data = response.content
            
            # 壓縮圖片
            compressed_image_data = compress_image(image_data)
            
            # 上傳到R2
            r2_client.put_object(
                Bucket=R2_BUCKET_NAME,
                Key=file_name,
                Body=io.BytesIO(compressed_image_data),
                ContentType="image/jpeg"
            )
            
            logger.info(f"圖片已壓縮並上傳到R2: {file_name}")
            # 使用公開URL而不是內部URL
            return f"{R2_PUBLIC_URL}/{file_name}"
            
    except Exception as e:
        logger.error(f"處理圖片時出錯: {str(e)}")
        return None

def compress_image(image_data: bytes) -> bytes:
    """
    壓縮圖片：
    1. 調整尺寸至最大1024x1024像素
    2. 設置JPEG壓縮質量為80%
    """
    try:
        # 打開圖片
        image = Image.open(io.BytesIO(image_data))
        
        # 獲取原始尺寸
        width, height = image.size
        
        # 如果圖片尺寸超過1024x1024，則等比例縮小
        max_size = 1024
        if width > max_size or height > max_size:
            # 計算等比例縮放後的尺寸
            if width > height:
                new_width = max_size
                new_height = int(max_size * height / width)
            else:
                new_height = max_size
                new_width = int(max_size * width / height)
                
            # 調整圖片尺寸
            image = image.resize((new_width, new_height), Image.LANCZOS)
            logger.info(f"圖片已調整尺寸: {width}x{height} -> {new_width}x{new_height}")
        
        # 轉換為RGB模式（某些圖片可能是RGBA或其他模式）
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # 保存為JPEG，質量為80%
        output = io.BytesIO()
        image.save(output, format='JPEG', quality=80, optimize=True)
        compressed_data = output.getvalue()
        
        logger.info(f"圖片已壓縮: 原始大小={len(image_data)}字節, 壓縮後={len(compressed_data)}字節, 壓縮率={(1-len(compressed_data)/len(image_data))*100:.2f}%")
        return compressed_data
    except Exception as e:
        logger.error(f"壓縮圖片時出錯: {str(e)}")
        # 如果壓縮失敗，返回原始圖片
        return image_data

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

async def process_place_details(place_id: str, place_details: dict, request_id: str) -> dict:
    """
    處理從Google Places API獲取的餐廳詳細資訊
    下載和處理圖片，並返回餐廳資料
    """
    # 取繁體中文名稱、地址、主要類型
    zh_name = place_details.get("displayName", {}).get("text", "")
    zh_address = place_details.get("formattedAddress", "")
    
    # 處理地址：移除郵遞區號和"臺灣"、"台灣"字樣
    if zh_address:
        # 移除郵遞區號（開頭的3-6位數字，可能有空格也可能無空格）
        zh_address = re.sub(r'^(\d{3,6})\s*', '', zh_address)
        # 移除"臺灣"或"台灣"字樣，無論位於地址開頭還是中間
        zh_address = re.sub(r'[台臺]灣[省市]?[,\s]*', '', zh_address)
        # 移除縣市後的"市"或"縣"字樣，讓地址更簡短
        # zh_address = re.sub(r'(市|縣)[,\s]*', '', zh_address)
        # 去除可能的前後空白
        zh_address = zh_address.strip()
        logger.info(f"[{request_id}] 處理後的地址: {zh_address}")
    
    types = place_details.get("types", [])
    category = get_category_from_types(types)
    
    # 提取電話號碼並轉換為台灣本地格式
    international_phone = place_details.get("internationalPhoneNumber")
    phone = format_phone_to_taiwan_format(international_phone)
    
    # 提取網站，優先順序：商家網頁 > Google Maps連結
    website = None
    if place_details.get("websiteUri"):
        website = place_details.get("websiteUri")
        logger.info(f"[{request_id}] 使用商家網站: {website}")
    else:
        website = f"https://www.google.com/maps/place/?q=place_id:{place_id}"
        logger.info(f"[{request_id}] 使用Google Maps連結: {website}")
    
    # 處理圖片 - 簡化邏輯，先返回None，後續再異步處理
    image_path = None
    
    restaurant_data = {
        "id": str(uuid4()),
        "name": zh_name,
        "category": category,
        "description": None,
        "address": zh_address,
        "latitude": place_details.get("location", {}).get("latitude"),
        "longitude": place_details.get("location", {}).get("longitude"),
        "image_path": image_path,
        "business_hours": str(place_details.get("regularOpeningHours", {})) if place_details.get("regularOpeningHours") else None,
        "google_place_id": place_id,
        "is_user_added": True,  # 設為True表示是通過搜尋添加的餐廳
        "phone": phone,
        "website": website,
        "created_at": datetime.utcnow().isoformat()
    }
    
    logger.info(f"[{request_id}] 從Google Places API成功獲取餐廳資訊: {restaurant_data['name']}")
    return restaurant_data

async def process_and_update_image(photo_reference: str, restaurant_id: str, supabase: Client, request_id: str):
    """
    下載、壓縮並上傳圖片，然後更新資料庫中餐廳的圖片路徑
    此函數用於非同步處理圖片，不阻塞API響應
    """
    try:
        logger.info(f"[{request_id}] 開始非同步處理圖片: {photo_reference}")
        
        # 下載並上傳圖片到R2
        image_path = await download_and_upload_photo(photo_reference)
        
        if not image_path:
            logger.error(f"[{request_id}] 圖片處理失敗，無法更新資料庫")
            return
            
        logger.info(f"[{request_id}] 圖片處理完成，更新資料庫: {image_path}")
        
        # 更新資料庫中的餐廳圖片路徑
        supabase.table("restaurants") \
            .update({"image_path": image_path}) \
            .eq("id", restaurant_id) \
            .execute()
            
        logger.info(f"[{request_id}] 資料庫已更新餐廳圖片路徑")
        
    except Exception as e:
        logger.error(f"[{request_id}] 非同步處理圖片時出錯: {str(e)}")
    

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