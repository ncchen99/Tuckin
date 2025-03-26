import boto3
from botocore.client import Config
import uuid
from typing import Optional
import os

from config import R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME

# 設置 Cloudflare R2 端點
R2_ENDPOINT = f'https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com'

# 建立 S3 客戶端連接到 Cloudflare R2
def get_r2_client():
    return boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        config=Config(signature_version='s3v4')
    )

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