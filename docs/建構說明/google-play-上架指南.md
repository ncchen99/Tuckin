# 🚀 Google Play 上架指南

## 📋 **重要概念**

### **雙重簽名系統**
Google Play 使用 **App Signing by Google Play** 服務：

1. **上傳簽名金鑰（Upload Key）** 
   - 您用來簽署 .aab 檔案的金鑰
   - 目前使用：`tuckin-release-key.jks`
   - SHA-1：`D0:1C:87:EC:AC:20:0E:1C:7A:45:9B:7C:A5:BF:15:38:87:7A:B5:45`

2. **應用程式簽名金鑰（App Signing Key）**
   - Google Play 用來簽署最終發佈 APK 的金鑰
   - 由 Google Play 管理
   - **這個 SHA-1 才是用戶實際安裝的版本**

## 🔨 **建置步驟**

### **1. 建立 Release App Bundle**
```powershell
flutter build appbundle --release
```

產生的檔案位於：`build\app\outputs\bundle\release\app-release.aab`

### **2. 驗證簽名**
```powershell
cd "C:\Program Files\Android\Android Studio\jbr\bin"
.\keytool.exe -printcert -jarfile "C:\Users\ncc\Desktop\TuckinApp\tuckin\build\app\outputs\bundle\release\app-release.aab"
```

## 📱 **Google Play Console 設定**

### **Step 1: 建立應用程式**
1. 前往 [Google Play Console](https://play.google.com/console)
2. 建立新的應用程式
3. 填寫基本資訊

### **Step 2: 上傳第一個版本**
1. 進入「發行」→「正式版」
2. 上傳 `app-release.aab`
3. **重要**：第一次上傳後，Google 會生成 App Signing Key

### **Step 3: 取得 App Signing Key 的 SHA-1**
1. 上傳完成後，前往「發行」→「設定」→「應用程式簽名」
2. 找到「應用程式簽名金鑰憑證」
3. 複製 **SHA-1 憑證指紋**

## 🔐 **GCP OAuth 設定**

### **需要在 GCP 中新增的 SHA-1 指紋**

1. **開發測試用**（Debug Keystore）：
   ```
   A0:EA:2B:43:F3:8E:5C:BA:67:8C:A8:09:7A:15:90:50:EC:FE:40:A2
   ```

2. **本地發佈測試用**（Upload Key）：
   ```
   D0:1C:87:EC:AC:20:0E:1C:7A:45:9B:7C:A5:BF:15:38:87:7A:B5:45
   ```

3. **Google Play 正式發佈用**（App Signing Key）：
   ```
   [需要從 Google Play Console 取得]
   ```

### **GCP Console 設定步驟**
1. 前往 [Google Cloud Console](https://console.cloud.google.com)
2. APIs與服務 → 憑證
3. 編輯 Android OAuth 2.0 用戶端 ID
4. 在「SHA-1憑證指紋」中新增上述三個指紋
5. 確認套件名稱：`com.tuckin.app`
6. 儲存設定

## ⚠️ **安全注意事項**

### **可以公開的資訊**
✅ SHA-1 指紋（完全安全，可放入 GitHub）
✅ 套件名稱
✅ 應用程式 ID

### **絕對不能公開的資訊**
❌ `.jks` keystore 檔案
❌ `key.properties` 中的密碼
❌ 任何私鑰檔案

## 📄 **重要檔案說明**

```
android/
├── key.properties          # 包含密碼，不能提交
├── app/
│   ├── tuckin-release-key.jks  # 私鑰檔案，不能提交
│   └── build.gradle.kts    # 建置配置，可以提交
```

### **.gitignore 確認**
確保以下檔案已被忽略：
```gitignore
# Android Keystore
*.jks
*.keystore
key.properties
upload-keystore.jks
```

## 🔄 **完整工作流程**

1. **開發階段**：使用 Debug Keystore 測試 OAuth
2. **本地測試**：使用 Upload Key 測試正式簽名
3. **上架準備**：建立 .aab 檔案
4. **首次上架**：上傳到 Google Play，取得 App Signing Key SHA-1
5. **GCP 設定**：將所有 SHA-1 加入 OAuth 限制
6. **正式發佈**：完成上架流程

## 🔐 **使用現有金鑰作為 App Signing Key（推薦）**

如果您希望所有版本（開發、測試、發佈）都使用相同的簽名金鑰，可以使用 PEPK 工具：

### **Step 1: 準備 PEPK 工具**
1. 下載 `pepk.jar` 和 `encryption_public_key.pem` 到專案根目錄
2. 執行 `run-pepk.bat` 腳本
3. 當提示時輸入密碼：`0c1d1214-329a-4ea4-b544-dd2508c64db1`

### **Step 2: 上傳到 Google Play Console**
1. 前往「發行」→「設定」→「應用程式簽名」
2. 選擇「上傳從 Play 加密私密金鑰工具匯出的金鑰」
3. 上傳產生的 `encrypted-private-key.zip`

### **優點**
✅ 所有環境使用相同的 SHA-1 指紋：`D0:1C:87:EC:AC:20:0E:1C:7A:45:9B:7C:A5:BF:15:38:87:7A:B5:45`
✅ OAuth 設定簡化，只需要兩個 SHA-1（Debug + Release）
✅ 完全控制您的簽名金鑰

## 🎯 **下一步行動**

### **選項 1：使用現有金鑰（推薦）**
1. ✅ 已完成：建立 .aab 檔案
2. ⏳ 執行：`run-pepk.bat` 產生加密金鑰
3. ⏳ 上傳：encrypted-private-key.zip 到 Google Play Console
4. ⏳ 設定：GCP OAuth（只需 2 個 SHA-1）

### **選項 2：讓 Google 產生新的 App Signing Key**
1. ✅ 已完成：建立 .aab 檔案
2. ⏳ 上傳：.aab 檔案到 Google Play Console
3. ⏳ 取得：App Signing Key SHA-1
4. ⏳ 設定：GCP OAuth（需要 3 個 SHA-1） 