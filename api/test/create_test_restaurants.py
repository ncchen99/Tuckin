import os
import sys
import uuid
import random
from datetime import datetime

# 添加父級目錄到路徑，以便導入模組
current_dir = os.path.dirname(os.path.abspath(__file__))
api_dir = os.path.dirname(current_dir)
sys.path.append(api_dir)

from supabase import create_client
from config import SUPABASE_URL, SUPABASE_SERVICE_KEY

# 確保有服務密鑰
if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise ValueError("SUPABASE_URL 和 SUPABASE_SERVICE_KEY 環境變數必須設置")

# 初始化 Supabase 客戶端
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# 配置日誌
import logging
# 使用絕對路徑
log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_restaurants.log")
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 食物類別列表（與APP一致）
FOOD_CATEGORIES = [
    '台灣料理', 
    '日式料理', 
    '日式咖哩', 
    '韓式料理', 
    '泰式料理', 
    '義式料理', 
    '美式餐廳', 
    '中式料理', 
    '港式飲茶', 
    '印度料理', 
    '墨西哥菜', 
    '越南料理', 
    '素食料理', 
    '漢堡速食', 
    '披薩料理', 
    '燒烤料理', 
    '火鍋料理'
]

# Unsplash 圖片庫 - 按類別分類的餐廳圖片
UNSPLASH_IMAGES = {
    "台灣料理": [
        "https://images.unsplash.com/photo-1563245372-f21724e3856d",
        "https://images.unsplash.com/photo-1526318896980-cf78c088247c",
        "https://images.unsplash.com/photo-1569058242567-93de6c36f198"
    ],
    "日式料理": [
        "https://images.unsplash.com/photo-1579871494447-9811cf80d66c",
        "https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56",
        "https://images.unsplash.com/photo-1553621042-f6e147245754"
    ],
    "日式咖哩": [
        "https://images.unsplash.com/photo-1574484284002-952d92456975",
        "https://images.unsplash.com/photo-1613614046092-b94e99e5eb0c",
        "https://images.unsplash.com/photo-1602030638412-bb8dcc0bc8b0"
    ],
    "韓式料理": [
        "https://images.unsplash.com/photo-1590301157890-4810ed352733",
        "https://images.unsplash.com/photo-1589647363585-f4a7d3877b10",
        "https://images.unsplash.com/photo-1632557501617-30a6a2d35288"
    ],
    "泰式料理": [
        "https://images.unsplash.com/photo-1559314809-0d155014e29e",
        "https://images.unsplash.com/photo-1562565652-a0d8f0c59eb4",
        "https://images.unsplash.com/photo-1569562211093-e88fb233b9d4"
    ],
    "義式料理": [
        "https://images.unsplash.com/photo-1595295333158-4742f28fbd85",
        "https://images.unsplash.com/photo-1555072956-7758afb20e8f",
        "https://images.unsplash.com/photo-1551183053-bf91a1d81141"
    ],
    "美式餐廳": [
        "https://images.unsplash.com/photo-1552566626-52f8b828add9",
        "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38",
        "https://images.unsplash.com/photo-1542574271-7f3b92e6c821"
    ],
    "中式料理": [
        "https://images.unsplash.com/photo-1563245372-f21724e3856d",
        "https://images.unsplash.com/photo-1583952936150-d1f208b65724",
        "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb"
    ],
    "港式飲茶": [
        "https://images.unsplash.com/photo-1579046288004-d7fb16852576",
        "https://images.unsplash.com/photo-1566464639632-caa4dea861d5",
        "https://images.unsplash.com/photo-1499715217757-2aa48ed7e593"
    ],
    "印度料理": [
        "https://images.unsplash.com/photo-1589647363585-f4a7d3877b10",
        "https://images.unsplash.com/photo-1585937421612-70a008356c36",
        "https://images.unsplash.com/photo-1567337710282-00832b415979"
    ],
    "墨西哥菜": [
        "https://images.unsplash.com/photo-1615870216519-2f9fa575fa5c",
        "https://images.unsplash.com/photo-1552332386-f8dd00dc2f85",
        "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b"
    ],
    "越南料理": [
        "https://images.unsplash.com/photo-1576577445504-6af96477db52",
        "https://images.unsplash.com/photo-1565557623262-b51c2513a641",
        "https://images.unsplash.com/photo-1511910849309-0dffb8785146"
    ],
    "素食料理": [
        "https://images.unsplash.com/photo-1512621776951-a57141f2eefd",
        "https://images.unsplash.com/photo-1540914124281-342587941389",
        "https://images.unsplash.com/photo-1490645935967-10de6ba17061"
    ],
    "漢堡速食": [
        "https://images.unsplash.com/photo-1550547660-d9450f859349",
        "https://images.unsplash.com/photo-1571091718767-18b5b1457add",
        "https://images.unsplash.com/photo-1572802419224-296b0aeee0d9"
    ],
    "披薩料理": [
        "https://images.unsplash.com/photo-1593560708920-61dd98c46a4e",
        "https://images.unsplash.com/photo-1604382354936-07c5d9983bd3",
        "https://images.unsplash.com/photo-1571407970349-bc81e7e96d47"
    ],
    "燒烤料理": [
        "https://images.unsplash.com/photo-1544025162-d76694265947",
        "https://images.unsplash.com/photo-1559847844-5315695dadae",
        "https://images.unsplash.com/photo-1555939594-58d7cb561ad1"
    ],
    "火鍋料理": [
        "https://images.unsplash.com/photo-1569718212165-3a8278d5f624",
        "https://images.unsplash.com/photo-1563557897850-a8d1fd4e34e7",
        "https://images.unsplash.com/photo-1613565101033-7e7efba9dc7c"
    ],
    "default": [
        "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4",
        "https://images.unsplash.com/photo-1414235077428-338989a2e8c0",
        "https://images.unsplash.com/photo-1552566626-52f8b828add9",
        "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4",
        "https://images.unsplash.com/photo-1559339352-11d035aa65de"
    ]
}

