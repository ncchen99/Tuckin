from fastapi import Depends, HTTPException, status, Header, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from gotrue import User
from postgrest import PostgrestClient
from supabase import create_client, Client
import logging
import os
from typing import Optional

from config import SUPABASE_URL, SUPABASE_KEY, SUPABASE_SERVICE_KEY

# 設置日誌記錄器
logger = logging.getLogger(__name__)

# 單例對象，存儲已初始化的客戶端
_supabase_client = None
_supabase_service_client = None

# 創建 Supabase 客戶端，基本上不會用到
def get_supabase() -> Client:
    global _supabase_client
    try:
        # 檢查是否已存在客戶端
        if _supabase_client is not None:
            return _supabase_client
            
        if not SUPABASE_URL or not SUPABASE_KEY:
            logger.error(f"Supabase 配置缺失: URL={bool(SUPABASE_URL)}, KEY={bool(SUPABASE_KEY)}")
            raise ValueError("Supabase URL 或 API 金鑰未配置")
        
        logger.info(f"初始化 Supabase 客戶端: URL={SUPABASE_URL[:10]}...")
        client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        # 測試連接
        try:
            # 使用更簡單的查詢來測試連接
            health_check = client.table("user_status").select("id").limit(1).execute()
            logger.info(f"Supabase 連接成功")
        except Exception as e:
            logger.warning(f"Supabase 連接測試遇到問題: {str(e)}")
        
        # 保存客戶端實例
        _supabase_client = client
        return client
    except Exception as e:
        logger.error(f"初始化 Supabase 客戶端時出錯: {str(e)}")
        # 我們還是返回客戶端，但在日誌中記錄錯誤
        client = create_client(SUPABASE_URL or "", SUPABASE_KEY or "")
        _supabase_client = client
        return client

# 創建 Supabase 服務客戶端 (擁有更高權限)，主要是使用這個
def get_supabase_service() -> Client:
    global _supabase_service_client
    try:
        # 檢查是否已存在服務客戶端
        if _supabase_service_client is not None:
            return _supabase_service_client
            
        if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
            logger.error(f"Supabase 服務配置缺失: URL={bool(SUPABASE_URL)}, SERVICE_KEY={bool(SUPABASE_SERVICE_KEY)}")
            raise ValueError("Supabase URL 或服務金鑰未配置")
        
        logger.info(f"初始化 Supabase 服務客戶端: URL={SUPABASE_URL[:10]}...")
        client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        
        # 保存服務客戶端實例
        _supabase_service_client = client
        return client
    except Exception as e:
        logger.error(f"初始化 Supabase 服務客戶端時出錯: {str(e)}")
        # 返回常規客戶端作為備用
        client = create_client(SUPABASE_URL or "", SUPABASE_KEY or "")
        _supabase_service_client = client
        return client

# 獲取 Postgrest 客戶端
def get_postgrest(supabase: Client = Depends(get_supabase_service)) -> PostgrestClient:
    return supabase.table

# 創建安全依賴
security = HTTPBearer()

# 修改驗證當前用戶的函數
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    supabase: Client = Depends(get_supabase_service)
) -> User:
    try:
        # 從請求頭獲取令牌
        token = credentials.credentials
        logger.debug(f"收到的JWT令牌: {token[:10]}...")
        
        # 使用令牌驗證用戶
        try:
            # 通過JWT令牌獲取用戶
            user = supabase.auth.get_user(token)
            if not user or not user.user:
                logger.warning("用戶驗證失敗: JWT令牌無效")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="無效的認證令牌",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            
            logger.info(f"用戶驗證成功: {user.user.email}")
            return user
        except Exception as e:
            logger.error(f"JWT驗證失敗: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"JWT認證錯誤: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except Exception as e:
        logger.error(f"用戶驗證過程出錯: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供有效的認證信息",
            headers={"WWW-Authenticate": "Bearer"},
        )

# 獲取環境變數中的API密鑰，如果沒有設定則使用默認值
CRON_API_KEY = os.environ.get("CRON_API_KEY", "")

# 依賴函數，用於驗證 cron job 調用
async def verify_cron_api_key(x_api_key: Optional[str] = Header(None)):
    if not x_api_key or x_api_key != CRON_API_KEY:
        raise HTTPException(status_code=403, detail="未授權訪問")
    return True 
