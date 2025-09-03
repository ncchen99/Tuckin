# Apple 登入疑難排解

## 常見錯誤：Unacceptable audience in id_token

### 錯誤描述
```
AuthApiException(message: Unacceptable audience in id_token: [com.tuckin-coop.tuckin], statusCode: 400, code: null)
```

### 可能原因和解決方法

#### 1. Supabase Apple OAuth 配置問題

**解決步驟：**

1. **登入 Supabase Dashboard**
   - 前往 Authentication > Providers
   - 找到 Apple 提供者並啟用

2. **配置 Apple OAuth 設定**
   ```
   Client ID: com.tuckin-coop.tuckin (你的 Bundle ID)
   Team ID: [從 Apple Developer Console 獲取]
   Key ID: [從 Apple Developer Console 獲取的 Key ID]
   Private Key: [下載的 .p8 私鑰文件內容]
   ```

#### 2. Apple Developer Console 設定

**確保以下設定正確：**

1. **App ID 配置**
   - Bundle ID: `com.tuckin-coop.tuckin`
   - 啟用 "Sign in with Apple" capability

2. **Service ID 配置**（如果需要）
   - Identifier: `com.tuckin-coop.tuckin.service`
   - 配置 Return URLs 包含你的 Supabase 回調 URL

3. **Private Key 配置**
   - 創建一個新的 Key
   - 啟用 "Sign in with Apple"
   - 下載 .p8 文件並記錄 Key ID

#### 3. 程式碼修正

**已完成的修正：**
- 修正了 `signInWithIdToken` 的參數使用
- 確保使用正確的 `authorizationCode`

### 驗證步驟

1. **檢查 Apple ID Token**
   ```dart
   debugPrint('Apple ID Token audience: ${credential.identityToken}');
   ```

2. **驗證 Supabase 配置**
   - 確認 Client ID 與 Bundle ID 一致
   - 確認私鑰和 Key ID 正確

3. **測試流程**
   - 在 iOS 模擬器/設備上測試
   - 檢查 Supabase 日誌以獲取詳細錯誤信息

### 替代解決方案

如果仍然遇到問題，可以考慮：

1. **使用 Web Auth Flow**
   ```dart
   // 使用 WebAuthenticationOptions 進行 Apple 登入
   await SignInWithApple.getAppleIDCredential(
     webAuthenticationOptions: WebAuthenticationOptions(
       clientId: 'com.tuckin-coop.tuckin.service',
       redirectUri: Uri.parse('https://your-supabase-url.supabase.co/auth/v1/callback'),
     ),
   );
   ```

2. **直接使用 Supabase OAuth URL**
   ```dart
   // 重導向到 Supabase Apple OAuth URL
   final url = 'https://your-supabase-url.supabase.co/auth/v1/authorize?provider=apple';
   ```

### 調試技巧

1. **啟用詳細日誌**
   ```dart
   debugPrint('Credential: ${credential.toString()}');
   debugPrint('Identity Token: ${credential.identityToken}');
   debugPrint('Authorization Code: ${credential.authorizationCode}');
   ```

2. **檢查 Supabase 後端日誌**
   - 在 Supabase Dashboard 查看 Authentication 日誌
   - 尋找相關的錯誤訊息

3. **驗證令牌內容**
   - 使用 jwt.io 解析 identity token
   - 確認 audience (aud) 欄位

### 聯絡支援

如果問題持續存在：
1. 檢查 [Supabase Apple OAuth 文件](https://supabase.com/docs/guides/auth/social-login/auth-apple)
2. 查看 [Apple 登入開發者文件](https://developer.apple.com/sign-in-with-apple/)
3. 聯絡 Supabase 支援團隊
