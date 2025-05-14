"""
餐廳URL檢查腳本
檢查Markdown文件中的餐廳URL是否與Supabase資料庫中已存在的餐廳資料匹配

執行方式:
python -m api.utils.restaurant_url_checker
"""

import os
import re
import logging
import asyncio
import urllib.parse
import httpx
from datetime import datetime
from typing import List, Tuple, Dict, Optional, Set
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
file_handler = logging.FileHandler(f'logs/restaurant_url_check_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log', encoding='utf-8')
file_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(file_handler)

# 載入環境變數
load_dotenv()

# 初始化 Supabase 客戶端
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
logger.info(f"Supabase URL: {SUPABASE_URL[:20]}..." if SUPABASE_URL else "未設置Supabase URL")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    logger.error("缺少必要的Supabase環境變數，無法繼續執行")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# 餐廳清單文件路徑
RESTAURANT_LIST_PATH = "docs/產品設計/餐廳清單.md"

def expand_short_url(url: str) -> str:
    """
    展開Google Maps短網址至完整URL
    
    Args:
        url: Google Maps短網址
        
    Returns:
        str: 完整的Google Maps URL
    """
    try:
        logger.debug(f"嘗試展開短網址: {url}")
        headers = {"User-Agent": "Mozilla/5.0 TuckinApp/1.0", "Cache-Control": "no-cache"}
        
        with httpx.Client(follow_redirects=True, timeout=10.0) as client:
            response = client.get(url, headers=headers)
            final_url = str(response.url)
            logger.debug(f"短網址展開為: {final_url}")
            return final_url
    except Exception as e:
        logger.error(f"展開短網址出錯: {url}, 錯誤: {str(e)}")
        return url

def extract_restaurant_name_from_url(url: str) -> Optional[str]:
    """
    從Google Maps URL提取餐廳名稱
    
    方法:
    1. 從URL路徑中提取 (/place/餐廳名稱)
    2. 從URL查詢參數提取
    3. 嘗試展開短網址後再提取
    4. 使用短網址ID作為後備方案
    
    Args:
        url: Google Maps URL
        
    Returns:
        Optional[str]: 餐廳名稱，如果未找到則返回None
    """
    try:
        logger.debug(f"正在從URL提取餐廳名稱: {url}")
        
        # 方法1: 處理含有place關鍵字的URL，直接從URL路徑中提取名稱
        # 例如：https://www.google.com/maps/place/餐廳名稱/@22.9869211...
        place_match = re.search(r'/place/([^/@]+)', url)
        if place_match:
            encoded_name = place_match.group(1)
            place_name = urllib.parse.unquote_plus(encoded_name)
            # 將+替換為空格
            place_name = place_name.replace('+', ' ')
            logger.debug(f"從URL路徑提取到餐廳名稱: {place_name}")
            return place_name
            
        # 方法2: 嘗試從URL參數中提取名稱
        query_match = re.search(r'[?&]q=([^&]+)', url)
        if query_match:
            query = urllib.parse.unquote_plus(query_match.group(1))
            logger.debug(f"從URL查詢參數提取到名稱: {query}")
            return query
        
        # 方法3: 如果是短網址，嘗試展開後再提取
        if "maps.app.goo.gl" in url:
            expanded_url = expand_short_url(url)
            if expanded_url != url:
                # 對展開的URL遞歸調用此函數
                expanded_name = extract_restaurant_name_from_url(expanded_url)
                if expanded_name:
                    logger.debug(f"從展開的URL提取到餐廳名稱: {expanded_name}")
                    return expanded_name
        
        # 方法4: 從原始短網址提取餐廳標識作為後備方案
        short_id_match = re.search(r'maps\.app\.goo\.gl/([A-Za-z0-9]+)', url)
        if short_id_match:
            short_id = short_id_match.group(1)
            logger.debug(f"從短網址提取到ID: {short_id}")
            return f"Restaurant-{short_id}"  # 使用短網址ID作為餐廳標識
            
        logger.warning(f"無法從URL提取餐廳名稱: {url}")
        return None
    except Exception as e:
        logger.error(f"從URL提取餐廳名稱出錯: {url}, 錯誤: {str(e)}")
        return None

