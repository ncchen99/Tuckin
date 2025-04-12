# 設置環境變數（也可以直接在系統中設置）
$apiKey = "your-default-api-key-change-this"  # 請更換為實際的API密鑰

# API端點
$apiUrl = "http://localhost:8000/api/dining/matching-failed"  # 請根據實際部署情況調整URL

# 呼叫API
try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers @{
        "X-API-Key" = $apiKey
        "Content-Type" = "application/json"
    }
    
    # 記錄結果
    Write-Host "配對失敗處理API呼叫成功: $($response.message)"
    
    # 可選：將結果寫入日誌文件
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - 配對失敗處理API呼叫成功: $($response.message)"
    Add-Content -Path "cron_log.txt" -Value $logMessage
    
} catch {
    # 記錄錯誤
    Write-Host "錯誤: $_"
    
    # 可選：將錯誤寫入日誌文件
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - 錯誤: $_"
    Add-Content -Path "cron_log.txt" -Value $logMessage
} 