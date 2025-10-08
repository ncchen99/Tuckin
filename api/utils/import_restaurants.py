"""
餐廳資料導入腳本
從餐廳清單.md文件中導入所有餐廳到資料庫

執行方式:
python -m api.utils.import_restaurants
"""

import os
import asyncio
import logging
import uuid
import re
import httpx
from datetime import datetime
from uuid import uuid4
from typing import Optional, Dict, Any, List, Tuple
from dotenv import load_dotenv

# 配置日誌記錄
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 添加檔案日誌記錄
os.makedirs('logs', exist_ok=True)
file_handler = logging.FileHandler(f'logs/restaurant_import_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log', encoding='utf-8')
file_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(file_handler)

# 創建失敗餐廳的專門日誌
failed_logger = logging.getLogger('failed_restaurants')
failed_logger.setLevel(logging.INFO)
failed_handler = logging.FileHandler('logs/failed_restaurants.log', encoding='utf-8')
failed_handler.setFormatter(logging.Formatter('%(asctime)s - %(message)s'))
failed_logger.addHandler(failed_handler)

# 載入環境變數
load_dotenv()

# 定義必要的環境變數
GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

# 檢查環境變數
if not GOOGLE_PLACES_API_KEY:
    logger.error("未設置 GOOGLE_PLACES_API_KEY 環境變數，無法繼續執行")
    exit(1)

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    logger.error("未設置 Supabase 環境變數，無法繼續執行")
    exit(1)

# 導入 Supabase 客戶端
from supabase import create_client, Client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# 導入圖片處理相關函數
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from utils.image_processor import download_and_upload_photo

# 餐廳清單檔案路徑
RESTAURANT_LIST_PATH = "docs/產品設計/餐廳清單.md"

# 實現必要的函數，避免導入問題
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
        logger.debug(f"嘗試從URL提取place_id: {url}")
        
        # 標準格式: place_id=ChIJ...
        if "place_id=" in url:
            match = re.search(r'place_id=([^&]+)', url)
            if match:
                place_id = match.group(1)
                logger.debug(f"從URL提取到標準place_id: {place_id}")
                return place_id
        
        return None
    except Exception as e:
        logger.error(f"從URL提取place_id出錯: {str(e)}")
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
        import urllib.parse
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

async def search_place_by_text(text: str, lat: float = None, lng: float = None) -> Optional[str]:
    """使用 Text Search API 搜索地點，返回place_id"""
    try:
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
        async with httpx.AsyncClient() as client:
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
    except Exception as e:
        logger.error(f"使用 Text Search API 搜索地點出錯: {str(e)}")
        return None

async def get_place_details(place_id: str) -> Optional[dict]:
    """使用Google Places API獲取地點詳細資訊，返回繁體中文內容"""
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

def format_phone_to_taiwan_format(phone: Optional[str]) -> Optional[str]:
    """將國際電話號碼格式化為台灣本地格式"""
    if not phone:
        return None
        
    # 移除所有非數字字符
    digits_only = re.sub(r'\D', '', phone)
    
    # 如果是台灣手機號碼 (+886 開頭的國際格式)
    if digits_only.startswith('886') and len(digits_only) >= 11:
        # 轉換 +886 912 345 678 為 0912 345 678
        local_number = '0' + digits_only[3:]
        return local_number
    
    # 如果是台灣市話號碼，例如 +886 2 1234 5678
    elif digits_only.startswith('886') and len(digits_only) >= 10:
        # 轉換 +886 2 1234 5678 為 (02) 1234-5678
        area_code = digits_only[3:5]  # 假設區碼是2位數
        if area_code.startswith('2'):  # 台北區碼
            return f'(0{area_code}) {digits_only[5:9]}-{digits_only[9:]}'
        else:
            # 其他區域區碼可能為 3 位數，例如 037
            area_code = digits_only[3:6]
            return f'(0{area_code}) {digits_only[6:]} '
    
    # 如果已經是台灣本地格式（以0開頭）
    elif digits_only.startswith('0'):
        return digits_only
    
    # 其他情況，保持原樣
    return phone