def clean_restaurant_name(name: str) -> str:
    """
    清理餐廳名稱，移除標點和地區信息
    
    Args:
        name: 原始餐廳名稱
        
    Returns:
        str: 清理後的餐廳名稱
    """
    if not name:
        return ""
    
    # 移除括號及其內容
    name = re.sub(r'\(.*?\)', '', name)
    # 移除方括號及其內容
    name = re.sub(r'\[.*?\]', '', name)
    # 移除常見地區標記
    name = re.sub(r'(台北|台中|台南|高雄|台灣).*?(市|店|區|路|號)', '', name)
    # 移除標點符號
    name = re.sub(r'[^\w\s]', '', name)
    # 移除多餘空格
    name = re.sub(r'\s+', ' ', name).strip()
    
    return name

def is_name_similar(name1: str, name2: str) -> bool:
    """
    檢查兩個餐廳名稱是否相似
    
    Args:
        name1: 第一個餐廳名稱
        name2: 第二個餐廳名稱
        
    Returns:
        bool: 是否相似
    """
    if not name1 or not name2:
        return False
    
    # 清理名稱
    clean_name1 = clean_restaurant_name(name1.lower())
    clean_name2 = clean_restaurant_name(name2.lower())
    
    # 判斷名稱是否包含關係
    if clean_name1 in clean_name2 or clean_name2 in clean_name1:
        return True
    
    # 判斷字符重疊程度
    common_chars = set(clean_name1) & set(clean_name2)
    total_chars = set(clean_name1) | set(clean_name2)
    
    if total_chars and len(common_chars) / len(total_chars) >= 0.7:
        return True
    
    return False

async def is_restaurant_in_db(url: str, restaurant_name: str, db_restaurants: List[Dict]) -> Tuple[bool, Optional[str]]:
    """
    檢查餐廳是否存在於資料庫
    
    Args:
        url: Google Maps URL
        restaurant_name: 從URL提取的餐廳名稱
        db_restaurants: 資料庫中所有餐廳列表
        
    Returns:
        Tuple[bool, Optional[str]]: 是否存在於資料庫，匹配的餐廳名稱
    """
    try:
        # 從URL中提取可能的識別符
        url_id = None
        short_id_match = re.search(r'maps\.app\.goo\.gl/([A-Za-z0-9]+)', url)
        if short_id_match:
            url_id = short_id_match.group(1)
        
        # 檢查每個資料庫餐廳
        for db_restaurant in db_restaurants:
            db_name = db_restaurant.get("name", "")
            db_website = db_restaurant.get("website", "")
            
            # 檢查URL匹配
            if url in db_website or (url_id and url_id in db_website):
                logger.debug(f"通過URL找到餐廳: {db_name}")
                return True, db_name
            
            # 檢查名稱匹配
            if restaurant_name and is_name_similar(restaurant_name, db_name):
                logger.debug(f"通過名稱匹配找到餐廳: {db_name}")
                return True, db_name
        
        logger.debug(f"餐廳不存在於資料庫: {restaurant_name}")
        return False, None
    except Exception as e:
        logger.error(f"檢查餐廳是否存在於資料庫時出錯: {url}, 錯誤: {str(e)}")
        return False, None

async def get_all_restaurants_from_db() -> List[Dict]:
    """
    從資料庫獲取所有餐廳
    
    Returns:
        List[Dict]: 餐廳列表
    """
    try:
        logger.info("正在從資料庫獲取所有餐廳...")
        result = supabase.table("restaurants").select("*").execute()
        
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
            for cat, count in sorted(categories.items()):
                logger.info(f"- {cat}: {count} 家")
        else:
            logger.warning("資料庫中沒有餐廳資料")
            
        return result.data if result.data else []
    except Exception as e:
        logger.error(f"從資料庫獲取餐廳出錯: {str(e)}")
        return []

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

