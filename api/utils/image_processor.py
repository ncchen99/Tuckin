import io
import httpx
import logging
import hashlib
from typing import Optional
import boto3
from PIL import Image

from config import GOOGLE_PLACES_API_KEY, CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_ACCESS_KEY_ID, CLOUDFLARE_SECRET_ACCESS_KEY

logger = logging.getLogger(__name__)

def get_r2_client():
    """
    獲取Cloudflare R2客戶端
    """
    return boto3.client(
        's3',
        endpoint_url=f'https://{CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com',
        aws_access_key_id=CLOUDFLARE_ACCESS_KEY_ID,
        aws_secret_access_key=CLOUDFLARE_SECRET_ACCESS_KEY,
        region_name='auto'
    )

async def download_and_upload_photo(photo_reference: str) -> Optional[str]:
    """
    下載Google Places圖片並上傳至Cloudflare R2
    
    Args:
        photo_reference: Google Places API的照片引用ID
        
    Returns:
        公開的URL路徑，失敗時返回None
    """
    if not photo_reference:
        logger.warning("未提供照片引用ID")
        return None
        
    try:
        # 計算照片雜湊值作為文件名
        photo_hash = hashlib.md5(photo_reference.encode()).hexdigest()
        file_name = f"places/{photo_hash}.jpg"
        
        # 初始化R2客戶端
        r2_client = get_r2_client()
        bucket_name = 'tuckin'
        
        try:
            # 檢查圖片是否已存在於R2
            r2_client.head_object(Bucket=bucket_name, Key=file_name)
            logger.info(f"圖片已存在於R2: {file_name}")
            return f"https://tuckin.r2.dev/{file_name}"
        except Exception:
            # 圖片不存在，需要下載和上傳
            logger.info(f"圖片不存在於R2，開始下載: {photo_reference}")
        
        # 從Google Places API下載圖片
        max_width = 1200
        api_url = f"https://places.googleapis.com/v1/places/{photo_reference}/media?maxHeightPx={max_width}&maxWidthPx={max_width}&key={GOOGLE_PLACES_API_KEY}"
        
        async with httpx.AsyncClient(follow_redirects=True) as client:
            response = await client.get(api_url)
            if response.status_code != 200:
                logger.error(f"下載圖片失敗: {response.status_code} {response.text}")
                return None
                
            image_data = response.content
        
        # 壓縮圖片
        compressed_image = compress_image(image_data)
        
        # 上傳到R2
        r2_client.put_object(
            Bucket=bucket_name,
            Key=file_name,
            Body=compressed_image,
            ContentType='image/jpeg',
            ACL='public-read'
        )
        
        logger.info(f"圖片已上傳至R2: {file_name}")
        return f"https://tuckin.r2.dev/{file_name}"
        
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

async def process_and_update_image(photo_reference: str, restaurant_id: str, supabase, request_id: str) -> Optional[str]:
    """
    處理圖片並更新餐廳圖片路徑
    
    Args:
        photo_reference: Google Places API的照片引用ID
        restaurant_id: 餐廳ID
        supabase: Supabase客戶端實例
        request_id: 請求ID，用於日誌關聯
        
    Returns:
        成功時返回圖片URL，失敗時返回None
    """
    try:
        logger.info(f"[{request_id}] 開始處理餐廳 {restaurant_id} 的圖片")
        
        image_url = await download_and_upload_photo(photo_reference)
        if not image_url:
            logger.warning(f"[{request_id}] 無法取得餐廳 {restaurant_id} 的圖片")
            return None
            
        # 更新數據庫中的圖片路徑
        update_result = await supabase.table('restaurants').update({
            "image_path": image_url
        }).eq('id', restaurant_id).execute()
        
        if len(update_result.data) > 0:
            logger.info(f"[{request_id}] 已更新餐廳 {restaurant_id} 的圖片路徑: {image_url}")
            return image_url
        else:
            logger.warning(f"[{request_id}] 更新餐廳 {restaurant_id} 的圖片路徑失敗")
            return None
            
    except Exception as e:
        logger.error(f"[{request_id}] 處理和更新餐廳 {restaurant_id} 的圖片時出錯: {str(e)}")
        return None 