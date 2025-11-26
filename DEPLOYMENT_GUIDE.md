# 🚀 AI 語音行事曆 APP - 完整部署指南

這份文件將引導您完成整個 MVP 的部署流程。

## 📋 部署前準備清單

### ✅ 需要準備的帳號與服務

1. **Firebase 專案**
   - Google 帳號
   - Firebase 專案（免費 Spark 方案即可）
   - 啟用的服務：Authentication, Firestore, Storage, Cloud Functions, Cloud Messaging

2. **OpenAI 帳號**
   - OpenAI API 金鑰
   - 充值帳戶（建議至少 $5 用於測試）

3. **Zeabur 帳號**（或其他容器託管平台）
   - GitHub 帳號（用於連接儲存庫）
   - Zeabur 專案

4. **開發環境**
   - Flutter SDK (>=3.0.0)
   - Node.js (v18+)
   - Python (3.11+)
   - Docker（選用，用於本地測試）

---

## 📝 需要您提供的資訊

在部署過程中，您需要提供以下資訊：

### 1. Firebase 設定檔案

#### Android
- 檔案：`google-services.json`
- 位置：`flutter_app/android/app/`
- 取得方式：Firebase Console > 專案設定 > 您的應用程式 > 下載 google-services.json

#### iOS
- 檔案：`GoogleService-Info.plist`
- 位置：`flutter_app/ios/Runner/`
- 取得方式：Firebase Console > 專案設定 > 您的應用程式 > 下載 GoogleService-Info.plist

#### Web
- 檔案：`firebase_options.dart`
- 位置：`flutter_app/lib/`
- 取得方式：使用 FlutterFire CLI 自動產生（見下方步驟）

### 2. API 金鑰

#### OpenAI API Key
- 用途：語音辨識（Whisper）和語意解析（GPT-4）
- 取得方式：https://platform.openai.com/api-keys
- 設定位置：
  - Zeabur 環境變數：`OPENAI_API_KEY`
  - 本地測試：`zeabur_api/.env`

### 3. Zeabur API URL

部署完 Zeabur API 後，會取得一個 URL（例如：`https://your-project.zeabur.app`）

需要更新到以下位置：
- `flutter_app/lib/utils/constants.dart` → `kZeaburApiBaseUrl`
- Firebase Functions 環境變數：`zeabur.api_url`

---

## 🔧 詳細部署步驟

### 第一階段：Firebase 設定（30 分鐘）

#### 1. 建立 Firebase 專案

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 點擊「建立專案」
3. 輸入專案名稱（例如：`ai-calendar-app`）
4. 選擇是否啟用 Google Analytics（建議啟用）
5. 等待專案建立完成

#### 2. 啟用 Firebase 服務

```bash
# Authentication
- 進入 Authentication > Sign-in method
- 啟用 Email/Password   
- （選用）啟用 Google 登入

# Firestore
- 進入 Firestore Database
- 點擊「建立資料庫」
- 選擇「測試模式」（稍後會部署安全規則）
- 選擇資料庫位置（建議選擇亞洲區域）

# Storage
- 進入 Storage
- 點擊「開始使用」
- 選擇「測試模式」

# Cloud Messaging
- 進入 Cloud Messaging
- 預設已啟用，無需額外設定
```

#### 3. 註冊應用程式並下載設定檔

**Android 應用程式：**
```bash
1. 進入專案設定 > 一般
2. 點擊「新增應用程式」> Android
3. 輸入套件名稱：com.example.ai_calendar_app（可自訂）
4. 下載 google-services.json
5. 將檔案放到：flutter_app/android/app/google-services.json
```

**iOS 應用程式：**
```bash
1. 點擊「新增應用程式」> iOS
2. 輸入套件 ID：com.example.aiCalendarApp（需與 Xcode 專案一致）
3. 下載 GoogleService-Info.plist
4. 將檔案放到：flutter_app/ios/Runner/GoogleService-Info.plist
```

