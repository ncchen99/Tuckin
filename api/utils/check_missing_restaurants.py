"""
餐廳資料檢查腳本
比對餐廳清單.md中的URL與Supabase資料庫中的餐廳，找出未成功導入的餐廳

執行方式:
python -m api.utils.check_missing_restaurants
"""

import os
import re
import logging
import json
import httpx
import asyncio
import urllib.parse
from datetime import datetime
from typing import List, Tuple, Dict, Set, Optional
from bs4 import BeautifulSoup
from dotenv import load_dotenv
from supabase import create_client, Client

# 配置日誌記錄
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 添加檔案日誌記錄
os.makedirs('logs', exist_ok=True)
file_handler = logging.FileHandler(f'logs/restaurant_check_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log', encoding='utf-8')
file_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(file_handler)

# 載入環境變數
load_dotenv()

# 初始化 Supabase 客戶端
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
logger.info(f"Supabase URL: {SUPABASE_URL[:20]}..." if SUPABASE_URL else "未設置Supabase URL")
logger.info(f"Supabase Key: {SUPABASE_SERVICE_KEY[:5]}..." if SUPABASE_SERVICE_KEY else "無法獲取Supabase金鑰")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# 餐廳清單文件路徑
RESTAURANT_LIST_PATH = "docs/產品設計/餐廳清單.md"

# 創建調試日誌目錄
DEBUG_DIR = 'logs/debug_data'
os.makedirs(DEBUG_DIR, exist_ok=True)

def save_debug_data(prefix: str, data: any, url: str = None):
    """保存調試數據到文件"""
    filename = f"{prefix}_{datetime.now().strftime('%H%M%S')}_{hash(str(url))}.json"
    filepath = os.path.join(DEBUG_DIR, filename)
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            if isinstance(data, (dict, list)):
                json.dump(data, f, ensure_ascii=False, indent=2)
            else:
                f.write(str(data))
        logger.info(f"調試數據已保存: {filepath}")
    except Exception as e:
        logger.error(f"保存調試數據出錯: {str(e)}")

def extract_restaurant_name_from_url(url: str) -> Optional[str]:
    """
    從Google Maps URL提取餐廳名稱
    
    Args:
        url: Google Maps URL
        
    Returns:
        Optional[str]: 餐廳名稱，如果未找到則返回None
    """
    try:
        logger.info(f"正在從URL提取餐廳名稱: {url}")
        
        # 處理含有place關鍵字的URL，直接從URL路徑中提取名稱
        # 例如：https://www.google.com/maps/place/餐廳名稱/@22.9869211...
        place_match = re.search(r'/place/([^/@]+)', url)
        if place_match:
            encoded_name = place_match.group(1)
            place_name = urllib.parse.unquote_plus(encoded_name)
            # 將+替換為空格
            place_name = place_name.replace('+', ' ')
            logger.info(f"從URL路徑提取到餐廳名稱: {place_name}")
            return place_name
            
        # 嘗試從URL參數中提取名稱
        query_match = re.search(r'[?&]q=([^&]+)', url)
        if query_match:
            query = urllib.parse.unquote_plus(query_match.group(1))
            logger.info(f"從URL查詢參數提取到名稱: {query}")
            return query
        
        # 從原始短網址提取餐廳標識
        short_id_match = re.search(r'maps\.app\.goo\.gl/([A-Za-z0-9]+)', url)
        if short_id_match:
            short_id = short_id_match.group(1)
            logger.info(f"從短網址提取到ID: {short_id}")
            return f"Restaurant-{short_id}"  # 使用短網址ID作為餐廳標識
            
        logger.warning(f"無法從URL提取餐廳名稱: {url}")
        return None
    except Exception as e:
        logger.error(f"從URL提取餐廳名稱出錯: {url}, 錯誤: {str(e)}")
        return None

