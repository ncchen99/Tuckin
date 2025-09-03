# Supabase + Flutter Apple 登入完整設定流程

## 1️⃣ Apple Developer 端設定

### 1. 建立 App ID

1. 前往 \[Apple Developer → Identifiers → App IDs]。
2. 點你的 App ID（例如 `com.tuckin-coop.tuckin`）。
3. 勾選 **Sign in with Apple** 能力。
4. 儲存修改。

---

### 2. 建立 Service ID (OAuth Client ID)

1. \[Identifiers → Service IDs → +] 新增一個 Service ID，例如 `com.tuckin-coop.tuckin.supabase`。
2. 勾選 **Sign in with Apple**。
3. 註冊網站 URL：

   * **Domains**: `vnovnsunudotmlkrrvqk.supabase.co`
   * **Return URLs**: `https://vnovnsunudotmlkrrvqk.supabase.co/auth/v1/callback`
4. 儲存 Service ID。

---

### 3. 建立 Key (.p8)

1. \[Keys → +] 新增 Key，勾選 **Sign in with Apple**。
2. 下載 `.p8` 檔案，記下：

   * Key ID
   * Team ID
   * 這個 `.p8` 檔案的內容

> ⚠️ 注意：.p8 檔案只能下載一次，如果遺失需要重新產生。

---

### 4. 產生 Apple OAuth client\_secret (JWT)

用 Node.js 產生 JWT：

```js
const fs = require('fs');
const jwt = require('jsonwebtoken');

const teamId = "V7H59QAJPL";           // 你的 Apple Team ID
const clientId = "com.tuckin-coop.tuckin.supabase"; // Service ID
const keyId = "ABC123XYZ9";            // Key ID
const privateKey = fs.readFileSync("./AuthKey_ABC123XYZ9.p8").toString();

const token = jwt.sign(
  {
    iss: teamId,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 86400 * 180, // 最多 6 個月
    aud: "https://appleid.apple.com",
    sub: clientId,
  },
  privateKey,
  {
    algorithm: "ES256",
    keyid: keyId,
  }
);

console.log(token); // 這個就是 Secret Key
```

> 將輸出的 JWT 字串填到 Supabase **Secret Key (for OAuth)**。

---

## 2️⃣ Supabase 設定

前往 **Dashboard → Auth → Providers → Apple**，填入：

| 欄位         | 填寫內容                                             |
| ---------- | ------------------------------------------------ |
| Client ID  | Service ID（例如 `com.tuckin-coop.tuckin.supabase`） |
| Team ID    | Apple Team ID（例如 `V7H59QAJPL`）                   |
| Key ID     | Apple Key 的 Key ID                               |
| Secret Key | JWT（用 `.p8` 簽出來的 Token）                          |

---

## 3️⃣ Flutter 前端整合

### 1. 安裝套件

```yaml
dependencies:
  supabase_flutter: ^2.0.0
  sign_in_with_apple: ^6.1.0
```

### 2. 呼叫 Apple 登入

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Future<void> signInWithApple() async {
  final rawNonce = Supabase.instance.client.auth.generateRawNonce();
  final appleCredential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: rawNonce,
  );

  final idToken = appleCredential.identityToken;
  if (idToken == null) throw Exception('No ID token from Apple.');

  final res = await Supabase.instance.client.auth.signInWithIdToken(
    provider: OAuthProvider.apple,
    idToken: idToken,
    nonce: rawNonce,
  );

  print("登入成功: ${res.user?.id}");
}
```

### 3. UI 加上按鈕

```dart
SignInWithAppleButton(
  onPressed: () async {
    try {
      await signInWithApple();
    } catch (e) {
      print('Apple 登入失敗: $e');
    }
  },
)
```

---

## 4️⃣ 注意事項

1. Apple OAuth JWT 最多有效期 6 個月，到期要更新 Secret Key。
2. iOS 13+ 才能使用 Apple 登入。
3. 確保 Xcode → Runner → Signing & Capabilities → 加上 **Sign in with Apple**。
4. 回呼 URL 必須和 Service ID 設定一致。

---

這樣照著做，你就能在 Flutter 專案裡順利加入 Apple 登入了 ✅

---

