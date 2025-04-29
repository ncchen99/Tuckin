"""
Google Places API 地點類型對照表
參考自: https://developers.google.com/maps/documentation/places/web-service/place-types
"""

from typing import Dict, List, Any, Optional

# 定義中文類別映射
PLACE_TYPES_MAPPING: Dict[str, str] = {
    # 餐廳類型
    "restaurant": "餐廳",
    "food": "美食",
    "cafe": "咖啡廳",
    "bakery": "麵包店",
    "bar": "酒吧",
    "night_club": "夜店",
    "meal_takeaway": "外帶",
    "meal_delivery": "外送",
    "ice_cream_shop": "冰淇淋店",
    "dessert_shop": "甜點店",
    
    # 國家/地區料理
    "chinese_restaurant": "中餐",
    "cantonese_restaurant": "粵菜",
    "szechuan_restaurant": "四川菜",
    "taiwanese_restaurant": "台灣美食",
    "japanese_restaurant": "日本料理",
    "sushi_restaurant": "壽司",
    "ramen_restaurant": "拉麵",
    "korean_restaurant": "韓國料理",
    "thai_restaurant": "泰國料理",
    "vietnamese_restaurant": "越南料理",
    "italian_restaurant": "義大利料理",
    "french_restaurant": "法式料理",
    "american_restaurant": "美式料理",
    "mexican_restaurant": "墨西哥料理",
    "vegetarian_restaurant": "素食",
    "vegan_restaurant": "純素",
    
    # 特色類型
    "hotpot_restaurant": "火鍋",
    "barbecue_restaurant": "燒烤",
    "seafood_restaurant": "海鮮",
    "steak_house": "牛排",
    "noodle_house": "麵館",
    "dumpling_restaurant": "餃子",
    "bubble_tea_shop": "珍珠奶茶",
    "all_you_can_eat_restaurant": "吃到飽",
    "brunch_restaurant": "早午餐",
    "fine_dining_restaurant": "高級餐廳",
    "fast_food_restaurant": "速食",
    "food_court": "美食廣場",
    "street_food": "街頭小吃"
}

# 主要類別優先順序
CATEGORY_PRIORITY = [
    "restaurant", "cafe", "bakery", "bar", "night_club", "food",
    "meal_takeaway", "meal_delivery", "ice_cream_shop", "dessert_shop"
]

def get_category_from_types(place_types: List[str]) -> str:
    """
    從Google Places類型列表中獲取主要類別
    
    Args:
        place_types: Google Places API返回的類型列表
        
    Returns:
        中文類別名稱
    """
    if not place_types:
        return "餐廳"  # 默認類別
    
    # 首先檢查優先順序類別
    for category in CATEGORY_PRIORITY:
        if category in place_types:
            return PLACE_TYPES_MAPPING.get(category, "餐廳")
    
    # 如果沒有找到優先類別，返回第一個有映射的類型
    for place_type in place_types:
        if place_type in PLACE_TYPES_MAPPING:
            return PLACE_TYPES_MAPPING[place_type]
    
    # 默認返回"餐廳"
    return "餐廳"

def extract_cuisine_types(place_types: List[str]) -> List[str]:
    """
    從Google Places類型列表中提取菜系類型
    
    Args:
        place_types: Google Places API返回的類型列表
        
    Returns:
        中文菜系類型列表
    """
    cuisine_types = []
    
    # 這些是主要類別，不算作菜系
    main_categories = set(CATEGORY_PRIORITY)
    
    for place_type in place_types:
        if place_type in PLACE_TYPES_MAPPING and place_type not in main_categories:
            # 可能是菜系類型
            cuisine_types.append(PLACE_TYPES_MAPPING[place_type])
    
    return cuisine_types

def categorize_restaurant(place_details: Dict[str, Any]) -> Dict[str, Any]:
    """
    根據場所詳情對餐廳進行分類，添加主要類別和菜系標籤
    
    Args:
        place_details: 來自Google Places API的場所詳情
        
    Returns:
        更新後的場所詳情，包含主要類別和菜系標籤
    """
    result = place_details.copy()
    
    # 獲取場所類型
    place_types = place_details.get("types", [])
    
    # 設置主要類別
    result["main_category"] = get_category_from_types(place_types)
    
    # 提取菜系類型
    result["cuisine_types"] = extract_cuisine_types(place_types)
    
    return result 