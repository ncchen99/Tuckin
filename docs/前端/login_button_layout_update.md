# 登入按鈕樣式更新記錄

## 修改概要

本次更新將登入頁面的按鈕排列從垂直（直排）改為水平（橫排），並更新了按鈕圖片，移除了文字標籤。

## 具體修改內容

### 1. 按鈕排列方式調整

**修改檔案：** `lib/screens/onboarding/login_page.dart`

**變更：**
- 將 `Column` 改為 `Row`
- 設置 `mainAxisAlignment: MainAxisAlignment.center` 居中對齊
- 調整按鈕間距：從 `SizedBox(height: 15.h)` 改為 `SizedBox(width: 20.w)`
- 調整按鈕尺寸：從 160x73 改為 100x60（適應橫排佈局）

**效果：**
- Google 和 Apple 登入按鈕現在並排顯示
- 在 iOS 設備上會同時顯示兩個按鈕（如果 Apple 登入可用）
- 在 Android 設備上只顯示 Google 登入按鈕

### 2. Google 登入按鈕更新

**修改檔案：** `lib/components/onboarding/google_sign_in_button.dart`

**變更：**
- 圖片路徑：`'assets/images/ui/button/red_l.webp'` → `'assets/images/ui/button/google_m.webp'`
- 文字內容：`'Google登入'` → `''`（移除文字）
- 更新註解：說明現在使用圖片按鈕不含文字

### 3. Apple 登入按鈕更新

**修改檔案：** `lib/components/onboarding/apple_sign_in_button.dart`

**變更：**
- 圖片路徑：`'assets/images/ui/button/red_l.webp'` → `'assets/images/ui/button/apple_m.webp'`
- 文字內容：`'Apple登入'` → `''`（移除文字）
- 更新註解：說明現在使用圖片按鈕不含文字

## 新的按鈕佈局

```
原先（垂直排列）：          現在（水平排列）：
┌─────────────┐            ┌─────┐   ┌─────┐
│  Google登入  │      →     │     │   │     │
└─────────────┘            └─────┘   └─────┘
┌─────────────┐             Google    Apple
│  Apple登入   │           (100x60)  (100x60)
└─────────────┘
```

## 使用的圖片資源

- **Google 按鈕圖片：** `assets/images/ui/button/google_m.webp`
- **Apple 按鈕圖片：** `assets/images/ui/button/apple_m.webp`

這些圖片資源已存在於專案中，預期包含相應平台的登入圖示。

## 響應式設計考量

- 按鈕尺寸從 160x73 調整為 100x60，更適合橫排佈局
- 使用 `.w` 和 `.h` 單位確保在不同螢幕尺寸下的適應性
- 按鈕間距設為 20.w，在不同設備上保持適當比例

## 平台兼容性

- **iOS：** 顯示 Google + Apple 登入按鈕（如果支援 Apple 登入）
- **Android：** 僅顯示 Google 登入按鈕
- **Web：** 僅顯示 Google 登入按鈕

## 測試建議

1. **iOS 設備測試：**
   - 驗證兩個按鈕正確並排顯示
   - 確認 Apple 登入按鈕僅在支援的設備上顯示
   - 測試按鈕點擊功能正常

2. **Android 設備測試：**
   - 確認只顯示 Google 登入按鈕
   - 驗證按鈕居中顯示

3. **不同螢幕尺寸測試：**
   - 小螢幕設備上按鈕大小和間距合適
   - 大螢幕設備上按鈕不會過度拉伸

## 後續考量

- 如果需要支援更多登入方式（如 Facebook），可輕鬆擴展橫排佈局
- 圖片資源應包含適當的視覺反饋（如按下狀態）
- 考慮無障礙功能（如語音提示）可能需要為圖片按鈕添加語意標籤
