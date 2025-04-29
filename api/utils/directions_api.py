import logging
import httpx
from typing import Dict, List, Any, Optional, Tuple
from tenacity import retry, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

# Google Directions API 基礎URL
DIRECTIONS_BASE_URL = "https://maps.googleapis.com/maps/api/directions/json"
DIRECTIONS_API_KEY = None  # 將在使用時通過環境變量注入

def set_api_key(api_key: str) -> None:
    """
    設置用於Directions API請求的Google API金鑰
    
    Args:
        api_key: Google API金鑰
    """
    global DIRECTIONS_API_KEY
    DIRECTIONS_API_KEY = api_key

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def get_directions(
    origin: str,
    destination: str,
    mode: str = "driving",
    departure_time: Optional[str] = None,
    avoid: Optional[List[str]] = None,
    alternatives: bool = False,
    language: str = "zh-TW",
    units: str = "metric",
    waypoints: Optional[List[str]] = None
) -> Optional[Dict[str, Any]]:
    """
    使用Google Directions API獲取路線指引
    
    Args:
        origin: 起點坐標 (lat,lng) 或地址
        destination: 終點坐標 (lat,lng) 或地址
        mode: 交通方式，可為 "driving", "walking", "bicycling", "transit"
        departure_time: 出發時間，格式為 "now" 或 Unix 時間戳
        avoid: 避開的路線特性，可包含 "tolls", "highways", "ferries"
        alternatives: 是否返回多條路線
        language: 返回結果的語言
        units: 距離單位，可為 "metric" 或 "imperial"
        waypoints: 途經點列表
        
    Returns:
        路線指引結果，如果出錯則返回None
    """
    if not DIRECTIONS_API_KEY:
        logger.error("Google Directions API金鑰未設置")
        return None
    
    params = {
        "origin": origin,
        "destination": destination,
        "mode": mode,
        "alternatives": str(alternatives).lower(),
        "language": language,
        "units": units,
        "key": DIRECTIONS_API_KEY
    }
    
    if departure_time:
        params["departure_time"] = departure_time
    
    if avoid:
        params["avoid"] = "|".join(avoid)
    
    if waypoints:
        params["waypoints"] = "|".join(waypoints)
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(DIRECTIONS_BASE_URL, params=params)
            response.raise_for_status()
            data = response.json()
            
            if data["status"] == "OK":
                return data
            else:
                logger.warning(f"獲取路線指引失敗: {data['status']} - 從 {origin} 到 {destination}")
                return None
    
    except Exception as e:
        logger.error(f"路線指引請求出錯: {str(e)}")
        return None

def extract_route_summary(directions_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    從Directions API結果中提取路線摘要信息
    
    Args:
        directions_data: Directions API 返回的結果
        
    Returns:
        路線摘要信息，包含距離、時間和基本指引
    """
    if not directions_data or "routes" not in directions_data or not directions_data["routes"]:
        return {}
    
    first_route = directions_data["routes"][0]
    legs = first_route["legs"]
    
    # 計算總距離和時間
    total_distance_meters = sum(leg["distance"]["value"] for leg in legs)
    total_duration_seconds = sum(leg["duration"]["value"] for leg in legs)
    
    # 獲取總覽信息
    summary = {
        "total_distance": {
            "text": f"{total_distance_meters/1000:.1f} km",
            "value": total_distance_meters
        },
        "total_duration": {
            "text": format_duration(total_duration_seconds),
            "value": total_duration_seconds
        },
        "start_address": legs[0]["start_address"],
        "end_address": legs[-1]["end_address"],
        "start_location": legs[0]["start_location"],
        "end_location": legs[-1]["end_location"],
        "overview_polyline": first_route.get("overview_polyline", {}).get("points", ""),
        "route_summary": first_route.get("summary", "")
    }
    
    return summary

def extract_step_instructions(directions_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    從Directions API結果中提取路線指引步驟
    
    Args:
        directions_data: Directions API 返回的結果
        
    Returns:
        路線指引步驟列表
    """
    if not directions_data or "routes" not in directions_data or not directions_data["routes"]:
        return []
    
    steps = []
    for leg in directions_data["routes"][0]["legs"]:
        for step in leg["steps"]:
            steps.append({
                "instruction": step["html_instructions"],
                "distance": step["distance"],
                "duration": step["duration"],
                "start_location": step["start_location"],
                "end_location": step["end_location"],
                "polyline": step.get("polyline", {}).get("points", ""),
                "travel_mode": step["travel_mode"],
                "maneuver": step.get("maneuver", "")
            })
    
    return steps

def format_duration(seconds: int) -> str:
    """
    將秒數格式化為易讀的時間格式
    
    Args:
        seconds: 秒數
        
    Returns:
        格式化後的時間字符串 (如 "1小時30分鐘")
    """
    hours, remainder = divmod(seconds, 3600)
    minutes, _ = divmod(remainder, 60)
    
    if hours > 0:
        if minutes > 0:
            return f"{hours}小時{minutes}分鐘"
        return f"{hours}小時"
    return f"{minutes}分鐘"

def get_eta(directions_data: Dict[str, Any]) -> Tuple[str, int]:
    """
    從Directions API結果中獲取預計到達時間
    
    Args:
        directions_data: Directions API 返回的結果
        
    Returns:
        (預計到達時間的文本表示, 預計用時的秒數)
    """
    if not directions_data or "routes" not in directions_data or not directions_data["routes"]:
        return "", 0
    
    first_leg = directions_data["routes"][0]["legs"][0]
    duration_text = first_leg["duration"]["text"]
    duration_seconds = first_leg["duration"]["value"]
    
    return duration_text, duration_seconds

async def calculate_delivery_time(
    restaurant_location: str,
    delivery_location: str,
    preparation_time_minutes: int = 20
) -> Dict[str, Any]:
    """
    計算餐廳準備時間和配送時間
    
    Args:
        restaurant_location: 餐廳位置坐標 (lat,lng) 或地址
        delivery_location: 配送地點坐標 (lat,lng) 或地址
        preparation_time_minutes: 餐廳準備食物的時間（分鐘）
        
    Returns:
        包含準備時間和配送時間的字典
    """
    # 獲取配送路線
    directions = await get_directions(
        origin=restaurant_location,
        destination=delivery_location,
        mode="driving",
        departure_time="now"
    )
    
    if not directions or "routes" not in directions or not directions["routes"]:
        return {
            "preparation_time": f"{preparation_time_minutes}分鐘",
            "preparation_time_seconds": preparation_time_minutes * 60,
            "delivery_time": "未知",
            "delivery_time_seconds": 0,
            "total_time": f"{preparation_time_minutes}分鐘",
            "total_time_seconds": preparation_time_minutes * 60
        }
    
    # 提取配送時間
    _, delivery_time_seconds = get_eta(directions)
    delivery_time = format_duration(delivery_time_seconds)
    
    # 計算總時間
    total_time_seconds = (preparation_time_minutes * 60) + delivery_time_seconds
    total_time = format_duration(total_time_seconds)
    
    return {
        "preparation_time": f"{preparation_time_minutes}分鐘",
        "preparation_time_seconds": preparation_time_minutes * 60,
        "delivery_time": delivery_time,
        "delivery_time_seconds": delivery_time_seconds,
        "total_time": total_time,
        "total_time_seconds": total_time_seconds,
        "distance": directions["routes"][0]["legs"][0]["distance"]
    } 