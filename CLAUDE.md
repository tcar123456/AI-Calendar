# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

AI Calendar App - 語音智能行事曆應用程式。使用 Flutter、Firebase 和 AI 服務。用戶可以自然語音建立行程（例如：「明天下午兩點在咖啡廳跟 Amy 開會」），AI 自動將語音轉換為結構化的行事曆事件。

## 🚨 核心開發原則（必讀）

### 1. 穩定性優先
- **目標**：保持專案穩定、可維護，避免引入不必要的風險
- **做法**：優先修 bug、優化現有功能，而非大規模重構

### 2. 修改前必須說明理由
- **強制要求**：修改任何檔案前，必須先清楚說明「為什麼要改這個檔案」
- **包含內容**：
  - 要解決什麼問題？
  - 為什麼現有程式碼無法滿足需求？
  - 修改的影響範圍是什麼？

### 3. 多檔案修改需要事前計畫
- **流程**：
  1. 先提出完整的修改計畫（哪些檔案、為什麼、怎麼改）
  2. 等待用戶確認計畫
  3. 確認後才開始實作
- **適用情境**：涉及 2 個以上檔案的修改、架構調整、新增功能

### 4. 保持現有架構
- **不要**：隨意更換技術棧（如 Riverpod → Bloc、Firebase → Supabase）
- **不要**：重構沒有問題的程式碼（如「改成更優雅的寫法」）
- **要**：在現有架構內解決問題
- **要**：只有在現有架構確實無法滿足需求時，才提議更換技術

### 5. 使用繁體中文溝通
- 所有回覆、說明、註解請使用繁體中文
- 程式碼變數名稱、函數名稱仍使用英文（遵循業界慣例）

### 6. 漸進式改進
- 優先小範圍修改、快速驗證
- 避免一次性大規模改動
- 確保每次改動都能獨立測試和回滾

## 開發指令

### Flutter App (flutter_app/)

```bash
# 安裝依賴套件
flutter pub get

# 執行應用程式（自動偵測裝置）
flutter run

# 指定平台執行
flutter run -d chrome        # Web
flutter run -d [device-id]   # iOS/Android 裝置

# 建置
flutter build apk            # Android APK
flutter build ios            # iOS
flutter build web            # Web

# 執行測試
flutter test

# 檢查程式碼問題
flutter analyze

# 清理建置產物
flutter clean
```

### Firebase Functions (firebase/functions/)

```bash
# 安裝依賴套件
npm install

# 建置 TypeScript
npm run build

# 監看模式（自動重建）
npm run build:watch

# 部署到 Firebase
npm run deploy

# 查看日誌
npm run logs

# 本地測試（使用模擬器）
npm run serve

# 程式碼檢查
npm run lint
```

### Firebase Emulators (firebase/)

```bash
# 啟動所有模擬器
firebase emulators:start

# 模擬器 UI: http://localhost:4000
# - Auth: port 9099
# - Functions: port 5001
# - Firestore: port 8080
# - Storage: port 9199
```

### Zeabur API (zeabur_api/)

```bash
# 安裝依賴套件
pip install -r requirements.txt

# 下載 spaCy 中文模型（必須）
python -m spacy download zh_core_web_sm

# 本地執行
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 建置 Docker 映像
docker build -t ai-calendar-api .

# 執行 Docker 容器
docker run -p 8000:8000 --env-file .env ai-calendar-api

# 測試 API 健康狀態
curl http://localhost:8000/health
```

## 架構說明

### 三層式分散架構

```
Flutter App (Mobile/Web)
    ↓ Firebase SDK
Firebase Backend (Firestore + Storage + Functions)
    ↓ HTTP
Zeabur API (FastAPI Python) → OpenAI APIs
```

### Flutter 狀態管理 (Riverpod)

使用分層式 Provider 架構：

