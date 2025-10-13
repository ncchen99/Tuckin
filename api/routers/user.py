from fastapi import APIRouter, Depends, HTTPException, status, Query
from supabase import Client
from typing import List, Optional
import logging

from schemas.user import (
    UserProfileCreate, 
    UserProfileResponse, 
    UserProfileUpdate,
    AvatarUploadResponse,
    AvatarUrlResponse
)
from dependencies import get_supabase, get_current_user
from utils.cloudflare import (
    generate_presigned_put_url,
    generate_presigned_get_url,
    delete_file_from_private_r2  # 僅用於明確刪除頭像的 API
)

logger = logging.getLogger(__name__)

router = APIRouter()

# @router.get("/profile/{user_id}", response_model=UserProfileResponse)
# async def get_user_profile(
#     user_id: str,
#     supabase: Client = Depends(get_supabase),
#     current_user = Depends(get_current_user)
# ):
#     """
#     獲取用戶個人資料
#     """
#     pass

# @router.post("/profile", response_model=UserProfileResponse, status_code=status.HTTP_201_CREATED)
# async def create_user_profile(
#     profile: UserProfileCreate,
#     supabase: Client = Depends(get_supabase),
#     current_user = Depends(get_current_user)
# ):
#     """
#     創建用戶個人資料
#     """
#     pass

# @router.put("/profile", response_model=UserProfileResponse)
# async def update_user_profile(
#     profile: UserProfileUpdate,
#     supabase: Client = Depends(get_supabase),
#     current_user = Depends(get_current_user)
# ):
#     """
#     更新用戶個人資料
#     """
#     pass

# @router.get("/profile", response_model=UserProfileResponse)
# async def get_my_profile(
#     supabase: Client = Depends(get_supabase),
#     current_user = Depends(get_current_user)
# ):
#     """
#     獲取當前用戶個人資料
#     """
#     pass

# @router.get("/device-tokens", response_model=List[str])
# async def get_user_device_tokens(
#     user_id: str,
#     supabase: Client = Depends(get_supabase),
#     current_user = Depends(get_current_user)
# ):
#     """
#     獲取用戶設備令牌列表（用於推送通知）
#     """
#     pass

@router.post("/avatar/upload-url", response_model=AvatarUploadResponse)
async def get_avatar_upload_url(
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取用戶頭像上傳的 Presigned PUT URL
    
    【方案A：統一副檔名】
    - 統一使用 WebP 格式，前端負責轉換
    - 固定檔案路徑：avatars/{user_id}.webp
    - PUT 操作自動覆蓋舊檔案，無需手動刪除
    - 完全避免孤立檔案問題
    
    流程：
    1. 生成固定的頭像路徑（統一使用 .webp）
    2. 生成 Presigned PUT URL
    3. 返回 URL 和 avatar_path 供前端上傳
    
    注意：不在此處更新資料庫，由前端在提交表單時統一保存所有資料
    """
    try:
        user_id = current_user.user.id
        
        # 統一使用固定的頭像路徑（WebP 格式）
        # 前端負責將任何格式轉換為 WebP
        # PUT 操作會自動覆蓋舊檔案，無需手動刪除
        avatar_path = f"avatars/{user_id}.webp"
        
        logger.info(f"用戶 {user_id} 準備上傳/更新頭像: {avatar_path}")
        
        # 生成 Presigned PUT URL（有效期 1 小時）
        upload_url = generate_presigned_put_url(
            file_key=avatar_path,
            expiration=3600,
            content_type="image/webp"
        )
        
        if not upload_url:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="無法生成上傳 URL"
            )
        
        logger.info(f"已為用戶 {user_id} 生成頭像上傳 URL（統一 WebP 格式）")
        
        return AvatarUploadResponse(
            upload_url=upload_url,
            avatar_path=avatar_path,
            expires_in=3600
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"獲取頭像上傳 URL 時發生錯誤: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="獲取上傳 URL 時發生錯誤"
        )

@router.delete("/avatar")
async def delete_avatar(
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    刪除用戶的頭像
    
    流程：
    1. 查詢用戶當前的頭像路徑
    2. 從 R2 刪除檔案
    3. 更新數據庫將 avatar_path 設為 NULL
    """
    try:
        user_id = current_user.user.id
        
        # 查詢用戶當前的頭像路徑
        result = supabase.table('user_profiles').select('avatar_path').eq('user_id', user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到用戶資料"
            )
        
        avatar_path = result.data[0].get('avatar_path')
        
        if not avatar_path:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用戶尚未設置頭像"
            )
        
        # 從 R2 刪除檔案
        delete_success = await delete_file_from_private_r2(avatar_path)
        
        if not delete_success:
            logger.warning(f"刪除 R2 檔案失敗，但仍會清除數據庫記錄: {avatar_path}")
        
        # 更新數據庫將 avatar_path 設為 NULL
        update_result = supabase.table('user_profiles').update({
            'avatar_path': None
        }).eq('user_id', user_id).execute()
        
        if not update_result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="更新數據庫失敗"
            )
        
        logger.info(f"已刪除用戶 {user_id} 的頭像: {avatar_path}")
        
        return {"message": "頭像已成功刪除"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"刪除頭像時發生錯誤: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="刪除頭像時發生錯誤"
        )

@router.get("/avatar/url", response_model=AvatarUrlResponse)
async def get_avatar_url(
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    獲取用戶頭像的 Presigned GET URL
    
    流程：
    1. 查詢用戶的頭像路徑
    2. 生成 Presigned GET URL（有效期 1 小時）
    3. 返回 URL 供前端顯示
    """
    try:
        user_id = current_user.user.id
        
        # 查詢用戶的頭像路徑
        result = supabase.table('user_profiles').select('avatar_path').eq('user_id', user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="找不到用戶資料"
            )
        
        avatar_path = result.data[0].get('avatar_path')
        
        if not avatar_path:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用戶尚未設置頭像"
            )
        
        # 生成 Presigned GET URL（有效期 1 小時）
        get_url = generate_presigned_get_url(
            file_key=avatar_path,
            expiration=3600
        )
        
        if not get_url:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="無法生成讀取 URL"
            )
        
        logger.info(f"已為用戶 {user_id} 生成頭像讀取 URL")
        
        return AvatarUrlResponse(
            url=get_url,
            expires_in=3600
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"獲取頭像 URL 時發生錯誤: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="獲取頭像 URL 時發生錯誤"
        ) 