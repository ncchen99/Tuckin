# Firebase 設置指南

為了讓推送通知功能正常運作，您需要完成以下 Firebase 設置步驟：

## 1. 創建 Firebase 項目

1. 訪問 [Firebase 控制台](https://console.firebase.google.com/)
2. 點擊「新增專案」
3. 輸入專案名稱（例如：TuckIn）
4. 按照指示完成項目創建

## 2. 添加 Android 應用程式

1. 在 Firebase 項目中，點擊「Android」圖標添加 Android 應用
2. 輸入應用程式的套件名稱（例如：com.example.tuckin）
   - 您可以在 `android/app/build.gradle` 文件中的 `applicationId` 找到套件名稱
3. 輸入應用程式暱稱（選填）
4. 下載 `google-services.json` 文件

## 3. 配置 Android 專案

1. 將下載的 `google-services.json` 文件放入 `android/app/` 目錄中
2. 打開 `android/build.gradle` 文件，添加 Google 服務插件：

```gradle
buildscript {
  dependencies {
    // 添加此行
    classpath 'com.google.gms:google-services:4.3.15'
  }
}
```

3. 打開 `android/app/build.gradle` 文件，應用 Google 服務插件：

```gradle
// 在文件底部添加
apply plugin: 'com.google.gms.google-services'
```

4. 同樣在 `android/app/build.gradle` 中，確保最小 SDK 版本至少為 19：

```gradle
defaultConfig {
  minSdkVersion 19
  // ...
}
```

## 4. 取得 Firebase 服務端金鑰

1. 在 Firebase 項目設置中，選擇「服務帳戶」標籤
2. 點擊「產生新私鑰」按鈕，下載私鑰 JSON 文件
3. 將此私鑰內容保存，用於設置 Supabase Edge Function 的環境變數

## 5. 取得 Firebase Cloud Messaging 伺服器金鑰

1. 在 Firebase 項目設置中，選擇「Cloud Messaging」標籤
2. 複製「伺服器金鑰」
3. 將此金鑰用於設置 Supabase Edge Function 的環境變數 `FIREBASE_SERVER_KEY`

## 6. 設置 Supabase Edge Function 環境變數

在 Supabase 控制台中：

1. 前往「設置」>「API」>「Edge Functions」
2. 設置以下環境變數：
   - `FIREBASE_SERVER_KEY`：Firebase Cloud Messaging 伺服器金鑰
   - `FIREBASE_SERVICE_ACCOUNT_JSON`：Firebase 服務帳戶私鑰的 JSON 內容（記得轉義特殊字符）
   - `SERVICE_ROLE_KEY`：Supabase 服務角色密鑰

## 7. 修改 AndroidManifest.xml

打開 `android/app/src/main/AndroidManifest.xml` 文件，添加以下權限：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 添加網絡權限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <!-- 添加通知權限（Android 13 及以上需要） -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <application
        ...>
        <!-- 添加 Firebase 消息服務 -->
        <service
            android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        ...
    </application>
</manifest>
```

## 8. 測試通知

完成上述設置後，您可以測試推送通知功能：

1. 使用 Supabase 管理員面板，將一位用戶的狀態設置為 "waiting_confirmation"
2. 檢查用戶設備是否收到通知
3. 點擊通知，確認是否能正確跳轉到確認出席頁面

## 常見問題排解

- **通知未顯示**：檢查 Firebase 服務是否正確配置，以及設備是否允許應用發送通知
- **通知顯示但點擊無反應**：檢查 `NotificationService` 中的點擊處理邏輯
- **無法部署 Edge Function**：檢查 Supabase CLI 配置和環境變數設置
- **觸發器未激活**：檢查 Supabase 數據庫日誌，確認觸發器是否正確執行