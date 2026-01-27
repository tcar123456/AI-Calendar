# 🎙️ AI 語音行事曆 APP

一個風格為黑白簡約風格同時支援語音建立行程的智能行事曆應用程式，使用 Flutter 開發，整合 Firebase 與 AI 語音辨識。

> 💡 **特色功能**：用「說」的就能建立行程！「明天下午兩點在咖啡廳跟 Amy 開會」→ AI 自動幫你建立行程

---

## 📱 主要功能

- ✅ **基礎行事曆功能**：建立、編輯、刪除、檢視行程
- 📅 **多行事曆管理**：支援建立多個行事曆，每個行事曆可設定不同顏色
- 🏷️ **行程標籤分類**：12 種預定義標籤（工作、個人、會議、生日等）
- 🎤 **AI 語音建立行程**：口語化描述自動轉換為結構化行程
- 🔔 **行程提醒推播**：透過 Firebase Cloud Messaging 推送通知
- 🔐 **多種登入方式**：Email/密碼、Google、Apple 登入
- 📝 **備忘錄功能**：待辦事項管理，支援優先級和釘選
- 📱 **跨平台支援**：iOS、Android、Web 三端通用
- 🌐 **即時同步**：所有裝置上的行程資料即時更新

---

## 🏗️ 技術架構

### 前端技術棧
- **框架**：Flutter 3.0+ (Dart)
- **狀態管理**：Riverpod 2.4+
- **UI 組件**：Material Design 3
- **行事曆**：table_calendar
- **語音錄製**：record, speech_to_text

### 後端技術棧
- **身份認證**：Firebase Authentication
- **資料庫**：Cloud Firestore (NoSQL)
- **檔案儲存**：Firebase Storage
- **無伺服器函數**：Firebase Cloud Functions (Node.js/TypeScript)
- **推播通知**：Firebase Cloud Messaging (FCM)

### AI 服務技術棧
- **語音辨識**：OpenAI Whisper API
- **語意解析**：OpenAI GPT-4
- **NLP 增強**：spaCy (中文模型) + dateparser
- **API 框架**：FastAPI (Python 3.11)
- **部署平台**：Zeabur (Docker)

---

## 📁 專案結構

```
AI-Calendar-App/
│
├── 📱 flutter_app/                    # Flutter 前端應用
│   ├── lib/
│   │   ├── models/                   # 資料模型（Event, User）
│   │   ├── providers/                # Riverpod 狀態管理
│   │   ├── services/                 # 服務層（Firebase, Voice）
│   │   ├── screens/                  # UI 畫面
│   │   └── widgets/                  # 共用元件
│   └── pubspec.yaml                  # Flutter 依賴設定
│
├── ☁️ firebase/                       # Firebase 設定與 Cloud Functions
│   ├── functions/                    # Cloud Functions 程式碼
│   │   └── src/
│   │       ├── voiceHandler.ts       # 語音處理函數
│   │       └── notificationHandler.ts # 推播處理函數
│   ├── firestore.rules               # Firestore 安全規則
│   ├── storage.rules                 # Storage 安全規則
│   └── firebase.json                 # Firebase 專案設定
│
├── 🤖 zeabur_api/                     # AI 語音處理 API
│   ├── app/
│   │   ├── services/
│   │   │   ├── whisper_service.py    # Whisper 語音辨識
│   │   │   ├── gpt_service.py        # GPT-4 語意解析
│   │   │   └── nlp_service.py        # NLP 增強處理
│   │   ├── routes/                   # API 路由
│   │   └── models/                   # 資料模型
│   ├── Dockerfile                    # Docker 映像設定
│   └── requirements.txt              # Python 依賴
│
├── 📖 DEPLOYMENT_GUIDE.md             # 完整部署指南（重要！）
├── 📘 CLAUDE.md                       # Claude Code 開發指南
├── 🎤 VOICE_OPTIMIZATION_GUIDE.md    # 語音功能優化指南
└── 📄 README.md                       # 本文件
```

---

## 🚀 快速開始

### ⚡ 5 分鐘快速預覽

**尚未部署？請先閱讀 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)**

如果您已經完成部署，可以：

```bash
# 1. 進入 Flutter 專案
cd flutter_app

# 2. 安裝依賴
flutter pub get

# 3. 執行應用程式
flutter run
```

### 📋 部署前準備

您需要準備以下帳號和資源：

- ✅ Firebase 專案（免費方案即可）
- ✅ OpenAI API 金鑰（需充值至少 $5）
- ✅ Zeabur 帳號或其他容器託管平台
- ✅ Flutter 開發環境（SDK >= 3.0）

### 📝 需要提供的資訊

在部署過程中，您需要提供：

1. **Firebase 設定檔案**
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)
   - `firebase_options.dart` (Web/所有平台)

2. **OpenAI API Key**
   - 用於 Whisper 語音辨識和 GPT-4 語意解析

3. **Zeabur API URL**
   - 部署 Zeabur API 後取得的端點 URL

**📘 詳細部署步驟請參閱：[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)**

---

