# 測試程式

本資料夾包含API的自動化測試腳本，用於驗證各功能模組的正確性。

## 目錄結構

```
test/
├── matching/               # 配對系統相關測試
│   ├── test_matching.py             # 基本批量配對測試
│   ├── test_matching_scenarios.py   # 配對場景測試
│   └── test_matching_mock.py        # 配對邏輯模擬測試（不需要資料庫）
├── notification/           # 通知服務相關測試
│   └── test_notification_service.py # 通知服務測試
├── README.md               # 本說明文件
└── run_tests.py            # 測試執行腳本
```

## 測試模組說明

### 配對系統測試 (matching/)

配對系統測試用於驗證配對算法的正確性，包括：

1. **基本功能測試**：驗證配對API是否正常工作
2. **配對邏輯測試**：驗證配對結果是否符合配對算法的要求
   - 優先形成2男2女的4人組
   - 優先保持人格類型相同
   - 處理性別不平衡的情況
   - 處理不足4人的情況

#### 測試場景

以下測試場景可在 `test_matching_scenarios.py` 或 `test_matching_mock.py` 中找到：

1. **場景1**: 完美的2男2女同人格類型組合
2. **場景2**: 性別不平衡的情況
3. **場景3**: 缺少某些人格類型的用戶
4. **場景4**: 單一人格類型人數不足4人
5. **場景5**: 自動成桌 - 測試不足4人的情況

### 配對邏輯模擬測試 (test_matching_mock.py)

這個測試文件模擬了資料庫操作，不需要實際的資料庫環境，專注於測試配對邏輯的正確性。對於沒有完整資料庫環境的開發者，可以直接使用這個測試文件驗證算法邏輯。

模擬測試包含：
- 模擬用戶數據
- 模擬配對組數據
- 模擬資料庫操作
- 所有配對邏輯場景測試

### 通知服務測試 (notification/)

通知服務測試用於驗證推送通知功能的正確性，包括：

1. **推送通知功能**：驗證系統能夠正確發送通知
2. **通知接收**：驗證用戶能夠正確接收通知

## 如何運行測試

### 前提條件

1. 對於使用真實資料庫的測試
   - 確保API服務器正在運行
   - 確保Supabase資料庫已連接
   - 確保環境變數已正確設置（SUPABASE_URL, SUPABASE_SERVICE_KEY）

2. 對於使用模擬資料庫的測試
   - 不需要額外設置，可直接運行 `test_matching_mock.py`

### 運行所有測試

```bash
cd api
python test/run_tests.py --all
```

### 運行特定類別測試

```bash
# 運行所有配對系統測試
python test/run_tests.py --matching

# 運行所有通知服務測試
python test/run_tests.py --notification
```

### 運行特定測試

```bash
# 只運行基本批量配對測試
python test/run_tests.py --basic

# 只運行配對場景測試
python test/run_tests.py --scenarios
```

### 直接運行特定測試文件

```bash
# 運行基本批量配對測試
python test/matching/test_matching.py

# 運行配對場景測試
python test/matching/test_matching_scenarios.py

# 運行配對邏輯模擬測試
python test/matching/test_matching_mock.py

# 運行通知服務測試
python test/notification/test_notification_service.py
```

## 測試結果

測試會在執行過程中輸出日誌，並將日誌保存到以下文件：

- `api/test/matching/matching_test.log`: 基本批量配對測試日誌
- `api/test/matching/matching_scenarios.log`: 配對場景測試日誌
- `api/test/matching/matching_mock_test.log`: 配對邏輯模擬測試日誌
- `api/test/notification/notification_test.log`: 通知服務測試日誌
- `api/test/test_results.log`: 測試執行腳本日誌

## 注意事項

1. 使用真實資料庫的測試會清理之前的測試數據，包括用戶資料、配對組等
2. 使用真實資料庫的測試需要服務密鑰有足夠的權限
3. 測試會創建虛擬測試數據，因此不要在生產環境中運行
4. 如果測試失敗，請檢查日誌以了解詳細錯誤信息
5. 對於認證機制較複雜的環境，建議使用 `test_matching_mock.py` 來測試配對邏輯 