from pydantic import BaseModel, Field
from typing import Optional


class ChatImageUploadRequest(BaseModel):
    """聊天圖片上傳請求"""
    dining_event_id: str = Field(..., description="聚餐事件 ID")
    message_id: str = Field(..., description="訊息 ID（前端生成的 UUID）")


class ChatImageUploadResponse(BaseModel):
    """聊天圖片上傳回應"""
    upload_url: str = Field(..., description="圖片上傳 URL")
    image_path: str = Field(..., description="圖片在 R2 上的路徑")
    expires_in: int = Field(..., description="URL 有效期（秒）")


class ChatImageUrlRequest(BaseModel):
    """聊天圖片讀取 URL 請求"""
    image_path: str = Field(..., description="圖片在 R2 上的路徑")


class ChatImageUrlResponse(BaseModel):
    """聊天圖片讀取 URL 回應"""
    url: str = Field(..., description="圖片讀取 URL")
    expires_in: int = Field(..., description="URL 有效期（秒）")


class ChatNotifyRequest(BaseModel):
    """聊天訊息通知請求"""
    dining_event_id: str = Field(..., description="聚餐事件 ID")
    message_preview: str = Field(..., description="訊息預覽內容", max_length=100)
    message_type: str = Field(..., description="訊息類型：text 或 image")