**Provider 層級：**
- **Service Providers**: 單例服務 (`firebaseServiceProvider`, `voiceServiceProvider`)
- **Auth Flow**: `authStateProvider` → `currentUserIdProvider` → `userDataProvider`
- **Event Flow**: `authState` → `allEventsProvider` → `eventsProvider` (依行事曆篩選)
- **Voice Flow**: `voiceServiceProvider` → `isRecordingProvider` + `voiceProcessingRecordProvider`
- **Controllers**: `StateNotifierProvider` 處理狀態變更 (`authControllerProvider`, `eventControllerProvider`, `voiceControllerProvider`)

**核心模式：**
- UI 使用 `ref.watch()` 監聽 providers
- UI 呼叫 controller 方法執行動作
- Controllers 呼叫 services (Firebase/Voice)
- Services 更新 Firestore
- Providers 透過 Firestore streams 接收即時更新
- UI 自動重建

### 語音處理流程

```
1. 用戶錄製語音 (voice_input_screen.dart)
   ↓
2. VoiceService 錄製音訊
   - Web: WAV 格式存在記憶體 (Uint8List)
   - Mobile: AAC-LC 格式存到暫存檔
   ↓
3. 上傳到 Firebase Storage (voice_recordings/{userId}/{timestamp})
   ↓
4. 建立 voiceProcessing 文檔 (status: "processing")
   ↓
5. Firestore 觸發器 → Cloud Function (voiceHandler.ts)
   ↓
6. Function 呼叫 Zeabur API: POST /api/voice/parse
   ↓
7. Zeabur 處理流程:
   - Whisper: 音訊 → 中文文字轉錄
   - GPT-4: 文字 → 結構化 JSON (標題、時間、地點等)
   - NLP (spaCy + dateparser): 實體提取與驗證
   ↓
8. Function 建立 events 文檔
   ↓
9. Function 更新 voiceProcessing (status: "completed")
   ↓
10. VoiceController 透過 StreamProvider 監聽 voiceProcessing
    ↓
11. 自動呼叫 EventController.createEvent() 建立行程
    ↓
12. 用戶在行事曆中看到新行程
```

### 關鍵檔案與職責

**Flutter App:**
- `lib/providers/`: 所有 Riverpod providers 和 controllers
  - `auth_provider.dart`: 認證狀態 + 用戶資料串流
  - `event_provider.dart`: Event CRUD + 篩選邏輯
  - `voice_provider.dart`: 錄音狀態 + 處理狀態
- `lib/services/firebase_service.dart`: 所有 Firebase 操作 (Firestore, Auth, Storage)
- `lib/services/voice_service.dart`: 跨平台音訊錄製
- `lib/models/`: 領域模型與 Firestore 序列化
  - `calendar_event.dart`: Event 模型 + EventMetadata (追蹤是否為語音建立)
  - `voice_processing_record.dart`: AI 處理狀態追蹤
  - `calendar_model.dart`: 多行事曆支援

**Firebase Functions:**
- `functions/src/voiceHandler.ts`: 監聽 voiceProcessing collection onCreate，呼叫 Zeabur API
- `functions/src/notificationHandler.ts`: 發送 FCM 通知提醒行程

**Zeabur API:**
- `app/routes/voice.py`: POST /api/voice/parse 端點
- `app/services/whisper_service.py`: OpenAI Whisper 轉錄
- `app/services/gpt_service.py`: GPT-4 行程解析（針對中文日期/時間的詳細提示工程）
- `app/services/nlp_service.py`: spaCy 實體提取 + dateparser 處理相對時間

## 資料模型與 Firestore Schema

### Collections

**events/{eventId}**
- `userId`, `calendarId?`, `title`, `startTime`, `endTime`, `location?`, `description?`
- `participants[]`, `reminderMinutes`, `isAllDay`, `labelId?`
- `metadata`: `{createdBy: "voice"|"manual", originalVoiceText?, voiceFileUrl?}`

**voiceProcessing/{processId}**
- `userId`, `audioUrl`, `status` ("processing" | "completed" | "failed")
- `transcription?`, `result?` (VoiceProcessingResult), `eventId?`, `errorMessage?`

