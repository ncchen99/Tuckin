import re
import hashlib
import logging
from typing import Optional, Dict, Any, Tuple
from uuid import uuid4
from datetime import datetime
import io
from PIL import Image
import unicodedata

from config import GOOGLE_PLACES_API_KEY
from .cloudflare import get_r2_client
from api.utils.place_types import get_category_from_types

logger = logging.getLogger(__name__)

# 處理餐廳名稱用於比較
def normalize_restaurant_name(name: str) -> str:
    """
    將餐廳名稱標準化，移除特殊字符、空格和標點符號，轉換為小寫
    用於比較不同來源的餐廳名稱
    """
    if not name:
        return ""
    
    # 轉換為NFKC格式，處理Unicode變體
    name = unicodedata.normalize('NFKC', name)
    
    # 移除括號及其內容，例如"某餐廳 (台北店)"
    name = re.sub(r'\s*\([^)]*\)', '', name)
    
    # 移除常見連鎖店的分店名稱，例如"某餐廳台北店"或"某餐廳-信義店"
    name = re.sub(r'[分店|台北店|信義店|東區店|西門店|忠孝店|復興店|敦化店|南西店]$', '', name)
    name = re.sub(r'-[^-]*店$', '', name)
    
    # 移除所有空格和標點符號
    name = re.sub(r'[\s\-.,&\'\":!?@#$%^*()_+=[\]{}|\\/<>~`]+', '', name)
    
    # 轉為小寫
    return name.lower()

# 處理從Google Places API獲取的餐廳詳細資訊
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
    
    from .place_types import get_category_from_types
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

def are_restaurants_same(restaurant1: Dict[str, Any], restaurant2: Dict[str, Any]) -> bool:
    """
    判斷兩個餐廳是否為同一家餐廳
    比較Google Place ID、名稱和地址
    """
    # 若有Google Place ID，優先使用其比較
    if restaurant1.get("google_place_id") and restaurant2.get("google_place_id"):
        return restaurant1["google_place_id"] == restaurant2["google_place_id"]
    
    # 若無Google Place ID，則比較名稱和位置
    # 名稱必須匹配
    name1 = normalize_restaurant_name(restaurant1.get("name", ""))
    name2 = normalize_restaurant_name(restaurant2.get("name", ""))
    
    if not name1 or not name2 or name1 != name2:
        return False
    
    # 若有地址，比較地址
    if restaurant1.get("address") and restaurant2.get("address"):
        # 地址不需要完全相同，檢查一個是否包含在另一個中
        addr1 = restaurant1["address"].lower()
        addr2 = restaurant2["address"].lower()
        if addr1 in addr2 or addr2 in addr1:
            return True
    
    # 若有經緯度，比較距離
    if (restaurant1.get("latitude") and restaurant1.get("longitude") and 
        restaurant2.get("latitude") and restaurant2.get("longitude")):
        # 計算兩點之間的距離，如果小於100米，認為是同一家餐廳
        from math import radians, cos, sin, asin, sqrt
        
        def haversine(lat1, lon1, lat2, lon2):
            # 計算兩點間距離的函數（單位：米）
            R = 6371000  # 地球半徑（米）
            dLat = radians(lat2 - lat1)
            dLon = radians(lon2 - lon1)
            lat1 = radians(lat1)
            lat2 = radians(lat2)
            
            a = sin(dLat/2)**2 + cos(lat1) * cos(lat2) * sin(dLon/2)**2
            c = 2 * asin(sqrt(a))
            return R * c
            
        distance = haversine(
            restaurant1["latitude"], restaurant1["longitude"],
            restaurant2["latitude"], restaurant2["longitude"]
        )
        
        if distance < 100:  # 距離小於100米
            return True
    
    return False 