**Web 應用程式（使用 FlutterFire CLI）：**
```bash
# 1. 安裝 FlutterFire CLI
dart pub global activate flutterfire_cli

# 2. 在 flutter_app 目錄執行
cd flutter_app
flutterfire configure

# 3. 選擇您的 Firebase 專案
# 4. 選擇要設定的平台（Android, iOS, Web）
# 5. CLI 會自動產生 firebase_options.dart
```

#### 4. 部署 Firestore 安全規則

```bash
# 進入 firebase 目錄
cd firebase

# 登入 Firebase
firebase login

# 初始化專案（如果尚未初始化）
firebase init

# 選擇：
# - Firestore
# - Functions
# - Storage

# 部署規則
firebase deploy --only firestore:rules
firebase deploy --only storage
```

#### 5. 部署 Firebase Cloud Functions

```bash
# 安裝依賴
cd functions
npm install

# 設定 Zeabur API URL（先使用預設值，稍後更新）
firebase functions:config:set zeabur.api_url="https://temp-url.com"

# 部署 Functions
cd ..
firebase deploy --only functions

# 記錄 Functions URL，例如：
# https://us-central1-your-project.cloudfunctions.net/processVoiceInput
```

---

### 第二階段：Zeabur API 部署（20 分鐘）

#### 1. 準備 OpenAI API Key

