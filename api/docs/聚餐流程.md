## 2. 大配對機制API（週二 6:00 AM）

### 2.1. 批量配對API
- **API名稱**：`POST /api/matching/batch`
- **功能**：在週二 6:00 AM 時，系統對所有 `waiting_matching` 狀態的用戶進行配對，嘗試按4人一桌分組。
- **請求參數**：無（由定時任務觸發）
- **處理邏輯**：
  - 將用戶按4人一組進行分組。
  - 滿4人的組別：用戶狀態更新為 `waiting_confirmation`。
  - 不足4人的組別：保持 `waiting_matching` 狀態。
- **響應**：
  ```json
  {
    "success": true,
    "message": "批量配對任務已啟動",
    "matched_groups": 10,
    "remaining_users": 3
  }
  ```

---

## 3. 參加階段API（週二 6:00 AM 至週三 06:00 AM）

### 3.1. 用戶參加API
- **API名稱**：`POST /api/matching/join`
- **功能**：用戶點擊「參加」後，系統嘗試將用戶補入不足4人的桌位或進入等待名單。
- **請求參數**：
  ```json
  {
    "user_id": "用戶ID"
  }
  ```
- **處理邏輯**：
  - 有不足4人的桌位：補入並將狀態更新為 `waiting_confirmation`。
  - 無可用桌位：加入等待名單。
- **響應**：
  ```json
  {
    "status": "waiting_matching",
    "message": "您已加入聚餐配對等待名單",
    "group_id": null,
    "deadline": null
  }
  ```
  或
  ```json
  {
    "status": "waiting_confirmation",
    "message": "您已被分配到桌位",
    "group_id": "GROUP_ID",
    "deadline": "2023-06-15T12:00:00Z"
  }
  ```

### 3.2. 自成桌位API
- **API名稱**：`POST /api/matching/auto-form`
- **功能**：參加階段結束時，若等待名單中用戶數≥3人，自動組成新桌位。
- **請求參數**：無（由定時任務觸發）
- **處理邏輯**：
  - 按3-4人一組組成新桌位。
  - 新桌位用戶狀態更新為 `waiting_confirmation`。
- **響應**：
  ```json
  {
    "success": true,
    "message": "自動成桌任務已啟動",
    "created_groups": 2,
    "remaining_users": 1
  }
  ```

---

## 4. 確認階段API

### 4.1. 用戶確認API
- **API名稱**：`POST /api/dining/confirm`
- **功能**：用戶收到通知後進行確認。
- **請求參數**：
  ```json
  {
    "user_id": "用戶ID",
    "table_id": "桌位ID",
    "status": "attend|not_attend"
  }
  ```
- **處理邏輯**：
  - 確認出席：狀態更新為 `waiting_other_users`（若其他用戶尚未全確認）。
  - 確認不出席：移出桌位並嘗試補位。
- **響應**：
  ```json
  {
    "success": true,
    "message": "已成功更新您的出席狀態",
    "confirmed_status": "attend"
  }
  ```

### 4.2. 檢查桌位確認狀態API
- **API名稱**：`GET /api/dining/groups/{group_id}/status`
- **功能**：查詢桌位中所有用戶的確認狀態。
- **請求參數**：
  - `group_id`：桌位ID
- **響應**：
  ```json
  {
    "group_id": "GROUP_ID",
    "status": "waiting_confirmation",
    "members": [
      {"user_id": "user1", "status": "attend"},
      {"user_id": "user2", "status": "attend"},
      {"user_id": "user3", "status": "pending"},
      {"user_id": "user4", "status": "pending"}
    ]
  }
  ```

### 4.3. 逾時處理API
- **API名稱**：`POST /api/dining/confirmation-timeout`
- **功能**：確認截止後，處理未確認用戶並補位。
- **請求參數**：無（由定時任務觸發）
- **處理邏輯**：
  - 未確認用戶狀態更新為 `confirmation_timeout`。
  - 從等待名單補位，或標記桌位為 `low_attendance`（若出席人數<3）。
- **響應**：
  ```json
  {
    "success": true,
    "message": "確認超時處理任務已啟動"
  }
  ```

---

## 5. 特殊狀態處理API

### 5.1. 配對失敗處理API
- **API名稱**：`POST /api/dining/matching-failed`
- **功能**：週三 06:00 AM 後，將未配對成功的 `waiting_matching` 用戶標記為 `matching_failed`。
- **請求參數**：無（由定時任務觸發）
- **處理邏輯**：
  - 更新狀態為 `matching_failed`。
  - 發送配對失敗通知。
- **響應**：
  ```json
  {
    "success": true,
    "message": "配對失敗處理任務已啟動"
  }
  ```

### 5.2. 低出席率處理API
- **API名稱**：`POST /api/dining/low-attendance`
- **功能**：確認階段結束後，若桌位出席人數<3，處理已確認用戶。
- **請求參數**：無（由定時任務觸發）
- **處理邏輯**：
  - 已確認用戶狀態更新為 `low_attendance`。
  - 發送通知告知桌位可能取消或調整。
- **響應**：
  ```json
  {
    "success": true,
    "message": "低出席率處理任務已啟動"
  }
  ```

---

## 6. 活動進行與後續流程API

### 6.1. 評分API
- **API名稱**：`POST /api/dining/ratings/submit`
- **功能**：活動結束後用戶提交評分。
- **請求參數**：
  ```json
  {
    "user_id": "用戶ID",
    "table_id": "桌位ID",
    "rating": 5,
    "comment": "評論內容"
  }
  ```
- **處理邏輯**：
  - 記錄評分和評論。
- **響應**：
  ```json
  {
    "success": true,
    "message": "評分提交成功"
  }
  ```

---

## 7. 數據模型

### 7.1. 用戶聚餐狀態
```
WAITING_MATCHING: 等待配對
WAITING_CONFIRMATION: 等待確認出席
WAITING_OTHER_USERS: 已確認出席，等待其他用戶確認
WAITING_ATTENDANCE: 全部確認出席，等待聚餐
CONFIRMATION_TIMEOUT: 確認超時
MATCHING_FAILED: 配對失敗
LOW_ATTENDANCE: 低出席率
COMPLETED: 已完成
CANCELLED: 已取消
```

### 7.2. 桌位出席確認狀態
```
ATTEND: 出席
NOT_ATTEND: 不出席
PENDING: 待定
```

---

## 8. 補充注意事項
- **定時任務**：大配對、逾時處理等需由後台定時任務自動執行。
- **通知系統**：建議整合推播服務，確保用戶及時收到狀態變更通知。
- **事務與鎖機制**：配對和補位操作需使用事務或鎖，防止並發衝突，確保桌位人數不超過4人。
- **前端整合**：所有API均支持前端整合，建議通過API客戶端統一調用。

---