## 🎬 功能展示

### 語音建立行程流程

```
1. 點擊「語音建立」按鈕
   ↓
2. 開始錄音並說出行程
   例如：「明天下午兩點在咖啡廳跟 Amy 開會，記得帶筆電」
   ↓
3. 停止錄音
   ↓
4. AI 自動處理（5-10 秒）
   - Whisper：語音 → 文字
   - GPT-4：文字 → 結構化資料
   - NLP：增強準確度
   ↓
5. 行程自動建立 ✅
   - 標題：跟 Amy 開會
   - 時間：明天 14:00-15:00
   - 地點：咖啡廳
   - 備註：記得帶筆電
```

### 支援的語音格式

| 語音描述 | AI 理解結果 |
|---------|----------|
| 「明天下午兩點開會」 | 明天 14:00-15:00，標題：開會 |
| 「下週一早上九點半去公司」 | 下週一 09:30-10:30，地點：公司 |
| 「後天全天休假」 | 後天 00:00-23:59，全天行程 |
| 「今晚七點在餐廳吃飯，記得訂位」 | 今天 19:00-20:00，地點：餐廳，備註：記得訂位 |

---

## 💡 核心技術亮點

### 1. 智慧語音解析

採用三階段 AI 處理流程，確保高準確度：

```
階段 1：Whisper API
語音 → 文字（支援繁體中文）

階段 2：GPT-4
文字 → 結構化 JSON
- 提取標題、時間、地點
- 處理相對時間（明天、下週）
- 整理備註資訊

階段 3：NLP 增強
- dateparser：處理複雜時間表達
- spaCy：提取地點實體
- 自動校正邏輯錯誤
```

### 2. 即時資料同步

使用 Firestore 的即時監聽功能：

```dart
// 所有裝置上的行程自動同步
Stream<List<CalendarEvent>> watchUserEvents(String userId) {
  return firestore
    .collection('events')
    .where('userId', isEqualTo: userId)
    .snapshots()
    .map((snapshot) => /* 轉換為模型 */);
}
```

### 3. 完善的狀態管理

使用 Riverpod 實現清晰的狀態管理架構：

```
AuthProvider → 認證狀態
  ├─ UserDataProvider → 用戶資料
  └─ EventsProvider → 行程列表
      └─ EventControllerProvider → 行程操作

VoiceProvider → 語音狀態
  └─ VoiceControllerProvider → 語音錄製與處理
```

---

## 📊 資料結構設計

### Firestore Collections

#### users/{userId}
```json
{
  "email": "user@example.com",
  "displayName": "John Doe",
  "photoURL": "https://...",
  "createdAt": Timestamp,
  "settings": {
    "defaultReminderMinutes": 15,
    "language": "zh-TW"
  },
  "fcmToken": "fcm_token_here"
}
```

#### events/{eventId}
```json
{
  "userId": "user_id",
  "title": "跟 Amy 開會",
  "startTime": Timestamp,
  "endTime": Timestamp,
  "location": "咖啡廳",
  "description": "記得帶筆電",
  "participants": [],
  "reminderMinutes": 15,
  "isAllDay": false,
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  "metadata": {
    "createdBy": "voice",
    "originalVoiceText": "明天下午兩點...",
    "voiceFileUrl": "https://..."
  }
}
```

