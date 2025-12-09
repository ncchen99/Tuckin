import boto3
from botocore.client import Config
import uuid
from typing import Optional, List, Dict
import os
import logging
import asyncio
from functools import lru_cache

from config import R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME, R2_PRIVATE_BUCKET_NAME

logger = logging.getLogger(__name__)

# 設置 Cloudflare R2 端點
R2_ENDPOINT = f'https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com'

# 單例 R2 客戶端（避免重複創建）
_r2_client = None

def get_r2_client():
    """獲取 R2 客戶端單例"""
    global _r2_client
    if _r2_client is None:
        _r2_client = boto3.client(
            's3',
            endpoint_url=R2_ENDPOINT,
            aws_access_key_id=R2_ACCESS_KEY_ID,
            aws_secret_access_key=R2_SECRET_ACCESS_KEY,
            config=Config(signature_version='s3v4')
        )
    return _r2_client

# 上傳檔案到 R2
async def upload_file_to_r2(
    file_content: bytes,
    content_type: str,
    folder: str = "general",
    file_extension: str = "jpg"
) -> Optional[str]:
    """
    上傳檔案到 Cloudflare R2
    
    Args:
        file_content: 檔案內容的位元組
        content_type: 檔案的 MIME 類型
        folder: 要保存檔案的資料夾
        file_extension: 檔案擴展名
        
    Returns:
        成功上傳後的檔案 URL，失敗時返回 None
    """
    try:
        client = get_r2_client()
        
        # 生成唯一檔案名
        filename = f"{folder}/{uuid.uuid4()}.{file_extension}"
        
        # 上傳檔案
        client.put_object(
            Bucket=R2_BUCKET_NAME,
            Key=filename,
            Body=file_content,
            ContentType=content_type
        )
        
        # 返回檔案 URL
        return f"https://{R2_BUCKET_NAME}.r2.dev/{filename}"
    except Exception as e:
        print(f"上傳檔案到 R2 時發生錯誤: {e}")
        return None

# 刪除 R2 上的檔案
async def delete_file_from_r2(file_path: str) -> bool:
    """
    從 Cloudflare R2 中刪除檔案
    
    Args:
        file_path: 要刪除的檔案路徑，相對於儲存桶根目錄
        
    Returns:
        刪除操作是否成功
    """
    try:
        client = get_r2_client()
        
        # 刪除檔案
        client.delete_object(
            Bucket=R2_BUCKET_NAME,
            Key=file_path
        )
        
        return True
    except Exception as e:
        print(f"從 R2 刪除檔案時發生錯誤: {e}")
        return False

# 從 URL 提取 R2 路徑
def extract_r2_path_from_url(url: str) -> Optional[str]:
    """
    從完整的 R2 URL 中提取相對路徑
    
    Args:
        url: 完整的 R2 檔案 URL
        
    Returns:
        R2 儲存桶中的相對路徑
    """
    try:
        base_url = f"https://{R2_BUCKET_NAME}.r2.dev/"
        if url.startswith(base_url):
            return url[len(base_url):]
        return None
    except Exception:
        return None

# 生成 Presigned PUT URL (用於上傳) - 同步版本
def generate_presigned_put_url(
    file_key: str,
    bucket_name: str = None,
    expiration: int = 3600,
    content_type: str = "image/png"
) -> Optional[str]:
    """
    生成用於上傳的 Presigned PUT URL（同步版本）
    
    Args:
        file_key: R2 中的檔案鍵值（路徑）
        bucket_name: Bucket 名稱，預設為私有 bucket
        expiration: URL 過期時間（秒），預設 1 小時
        content_type: 檔案的 MIME 類型
        
    Returns:
        Presigned PUT URL，失敗時返回 None
    """
    try:
        if bucket_name is None:
            bucket_name = R2_PRIVATE_BUCKET_NAME
            
        if not bucket_name:
            logger.error("未設置 Bucket 名稱")
            return None
            
        client = get_r2_client()
        
        url = client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': file_key,
                'ContentType': content_type
            },
            ExpiresIn=expiration
        )
        
        logger.debug(f"已生成 PUT Presigned URL: {file_key}")
        return url
    except Exception as e:
        logger.error(f"生成 PUT Presigned URL 時發生錯誤: {e}")
        return None


# 生成 Presigned PUT URL (用於上傳) - 非同步版本
async def generate_presigned_put_url_async(
    file_key: str,
    bucket_name: str = None,
    expiration: int = 3600,
    content_type: str = "image/png"
) -> Optional[str]:
    """
    生成用於上傳的 Presigned PUT URL（非同步版本）
    """
    return await asyncio.to_thread(
        generate_presigned_put_url,
        file_key,
        bucket_name,
        expiration,
        content_type
    )

# 生成 Presigned GET URL (用於讀取) - 同步版本
def generate_presigned_get_url(
    file_key: str,
    bucket_name: str = None,
    expiration: int = 3600
) -> Optional[str]:
    """
    生成用於讀取的 Presigned GET URL（同步版本）
    
    Args:
        file_key: R2 中的檔案鍵值（路徑）
        bucket_name: Bucket 名稱，預設為私有 bucket
        expiration: URL 過期時間（秒），預設 1 小時
        
    Returns:
        Presigned GET URL，失敗時返回 None
    """
    try:
        if bucket_name is None:
            bucket_name = R2_PRIVATE_BUCKET_NAME
            
        if not bucket_name:
            logger.error("未設置 Bucket 名稱")
            return None
            
        client = get_r2_client()
        
        url = client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': bucket_name,
                'Key': file_key
            },
            ExpiresIn=expiration
        )
        
        logger.debug(f"已生成 GET Presigned URL: {file_key}")
        return url
    except Exception as e:
        logger.error(f"生成 GET Presigned URL 時發生錯誤: {e}")
        return None


