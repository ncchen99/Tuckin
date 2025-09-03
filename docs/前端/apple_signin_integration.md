# Apple 登入整合說明

本文件說明如何在 Tuckin Flutter 專案中整合 Apple 登入功能。

## 已完成的整合步驟

### 1. 添加依賴套件

在 `pubspec.yaml` 中添加了 `sign_in_with_apple: ^7.0.1` 套件：

```yaml
dependencies:
  sign_in_with_apple: ^7.0.1
```

### 2. 更新 AuthService

在 `lib/services/auth_service.dart` 中添加了 Apple 登入功能：

- 導入了 `sign_in_with_apple` 套件
- 添加了 `signInWithApple()` 方法
- 實現了設備可用性檢查
- 整合了 Supabase OAuth 登入流程
- 包含錯誤處理和調試資訊

### 3. 創建 Apple 登入按鈕元件

創建了 `lib/components/onboarding/apple_sign_in_button.dart`：

- 基於現有的 `ImageButton` 元件
- 支援啟用/禁用狀態
- 使用應用的一致視覺風格

### 4. 更新登入頁面

在 `lib/screens/onboarding/login_page.dart` 中：

- 添加了 Apple 登入處理方法 `_handleAppleSignIn()`
- 實現了與 Google 登入相同的用戶處理邏輯
- 在 UI 中僅在 iOS 平台上顯示 Apple 登入按鈕
- 使用 `FutureBuilder` 檢查 Apple 登入可用性

### 5. 配置 iOS Info.plist

在 `ios/Runner/Info.plist` 中添加了 Apple 登入支援：

```xml
<dict>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>applinks:com.tuckin-coop.tuckin</string>
    </array>
</dict>
```

## 使用方式

Apple 登入按鈕會自動在 iOS 設備上顯示（當 Apple 登入可用時）。用戶點擊後：

1. 檢查隱私條款是否已同意
2. 啟動 Apple 登入流程
3. 獲取用戶憑證
4. 透過 Supabase 完成認證
5. 設定用戶配對偏好
6. 導航到相應頁面

## 特色功能

- **平台檢測**：僅在 iOS 設備上顯示
- **可用性檢查**：動態檢查設備是否支援 Apple 登入
- **統一體驗**：與 Google 登入保持一致的用戶體驗
- **錯誤處理**：完整的錯誤處理和用戶反饋
- **調試支援**：包含詳細的調試日誌

## 注意事項

1. Apple 登入僅在 iOS 13+ 上可用
2. 需要在 Apple Developer Portal 中配置相應的服務
3. 需要在 Xcode 中啟用 "Sign in with Apple" capability
4. 用戶首次登入時可能不提供電子郵件（Apple 的隱私保護）

## 相關文件

- [Apple 登入官方文件](https://developer.apple.com/sign-in-with-apple/)
- [sign_in_with_apple 套件文件](https://pub.dev/packages/sign_in_with_apple)
- [Supabase Apple OAuth 文件](https://supabase.com/docs/guides/auth/social-login/auth-apple)
