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
from dependencies import get_supabase_service, get_current_user
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
    supabase: Client = Depends(get_supabase_service),
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
async def delete_avatar_from_r2(
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    從 R2 刪除用戶的頭像檔案
    
    流程：
    1. 查詢用戶當前的頭像路徑
    2. 檢查是否為 R2 上的檔案（avatars/ 開頭）
    3. 從 R2 刪除檔案
    4. 返回刪除結果
    
    注意：
    - 用戶只能刪除自己的頭像
    - 只負責 R2 的檔案刪除操作
    - 資料庫更新由前端處理
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
        
        # 檢查是否為 R2 上的檔案
        if not avatar_path.startswith('avatars/'):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="該頭像不在 R2 上，無需刪除"
            )
        
        logger.info(f"用戶 {user_id} 請求刪除 R2 檔案: {avatar_path}")
        
        # 從 R2 刪除檔案
        delete_success = await delete_file_from_private_r2(avatar_path)
        
        if not delete_success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="從 R2 刪除檔案失敗"
            )
        
        logger.info(f"已從 R2 刪除用戶 {user_id} 的頭像檔案: {avatar_path}")
        
        return {"message": "頭像檔案已從 R2 成功刪除"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"刪除 R2 檔案時發生錯誤: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="刪除 R2 檔案時發生錯誤"
        )

@router.get("/avatar/url", response_model=AvatarUrlResponse)
async def get_avatar_url(
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    獲取用戶頭像的 Presigned GET URL
    
    流程：
    1. 查詢用戶的頭像路徑
    2. 檢查是否為 R2 上的自訂頭像（avatars/ 開頭）
    3. 生成 Presigned GET URL（有效期 1 小時）
    4. 返回 URL 供前端顯示
    
    注意：
    - 如果用戶記錄不存在、沒有頭像、或使用預設頭像，返回 404
    - 只有 R2 上的自訂頭像（avatars/ 開頭）才生成 presigned URL
    """
    try:
        user_id = current_user.user.id
        logger.info(f"用戶 {user_id} 請求獲取頭像 URL")
        
        # 查詢用戶的頭像路徑
        result = supabase.table('user_profiles').select('avatar_path').eq('user_id', user_id).execute()
        
        logger.info(f"查詢結果: result.data={result.data}, len={len(result.data) if result.data else 0}")
        
        if not result.data:
            # 用戶記錄不存在（首次使用）
            logger.warning(f"用戶 {user_id} 記錄不存在")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用戶尚未設置頭像"
            )
        
        avatar_path = result.data[0].get('avatar_path')
        logger.info(f"用戶 {user_id} 的頭像路徑: {avatar_path}")
        
        if not avatar_path:
            # 沒有設置頭像
            logger.warning(f"用戶 {user_id} 的 avatar_path 為空")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用戶尚未設置頭像"
            )
        
        # 檢查是否為預設頭像（assets/ 開頭）
        if avatar_path.startswith('assets/'):
            # 使用預設頭像，不需要生成 presigned URL
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用戶使用預設頭像"
            )
        
        # 檢查是否為 R2 上的自訂頭像
        if not avatar_path.startswith('avatars/'):
            logger.warning(f"未知的頭像路徑格式: {avatar_path}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="未知的頭像路徑格式"
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

@router.get("/{user_id}/avatar/url", response_model=AvatarUrlResponse)
async def get_other_user_avatar_url(
    user_id: str,
    supabase: Client = Depends(get_supabase_service),
    current_user = Depends(get_current_user)
):
    """
    獲取其他用戶頭像的 Presigned GET URL
    
    權限控制：
    - 只能查看同一配對組成員的頭像
    - 基於 user_matching_info 表的 RLS 政策進行權限驗證
    
    流程：
    1. 驗證請求者和目標用戶是否在同一配對組
    2. 查詢目標用戶的頭像路徑
    3. 檢查是否為 R2 上的自訂頭像（avatars/ 開頭）
    4. 生成 Presigned GET URL（有效期 1 小時）
    5. 返回 URL 供前端顯示
    
    注意：
    - 如果不在同一配對組，返回 403 Forbidden
    - 如果用戶記錄不存在、沒有頭像、或使用預設頭像，返回 404
    - 只有 R2 上的自訂頭像（avatars/ 開頭）才生成 presigned URL
    """
    try:
        current_user_id = current_user.user.id
        logger.info(f"用戶 {current_user_id} 請求查看用戶 {user_id} 的頭像")
        
        # 1. 驗證權限：檢查兩個用戶是否在同一配對組
        # 查詢當前用戶的配對組
        current_user_matching = supabase.table('user_matching_info') \
            .select('matching_group_id') \
            .eq('user_id', current_user_id) \
            .execute()
        
        if not current_user_matching.data or not current_user_matching.data[0].get('matching_group_id'):
            logger.warning(f"用戶 {current_user_id} 不在任何配對組中")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="您不在任何配對組中，無法查看其他用戶頭像"
            )
        
        current_group_id = current_user_matching.data[0]['matching_group_id']
        
        # 查詢目標用戶的配對組
        target_user_matching = supabase.table('user_matching_info') \
            .select('matching_group_id') \
            .eq('user_id', user_id) \
            .execute()
        
        if not target_user_matching.data or not target_user_matching.data[0].get('matching_group_id'):
            logger.warning(f"目標用戶 {user_id} 不在任何配對組中")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="目標用戶不在任何配對組中"
            )
        
        target_group_id = target_user_matching.data[0]['matching_group_id']
        
        # 驗證是否在同一組
        if current_group_id != target_group_id:
            logger.warning(f"用戶 {current_user_id} 和 {user_id} 不在同一配對組")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="您只能查看同組成員的頭像"
            )
        
        logger.info(f"權限驗證通過：兩用戶都在配對組 {current_group_id} 中")
        
        # 2. 查詢目標用戶的頭像路徑
        result = supabase.table('user_profiles').select('avatar_path').eq('user_id', user_id).execute()
        
        if not result.data:
            logger.warning(f"用戶 {user_id} 記錄不存在")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="目標用戶尚未設置頭像"
            )
        
        avatar_path = result.data[0].get('avatar_path')
        logger.info(f"用戶 {user_id} 的頭像路徑: {avatar_path}")
        
        if not avatar_path:
            logger.warning(f"用戶 {user_id} 的 avatar_path 為空")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="目標用戶尚未設置頭像"
            )
        
        # 3. 檢查是否為預設頭像（assets/ 開頭）
        if avatar_path.startswith('assets/'):
            # 使用預設頭像，不需要生成 presigned URL
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="目標用戶使用預設頭像"
            )
        
        # 4. 檢查是否為 R2 上的自訂頭像
        if not avatar_path.startswith('avatars/'):
            logger.warning(f"未知的頭像路徑格式: {avatar_path}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="未知的頭像路徑格式"
            )
        
        # 5. 生成 Presigned GET URL（有效期 1 小時）
        get_url = generate_presigned_get_url(
            file_key=avatar_path,
            expiration=3600
        )
        
        if not get_url:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="無法生成讀取 URL"
            )
        
        logger.info(f"已為用戶 {current_user_id} 生成用戶 {user_id} 的頭像讀取 URL")
        
        return AvatarUrlResponse(
            url=get_url,
            expires_in=3600
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"獲取其他用戶頭像 URL 時發生錯誤: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="獲取頭像 URL 時發生錯誤"
        ) 