#### voiceProcessing/{processId}
```json
{
  "userId": "user_id",
  "audioUrl": "https://storage.googleapis.com/...",
  "status": "completed",  // uploading, processing, completed, failed
  "result": { /* 解析結果 */ },
  "transcription": "明天下午兩點在咖啡廳開會",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

#### calendars/{calendarId}
```json
{
  "ownerId": "user_id",
  "name": "工作行事曆",
  "colorValue": 4294198070,  // Color 的整數表示
  "isDefault": false,
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

#### memos/{memoId}
```json
{
  "userId": "user_id",
  "title": "待辦事項標題",
  "content": "詳細內容",
  "isCompleted": false,
  "isPinned": false,
  "priority": 0,  // 0-2: 低、中、高
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

---

## 🔒 安全性設計

### Firestore 安全規則

```javascript
// 用戶只能存取自己的資料
match /events/{eventId} {
  allow read, write: if request.auth.uid == resource.data.userId;
}

// 語音檔案隔離
match /voice_recordings/{userId}/{filename} {
  allow read, write: if request.auth.uid == userId;
  allow read: if request.auth == null;  // Cloud Functions 存取
}
```

### API 安全

- ✅ CORS 限制
- ✅ 請求大小限制（10 MB）
- ✅ 超時保護（60 秒）
- ✅ 錯誤訊息不洩漏敏感資訊

---

## 💰 成本分析

### 月活 1000 用戶估算

| 項目 | 用量 | 單價 | 月成本 |
|------|------|------|-------|
| Firebase (免費方案) | 基礎用量 | - | $0 |
| Whisper API | 5000 次（30 秒/次） | $0.006/分鐘 | ~$15 |
| GPT-4 API | 5000 次解析 | $0.03/1K tokens | ~$25 |
| Zeabur (512MB) | 持續運行 | - | ~$5 |
| **總計** | - | - | **~$45/月** |

### 成本優化建議

- 使用 GPT-3.5-turbo 替代 GPT-4（成本降低 90%）
- 加入結果快取機制
- 限制單用戶每日語音次數
- 使用 faster-whisper 本地部署（降低 API 成本）

---

## 🧪 測試指南

### 單元測試（未來實作）

```bash
# Flutter 測試
cd flutter_app
flutter test

# API 測試
cd zeabur_api
pytest
```

### 手動測試清單

- [ ] 用戶註冊與登入
- [ ] 建立手動行程
- [ ] 編輯行程
- [ ] 刪除行程
- [ ] 語音錄製與上傳
- [ ] AI 語音解析
- [ ] 行程提醒推播
- [ ] 多裝置同步

---

## 🛠️ 開發工具

### 推薦 VS Code 擴充套件

```json
{
  "recommendations": [
    "dart-code.flutter",
    "dart-code.dart-code",
    "ms-python.python",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode"
  ]
}
```

### Firebase Emulators（本地開發）

```bash
# 啟動模擬器
cd firebase
firebase emulators:start

# 模擬器 UI: http://localhost:4000
```

---

## 📈 未來功能規劃

### Phase 2（近期）
- [ ] 行程分享功能
- [ ] 日曆匯入/匯出（iCal）
- [ ] 深色模式
- [ ] 排程未來通知（需整合 Cloud Scheduler）

### Phase 3（中期）
- [ ] 週期性行程（每週、每月）
- [ ] 多人協作行程
- [ ] 語音編輯行程
- [ ] 離線模式與本地快取

### Phase 4（長期）
- [ ] AI 智能排程建議
- [ ] 與 Google Calendar 整合
- [ ] 桌面版應用程式
- [ ] 團隊版功能

### ✅ 已實作功能
- [x] Google / Apple 登入
- [x] 行程分類標籤（12 種預定義標籤）
- [x] 多行事曆管理
- [x] 備忘錄功能

---

## ⚠️ 已知限制

根據目前的實作，以下功能尚未支援或有限制：

1. **排程通知**：需要 Cloud Scheduler 整合（目前僅在行程建立時發送即時通知）
2. **週期性行程**：尚不支援重複行程（每日/每週/每月）
3. **行程分享**：尚無多人協作功能
4. **離線模式**：無本地快取，需要網路連線
5. **行事曆匯入/匯出**：尚不支援 iCal 或 Google Calendar 同步
6. **語音編輯**：無法用語音編輯現有行程（僅能建立新行程）

詳細的限制說明請參閱 [CLAUDE.md](./CLAUDE.md)。

---

## 🎯 多行事曆功能

每位用戶可以建立多個行事曆，方便分類管理不同類型的行程：

- **預設行事曆**：首次使用時自動建立
- **自訂顏色**：每個行事曆可設定專屬顏色
- **獨立管理**：可以隨時切換顯示不同行事曆
- **批次刪除**：刪除行事曆時，其下所有行程都會一併刪除
- **向下相容**：舊版建立的行程（無 `calendarId`）會自動顯示在第一個可用的行事曆

### 行程標籤系統

支援 12 種預定義標籤類型，讓行程分類更清晰：

- 🏢 **工作** (work)
- 👤 **個人** (personal)
- 👥 **會議** (meeting)
- 🎂 **生日** (birthday)
- 📅 **預約** (appointment)
- 📚 **學習** (study)
- 💪 **運動** (exercise)
- ✈️ **旅遊** (travel)
- 🔔 **提醒** (reminder)
- 🎄 **假期** (holiday)
- 👨‍👩‍👧‍👦 **家庭** (family)
- 📝 **其他** (other)

---

## 🤝 貢獻指南

歡迎提交 Issue 和 Pull Request！

### 開發流程

1. Fork 本專案
2. 建立功能分支：`git checkout -b feature/amazing-feature`
3. 提交變更：`git commit -m 'Add amazing feature'`
4. 推送分支：`git push origin feature/amazing-feature`
5. 開啟 Pull Request

---

## 📄 授權

MIT License - 詳見 [LICENSE](LICENSE) 文件

---

## 🙏 致謝

本專案使用了以下開源專案和服務：

- [Flutter](https://flutter.dev/) - Google 的跨平台 UI 框架
- [Firebase](https://firebase.google.com/) - Google 的後端服務平台
- [OpenAI](https://openai.com/) - Whisper 與 GPT API
- [Riverpod](https://riverpod.dev/) - Flutter 狀態管理
- [FastAPI](https://fastapi.tiangolo.com/) - Python Web 框架
- [spaCy](https://spacy.io/) - NLP 工具

---

## 📞 支援與聯繫

- 📧 Email: your-email@example.com
- 🐛 Issue Tracker: [GitHub Issues](https://github.com/your-repo/issues)
- 📖 文件: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)

---

**⭐ 如果這個專案對您有幫助，請給個 Star！**

Made with ❤️ by AI Calendar Team | 2025

