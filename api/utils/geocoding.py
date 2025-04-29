import logging
import httpx
from typing import Dict, List, Any, Optional, Tuple
from tenacity import retry, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

# Google Maps API 基礎URL
GEOCODING_BASE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
MAPS_API_KEY = None  # 將在使用時通過環境變量注入

def set_api_key(api_key: str) -> None:
    """
    設置用於地理編碼請求的Google Maps API金鑰
    
    Args:
        api_key: Google Maps API金鑰
    """
    global MAPS_API_KEY
    MAPS_API_KEY = api_key

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def geocode_address(address: str) -> Optional[Dict[str, Any]]:
    """
    使用Google Maps地理編碼API將地址轉換為經緯度坐標
    
    Args:
        address: 要地理編碼的地址字符串
    
    Returns:
        包含地理編碼結果的字典，如果失敗則返回None
    """
    if not MAPS_API_KEY:
        logger.error("Google Maps API金鑰未設置")
        return None
    
    params = {
        "address": address,
        "key": MAPS_API_KEY
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(GEOCODING_BASE_URL, params=params)
            response.raise_for_status()
            data = response.json()
            
            if data["status"] == "OK" and data["results"]:
                return data["results"][0]
            else:
                logger.warning(f"地理編碼失敗: {data['status']} - {address}")
                return None
    
    except Exception as e:
        logger.error(f"地理編碼請求出錯: {str(e)}")
        return None

def extract_coordinates(geocode_result: Dict[str, Any]) -> Tuple[float, float]:
    """
    從地理編碼結果中提取經緯度坐標
    
    Args:
        geocode_result: 地理編碼API的響應結果
    
    Returns:
        包含經度和緯度的元組 (lng, lat)
    """
    location = geocode_result["geometry"]["location"]
    return (location["lng"], location["lat"])

def format_address_components(components: List[Dict[str, Any]]) -> Dict[str, str]:
    """
    處理並格式化地址組件
    
    Args:
        components: 地理編碼API返回的地址組件列表
    
    Returns:
        格式化後的地址組件字典
    """
    result = {}
    
    # 地址組件類型映射
    component_types = {
        "street_number": "street_number",
        "route": "street",
        "sublocality_level_1": "district",
        "administrative_area_level_3": "district",
        "administrative_area_level_2": "city",
        "administrative_area_level_1": "state",
        "country": "country",
        "postal_code": "postal_code"
    }
    
    for component in components:
        for type_key, result_key in component_types.items():
            if type_key in component["types"]:
                result[result_key] = component["long_name"]
    
    return result

def format_address(geocode_result: Dict[str, Any]) -> Dict[str, Any]:
    """
    從地理編碼結果中提取並格式化地址信息
    
    Args:
        geocode_result: 地理編碼API的響應結果
    
    Returns:
        格式化的地址信息字典
    """
    result = {
        "formatted_address": geocode_result.get("formatted_address", ""),
    }
    
    # 提取地址組件
    if "address_components" in geocode_result:
        components = format_address_components(geocode_result["address_components"])
        result.update(components)
    
    # 提取坐標
    if "geometry" in geocode_result and "location" in geocode_result["geometry"]:
        location = geocode_result["geometry"]["location"]
        result["latitude"] = location["lat"]
        result["longitude"] = location["lng"]
    
    return result

async def enrich_address_data(place_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    使用地理編碼豐富場所數據的地址信息
    
    Args:
        place_data: 包含地址信息的場所數據
    
    Returns:
        帶有豐富地址信息的場所數據
    """
    result = place_data.copy()
    
    # 如果已有完整坐標，則使用坐標進行反向地理編碼
    if "latitude" in place_data and "longitude" in place_data:
        lat, lng = place_data["latitude"], place_data["longitude"]
        geocode_data = await reverse_geocode(lat, lng)
    # 否則使用地址進行地理編碼
    elif "address" in place_data:
        geocode_data = await geocode_address(place_data["address"])
    else:
        logger.warning("無法進行地理編碼: 缺少地址或坐標")
        return result
    
    # 處理地理編碼結果
    if geocode_data:
        address_info = format_address(geocode_data)
        result.update(address_info)
    
    return result

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def reverse_geocode(lat: float, lng: float) -> Optional[Dict[str, Any]]:
    """
    使用Google Maps API進行反向地理編碼，將經緯度轉換為地址
    
    Args:
        lat: 緯度
        lng: 經度
    
    Returns:
        地理編碼結果，如果失敗則返回None
    """
    if not MAPS_API_KEY:
        logger.error("Google Maps API金鑰未設置")
        return None
    
    params = {
        "latlng": f"{lat},{lng}",
        "key": MAPS_API_KEY
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(GEOCODING_BASE_URL, params=params)
            response.raise_for_status()
            data = response.json()
            
            if data["status"] == "OK" and data["results"]:
                return data["results"][0]
            else:
                logger.warning(f"反向地理編碼失敗: {data['status']} - ({lat}, {lng})")
                return None
    
    except Exception as e:
        logger.error(f"反向地理編碼請求出錯: {str(e)}")
        return None 