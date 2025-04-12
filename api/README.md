# TuckIn API 服務

學生聚餐與交友平台的後端 API 服務。

## 架構概述

此 API 服務基於 FastAPI 建構，主要處理需要伺服器端處理的敏感資料、通知發送及無法透過 Supabase RLS 直接在前端處理的操作。

### 主要功能模組

- **群組管理模組**: 處理群組創建、成員管理等功能
- **餐廳管理模組**: 搜索、記錄餐廳資訊及投票功能
- **配對系統模組**: 處理用戶聚餐配對、成桌管理等功能
- **聚餐管理模組**: 處理桌位確認、評分等功能
- **通知模組**: 發送和管理用戶通知
- **用戶資料處理模組**: 處理用戶資料的讀寫
- **通用工具**: 提供圖片上傳等功能

## 技術棧

- **FastAPI**: Web 框架
- **Supabase**: 身份認證、數據存儲
- **Firebase Cloud Messaging**: 推送通知
- **Google Places API**: 餐廳資訊獲取
- **Cloudflare R2**: 圖片存儲

## 安裝與運行

### 必要條件

- Python 3.8+
- 正確設置的環境變數

### 設置環境變數

創建 `.env` 文件，包含以下配置:

```
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_key
FIREBASE_CONFIG={"your_firebase_config_json"}
GOOGLE_PLACES_API_KEY=your_google_places_api_key
R2_ACCOUNT_ID=your_r2_account_id
R2_ACCESS_KEY_ID=your_r2_access_key
R2_SECRET_ACCESS_KEY=your_r2_secret_key
R2_BUCKET_NAME=your_r2_bucket_name
```

### 安裝依賴

```bash
pip install -r requirements.txt
```

### 運行開發服務器

```bash
uvicorn main:app --reload
```

## API 端點

服務啟動後，可通過 `/docs` 訪問 Swagger UI 查看完整 API 文檔。

### 主要端點概述

- **群組 API**: `/api/group/*`
- **餐廳 API**: `/api/restaurant/*`
- **用戶 API**: `/api/user/*`
- **工具 API**: `/api/utils/*`
- **配對 API**: `/api/matching/*`
- **聚餐 API**: `/api/dining/*`

### 聚餐配對API端點

#### 配對端點
- **`POST /api/matching/batch`**: 批量配對任務
- **`POST /api/matching/join`**: 用戶參加聚餐配對
- **`POST /api/matching/auto-form`**: 自動成桌任務

#### 聚餐端點
- **`POST /api/dining/confirm`**: 用戶確認出席狀態
- **`GET /api/dining/groups/{group_id}/status`**: 查詢桌位確認狀態
- **`POST /api/dining/confirmation-timeout`**: 處理確認超時
- **`POST /api/dining/matching-failed`**: 處理配對失敗
- **`POST /api/dining/low-attendance`**: 處理低出席率
- **`POST /api/dining/ratings/submit`**: 提交聚餐評分

## 數據庫設計

系統使用 Supabase 作為數據庫，主要表結構包括:

- 用戶資料相關表
- 群組及成員表
- 餐廳資訊表
- 聚餐配對表
- 聚餐成員表
- 投票和評分表
- 聚餐事件表
- 通知表

## 聚餐配對流程

系統使用固定的聚餐配對週期：

1. **等待配對階段**: 用戶可以加入等待配對
2. **大配對機制**: 週二早上6:00自動配對
3. **參加階段**: 未配對成功的用戶可繼續加入
4. **確認階段**: 用戶確認是否參加聚餐
5. **活動進行與評分**: 用戶參加聚餐並於事後評分

詳細流程請參見 `api/docs/聚餐流程.md`

## 注意事項

- 所有敏感操作均需要進行身份驗證
- 確保所有外部服務 (Firebase, Google Places, Cloudflare R2) 的正確配置
- 聚餐配對相關的定時任務需要單獨設置排程 