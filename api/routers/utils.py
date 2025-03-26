from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from supabase import Client
from typing import List, Optional

from dependencies import get_supabase, get_current_user

router = APIRouter()

@router.post("/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    folder: Optional[str] = "general",
    supabase: Client = Depends(get_supabase),
    current_user = Depends(get_current_user)
):
    """
    上傳圖片到 Cloudflare R2
    """
    pass

@router.get("/health")
async def health_check():
    """
    健康檢查端點
    """
    return {"status": "ok"} 