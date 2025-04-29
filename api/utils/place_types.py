"""
Google Places API 地點類型對照表
參考自: https://developers.google.com/maps/documentation/places/web-service/place-types
"""

# 餐廳和食物類型對照表 (以繁體中文表示)
FOOD_AND_DRINK_TYPES = {
    # 餐廳類型 (xxx_restaurant)
    "restaurant": "餐廳",
    "american_restaurant": "美式餐廳",
    "asian_restaurant": "亞洲餐廳",
    "barbecue_restaurant": "燒烤餐廳",
    "bbq_restaurant": "燒烤店",
    "brazilian_restaurant": "巴西餐廳",
    "breakfast_restaurant": "早餐餐廳",
    "brunch_restaurant": "早午餐餐廳",
    "buffet_restaurant": "自助餐廳",
    "chinese_restaurant": "中式餐廳",
    "dim_sum_restaurant": "點心餐廳",
    "diner": "小餐館",
    "donburi_restaurant": "丼飯餐廳",
    "dumpling_restaurant": "餃子館",
    "family_restaurant": "家庭餐廳",
    "fast_food_restaurant": "速食店",
    "fine_dining_restaurant": "高級餐廳",
    "food_court": "美食廣場",
    "french_restaurant": "法式餐廳",
    "greek_restaurant": "希臘餐廳",
    "hamburger_restaurant": "漢堡店",
    "hawaiian_restaurant": "夏威夷餐廳",
    "hot_pot_restaurant": "火鍋店",
    "indian_restaurant": "印度餐廳",
    "indonesian_restaurant": "印尼餐廳",
    "italian_restaurant": "義式餐廳",
    "japanese_restaurant": "日式餐廳",
    "korean_restaurant": "韓式餐廳",
    "latin_american_restaurant": "拉丁美洲餐廳",
    "mediterranean_restaurant": "地中海餐廳",
    "mexican_restaurant": "墨西哥餐廳",
    "middle_eastern_restaurant": "中東餐廳",
    "noodle_restaurant": "麵食餐廳",
    "noodle_shop": "麵館",
    "pizza_restaurant": "披薩店",
    "ramen_restaurant": "拉麵店",
    "seafood_restaurant": "海鮮餐廳",
    "spanish_restaurant": "西班牙餐廳",
    "steak_house": "牛排館",
    "sushi_restaurant": "壽司店",
    "taiwanese_restaurant": "台灣餐廳",
    "thai_restaurant": "泰式餐廳",
    "turkish_restaurant": "土耳其餐廳",
    "vegetarian_restaurant": "素食餐廳",
    "vietnamese_restaurant": "越南餐廳",
    
    # 咖啡廳和飲品店
    "cafe": "咖啡廳",
    "coffee_shop": "咖啡店",
    "tea_shop": "茶店",
    "teahouse": "茶館",
    "bubble_tea_shop": "珍珠奶茶店",
    "smoothie_shop": "冰沙店",
    "juice_bar": "果汁吧",
    
    # 酒吧類型
    "bar": "酒吧",
    "wine_bar": "葡萄酒吧",
    "beer_bar": "啤酒吧",
    "pub": "酒館",
    "sports_bar": "運動酒吧",
    "night_club": "夜店",
    "gastropub": "餐酒館",
    "izakaya": "居酒屋",
    "whiskey_bar": "威士忌酒吧",
    "cocktail_bar": "雞尾酒吧",
    "brewery": "啤酒廠",
    "brewpub": "自釀酒吧",
    
    # 烘焙和甜點
    "bakery": "烘焙坊",
    "cake_shop": "蛋糕店",
    "dessert_shop": "甜點店",
    "ice_cream_shop": "冰品店",
    "pastry_shop": "糕點店",
    "chocolate_shop": "巧克力店",
    "donut_shop": "甜甜圈店",
    
    # 其他食物相關
    "food": "美食",
    "meal_takeaway": "外帶餐飲",
    "meal_delivery": "外送餐飲",
    "food_market": "食品市場",
    "frozen_food_store": "冷凍食品店",
    "grocery_store": "雜貨店",
    "supermarket": "超市",
    "convenience_store": "便利商店",
    "butcher_shop": "肉店",
    "fish_market": "魚市場",
    "deli": "熟食店",
    "caterer": "餐飲服務商",
    "food_truck": "食物卡車",
    "hawker_center": "小販中心",
    "street_food": "街頭小吃"
}

def get_category_from_types(types: list) -> str:
    """
    從Google Place types列表中獲取餐廳或食物類型並轉換為繁體中文
    
    參數:
        types: Google Place API返回的類型列表
        
    返回:
        繁體中文類型名稱，若找不到對應則返回第一個類型
    """
    # 先檢查主要餐廳類型
    for t in types:
        if t in FOOD_AND_DRINK_TYPES:
            return FOOD_AND_DRINK_TYPES[t]
        
        # 處理未在表中但以_restaurant結尾的類型
        if t.endswith("_restaurant"):
            prefix = t.replace("_restaurant", "")
            return f"{prefix}餐廳"
    
    # 若無對應，回傳第一個type
    return types[0] if types else None 