# 為每個 Unsplash 圖片 URL 添加參數
def format_unsplash_url(url, width=800, height=600):
    """為 Unsplash 圖片 URL 添加參數以控制尺寸"""
    return f"{url}?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxzZWFyY2h8Mnx8cmVzdGF1cmFudHxlbnwwfHwwfHw%3D&auto=format&fit=crop&w={width}&q=80"

# 餐廳資料
restaurant_data = [
    {
        "name": "水月台北",
        "category": "日式料理",
        "description": "提供精緻日本料理，包括壽司、刺身和烤物等。",
        "address": "台北市信義區松高路19號",
        "latitude": 25.039722,
        "longitude": 121.567889,
        "business_hours": "每日 11:30-14:30, 17:30-22:00",
        "google_place_id": "ChIJxyz123456789",
    },
    {
        "name": "鼎泰豐",
        "category": "中式料理",
        "description": "以小籠包聞名的台灣餐廳，提供多種點心和麵食。",
        "address": "台北市大安區信義路二段194號",
        "latitude": 25.033689,
        "longitude": 121.531386,
        "business_hours": "每日 10:00-21:00",
        "google_place_id": "ChIJabc789012345",
    },
    {
        "name": "夜間部",
        "category": "美式餐廳",
        "description": "提供特色調酒和咖啡，晚間有現場音樂表演。",
        "address": "台北市中山區林森北路107巷10號",
        "latitude": 25.052112,
        "longitude": 121.525994,
        "business_hours": "週二至週日 19:00-02:00，週一公休",
        "google_place_id": "ChIJdef345678901",
    },
    {
        "name": "RAW",
        "category": "台灣料理",
        "description": "由名廚江振誠主理的創意料理餐廳，提供季節性菜單。",
        "address": "台北市中山區樂群三路301號",
        "latitude": 25.082042,
        "longitude": 121.556786,
        "business_hours": "週三至週日 11:30-14:30, 18:00-22:00，週一週二公休",
        "google_place_id": "ChIJghi901234567",
    },
    {
        "name": "雙月食品社",
        "category": "台灣料理",
        "description": "提供傳統台灣風味餐點，以雞湯和油飯聞名。",
        "address": "台北市中山區中山北路二段105巷18號",
        "latitude": 25.059361,
        "longitude": 121.522695,
        "business_hours": "每日 11:00-21:30",
        "google_place_id": "ChIJjkl567890123",
    },
    {
        "name": "MUME",
        "category": "義式料理",
        "description": "由國際主廚團隊打造的創意餐廳，以北歐料理技法詮釋台灣在地食材。",
        "address": "台北市大安區安和路一段27號",
        "latitude": 25.037256,
        "longitude": 121.551682,
        "business_hours": "週二至週日 18:00-22:00，週一公休",
        "google_place_id": "ChIJmno234567890",
    },
    {
        "name": "天香樓",
        "category": "中式料理",
        "description": "提供正宗四川麻辣菜餚，環境優雅。",
        "address": "台北市信義區松仁路28號",
        "latitude": 25.036382,
        "longitude": 121.568123,
        "business_hours": "每日 11:30-14:30, 17:30-21:30",
        "google_place_id": "ChIJpqr678901234",
    },
    {
        "name": "Impromptu by Paul Lee",
        "category": "義式料理",
        "description": "由主廚Paul Lee主理的法式料理餐廳，強調季節性和創意。",
        "address": "台北市大安區仁愛路四段27巷18號",
        "latitude": 25.037876,
        "longitude": 121.545923,
        "business_hours": "週二至週日 12:00-14:30, 18:00-22:00，週一公休",
        "google_place_id": "ChIJstu345678901",
    },
    {
        "name": "樂軒鐵板懷石",
        "category": "燒烤料理",
        "description": "高級鐵板燒餐廳，精選日本和台灣頂級食材。",
        "address": "台北市大安區敦化南路一段233巷63號",
        "latitude": 25.039784,
        "longitude": 121.548965,
        "business_hours": "每日 12:00-14:30, 18:00-22:00",
        "google_place_id": "ChIJvwx789012345",
    },
    {
        "name": "頤宮中餐廳",
        "category": "港式飲茶",
        "description": "米其林三星中餐廳，提供精緻粵菜和港式點心。",
        "address": "台北市中山區民生東路三段111號",
        "latitude": 25.058123,
        "longitude": 121.544567,
        "business_hours": "每日 11:30-14:30, 17:30-21:30",
        "google_place_id": "ChIJyz0123456789",
    },
    {
        "name": "大四喜牛肉麵",
        "category": "台灣料理",
        "description": "提供多種台灣傳統小吃，平價美味。",
        "address": "台北市中正區汀州路三段160巷4號",
        "latitude": 25.018934,
        "longitude": 121.533246,
        "business_hours": "週一至週六 11:00-20:00，週日公休",
        "google_place_id": "ChIJabc123456789",
    },
    {
        "name": "金鐘茶餐廳",
        "category": "港式飲茶",
        "description": "提供道地港式餐點，以燒臘和點心聞名。",
        "address": "台北市信義區松壽路12號",
        "latitude": 25.035671,
        "longitude": 121.566823,
        "business_hours": "每日 07:30-22:00",
        "google_place_id": "ChIJdef987654321",
    },
    {
        "name": "Osteria by Angie",
        "category": "義式料理",
        "description": "提供道地南義料理，食材新鮮且菜色豐富。",
        "address": "台北市大安區安和路二段67號",
        "latitude": 25.032541,
        "longitude": 121.553214,
        "business_hours": "週二至週日 11:30-14:30, 17:30-22:00，週一公休",
        "google_place_id": "ChIJghi654321098",
    },
    {
        "name": "青葉餐廳",
        "category": "台灣料理",
        "description": "歷史悠久的台菜餐廳，提供經典台灣料理。",
        "address": "台北市中山區中山北路二段105巷1號",
        "latitude": 25.059481,
        "longitude": 121.522789,
        "business_hours": "每日 11:30-14:30, 17:30-21:30",
        "google_place_id": "ChIJjkl210987654",
    },
    {
        "name": "初魚鐵板燒",
        "category": "燒烤料理",
        "description": "精緻鐵板燒餐廳，強調食材原味與新鮮度。",
        "address": "台北市大安區忠孝東路四段216巷27弄1號",
        "latitude": 25.041234,
        "longitude": 121.547681,
        "business_hours": "週二至週日 12:00-14:30, 18:00-22:00，週一公休",
        "google_place_id": "ChIJmno543210987",
    },
    {
        "name": "咚咚家韓式豆腐鍋",
        "category": "韓式料理",
        "description": "專門提供道地韓式豆腐鍋與韓式小菜。",
        "address": "台北市大安區安和路一段78號",
        "latitude": 25.033123,
        "longitude": 121.553456,
        "business_hours": "每日 11:30-21:30",
        "google_place_id": "ChIJdongdong1234",
    },
    {
        "name": "馬友友印度廚房",
        "category": "印度料理",
        "description": "正宗印度料理，提供咖哩、烤餅和坦都里烤雞等經典美食。",
        "address": "台北市大安區安和路一段33號",
        "latitude": 25.035432,
        "longitude": 121.551234,
        "business_hours": "每日 11:30-14:30, 17:30-21:30",
        "google_place_id": "ChIJindia543210",
    },
    {
        "name": "瓦城泰國料理",
        "category": "泰式料理",
        "description": "提供多樣泰式料理，口味正宗，裝潢優雅舒適。",
        "address": "台北市信義區松高路11號",
        "latitude": 25.040123,
        "longitude": 121.567456,
        "business_hours": "每日 11:00-22:00",
        "google_place_id": "ChIJthai7890123",
    },
    {
        "name": "鳥哲燒物專門店",
        "category": "日式料理",
        "description": "主打日式串燒與生啤酒，提供舒適的日式居酒屋體驗。",
        "address": "台北市大安區復興南路一段107巷5號",
        "latitude": 25.042456,
        "longitude": 121.543789,
        "business_hours": "週一至週六 17:30-23:30，週日公休",
        "google_place_id": "ChIJjapan6543210",
    },
    {
        "name": "一幻拉麵",
        "category": "日式料理",
        "description": "來自北海道的人氣拉麵店，特色是蝦湯頭拉麵。",
        "address": "台北市信義區松壽路12號",
        "latitude": 25.036789,
        "longitude": 121.566123,
        "business_hours": "每日 11:00-21:30",
        "google_place_id": "ChIJramen9876543",
    },
    {
        "name": "越南小吃",
        "category": "越南料理",
        "description": "提供道地越南河粉、春捲與越式法國麵包。",
        "address": "台北市中正區羅斯福路三段144巷8號",
        "latitude": 25.019876,
        "longitude": 121.532456,
        "business_hours": "週一至週六 11:00-20:00，週日公休",
        "google_place_id": "ChIJvietnam1234",
    },
    {
        "name": "漢堡王信義店",
        "category": "漢堡速食",
        "description": "國際連鎖速食店，提供各式漢堡、薯條和飲料。",
        "address": "台北市信義區松高路12號",
        "latitude": 25.039456,
        "longitude": 121.566789,
        "business_hours": "每日 10:00-22:00",
        "google_place_id": "ChIJburger12345",
    },
    {
        "name": "必勝客台北敦南店",
        "category": "披薩料理",
        "description": "提供多種口味披薩和義式料理，適合聚餐。",
        "address": "台北市大安區敦化南路一段245號",
        "latitude": 25.038123,
        "longitude": 121.549456,
        "business_hours": "每日 11:00-22:00",
        "google_place_id": "ChIJpizza123456",
    },
    {
        "name": "四季石頭火鍋",
        "category": "火鍋料理",
        "description": "傳統台灣石頭火鍋，食材新鮮，湯頭鮮美。",
        "address": "台北市大安區和平東路二段118巷2號",
        "latitude": 25.026789,
        "longitude": 121.535123,
        "business_hours": "每日 17:00-24:00",
        "google_place_id": "ChIJhotpot5678",
    },
    {
        "name": "素食天地",
        "category": "素食料理",
        "description": "精緻素食餐廳，提供多種創意素食料理。",
        "address": "台北市中山區中山北路二段27巷3號",
        "latitude": 25.057123,
        "longitude": 121.523456,
        "business_hours": "每日 11:00-20:30",
        "google_place_id": "ChIJvegan12345",
    },
    {
        "name": "CoCo壹番屋咖哩",
        "category": "日式咖哩",
        "description": "來自日本的連鎖咖哩店，提供多種口味咖哩飯。",
        "address": "台北市信義區松壽路9號",
        "latitude": 25.037123,
        "longitude": 121.565456,
        "business_hours": "每日 11:00-21:00",
        "google_place_id": "ChIJcurry123456",
    },
    {
        "name": "Taco Bell 台北店",
        "category": "墨西哥菜",
        "description": "美式墨西哥連鎖餐廳，提供墨西哥捲餅、玉米脆片等。",
        "address": "台北市信義區松高路11號",
        "latitude": 25.040456,
        "longitude": 121.567123,
        "business_hours": "每日 10:00-22:00",
        "google_place_id": "ChIJmexican1234",
    }
]