1. 前往 [OpenAI Platform](https://platform.openai.com/)
2. 登入帳號
3. 進入 API Keys
4. 點擊「Create new secret key」
5. 複製並儲存金鑰（只顯示一次）

#### 2. 部署到 Zeabur

**方式一：使用 Zeabur Dashboard（推薦）**

```bash
1. 前往 https://zeabur.com/
2. 使用 GitHub 登入
3. 建立新專案
4. 點擊「Deploy New Service」
5. 連接您的 GitHub 儲存庫
6. 選擇 zeabur_api 目錄
7. Zeabur 會自動偵測 Dockerfile
8. 設定環境變數：
   - OPENAI_API_KEY=您的 OpenAI 金鑰
   - ENVIRONMENT=production
   - LOG_LEVEL=INFO
9. 點擊「Deploy」
10. 等待部署完成（約 5-10 分鐘）
11. 記錄您的 API URL（例如：https://ai-calendar-voice-api.zeabur.app）
```

**方式二：本地測試（開發用）**

```bash
# 進入 zeabur_api 目錄
cd zeabur_api

# 安裝依賴
pip install -r requirements.txt

# 下載 spaCy 中文模型
python -m spacy download zh_core_web_sm

# 建立 .env 檔案
cp .env.example .env

# 編輯 .env，填入您的 OpenAI API Key
# OPENAI_API_KEY=sk-your-key-here

# 啟動服務
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 測試 API
curl http://localhost:8000/api/voice/test
```

#### 3. 更新 Zeabur API URL

拿到 Zeabur URL 後，更新以下位置：

**Flutter App:**
```dart
// flutter_app/lib/utils/constants.dart
const String kZeaburApiBaseUrl = 'https://your-actual-url.zeabur.app';
```

**Firebase Functions:**
```bash
firebase functions:config:set zeabur.api_url="https://your-actual-url.zeabur.app"
firebase deploy --only functions
```

---

### 第三階段：Flutter App 設定與執行（15 分鐘）

#### 1. 安裝依賴

```bash
cd flutter_app
flutter pub get
```

#### 2. 確認設定檔案

確保以下檔案已就位：
- ✅ `android/app/google-services.json`
- ✅ `ios/Runner/GoogleService-Info.plist`
- ✅ `lib/firebase_options.dart`（FlutterFire CLI 產生）
- ✅ `lib/utils/constants.dart`（Zeabur URL 已更新）

#### 3. 更新 main.dart

取消註解 Firebase 初始化：

```dart
// flutter_app/lib/main.dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform, // 取消這行的註解
);
```

#### 4. 執行應用程式

**Android:**
```bash
flutter run
```

**iOS (需要 Mac):**
```bash
cd ios
pod install
cd ..
flutter run
```

**Web:**
```bash
flutter run -d chrome
```

---

## ✅ 測試流程

### 1. 測試帳號註冊與登入

1. 啟動 APP
2. 點擊「註冊」
3. 輸入 Email 和密碼
4. 檢查 Firebase Console > Authentication 是否出現新用戶

### 2. 測試手動建立行程

1. 登入後進入行事曆畫面
2. 點擊右下角「+」按鈕
3. 填寫行程資訊
4. 儲存
5. 檢查行程是否出現在行事曆上
6. 檢查 Firestore > events 集合是否有新文檔

### 3. 測試語音建立行程

1. 點擊「語音建立」按鈕
2. 允許麥克風權限
3. 點擊麥克風圖示開始錄音
4. 說出行程（例如：「明天下午兩點在咖啡廳跟 Amy 開會」）
5. 再次點擊停止錄音
6. 等待 AI 處理（約 5-10 秒）
7. 檢查行程是否自動建立

### 4. 除錯檢查點

如果語音功能失敗，依序檢查：

**Zeabur API:**
```bash
# 測試 API 是否運作
curl https://your-zeabur-api.zeabur.app/api/voice/test

# 預期回應：
{
  "status": "ok",
  "message": "Voice API is running",
  ...
}
```

**Firebase Cloud Functions:**
```bash
# 查看日誌
firebase functions:log --only processVoiceInput

# 檢查是否有錯誤訊息
```

**Firestore:**
```bash
# 檢查 voiceProcessing 集合
# 應該有狀態為 "completed" 的文檔

# 檢查 events 集合
# 應該有對應的行程文檔
```

---

## 💰 成本估算（月活 100 用戶）

| 服務 | 用量 | 成本 |
|------|------|------|
| Firebase Spark (免費方案) | - | $0 |
| OpenAI Whisper | 500 次語音（平均 30 秒） | ~$1.5 |
| OpenAI GPT-4 | 500 次解析 | ~$2.5 |
| Zeabur | 512MB RAM | ~$5 |
| **總計** | - | **~$9/月** |

---

## 🎯 下一步擴展功能

部署完成後，您可以考慮：

1. ✅ 加入 Google / Apple 登入
2. ✅ 實作 Cloud Scheduler 排程推播
3. ✅ 加入行程分享功能
4. ✅ 支援週期性行程
5. ✅ 離線模式
6. ✅ 資料匯出（iCal 格式）

---

## 🆘 常見問題

### Q: Flutter 編譯錯誤？
A: 確認 Flutter SDK 版本 >= 3.0，執行 `flutter doctor` 檢查環境。

### Q: Firebase 初始化失敗？
A: 檢查 `firebase_options.dart` 是否正確產生，執行 `flutterfire configure` 重新設定。

### Q: 語音辨識沒反應？
A: 檢查 Zeabur API 是否正常運作，查看 Firebase Functions 日誌。

### Q: OpenAI API 錯誤？
A: 確認 API Key 正確，帳戶有足夠配額。

---

## 📞 支援

如有問題，請檢查：
- Firebase Console 的 Functions 日誌
- Zeabur Dashboard 的應用程式日誌
- Flutter 開發者工具的 Console 輸出

祝您部署順利！🎉



🔹 前端（Flutter）

框架：Flutter（iOS / Android / Web）

套件：

firebase_auth（登入）

cloud_firestore（資料庫）

firebase_messaging（推播）

flutter_sound 或 speech_to_text（語音錄製）

riverpod（狀態管理）

🔹 後端（Firebase）

Firebase Auth → Google / Apple / Email 登入

Firestore → 行程資料儲存

Storage → 語音檔暫存

Cloud Functions →

接收語音檔

呼叫 Zeabur API

寫回 Firestore

Firebase Cloud Messaging (FCM) → 行程提醒

🔹 後端（Zeabur）

語音服務 API（Node.js / FastAPI）

Whisper API（語音 → 文字）

GPT API（文字 → JSON）

NLP 規則（時間 / 地點抽取）

部署：Zeabur 平台（Docker 支援）

🔹 AI & NLP

ASR（語音辨識）：OpenAI Whisper API / faster-whisper

LLM（語意解析）：GPT-4/5 API

NLP 規則：

dateparser（時間）

spaCy（人名 / 地點）

寫在行程備註欄(其他資訊 ex:什麼事、帶什麼物品)