**users/{userId}**
- `email`, `displayName`, `photoURL?`, `fcmToken?`, `settings`

**calendars/{calendarId}**
- `ownerId`, `name`, `colorValue`, `isDefault`

**memos/{memoId}**
- `userId`, `title`, `content?`, `isCompleted`, `isPinned`, `priority`

### 安全規則 (firestore.rules)

- 用戶只能讀寫自己的資料（透過 `request.auth.uid == userId` 驗證）
- 建立時強制要求必填欄位（例如：events 必須有 title, startTime, endTime）
- `userId`/`ownerId` 和 `createdAt` 在建立後不可變更
- voiceProcessing collection: Cloud Functions 可透過 service account 更新 (`request.auth == null`)

## 重要模式

### 跨平台音訊錄製

```dart
// VoiceService 中的平台特定處理
if (kIsWeb) {
  // Web: 在記憶體中錄製 WAV，直接上傳 bytes
  final bytes = await record.stop();
  await firebaseService.uploadVoiceFile(bytes: bytes);
} else {
  // Mobile: 錄製到檔案，上傳檔案
  final path = await record.stop();
  await firebaseService.uploadVoiceFile(filePath: path);
}
```

### Firestore 即時同步模式

所有資料 providers 使用 `StreamProvider` 進行即時更新：

```dart
final allEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return ref.read(firebaseServiceProvider).watchUserEvents(userId);
});
```

### Service 單例模式

```dart
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // 所有 Firebase 操作...
}
```

### Controller 狀態變更

```dart
class EventController extends StateNotifier<EventState> {
  final FirebaseService _firebaseService;

  Future<void> createEvent(CalendarEvent event) async {
    state = state.copyWith(isLoading: true);
    try {
      await _firebaseService.createEvent(event);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
```

## 環境配置

### Firebase 設定（必要）

1. 在 https://console.firebase.google.com 建立 Firebase 專案
2. 新增 Flutter 應用程式 (iOS/Android/Web) 並下載設定檔：
   - `google-services.json` → `flutter_app/android/app/`
   - `GoogleService-Info.plist` → `flutter_app/ios/Runner/`
   - 使用 FlutterFire CLI 產生 `firebase_options.dart`
3. 啟用 Authentication (Email/Password, Google, Apple)
4. 建立 Firestore 資料庫 (production mode)
5. 設定 Storage bucket

### Firebase Functions 環境變數

```bash
cd firebase/functions
firebase functions:config:set zeabur.api_url="https://your-api.zeabur.app"
```

或使用 `.env` 檔案（模擬器用）：
```
ZEABUR_API_URL=http://localhost:8000
```

### Zeabur API 環境變數 (.env)

```bash
OPENAI_API_KEY=sk-...
ENVIRONMENT=production
ALLOWED_ORIGINS=https://your-app.firebaseapp.com
```

### Flutter 環境常數

更新 `lib/services/firebase_service.dart` 或建立設定檔：
```dart
static const String zeaburApiUrl = 'https://your-api.zeabur.app';
```

## 本地測試語音功能

1. 啟動 Zeabur API：
   ```bash
   cd zeabur_api
   uvicorn app.main:app --reload
   ```

2. 啟動 Firebase Emulators：
   ```bash
   cd firebase
   firebase emulators:start
   ```

3. 更新 Flutter app 使用模擬器（加到 main.dart）：
   ```dart
   await Firebase.initializeApp();
   if (kDebugMode) {
     FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
     FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
     await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
   }
   ```

4. 執行 Flutter app：
   ```bash
   cd flutter_app
   flutter run
   ```

## 部署說明

### Firebase Functions 部署

```bash
cd firebase
firebase deploy --only functions
```

注意：需使用 Node.js 版本 22（在 package.json engines 中指定）。

### Zeabur API 部署

1. 連接 GitHub repo 到 Zeabur
2. Zeabur 自動偵測 zeabur_api/ 中的 Dockerfile
3. 在 Zeabur dashboard 設定環境變數
4. git push 時自動觸發部署