async def process_place_details(place_id: str, place_details: dict, request_id: str) -> dict:
    """
    處理從Google Places API獲取的餐廳詳細資訊
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
        # 去除可能的前後空白
        zh_address = zh_address.strip()
        logger.info(f"[{request_id}] 處理後的地址: {zh_address}")
    
    # 此處使用預設類別而不是從類型中獲取，因為我們之後會用傳入的類別覆蓋
    category = "餐廳"
    
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
    
    # 處理圖片 - 初始化為None，後續在資料儲存前再處理
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
        "is_user_added": True,  # 將在調用函數中覆蓋
        "phone": phone,
        "website": website,
        "created_at": datetime.utcnow().isoformat()
    }
    
    logger.info(f"[{request_id}] 從Google Places API成功獲取餐廳資訊: {restaurant_data['name']}")
    return restaurant_data

async def import_restaurant(url: str, category: str) -> bool:
    """
    導入單個餐廳到資料庫
    
    Args:
        url: Google Maps 餐廳連結
        category: 餐廳類別
        
    Returns:
        bool: 是否成功導入
    """
    try:
        # 生成唯一請求ID用於日誌追踪
        request_id = uuid.uuid4().hex[:8]
        logger.info(f"[{request_id}] 開始處理餐廳: {url}, 類別: {category}")
        
        # 展開短網址
        full_url = expand_short_url_if_needed(url)
        if full_url != url:
            logger.info(f"[{request_id}] 短網址已展開: {full_url}")
            
        # 先嘗試從URL直接提取place_id
        valid_place_id = None
        original_place_id = extract_place_id_from_url(full_url)
        
        # 如果直接提取成功並且是標準格式
        if original_place_id and not original_place_id.startswith("0x") and ":" not in original_place_id:
            logger.info(f"[{request_id}] 使用標準格式place_id: {original_place_id}")
            valid_place_id = original_place_id
            
            # 檢查是否已存在於資料庫
            existing_restaurant = supabase.table("restaurants") \
                .select("*") \
                .eq("google_place_id", valid_place_id) \
                .execute()
                
            if existing_restaurant.data and len(existing_restaurant.data) > 0:
                logger.info(f"[{request_id}] 餐廳已存在於資料庫: {existing_restaurant.data[0].get('name', '未知')}, place_id: {valid_place_id}")
                return False
                
        # 如果直接提取失敗，使用Text Search搜尋
        if not valid_place_id:
            # 嘗試提取餐廳名稱
            place_name = extract_place_name_from_url(full_url)
            coordinates = extract_coordinates_from_url(full_url)
            
            if place_name:
                logger.info(f"[{request_id}] 從URL提取的名稱: {place_name}")
                if coordinates:
                    logger.info(f"[{request_id}] 使用 Text Search 名稱+經緯度搜尋")
                    valid_place_id = await search_place_by_text(place_name, coordinates[0], coordinates[1])
                else:
                    logger.info(f"[{request_id}] 使用 Text Search 僅名稱搜尋")
                    valid_place_id = await search_place_by_text(place_name)
                    
                if valid_place_id:
                    # 再次檢查是否已存在於資料庫
                    existing_restaurant = supabase.table("restaurants") \
                        .select("*") \
                        .eq("google_place_id", valid_place_id) \
                        .execute()
                        
                    if existing_restaurant.data and len(existing_restaurant.data) > 0:
                        logger.info(f"[{request_id}] 餐廳已存在於資料庫: {existing_restaurant.data[0].get('name', '未知')}, place_id: {valid_place_id}")
                        return False
        
        if not valid_place_id:
            logger.warning(f"[{request_id}] 使用所有方法都無法獲取有效的地點ID: {url}")
            failed_logger.info(f"無法獲取地點ID, URL: {url}, 類別: {category}")
            return False
        
        logger.info(f"[{request_id}] 最終使用的有效place_id: {valid_place_id}")
        
        # 從 Google Places API 獲取餐廳詳細資訊
        place_details = await get_place_details(valid_place_id)
        if not place_details:
            logger.error(f"[{request_id}] 無法從 Google Places API 獲取地點詳情: {valid_place_id}")
            failed_logger.info(f"無法獲取地點詳情, URL: {url}, place_id: {valid_place_id}, 類別: {category}")
            return False
            
        # 處理餐廳資料
        restaurant_data = await process_place_details(valid_place_id, place_details, request_id)
        
        # 手動設置特定欄位
        restaurant_data["is_user_added"] = False  # 標記為系統添加
        restaurant_data["category"] = category  # 使用傳入的類別，而非 Google API 提供的類別
        restaurant_data["created_at"] = datetime.utcnow().isoformat()
        
        # 如果有圖片，同步處理並保存圖片URL
        if place_details.get("photos") and len(place_details.get("photos")) > 0:
            photo = place_details.get("photos")[0]
            photo_reference = None
            
            if "name" in photo:
                photo_reference = photo.get("name")
            elif "photoReference" in photo:
                # 舊版API格式
                photo_reference = photo.get("photoReference")
                
            if photo_reference:
                logger.info(f"[{request_id}] 開始非同步處理和保存圖片...")
                image_url = await download_and_upload_photo(photo_reference)
                if image_url:
                    logger.info(f"[{request_id}] 圖片處理成功，更新餐廳圖片路徑: {image_url}")
                    restaurant_data["image_path"] = image_url
                else:
                    logger.warning(f"[{request_id}] 圖片處理失敗")
        
        # 保存到資料庫
        result = supabase.table("restaurants").insert(restaurant_data).execute()
        
        if result.data and len(result.data) > 0:
            logger.info(f"[{request_id}] 餐廳保存成功: {restaurant_data['name']}, place_id: {valid_place_id}")
            return True
        else:
            logger.error(f"[{request_id}] 餐廳保存失敗")
            failed_logger.info(f"數據庫保存失敗, URL: {url}, 名稱: {restaurant_data.get('name', '未知')}, 類別: {category}")
            return False
            
    except Exception as e:
        logger.error(f"處理餐廳時出錯: {url}, 錯誤: {str(e)}")
        failed_logger.info(f"處理出錯, URL: {url}, 類別: {category}, 錯誤: {str(e)}")
        return False

async def parse_restaurant_list():
    """
    解析餐廳清單文件並導入餐廳
    """
    try:
        # 檢查文件是否存在
        if not os.path.exists(RESTAURANT_LIST_PATH):
            logger.error(f"餐廳清單文件不存在: {RESTAURANT_LIST_PATH}")
            return
            
        # 讀取餐廳清單文件
        with open(RESTAURANT_LIST_PATH, 'r', encoding='utf-8') as file:
            content = file.read()
            
        # 分割為不同的類別章節
        sections = re.split(r'## (.+)', content)
        
        # 第一個元素是空的，之後的元素是交替的類別名稱和內容
        total_count = 0
        success_count = 0
        failed_urls = []
        
        # 從索引1開始，每兩個元素為一組 (類別名稱和內容)
        for i in range(1, len(sections), 2):
            if i + 1 < len(sections):
                category = sections[i].strip()
                section_content = sections[i + 1].strip()
                
                # 提取該類別下的所有餐廳連結
                links = re.findall(r'(https://maps\.app\.goo\.gl/\S+)', section_content)
                
                logger.info(f"發現 {len(links)} 個 {category} 類別的餐廳")
                
                # 處理每個連結
                for link in links:
                    total_count += 1
                    success = await import_restaurant(link, category)
                    if success:
                        success_count += 1
                    else:
                        failed_urls.append((link, category))
                    
                    # 為了避免 API 請求過於頻繁，加入延遲
                    await asyncio.sleep(1)
        
        logger.info(f"餐廳導入完成！共處理 {total_count} 個餐廳，成功導入 {success_count} 個")
        
        # 記錄失敗的URL
        if failed_urls:
            logger.info(f"以下 {len(failed_urls)} 個餐廳導入失敗:")
            for url, category in failed_urls:
                logger.info(f"- {url} (類別: {category})")
            
    except Exception as e:
        logger.error(f"解析餐廳清單文件時出錯: {str(e)}")

async def main():
    """
    主函數
    """
    logger.info("開始導入餐廳資料...")
    await parse_restaurant_list()
    logger.info("餐廳資料導入完成")

if __name__ == "__main__":
    asyncio.run(main()) 