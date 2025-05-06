* [x] [API] 餐廳搜尋功能，google map api
* [x] [前端] 尚未儲存，是否要儲存
* [x] [前端] 餐廳資訊業面，profile_page route
* [x] [API] 完成餐廳資訊Get功能
* [x] [API] 確保重構是可以正常運作的
* [x] [前端] 歡迎和登錄設定頁面的液面指示器對齊問題

- [x] [SQL] dining_events 新增餐廳已經確認(status 已確認?)
- [x] [API] 完成"餐廳投票功能"
    - [x] 檢查投票是否完成
    - [x] 若已完成，建立聚餐資訊 (dining_events)，設置聚餐資訊status為pending_confirmation，更改所有用戶狀態成 waiting_attendance，發送提醒，返回用戶狀態
    - [x] 若未完成，更改用戶狀態成 waiting_other_users，返回用戶狀態
    - [x] 聚餐時間計算
- [x] [API] server 端計算流程時程
- [x] [API] 修改推薦餐廳的邏輯先檢查餐廳的營業時間
- [x] 歡迎葉面加入手勢 左右
- [x] 修正動畫的比例，按鈕的位置
- [x] 統一有卡片頁面的文字排版 由左至右 Restaurant reservation
- [x] 修正 dialog 字體大小
- [x] [API] 定時更改投票狀態
    - [x] 若已完成，pass
    - [x] 若未完成，更改投票狀態，(根據投票結果)建立聚餐資訊 (dining_events)，更改所有用戶狀態，發送提醒
- [x] [前端] 選擇餐廳葉面
  - [x] 取得投票的餐廳
  - [x] 新增餐廳的呼叫，placeholder 圖片
  - [x] 點擊投票後，送出 API 投票
  - [?] 回傳的餐廳資訊建構聚餐資訊頁面
  - [x] 持久化儲存group ID event ID restaurant info ?
- [x] [前端] 取得聚餐資訊
    - [x] 取得聚餐資訊
    - [x] 持久化儲存dining_events，供 rating 頁面使用
- [x] [前端] 聚餐頁面，下面的提示區域如果餐廳尚未確認完畢顯示提示訊息否則顯示現在的訊息，這則訊息可以點擊點擊之後會跳出對話框是否愿意幫忙訂位，進入餐廳確認頁面
- [x] [前端] 進入聚餐葉面時，檢查餐廳確認是否完成
    - [x] 若已完成，pass
    - [x] 若未完成，跳出對話框，詢問是否願意幫忙確認餐廳
        - [x] 若願意，跳轉至餐廳確認頁面
        - [x] 若不願意，pass
- [x] [前端] 餐廳確認頁面(幫忙檢查營業時間，可以的話幫忙定位)
    - [x] 十分鐘跳轉功能，按這間無法重新跳轉，縱使離開APP再回來，還是惠在正確的時間重新跳轉
    - [ ] 若確認，跳出輸入訂位資料的對話框，更新餐廳狀態
    - [x] 若不確認，此頁面換新餐廳，請用戶再確認一下
- [ ] [前端] 評分葉面
    - [ ] 進入頁面時檢查dining event狀態，如果狀態為pending_confirmation，則跳轉至餐廳確認頁面
    - [ ] 如果查詢不到，則跳轉至預約聚餐頁面
    - [ ] 取得評分資料
    - [ ] 送出評分資料 
- [x] [API] 確認餐廳
    - [x] 若確認，更新餐廳狀態
    - [x] 若不確認，更新聚餐資訊，換新餐廳，返回資訊新餐廳

- [x] [前端] 定時跳出通知，提醒用戶填寫用餐回饋
- [x] [API] 定時更改狀態成 rating
- [x] [API] 刪除非必要端點
- [x] [API] 刪除週期資料 rating_sessions、restaurant_votes、matching_groups、dining_events、user_matching_info，遷移 dining_events 資料(包含 ids)
- [ ] [API] 定時 API 們加入時間檢查
- [ ] [前端] 音樂會暫停的問題

** optional **
- [ ] [API] 後端定時提醒用戶取消預約
- [ ] [新功能] 設計餐廳評價功能
- [ ] [新功能] 聚餐歷史數據查詢
- [ ] [新功能] 推薦餐廳移除，取消選取時右上角出現一個叉叉
- [ ] [新功能] 餐廳移除 API ，需更新table加入包含user ID的欄
- [ ] [新功能] dining_events realtime 更新餐廳資訊頁面
