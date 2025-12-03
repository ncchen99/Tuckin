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


class GroupAvatarsRequest(BaseModel):
    """群組成員頭像批量請求"""
    dining_event_id: str = Field(..., description="聚餐事件 ID")


class GroupAvatarsResponse(BaseModel):
    """群組成員頭像批量回應"""
    avatars: dict = Field(..., description="用戶頭像 URL 映射 {user_id: url 或 null}")
    expires_in: int = Field(..., description="URL 有效期（秒）")


class BatchChatImagesRequest(BaseModel):
    """批量聊天圖片 URL 請求"""
    dining_event_id: str = Field(..., description="聚餐事件 ID")
    limit: int = Field(default=50, ge=1, le=200, description="每次請求的圖片數量上限")
    offset: int = Field(default=0, ge=0, description="從第幾張圖片開始（用於分頁）")


class BatchChatImagesResponse(BaseModel):
    """批量聊天圖片 URL 回應"""
    images: dict = Field(..., description="圖片路徑與 URL 映射 {image_path: url}")
    total: int = Field(..., description="總圖片數量")
    has_more: bool = Field(..., description="是否還有更多圖片")
    expires_in: int = Field(..., description="URL 有效期（秒）")


