# Android 手動簽名流程開發日誌

## 📅 記錄日期
建立日期：2025年8月5日  
最後更新：2025年8月5日

## 🎯 問題背景

### 問題描述
- **現象**：Flutter 自動簽名過程失效，出現 `NullPointerException`
- **時間線**：2025年6月時自動簽名正常工作，現在（8月）失效
- **影響**：`flutter build appbundle --release` 構建失敗

### 錯誤訊息
```
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':app:signReleaseBundle'.
> A failure occurred while executing com.android.build.gradle.internal.tasks.FinalizeBundleTask$BundleToolRunnable
   > java.lang.NullPointerException (no error message)
```

## 🔧 解決方案：手動簽名流程

### 步驟1：修復構建配置
修復 `build.gradle.kts` 文件以避免 NullPointerException，使構建過程能夠完成（產生未簽名的 AAB）。

### 步驟2：手動簽名過程

#### 環境需求
- Android Studio JBR (Java Runtime)
- 有效的 `.jks` 密鑰文件
- 正確的密鑰密碼

#### 完整指令
```powershell
# 1. 清理並構建未簽名的 AAB
flutter clean
flutter build appbundle --release

# 2. 驗證密鑰文件（可選）
echo "0c1d1214-329a-4ea4-b544-dd2508c64db1" | & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore .\android\app\tuckin-release-key.jks -alias tuckin

# 3. 手動簽名 AAB 文件
& "C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore "android\app\tuckin-release-key.jks" -storepass "0c1d1214-329a-4ea4-b544-dd2508c64db1" "build\app\outputs\bundle\release\app-release.aab" tuckin

# 4. 驗證簽名結果
& "C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -verify -verbose -certs "build\app\outputs\bundle\release\app-release.aab"
```

#### 成功指標
簽名成功時會看到：
- `jar signed.` 訊息
- 簽名者信息：`CN=Tuckin App, OU=Development, O=Tuckin, L=Taiwan, ST=Taiwan, C=TW`
- 驗證結果：`jar verified.`

## 📁 Android 簽名重要檔案說明

### 1. `android/key.properties`
**用途**：密鑰配置文件，存儲簽名相關的敏感信息

**內容結構**：
```properties
storePassword=0c1d1214-329a-4ea4-b544-dd2508c64db1  # 密鑰庫密碼
keyPassword=0c1d1214-329a-4ea4-b544-dd2508c64db1    # 密鑰密碼
keyAlias=tuckin                                      # 密鑰別名
storeFile=app/tuckin-release-key.jks                # 密鑰文件路徑（相對於android資料夾）
```

**重要性**：
- 包含所有簽名必需的認證信息
- **絕對不能**提交到 Git 版本控制
- 應該加入 `.gitignore` 並安全保存備份

### 2. `android/app/build.gradle.kts`
**用途**：Android 應用構建配置文件，定義簽名配置和構建規則

**關鍵簽名配置段落**：
```kotlin
// 讀取簽名配置
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("android/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// 配置簽名
signingConfigs {
    create("release") {
        if (keystorePropertiesFile.exists()) {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
}

// 構建類型配置
buildTypes {
    release {
        if (keystorePropertiesFile.exists()) {
            signingConfig = signingConfigs.getByName("release")
        }
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
```

**重要性**：
- 定義如何讀取和使用簽名配置
- 控制 debug 和 release 版本的構建行為
- 負責將簽名配置應用到構建過程

### 3. `android/app/tuckin-release-key.jks`
**用途**：Java KeyStore 檔案，包含用於簽名 Android 應用的數位憑證和私鑰

**檔案特性**：
- **檔案格式**：Java KeyStore (JKS)
- **大小**：2,744 bytes
- **憑證信息**：
  ```
  擁有者: CN=Tuckin App, OU=Development, O=Tuckin, L=Taiwan, ST=Taiwan, C=TW
  有效期: 2025/6/9 - 2052/10/25 (27年)
  演算法: SHA256withRSA, 2048-bit key
  ```

**重要性**：
- **應用身份識別**：每個 JKS 檔案為應用提供唯一身份
- **更新一致性**：同一應用的所有版本更新必須使用相同的 JKS 檔案
- **安全性極高**：遺失此檔案將無法再更新應用到 Google Play Store
- **備份必要性**：必須妥善保存多份備份

## ⚠️ 安全注意事項

### 檔案權限管理
- `key.properties` 和 `.jks` 檔案包含敏感信息
- 絕對不可提交到版本控制系統
- 應該存儲在安全的地方並定期備份

### `.gitignore` 設定
```gitignore
# Android 簽名檔案
android/key.properties
android/app/*.jks
android/app/*.keystore
```

## 🔍 問題分析

### 可能原因
1. **Flutter/Gradle 版本更新**：6月到8月期間工具鏈版本變化
2. **簽名流程變更**：新版本 Flutter 對簽名配置處理方式改變
3. **環境差異**：Java/Android SDK 版本更新
4. **路徑解析問題**：新版本對檔案路徑處理更嚴格

### 暫時解決方案
使用手動簽名流程，確保應用能夠正常發布到 Google Play Store。

### 長期解決方案
- 研究 Flutter 最新版本的簽名最佳實踐
- 考慮建立自動化腳本簡化手動簽名過程
- 或固定使用特定版本的 Flutter SDK

## 📝 操作檢查清單

### 構建前檢查
- [ ] 確認 `key.properties` 檔案存在且內容正確
- [ ] 確認 `.jks` 檔案存在於正確位置
- [ ] 確認密碼信息正確

### 構建過程
- [ ] 執行 `flutter clean`
- [ ] 執行 `flutter build appbundle --release`
- [ ] 檢查構建是否成功（即使未簽名）

### 手動簽名
- [ ] 使用 `keytool` 驗證密鑰檔案（可選）
- [ ] 使用 `jarsigner` 進行簽名
- [ ] 使用 `jarsigner -verify` 驗證簽名結果

### 發布前確認
- [ ] 確認看到 "jar signed" 訊息
- [ ] 確認看到 "jar verified" 訊息
- [ ] 確認簽名者信息正確
- [ ] AAB 檔案準備好上傳到 Google Play Console

## 🚀 後續改進建議

1. **自動化腳本**：建立 PowerShell 或批處理腳本自動執行手動簽名
2. **版本管理**：記錄工作的 Flutter/Android 工具版本
3. **備份策略**：建立完整的簽名檔案備份和恢復程序
4. **團隊文檔**：確保團隊成員都了解手動簽名流程

---

**作者**：AI Assistant  
**版本**：1.0  
**狀態**：已驗證可用

> 💡 **提示**：此流程已經過實際測試，生成的 AAB 檔案可以成功上傳到 Google Play Store。