async def check_restaurant_exists(url: str, category: str = None) -> Tuple[bool, Optional[str], Optional[Dict]]:
    """
    檢查餐廳是否存在於資料庫
    
    Args:
        url: Google Maps URL
        category: 餐廳類別
        
    Returns:
        Tuple[bool, Optional[str], Optional[Dict]]: 是否存在，餐廳名稱，餐廳資料
    """
    try:
        logger.info(f"開始檢查餐廳: {url}, 類別: {category}")
        
        # 直接從URL提取餐廳名稱
        restaurant_name = extract_restaurant_name_from_url(url)
            
        if not restaurant_name:
            logger.warning(f"無法獲取餐廳名稱: {url}")
            return False, None, None
            
        logger.info(f"獲取到餐廳名稱: {restaurant_name}")
            
        # 使用餐廳名稱在資料庫中進行模糊匹配
        name_query = supabase.table("restaurants").select("*").ilike("name", f"%{restaurant_name}%")
        name_result = name_query.execute()
        
        # 輸出查詢結果，以便調試
        debug_data = {
            "restaurant_name": restaurant_name,
            "query_type": "by_name",
            "result_count": len(name_result.data) if name_result.data else 0,
            "results": name_result.data
        }
        save_debug_data("db_query_name", debug_data, restaurant_name)
        
        if name_result.data and len(name_result.data) > 0:
            restaurant = name_result.data[0]
            logger.info(f"通過名稱找到餐廳: {restaurant.get('name')}")
            return True, restaurant_name, restaurant
        
        # 如果模糊匹配失敗，嘗試更寬鬆的匹配
        # 例如：可以檢查名稱的一部分是否包含在資料庫中的餐廳名稱中
        for db_restaurant in await get_all_restaurants_from_db():
            db_name = db_restaurant.get("name", "").lower()
            search_name = restaurant_name.lower()
            
            # 檢查名稱是否有部分匹配
            if db_name in search_name or search_name in db_name:
                logger.info(f"通過部分名稱匹配找到餐廳: DB名稱={db_name}, 搜索名稱={search_name}")
                return True, restaurant_name, db_restaurant
        
        # 打印資料庫查詢結果摘要
        logger.warning(f"餐廳不存在於資料庫: name={restaurant_name}")
        return False, restaurant_name, None
        
    except Exception as e:
        logger.error(f"檢查餐廳是否存在出錯: {url}, 錯誤: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        return False, None, None

async def parse_restaurant_list() -> List[Tuple[str, str]]:
    """
    解析餐廳清單文件並返回所有餐廳URL和類別
    
    Returns:
        List[Tuple[str, str]]: URL和類別的列表
    """
    restaurants = []
    
    try:
        # 檢查文件是否存在
        if not os.path.exists(RESTAURANT_LIST_PATH):
            logger.error(f"餐廳清單文件不存在: {RESTAURANT_LIST_PATH}")
            return restaurants
            
        # 讀取餐廳清單文件
        with open(RESTAURANT_LIST_PATH, 'r', encoding='utf-8') as file:
            content = file.read()
            
        # 分割為不同的類別章節
        sections = re.split(r'## (.+)', content)
        
        # 第一個元素是空的，之後的元素是交替的類別名稱和內容
        for i in range(1, len(sections), 2):
            if i + 1 < len(sections):
                category = sections[i].strip()
                section_content = sections[i + 1].strip()
                
                # 提取該類別下的所有餐廳連結
                links = re.findall(r'(https://maps\.app\.goo\.gl/\S+)', section_content)
                
                logger.info(f"發現 {len(links)} 個 {category} 類別的餐廳")
                
                # 添加連結和類別到列表
                for link in links:
                    restaurants.append((link, category))
                    
    except Exception as e:
        logger.error(f"解析餐廳清單文件時出錯: {str(e)}")
        
    return restaurants

async def get_all_restaurants_from_db() -> List[Dict]:
    """
    從資料庫獲取所有餐廳
    
    Returns:
        List[Dict]: 餐廳列表
    """
    try:
        logger.info("正在從資料庫獲取所有餐廳...")
        result = supabase.table("restaurants").select("*").execute()
        
        # 保存資料庫響應，以便調試
        debug_data = {
            "query_type": "all_restaurants",
            "result_count": len(result.data) if result.data else 0,
            "first_10_results": result.data[:10] if result.data and len(result.data) > 0 else []
        }
        save_debug_data("all_restaurants", debug_data)
        
        # 打印一些統計資訊
        if result.data:
            logger.info(f"成功獲取 {len(result.data)} 個餐廳")
            # 按類別統計
            categories = {}
            for r in result.data:
                cat = r.get("category", "未分類")
                if cat in categories:
                    categories[cat] += 1
                else:
                    categories[cat] = 1
            for cat, count in categories.items():
                logger.info(f"- {cat}: {count} 家")
        else:
            logger.warning("資料庫中沒有餐廳資料")
            
        return result.data if result.data else []
    except Exception as e:
        logger.error(f"從資料庫獲取餐廳出錯: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        return []

async def main():
    """
    主函數
    """
    logger.info("開始檢查餐廳資料...")
    
    # 解析餐廳清單
    restaurants_from_md = await parse_restaurant_list()
    logger.info(f"從餐廳清單中解析出 {len(restaurants_from_md)} 個餐廳")
    
    # 從資料庫獲取所有餐廳
    db_restaurants = await get_all_restaurants_from_db()
    logger.info(f"從資料庫獲取到 {len(db_restaurants)} 個餐廳")
    
    # 創建資料庫餐廳名稱集合，用於快速查詢
    db_names = {r.get("name", "").lower() for r in db_restaurants if r.get("name")}
    logger.info(f"資料庫中有 {len(db_names)} 個不同的餐廳名稱")
    
    # 檢查每個餐廳清單中的URL
    missing_restaurants = []
    existing_restaurants = []
    
    # 為了測試，可以僅處理部分餐廳
    test_limit = int(os.environ.get("TEST_LIMIT", "0"))
    if test_limit > 0:
        logger.info(f"測試模式: 僅處理前 {test_limit} 個餐廳")
        restaurants_to_check = restaurants_from_md[:test_limit]
    else:
        restaurants_to_check = restaurants_from_md
    
    try:
        for i, (url, category) in enumerate(restaurants_to_check):
            logger.info(f"處理第 {i+1}/{len(restaurants_to_check)} 個餐廳...")
            exists, restaurant_name, restaurant_data = await check_restaurant_exists(url, category)
            
            if exists:
                db_name = restaurant_data.get("name", "未知")
                logger.info(f"餐廳已存在: {db_name}, URL: {url}")
                existing_restaurants.append((url, db_name, category))
            else:
                logger.warning(f"餐廳未導入: URL: {url}, 找到名稱: {restaurant_name}, 類別: {category}")
                missing_restaurants.append((url, category, restaurant_name))
                
            # 避免連續處理過快，加入少量延遲
            await asyncio.sleep(0.2)
            
    except KeyboardInterrupt:
        logger.info("用戶中斷執行，輸出已處理的結果...")
    except Exception as e:
        logger.error(f"處理過程中出錯: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
    
    finally:
        # 即使出錯也輸出結果
        # 輸出結果
        total_processed = len(existing_restaurants) + len(missing_restaurants)
        logger.info(f"\n檢查完成！共處理 {total_processed}/{len(restaurants_to_check)} 個餐廳")
        logger.info(f"已成功導入: {len(existing_restaurants)} 個")
        logger.info(f"未成功導入: {len(missing_restaurants)} 個")
        
        if missing_restaurants:
            logger.info("\n未成功導入的餐廳:")
            for url, category, name in missing_restaurants:
                name_info = f", 名稱: {name}" if name else ""
                logger.info(f"- URL: {url}, 類別: {category}{name_info}")
                
        # 保存結果到文件
        with open('logs/missing_restaurants.txt', 'w', encoding='utf-8') as f:
            f.write(f"檢查時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"總餐廳數: {len(restaurants_to_check)}\n")
            f.write(f"已處理數: {total_processed}\n")
            f.write(f"已導入數: {len(existing_restaurants)}\n")
            f.write(f"未導入數: {len(missing_restaurants)}\n\n")
            
            if missing_restaurants:
                f.write("未導入餐廳列表:\n")
                for url, category, name in missing_restaurants:
                    name_info = f", 名稱: {name}" if name else ""
                    f.write(f"- URL: {url}, 類別: {category}{name_info}\n")

if __name__ == "__main__":
    asyncio.run(main()) 