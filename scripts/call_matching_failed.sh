#!/bin/bash

# 設置環境變數（也可以直接在系統中設置）
API_KEY="your-default-api-key-change-this"  # 請更換為實際的API密鑰

# API端點
API_URL="http://localhost:8000/api/dining/matching-failed"  # 請根據實際部署情況調整URL

# 日誌文件
LOG_FILE="cron_log.txt"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# 呼叫API
echo "開始呼叫配對失敗處理API: $TIMESTAMP" >> $LOG_FILE

response=$(curl -s -X POST $API_URL \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -w "\n%{http_code}")

# 解析響應和狀態碼
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    # 成功處理
    echo "配對失敗處理API呼叫成功: $body"
    echo "$TIMESTAMP - 配對失敗處理API呼叫成功: $body" >> $LOG_FILE
else
    # 錯誤處理
    echo "錯誤: HTTP狀態碼 $http_code - $body"
    echo "$TIMESTAMP - 錯誤: HTTP狀態碼 $http_code - $body" >> $LOG_FILE
fi 