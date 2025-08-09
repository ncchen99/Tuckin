## GCP Scheduler 設定指南（Generate 與 Execute）

本指南說明如何在 GCP 建立兩個 Cloud Scheduler 工作，定時呼叫後端排程 API：

- 產生排程：POST /api/schedule/generate
- 執行排程：POST /api/schedule/execute

注意：若你的後端目前將 `schedule` 路由無 prefix 掛載，實際路徑會是 `/generate` 與 `/execute`。請依你的服務實際路徑替換以下 URL。

### 先決條件
- 後端可被外部 HTTPS 存取（Cloud Run、VM、其他均可）。
- 後端已實作並部署 API：
  - 產生排程：POST `/api/schedule/generate`（或 `/generate`）
  - 執行排程：POST `/api/schedule/execute`（或 `/execute`）
- 於後端 `.env` 設定 `CRON_API_KEY`，並於呼叫端（GCP Scheduler）以 `X-API-KEY` Header 提供相同值。

---

## 建立 Scheduler（GCP Console）

### 1) 產生排程：generate-schedule
- 頻率（UTC）：`0 0 * * *`（每天 00:00 UTC）
- 方法：POST
- URL：`https://<YOUR_HOST>/api/schedule/generate`（或 `/generate`）
- 標頭：
  - `Content-Type: application/json`
  - `X-API-KEY: <CRON_API_KEY>`
- Body：`{}`
- 時區：`Etc/UTC`

### 2) 執行排程：execute-schedule
- 頻率（UTC）：`0 */2 * * *`（每 2 小時整點）
- 方法：POST
- URL：`https://<YOUR_HOST>/api/schedule/execute`（或 `/execute`）
- 標頭：
  - `Content-Type: application/json`
  - `X-API-KEY: <CRON_API_KEY>`
- Body：`{}`
- 時區：`Etc/UTC`

備註：後端在 `/execute` 內使用 ±10 分鐘容忍視窗擷取待執行任務，兩小時頻率即可涵蓋 06:00、22:00 等整點任務。

---

## 建立 Scheduler（gcloud 指令）

請先替換：
- `<PROJECT_ID>`：你的 GCP 專案 ID
- `<REGION>`：Scheduler 地區（例：`asia-east1`）
- `<YOUR_HOST>`：後端域名（含 HTTPS）
- `<CRON_API_KEY>`：與後端環境變數一致

```bash
gcloud config set project <PROJECT_ID>

# 1) generate-schedule：每日 00:00 UTC
gcloud scheduler jobs create http generate-schedule \
  --location=<REGION> \
  --schedule="0 0 * * *" \
  --time-zone="Etc/UTC" \
  --http-method=POST \
  --uri="https://<YOUR_HOST>/api/schedule/generate" \
  --headers="Content-Type=application/json,X-API-KEY=<CRON_API_KEY>" \
  --message-body='{}'

# 2) execute-schedule：每 2 小時
gcloud scheduler jobs create http execute-schedule \
  --location=<REGION> \
  --schedule="0 */2 * * *" \
  --time-zone="Etc/UTC" \
  --http-method=POST \
  --uri="https://<YOUR_HOST>/api/schedule/execute" \
  --headers="Content-Type=application/json,X-API-KEY=<CRON_API_KEY>" \
  --message-body='{}'
```

若你的路由無 prefix，將上述 `.../api/schedule/generate` 改為 `.../generate`，`.../api/schedule/execute` 改為 `.../execute`。

---

## 驗證與除錯

### cURL 測試
```bash
# 產生排程
curl -X POST "https://<YOUR_HOST>/api/schedule/generate" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: <CRON_API_KEY>" \
  -d '{}'

# 執行排程
curl -X POST "https://<YOUR_HOST>/api/schedule/execute" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: <CRON_API_KEY>" \
  -d '{}'
```

### 常見問題
- 401/403：
  - 確認 `X-API-KEY` 是否與後端 `.env` 的 `CRON_API_KEY` 一致。
  - 確認後端是否正確讀取環境變數。
- 404：
  - 確認實際掛載路徑是否有 prefix（`/api/schedule/*`）或沒有（`/generate`、`/execute`）。
- 時間點未觸發：
  - 後端以台北時區推導單/雙週聚餐日與四種任務點，最後轉 UTC 寫入 DB；請確認 Scheduler 時區為 `Etc/UTC`。
  - `/execute` 使用 ±10 分鐘容忍視窗，若你自訂頻率，請確保能涵蓋整點附近時段。
- DB 唯一約束衝突：
  - 已在後端批次內去重與 upsert 防重；若仍有衝突請檢查 DB 時區與既有資料是否手動插入重複。

---

## 安全性建議
- `CRON_API_KEY` 請存於安全的 Secret（例如 Cloud Scheduler 透過 Secret Manager 注入或直接在 Scheduler 設定頁面輸入 Header）。
- 後端應僅以 HTTPS 對外提供，避免金鑰外洩。
- 若你的服務僅允許內部訪問，可改用 OIDC 並驗證 `Authorization`，但目前後端已使用 `X-API-KEY` 即可。

---

## 維護與調整
- 調整任務規則：修改後端 `api/routers/schedule.py` 中的時間推導邏輯（已依單/雙週與聚餐相對時間實作）。
- 手動補排：直接呼叫 `/api/schedule/generate`。
- 觀察執行：
  - `/api/schedule/execute` 回傳包含每筆任務的執行結果與錯誤訊息。
  - 檢查 DB `schedule_table` 的 `status` 欄位（`pending/done/failed`）。