def create_test_restaurant(restaurant_info):
    """創建測試餐廳並返回餐廳ID"""
    restaurant_id = str(uuid.uuid4())
    
    try:
        # 根據餐廳類別選擇適當的 Unsplash 圖片
        category = restaurant_info["category"]
        if category in UNSPLASH_IMAGES:
            # 從類別對應的圖片中隨機選擇一張
            image_url = random.choice(UNSPLASH_IMAGES[category])
        else:
            # 如果沒有對應的類別，使用預設圖片
            image_url = random.choice(UNSPLASH_IMAGES["default"])
        
        # 格式化圖片 URL
        formatted_image_url = format_unsplash_url(image_url)
        restaurant_info["image_path"] = formatted_image_url
        
        # 創建餐廳記錄
        restaurant_data = {
            "id": restaurant_id,
            **restaurant_info,
            "created_at": datetime.now().isoformat()
        }
        
        result = supabase.table("restaurants").insert(restaurant_data).execute()
        
        if result.data:
            logger.info(f"已創建餐廳: {restaurant_info['name']} (圖片: {formatted_image_url})")
            return restaurant_id
        else:
            logger.error(f"創建餐廳失敗: {restaurant_info['name']}")
            return None
            
    except Exception as e:
        logger.error(f"創建餐廳時出錯: {e}")
        return None