重要：spaCy 模型 (zh_core_web_sm) 在 Docker build 時下載（見 Dockerfile 第 20 行）。

### Flutter App 部署

**Web:**
```bash
flutter build web
# 部署到 Firebase Hosting 或其他靜態託管
```

**Mobile:**
- iOS: 透過 Xcode 建置，上傳到 App Store Connect
- Android: 建置 APK/AAB，上傳到 Google Play Console

## 多行事曆架構

支援每位用戶建立多個行事曆：

- **舊版行程**：沒有 `calendarId` 的行程會顯示在第一個可用的行事曆
- **預設行事曆**：首次啟動時自動建立 (`isDefault: true`)
- **行事曆顏色**：儲存為 `colorValue` (Color 的整數表示)
- **刪除**：刪除行事曆時，其下所有行程都會被刪除（批次操作）

## 行程標籤

12 種預定義標籤類型 (EventLabelType enum)：
- work, personal, meeting, birthday, appointment, study, exercise, travel, reminder, other, holiday, family

標籤儲存在 `events.labelId`（選填欄位）。

## 通知系統

**目前實作：**
- `notificationHandler.ts` 監聽行程建立
- 如果提醒時間已過，立即發送 FCM 通知
- 使用 users collection 中的 `fcmToken`

**限制：**
- 排程未來通知需要 Cloud Scheduler（尚未實作）
- 正式環境需整合 Cloud Tasks 或 Cloud Scheduler，在 `startTime - reminderMinutes` 時觸發通知

## 常見除錯

### 語音處理卡住

依序檢查：
1. Firestore: voiceProcessing 文檔的 status ("processing" vs "completed")
2. Cloud Functions 日誌: `firebase functions:log`
3. Zeabur API 日誌: 檢查 Zeabur dashboard 或容器日誌
4. 驗證 Cloud Functions 中的 ZEABUR_API_URL 環境變數是否設定

### Firestore 權限錯誤

檢查：
1. 用戶已認證 (`currentUserIdProvider` 不是 null)
2. 文檔的 `userId` 符合 `request.auth.uid`
3. 必填欄位存在（見 firestore.rules 驗證）

### 音訊錄製失敗

檢查：
1. 麥克風權限已授予（iOS Info.plist, Android manifest）
2. 平台：`kIsWeb` 邏輯正確處理 Web vs Mobile
3. Record package 初始化：`await record.hasPermission()`

## GPT 提示工程注意事項

GPT 服務使用 temperature 0.3 和詳細的系統提示（見 `zeabur_api/app/services/gpt_service.py`）：

- 處理中文相對日期：「明天」→ 明天的日期、「下週一」→ 下週一
- 時段關鍵字：「早上」→ 09:00、「下午」→ 14:00、「晚上」→ 19:00
- 預設時長：若未指定則為 1 小時
- 全天行程：偵測關鍵字如「全天」、「整天」
- 要求 ISO 8601 輸出格式

若要提升準確度，修改 `gpt_service.py` 中的系統提示。

## 成本優化

目前設定（每 1000 次語音行程）：
- Whisper API: ~$3 (平均 30 秒 × $0.006/分鐘)
- GPT-4: ~$5 (假設平均 500 tokens × $0.03/1K tokens)

**降低成本方法：**
1. 在 `gpt_service.py` 中改用 GPT-3.5-turbo（便宜 90%）：
   ```python
   model="gpt-3.5-turbo"  # instead of gpt-4
   ```
2. 考慮本地部署 Whisper (faster-whisper)
3. 加入結果快取機制（相同轉錄結果）
4. 限制每位用戶的語音行程次數

## 已知限制

1. **排程通知**：需要 Cloud Scheduler 整合（尚未實作）
2. **週期性行程**：尚不支援重複行程（每日/每週/每月）
3. **行程分享**：尚無多人協作功能
4. **離線模式**：無本地快取，需要網路連線
5. **行事曆匯入/匯出**：尚不支援 iCal
6. **語音編輯**：無法用語音編輯現有行程（僅能建立）
