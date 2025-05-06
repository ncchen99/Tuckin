
對於部署在 Heroku 上的後端，而使用 Google Cloud Scheduler 作為 cron 定時器，您需要以下配置：

1. 首先確保您的 Heroku 應用程式正確設置環境變數：

```bash
echo "# Heroku 環境變數設置命令" | Out-Host
```
```powershell
# 設置 Heroku 環境變數
heroku config:set CRON_API_KEY="your-secure-api-key" --app your-app-name
```

2. 在 Google Cloud Console 中設置 Cloud Scheduler：

- 登入 Google Cloud Console
- 啟用 Cloud Scheduler API
- 創建新的排程作業，設置為 HTTP 請求類型
- 針對批量配對 API 的設置：

```
名稱: tuckin-batch-matching
頻率: 0 6 * * 2  (每週二早上 6 點)
時區: Asia/Taipei
目標類型: HTTP
URL: https://your-heroku-app.herokuapp.com/api/matching/batch
HTTP 方法: POST
HTTP 標頭: 
  Content-Type: application/json
  X-API-Key: your-secure-api-key
```

- 針對配對失敗處理 API 的設置：

```
名稱: tuckin-matching-failed
頻率: 0 8 * * *  (每天早上 8 點)
時區: Asia/Taipei
目標類型: HTTP
URL: https://your-heroku-app.herokuapp.com/api/dining/matching-failed
HTTP 方法: POST
HTTP 標頭: 
  Content-Type: application/json
  X-API-Key: your-secure-api-key
```

3. 自動成桌 API (如果需要)：

```
名稱: tuckin-auto-form
頻率: 0 6 * * 3  (每週三早上 6 點)
時區: Asia/Taipei
目標類型: HTTP
URL: https://your-heroku-app.herokuapp.com/api/matching/auto-form
HTTP 方法: POST
HTTP 標頭: 
  Content-Type: application/json
  X-API-Key: your-secure-api-key
```

4. 確保您的 API 使用 HTTPS，並考慮添加額外的安全措施：

- 在 Heroku 應用設置中啟用自動 SSL
- 考慮將 Cloud Scheduler 設置為使用服務帳戶驗證
- 對於更高的安全需求，可以設置 IP 限制

5. 監控和記錄：

- 在 Heroku 上設置日誌加載項：
```powershell
heroku addons:create papertrail --app your-app-name
```

- 確保您的 API 處理代碼記錄所有重要事件：
```python
# 在您的 API 函數中記錄 Cloud Scheduler 調用
logger.info(f"API 被 Cloud Scheduler 調用: {datetime.now()}")
```

透過 Google Cloud Scheduler 呼叫 Heroku API 的好處是：
- 更可靠的排程執行
- 支援複雜的 cron 表達式
- 集中管理所有排程作業
- 詳細的執行歷史記錄和監控
- 自動重試機制

請確保將 API 密鑰保密，並定期輪換密鑰以提高安全性。
