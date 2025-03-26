from fastapi import Depends, HTTPException, status
from gotrue import User
from postgrest import PostgrestClient
from supabase import create_client, Client

from config import SUPABASE_URL, SUPABASE_KEY, SUPABASE_SERVICE_KEY

# 創建 Supabase 客戶端
def get_supabase() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

# 創建 Supabase 服務客戶端 (擁有更高權限)
def get_supabase_service() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# 獲取 Postgrest 客戶端
def get_postgrest(supabase: Client = Depends(get_supabase)) -> PostgrestClient:
    return supabase.table

# 驗證當前用戶
async def get_current_user(supabase: Client = Depends(get_supabase)) -> User:
    try:
        user = supabase.auth.get_user()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="用戶未登入",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return user
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="無效的認證憑證",
            headers={"WWW-Authenticate": "Bearer"},
        ) 