def clean_test_restaurants():
    """清理之前的測試餐廳數據"""
    logger.info("清理之前的測試餐廳數據...")
    
    try:
        # 獲取所有餐廳資料
        restaurants_response = supabase.table("restaurants").select("id").execute()
        restaurant_ids = [restaurant["id"] for restaurant in restaurants_response.data] if restaurants_response.data else []
        
        if restaurant_ids:
            # 使用IN運算符刪除多個餐廳記錄
            logger.info(f"找到 {len(restaurant_ids)} 個餐廳記錄準備清理")
            
            # 刪除restaurant_votes表中的相關資料
            supabase.table("restaurant_votes").delete().in_("restaurant_id", restaurant_ids).execute()
            logger.info("已清理restaurant_votes表中的相關資料")
            
            # 刪除restaurants表中的資料
            supabase.table("restaurants").delete().in_("id", restaurant_ids).execute()
            logger.info("已清理restaurants表中的資料")
        else:
            logger.info("未找到餐廳記錄，跳過清理")
        
    except Exception as e:
        logger.error(f"清理測試餐廳數據時出錯: {e}")

def create_all_test_restaurants():
    """創建所有測試餐廳"""
    logger.info("開始創建測試餐廳...")
    
    restaurant_ids = []
    for restaurant_info in restaurant_data:
        restaurant_id = create_test_restaurant(restaurant_info)
        if restaurant_id:
            restaurant_ids.append(restaurant_id)
    
    logger.info(f"成功創建 {len(restaurant_ids)} 個測試餐廳")
    return restaurant_ids

def create_restaurants_by_category():
    """按類別統計創建餐廳數量"""
    logger.info("按類別統計創建餐廳：")
    
    # 按類別統計餐廳數量
    category_count = {}
    for restaurant in restaurant_data:
        category = restaurant["category"]
        if category in category_count:
            category_count[category] += 1
        else:
            category_count[category] = 1
    
    # 顯示統計結果
    for category in FOOD_CATEGORIES:
        count = category_count.get(category, 0)
        logger.info(f"{category}: {count}家餐廳")
    
    # 檢查未使用的類別
    unused_categories = [cat for cat in FOOD_CATEGORIES if cat not in category_count]
    if unused_categories:
        logger.warning(f"未創建餐廳的類別: {', '.join(unused_categories)}")

if __name__ == "__main__":
    # 是否需要先清理
    should_clean = input("是否需要先清理現有餐廳數據？(y/n): ").strip().lower()
    if should_clean == 'y':
        clean_test_restaurants()
    
    # 創建測試餐廳
    create_all_test_restaurants()
    
    # 顯示餐廳類別統計
    create_restaurants_by_category() 