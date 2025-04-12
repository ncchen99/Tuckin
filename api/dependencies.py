from fastapi import Depends, HTTPException, status
from gotrue import User
from postgrest import PostgrestClient
from supabase import create_client, Client
import logging
import os

from config import SUPABASE_URL, SUPABASE_KEY, SUPABASE_SERVICE_KEY

# 設置日誌記錄器
logger = logging.getLogger(__name__)

# 創建 Supabase 客戶端
def get_supabase() -> Client:
    try:
        if not SUPABASE_URL or not SUPABASE_KEY:
            logger.error(f"Supabase 配置缺失: URL={bool(SUPABASE_URL)}, KEY={bool(SUPABASE_KEY)}")
            raise ValueError("Supabase URL 或 API 金鑰未配置")
        
        logger.info(f"初始化 Supabase 客戶端: URL={SUPABASE_URL[:10]}...")
        client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        # 測試連接
        try:
            health_check = client.table("user_status").select("count(*)", count="exact").execute()
            logger.info(f"Supabase 連接成功: user_status 表記錄數 = {health_check.count if hasattr(health_check, 'count') else '未知'}")
        except Exception as e:
            logger.warning(f"Supabase 連接測試遇到問題: {str(e)}")
        
        return client
    except Exception as e:
        logger.error(f"初始化 Supabase 客戶端時出錯: {str(e)}")
        # 我們還是返回客戶端，但在日誌中記錄錯誤
        return create_client(SUPABASE_URL or "", SUPABASE_KEY or "")

# 創建 Supabase 服務客戶端 (擁有更高權限)
def get_supabase_service() -> Client:
    try:
        if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
            logger.error(f"Supabase 服務配置缺失: URL={bool(SUPABASE_URL)}, SERVICE_KEY={bool(SUPABASE_SERVICE_KEY)}")
            raise ValueError("Supabase URL 或服務金鑰未配置")
        
        logger.info(f"初始化 Supabase 服務客戶端: URL={SUPABASE_URL[:10]}...")
        return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    except Exception as e:
        logger.error(f"初始化 Supabase 服務客戶端時出錯: {str(e)}")
        # 返回常規客戶端作為備用
        return create_client(SUPABASE_URL or "", SUPABASE_KEY or "")

# 獲取 Postgrest 客戶端
def get_postgrest(supabase: Client = Depends(get_supabase)) -> PostgrestClient:
    return supabase.table

# 驗證當前用戶
async def get_current_user(supabase: Client = Depends(get_supabase)) -> User:
    try:
        # 記錄當前環境變數檢查
        env_vars = {
            "SUPABASE_URL": os.environ.get("SUPABASE_URL", "未設置"),
            "SUPABASE_KEY_SET": bool(os.environ.get("SUPABASE_KEY")),
            "CONFIG_URL": SUPABASE_URL[:10] + "..." if SUPABASE_URL else "未設置"
        }
        logger.debug(f"環境變數檢查: {env_vars}")
        
        user = supabase.auth.get_user()
        if not user:
            logger.warning("用戶驗證失敗: 未找到用戶")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="用戶未登入",
                headers={"WWW-Authenticate": "Bearer"},
            )
        logger.info(f"用戶驗證成功: {user.user.email if hasattr(user, 'user') and hasattr(user.user, 'email') else '未知'}")
        return user
    except Exception as e:
        logger.error(f"用戶驗證出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"認證錯誤: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        ) 