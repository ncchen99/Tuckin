
### 總覽：上架流程的五大階段

1.  **事前準備 (Apple Developer Portal & App Store Connect)**：設定好所有必要的憑證、ID 和 App 記錄。
2.  **Flutter 專案準備**：確保您的 Flutter 專案設定正確，特別是版本號和 App 圖示。
3.  **Xcode 設定與封存 (Archive)**：在 Xcode 中進行最後的設定，並將您的 App 打包成一個 `.ipa` 封存檔。
4.  **上傳至 App Store Connect**：使用 Xcode 的工具將封存檔上傳到蘋果的後台。
5.  **最終設定與提交審核**：在 App Store Connect 網站上填寫 App 的所有資訊（截圖、描述等）並提交審核。

-----

### 階段一：事前準備 (一次性設定)

在您開始打包之前，請確保您已經完成了以下在蘋果開發者網站上的設定。

1.  **加入 Apple Developer Program**

      * 您必須擁有一個有效的 Apple 開發者帳號（年費 $99 美元）。

2.  **建立發布憑證 (Distribution Certificate)**

      * 登入 [Apple Developer Portal](https://www.google.com/search?q=https://developer.apple.com/account)。
      * 前往 `Certificates, Identifiers & Profiles` -\> `Certificates`。
      * 點擊 `+` 按鈕，選擇 `Apple Distribution`，然後按照指示建立一個發布憑證。這會需要在您的 Mac 上的「鑰匙圈存取 (Keychain Access)」中產生一個憑證簽署要求 (CSR) 檔案。建立完成後，下載憑證檔案 (`.cer`) 並雙擊安裝到您的鑰匙圈中。

3.  **註冊 App ID**

      * 在 `Identifiers` 頁面，點擊 `+` 按鈕，選擇 `App IDs`。
      * **Description**: 輸入您的 App 名稱（例如：My Awesome App）。
      * **Bundle ID**: 選擇 `Explicit`，並輸入一個全球唯一的 ID，通常是反向網域名稱格式，例如 `com.yourcompany.yourappname`。**這個 ID 非常重要，必須和您 Xcode 專案中的 Bundle Identifier 完全一致。**
      * 如果您的 App 需要推播通知、Apple 登入等服務，請在這裡啟用它們。

4.  **建立描述檔 (Provisioning Profile)**

      * 在 `Profiles` 頁面，點擊 `+` 按鈕。
      * 在 `Distribution` 區塊下，選擇 `App Store`。
      * 選擇您剛剛建立的 App ID。
      * 選擇您剛剛建立的發布憑證。
      * 為這個描述檔命名（例如：My Awesome App AppStore Profile），然後下載 (`.mobileprovision` 檔案)。下載後，雙擊它，Xcode 會自動將其安裝。

5.  **在 App Store Connect 建立 App 記錄**

      * 登入 [App Store Connect](https://appstoreconnect.apple.com/)。
      * 前往 `我的 App (My Apps)`，點擊 `+` 選擇 `新增 App (New App)`。
      * 填寫 App 名稱、主要語言、選擇您剛剛建立的 Bundle ID、並設定一個 SKU（可以和 Bundle ID 相同）。
      * 完成後，您就有了一個可以上傳建置版本的空殼 App。

-----

### 階段二：Flutter 專案準備

現在回到您的 Flutter 專案。

1.  **檢查版本號**

      * 打開 `pubspec.yaml` 檔案。
      * 找到 `version` 欄位，例如：`version: 1.0.0+1`
          * `1.0.0` 是 **版本名稱 (Version Name)**，會顯示在 App Store 上給用戶看。
          * `+1` 是 **版本號 (Build Number)**，這是給 App Store Connect 內部識別用的。**每次上傳新的建置版本時，這個數字都必須增加** (例如 `+2`, `+3`, ...)。

2.  **設定 App 圖示**

      * 建議使用 `flutter_launcher_icons` 套件來自動產生所有尺寸的 iOS 圖示。
      * 如果您選擇手動設定，請在 Xcode 中打開 `ios/Runner/Assets.xcassets/AppIcon` 並將對應尺寸的圖檔拖入。

3.  **編譯 Flutter Release 版本**

      * 在您的 Flutter 專案根目錄下，打開終端機並執行以下指令：
        ```bash
        flutter build ipa
        ```
      * 這個指令會以 `release` 模式編譯您的 Dart 程式碼和 Flutter 引擎，並產生 iOS 需要的檔案。

-----

### 階段三：Xcode 設定與封存 (Archive)

這是本地打包的核心步驟。

1.  **用 Xcode 開啟專案**

      * **非常重要**：不要直接打開 `Runner.xcodeproj`。請打開 `ios/Runner.xcworkspace` 這個白色的檔案。因為 Flutter 專案依賴 Cocoapods，`.xcworkspace` 才會包含所有必要的相依套件。

2.  **設定簽署與能力 (Signing & Capabilities)**

      * 在左側的專案導航器中，點擊最上方的 `Runner` 專案檔，然後在中間的編輯區選擇 `Runner` Target。
      * 切換到 `Signing & Capabilities` 標籤頁。
      * 勾選 `Automatically manage signing` (自動管理簽署)。
      * 在 `Team` 欄位，選擇您加入 Apple Developer Program 的開發者團隊。
      * Xcode 應該會自動幫您選擇正確的簽署憑證和描述檔。如果出錯，請檢查您的 Bundle Identifier 是否與 App ID 完全一致。

3.  **檢查版本號與 Build 號**

      * 切換到 `General` 標籤頁。
      * 在 `Identity` 區塊，確認 `Version` (版本名稱) 和 `Build` (版本號) 與您在 `pubspec.yaml` 中設定的一致。Flutter build 指令通常會自動同步這些值。

4.  **選擇建置裝置**

      * 在 Xcode 頂端的裝置選擇下拉選單中，不要選擇任何模擬器或連接的實體手機，而是選擇 **Any iOS Device (arm64)**。

5.  **封存 (Archive)**

      * 在 Xcode 的頂部選單列中，點擊 `Product` -\> `Archive`。
      * Xcode 會開始編譯和封存您的 App。這個過程可能需要幾分鐘。
      * 如果 `Archive` 選項是灰色的，通常是因為您沒有選擇 `Any iOS Device (arm64)`。

-----

### 階段四：上傳至 App Store Connect

封存成功後，Xcode 會自動彈出一個 "Organizer" 視窗，裡面會列出您剛剛建立的封存檔。

1.  **驗證 App (Validate App)**

      * 在 Organizer 視窗中，選擇您剛剛建立的封存檔。
      * 點擊右側的 `Validate App` 按鈕。
      * Xcode 會檢查憑證、描述檔等設定是否正確。如果沒有問題，會顯示驗證成功。這是一個很好的預先檢查步驟。

2.  **分發 App (Distribute App)**

      * 驗證成功後，點擊右側的 `Distribute App` 按鈕。
      * 選擇 `App Store Connect` 作為分發方式，點擊 `Next`。
      * 選擇 `Upload`，點擊 `Next`。
      * Xcode 會詢問是否要包含 `dSYM` 檔案以供分析 crash log，**強烈建議勾選**。
      * 接下來，Xcode 會處理簽署等問題，您只需要一直點擊 `Next` 或 `Upload`。
      * 上傳過程會需要一些時間，取決於您的網路速度和 App 大小。

3.  **等待處理完成**

      * 上傳成功後，App Store Connect 需要時間來處理您的建置版本（通常是 15 分鐘到幾小時不等）。處理完成後，您會在 App Store Connect 的 `TestFlight` 標籤頁看到您的建置版本，並且會收到一封來自 Apple 的電子郵件通知。

-----

### 階段五：最終設定與提交審核

1.  **回到 App Store Connect 網站**

      * 前往您的 App 頁面。
      * 在 `App Store` 標籤頁下，選擇左側的 `1.0 準備提交` (或對應的版本)。

2.  **選擇建置版本**

      * 在「建置版本 (Build)」區塊，點擊 `+` 按鈕，選擇您剛剛上傳並處理完成的版本。

3.  **填寫 App 資訊**

      * **App 預覽和螢幕快照**: 上傳您 App 的截圖（需要針對不同尺寸的 iPhone 和 iPad）。
      * **描述、關鍵字、技術支援網址、行銷網址**。
      * **分級**: 根據內容回答分級問卷。
      * **價格與銷售範圍**。
      * **App 隱私權**: 填寫您的 App 會收集哪些用戶資料以及用途。
      * **審核資訊**: 如果您的 App 需要登入，請提供一組測試帳號密碼給審核人員。

4.  **提交審核**

      * 當所有必填欄位都完成後，右上角的 `儲存 (Save)` 按鈕會變成 `加入審核 (Add for Review)` 或 `提交以供審核 (Submit for Review)`。
      * 點擊按鈕，確認提交。

您的 App 狀態會變成「等待審核 (Waiting for Review)」。接下來就是等待 Apple 團隊的審核結果了！