# 生成 Presigned GET URL (用於讀取) - 非同步版本
async def generate_presigned_get_url_async(
    file_key: str,
    bucket_name: str = None,
    expiration: int = 3600
) -> Optional[str]:
    """
    生成用於讀取的 Presigned GET URL（非同步版本）
    """
    return await asyncio.to_thread(
        generate_presigned_get_url,
        file_key,
        bucket_name,
        expiration
    )


# 批量生成 Presigned GET URLs - 非同步並行版本
async def generate_presigned_get_urls_batch(
    file_keys: List[str],
    bucket_name: str = None,
    expiration: int = 3600
) -> Dict[str, Optional[str]]:
    """
    批量生成用於讀取的 Presigned GET URLs（非同步並行版本）
    
    Args:
        file_keys: R2 中的檔案鍵值列表
        bucket_name: Bucket 名稱，預設為私有 bucket
        expiration: URL 過期時間（秒），預設 1 小時
        
    Returns:
        {file_key: url} 的映射字典
    """
    if not file_keys:
        return {}
    
    async def generate_single(file_key: str) -> tuple[str, Optional[str]]:
        url = await asyncio.to_thread(
            generate_presigned_get_url,
            file_key,
            bucket_name,
            expiration
        )
        return file_key, url
    
    # 並行生成所有 URL
    results = await asyncio.gather(*[generate_single(key) for key in file_keys])
    
    return {key: url for key, url in results}

# 從私有 R2 刪除檔案
async def delete_file_from_private_r2(file_key: str) -> bool:
    """
    從 Cloudflare R2 私有 Bucket 中刪除檔案
    
    Args:
        file_key: 要刪除的檔案鍵值（路徑）
        
    Returns:
        刪除操作是否成功
    """
    try:
        if not R2_PRIVATE_BUCKET_NAME:
            logger.error("未設置私有 Bucket 名稱")
            return False
            
        client = get_r2_client()
        
        # 刪除檔案
        client.delete_object(
            Bucket=R2_PRIVATE_BUCKET_NAME,
            Key=file_key
        )
        
        logger.info(f"已從私有 R2 刪除檔案: {file_key}")
        return True
    except Exception as e:
        logger.error(f"從私有 R2 刪除檔案時發生錯誤: {e}")
        return False


# 刪除私有 R2 資料夾內的所有檔案
def delete_folder_from_private_r2_sync(folder_prefix: str) -> dict:
    """
    從 Cloudflare R2 私有 Bucket 中刪除指定資料夾（前綴）內的所有檔案（同步版本）
    
    Args:
        folder_prefix: 資料夾前綴，例如 "chat_images/"
        
    Returns:
        包含刪除結果的字典 {"deleted_count": int, "errors": list}
    """
    result = {"deleted_count": 0, "errors": []}
    
    try:
        if not R2_PRIVATE_BUCKET_NAME:
            logger.error("未設置私有 Bucket 名稱")
            result["errors"].append("未設置私有 Bucket 名稱")
            return result
            
        client = get_r2_client()
        
        # 列出資料夾內的所有物件
        paginator = client.get_paginator('list_objects_v2')
        pages = paginator.paginate(
            Bucket=R2_PRIVATE_BUCKET_NAME,
            Prefix=folder_prefix
        )
        
        objects_to_delete = []
        
        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    objects_to_delete.append({'Key': obj['Key']})
        
        if not objects_to_delete:
            logger.info(f"資料夾 '{folder_prefix}' 內沒有檔案需要刪除")
            return result
        
        # 批量刪除（每次最多 1000 個）
        batch_size = 1000
        for i in range(0, len(objects_to_delete), batch_size):
            batch = objects_to_delete[i:i + batch_size]
            
            try:
                delete_response = client.delete_objects(
                    Bucket=R2_PRIVATE_BUCKET_NAME,
                    Delete={'Objects': batch}
                )
                
                # 統計成功刪除的數量
                if 'Deleted' in delete_response:
                    result["deleted_count"] += len(delete_response['Deleted'])
                
                # 記錄錯誤
                if 'Errors' in delete_response:
                    for error in delete_response['Errors']:
                        result["errors"].append(f"{error['Key']}: {error['Message']}")
                        
            except Exception as batch_error:
                result["errors"].append(f"批量刪除錯誤: {str(batch_error)}")
        
        logger.info(f"已從私有 R2 刪除資料夾 '{folder_prefix}' 內的 {result['deleted_count']} 個檔案")
        
        if result["errors"]:
            logger.warning(f"刪除過程中發生 {len(result['errors'])} 個錯誤")
        
        return result
        
    except Exception as e:
        logger.error(f"從私有 R2 刪除資料夾時發生錯誤: {e}")
        result["errors"].append(str(e))
        return result


# 刪除私有 R2 資料夾內的所有檔案 - 非同步版本
async def delete_folder_from_private_r2(folder_prefix: str) -> dict:
    """
    從 Cloudflare R2 私有 Bucket 中刪除指定資料夾（前綴）內的所有檔案（非同步版本）
    
    Args:
        folder_prefix: 資料夾前綴，例如 "chat_images/"
        
    Returns:
        包含刪除結果的字典 {"deleted_count": int, "errors": list}
    """
    return await asyncio.to_thread(delete_folder_from_private_r2_sync, folder_prefix)