async def check_restaurants():
    """
    檢查餐廳清單中的URL是否存在於資料庫
    """
    # 解析餐廳清單
    restaurants_from_md = await parse_restaurant_list()
    total_restaurants = len(restaurants_from_md)
    logger.info(f"從餐廳清單中解析出 {total_restaurants} 個餐廳")
    
    # 從資料庫獲取所有餐廳
    db_restaurants = await get_all_restaurants_from_db()
    logger.info(f"從資料庫獲取到 {len(db_restaurants)} 個餐廳")
    
    # 檢查每個餐廳清單中的URL
    imported_restaurants = []
    not_imported_restaurants = []
    categories_stats = {}  # 按類別統計
    
    # 設置批量處理大小，避免腳本運行時間過長
    batch_size = int(os.environ.get("BATCH_SIZE", "0")) or total_restaurants
    logger.info(f"設定批量處理大小: {batch_size}")
    
    # 檢查每個餐廳
    try:
        for i, (url, category) in enumerate(restaurants_from_md[:batch_size]):
            logger.info(f"處理第 {i+1}/{min(batch_size, total_restaurants)} 個餐廳: {url}")
            
            # 從URL提取餐廳名稱
            restaurant_name = extract_restaurant_name_from_url(url)
            
            # 初始化類別統計
            if category not in categories_stats:
                categories_stats[category] = {"total": 0, "imported": 0, "not_imported": 0}
            categories_stats[category]["total"] += 1
            
            # 檢查是否存在於資料庫
            is_imported, matched_name = await is_restaurant_in_db(url, restaurant_name, db_restaurants)
            
            # 記錄結果
            if is_imported:
                imported_restaurants.append((url, category, restaurant_name, matched_name))
                categories_stats[category]["imported"] += 1
                logger.info(f"已導入: {restaurant_name or url} -> 匹配到: {matched_name}")
            else:
                not_imported_restaurants.append((url, category, restaurant_name))
                categories_stats[category]["not_imported"] += 1
                logger.warning(f"未導入: {restaurant_name or url}")
            
            # 避免過於頻繁的請求
            await asyncio.sleep(0.1)
    
    except KeyboardInterrupt:
        logger.info("用戶中斷執行，輸出已處理的結果...")
    except Exception as e:
        logger.error(f"處理過程中出錯: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
    
    finally:
        # 即使出錯也輸出結果
        return total_restaurants, imported_restaurants, not_imported_restaurants, categories_stats

async def main():
    """
    主函數
    """
    logger.info("開始檢查餐廳URL...")
    
    # 檢查餐廳
    total_restaurants, imported_restaurants, not_imported_restaurants, categories_stats = await check_restaurants()
    
    # 計算處理餐廳總數
    processed_count = len(imported_restaurants) + len(not_imported_restaurants)
    
    # 輸出結果
    logger.info("\n=============== 檢查結果 ===============")
    logger.info(f"總餐廳數: {total_restaurants}")
    logger.info(f"已處理數: {processed_count}")
    logger.info(f"已導入數: {len(imported_restaurants)}")
    logger.info(f"未導入數: {len(not_imported_restaurants)}")
    
    # 按類別統計
    logger.info("\n按類別統計:")
    for category, stats in sorted(categories_stats.items()):
        logger.info(f"{category}: 共{stats['total']}家，已導入{stats['imported']}家，未導入{stats['not_imported']}家")
    
    # 顯示未導入的餐廳
    if not_imported_restaurants:
        logger.info("\n未導入的餐廳:")
        for url, category, name in not_imported_restaurants:
            name_info = f"名稱: {name}" if name else "無法提取名稱"
            logger.info(f"- URL: {url}, 類別: {category}, {name_info}")
    
    # 保存結果到文件
    with open('logs/restaurant_url_check_result.txt', 'w', encoding='utf-8') as f:
        f.write(f"檢查時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"總餐廳數: {total_restaurants}\n")
        f.write(f"已處理數: {processed_count}\n")
        f.write(f"已導入數: {len(imported_restaurants)}\n")
        f.write(f"未導入數: {len(not_imported_restaurants)}\n\n")
        
        f.write("===== 按類別統計 =====\n")
        for category, stats in sorted(categories_stats.items()):
            f.write(f"{category}: 共{stats['total']}家，已導入{stats['imported']}家，未導入{stats['not_imported']}家\n")
        
        if not_imported_restaurants:
            f.write("\n===== 未導入的餐廳 =====\n")
            for url, category, name in not_imported_restaurants:
                name_info = f"名稱: {name}" if name else "無法提取名稱"
                f.write(f"- URL: {url}, 類別: {category}, {name_info}\n")
    
    logger.info(f"\n檢查結果已保存到: logs/restaurant_url_check_result.txt")

if __name__ == "__main__":
    asyncio.run(main()) 