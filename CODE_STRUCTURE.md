# AI 語音行事曆 - 程式碼結構說明

本文件分類整理專案中所有程式碼文件，方便理解專案架構與功能模組。

---

## 📁 專案結構總覽

```
AI calendar/
├── flutter_app/          # Flutter 前端應用程式
├── firebase/             # Firebase 後端服務（Cloud Functions）
└── zeabur_api/           # Zeabur 雲端 API（語音處理服務）
```

---

## 🎯 Flutter 前端應用程式 (`flutter_app/lib/`)

### 1. 應用程式入口

| 文件 | 說明 |
|------|------|
| `main.dart` | 應用程式主入口，負責 Firebase 初始化、主題設定、本地化配置（繁體中文）、認證狀態監聽及路由導向 |
| `firebase_options.dart` | Firebase 專案設定檔，包含各平台（iOS/Android/Web）的 API 金鑰與設定 |

---

### 2. 資料模型 (`models/`)

| 文件 | 說明 |
|------|------|
| `calendar_model.dart` | **行事曆模型** - 定義行事曆結構（ID、擁有者、名稱、顏色、預設標記等），支援多行事曆功能，包含 Firestore 序列化方法 |
| `calendar_member_model.dart` | **行事曆成員模型** - 定義行事曆成員結構，支援共用行事曆功能，包含成員角色（擁有者/編輯者/檢視者）、邀請狀態等 |
| `calendar_settings_model.dart` | **行事曆設定模型** - 定義行事曆相關設定結構 |
| `event_model.dart` | **行程模型** - 定義行程結構（標題、時間、地點、提醒、標籤等），包含 `EventMetadata` 子類別記錄建立方式（語音/手動），提供跨日行程判斷方法 |
| `event_label_model.dart` | **行程標籤模型** - 定義 12 種預設行程標籤（工作、重要、個人、家庭等），每個標籤包含顏色和名稱，支援用戶自訂 |
| `holiday_model.dart` | **節日模型** - 定義節日資料結構，目前實作台灣地區節日（國定假日、傳統節日、紀念日），包含 `TaiwanHolidays` 靜態資料和 `HolidayManager` 管理類別 |
| `memo_model.dart` | **備忘錄模型** - 定義備忘錄結構（標題、內容、完成狀態、釘選、提醒時間、優先級等） |
| `recurrence_rule.dart` | **重複規則模型** - 定義行程重複規則結構，支援每日/每週/每月/每年重複，包含間隔、結束日期等設定 |
| `user_model.dart` | **用戶模型** - 定義用戶資料結構（ID、Email、顯示名稱、大頭照、FCM Token），包含 `UserSettings` 子類別儲存個人偏好（提醒時間、語言、時區、節日顯示、外觀模式等） |
| `voice_processing_model.dart` | **語音處理模型** - 定義語音處理狀態（上傳中、處理中、完成、失敗）和處理記錄結構，包含 `VoiceProcessingResult` 解析結果子類別 |

---

### 3. 狀態管理 (`providers/`) - 使用 Riverpod

| 文件 | 說明 |
|------|------|
| `auth_provider.dart` | **認證狀態管理** - 提供認證相關 Provider（登入狀態、當前用戶 ID、用戶資料），包含 `AuthController` 處理登入/註冊/登出/重設密碼等操作 |
| `calendar_provider.dart` | **行事曆狀態管理** - 提供行事曆列表 Provider，管理當前選擇的行事曆（自動儲存至 SharedPreferences），包含 `CalendarController` 處理 CRUD 操作 |
| `event_provider.dart` | **行程狀態管理** - 提供行程列表 Provider（支援依行事曆過濾），管理選中日期，包含 `EventController` 處理行程的 CRUD 操作 |
| `event_label_provider.dart` | **標籤狀態管理** - 管理行程標籤列表（12 種預設標籤），支援自訂標籤名稱，資料持久化至 SharedPreferences |
| `holiday_provider.dart` | **節日狀態管理** - 提供節日列表 Provider，依據用戶設定的節日地區提供對應節日資料 |
| `memo_provider.dart` | **備忘錄狀態管理** - 提供備忘錄列表 Provider（未完成/已完成分開），包含 `MemoController` 處理 CRUD 及切換完成/釘選狀態 |
| `theme_provider.dart` | **主題狀態管理** - 從用戶設定讀取外觀模式（預設/深色模式），提供對應的 ThemeData，支援即時切換 |
| `voice_provider.dart` | **語音狀態管理** - 管理錄音狀態、處理進度、錄音時長，包含 `VoiceController` 處理開始/停止錄音、上傳處理、從語音結果建立行程等 |

---

### 4. 服務層 (`services/`)

| 文件 | 說明 |
|------|------|
| `firebase_service.dart` | **Firebase 服務** - 統一管理所有 Firebase 操作（單例模式），包含：認證（登入/註冊/登出）、用戶資料 CRUD、行程 CRUD、備忘錄 CRUD、行事曆 CRUD、語音檔案上傳（支援移動平台/Web）、語音處理記錄管理 |
| `holiday_service.dart` | **節日服務** - 處理節日資料，提供依日期查詢節日、依地區篩選節日等功能 |
| `notification_service.dart` | **推播通知服務** - 處理 Firebase Cloud Messaging，包含：請求通知權限、取得/儲存 FCM Token、處理前景/背景/終止狀態訊息、主題訂閱功能 |
| `recurrence_service.dart` | **重複行程服務** - 處理重複行程邏輯，包含：計算下一次重複日期、產生重複行程實例、判斷重複規則是否結束等 |
| `voice_service.dart` | **語音服務** - 處理語音錄製和上傳，包含：麥克風權限檢查/請求、開始/停止/取消錄音（支援移動平台和 Web）、錄音振幅取得（用於波形動畫）、上傳語音至 Firebase Storage 並觸發 AI 處理 |

---

### 5. 畫面 (`screens/`)

#### 5.1 認證畫面 (`auth/`)

| 文件 | 說明 |
|------|------|
| `login_screen.dart` | **登入/註冊畫面** - 提供 Email 登入和註冊功能的 UI 介面 |

#### 5.2 行事曆畫面 (`calendar/`)

| 文件 | 說明 |
|------|------|
| `calendar_screen.dart` | **行事曆主畫面** - 顯示月曆視圖，整合語音輸入按鈕和底部導航 |
| `event_detail_screen.dart` | **行程詳情畫面** - 顯示/編輯行程詳細資訊（標題、時間、地點、提醒、標籤等） |
| `profile_edit_screen.dart` | **個人資料編輯畫面** - 編輯用戶顯示名稱和大頭照 |

##### 行事曆元件 (`calendar/widgets/`)

| 文件 | 說明 |
|------|------|
| `app_bottom_nav.dart` | **底部導航列** - 切換行事曆、備忘錄、通知等主要功能頁面 |
| `calendar_header.dart` | **行事曆標頭** - 顯示當前年月，提供月份切換功能 |
| `calendar_members_sheet.dart` | **行事曆成員底部彈窗** - 管理行事曆成員，支援邀請新成員、變更角色、移除成員等 |
| `calendar_settings_sheet.dart` | **行事曆設定底部彈窗** - 設定週起始日、節日顯示、時區等行事曆偏好 |
| `day_cell.dart` | **日期格子元件** - 顯示單一日期，包含節日標記和行程指示點 |
| `day_events_bottom_sheet.dart` | **當日行程底部彈窗** - 顯示選中日期的所有行程列表，提供新增行程功能 |
| `event_search_sheet.dart` | **行程搜尋底部彈窗** - 搜尋行程功能介面 |
| `label_filter_sheet.dart` | **標籤篩選底部彈窗** - 依標籤篩選行程顯示 |
| `multi_day_event_bar.dart` | **跨日行程橫條** - 顯示橫跨多天的行程條 |
| `repeat_settings_page.dart` | **重複設定頁面** - 設定行程重複規則（每日/每週/每月/每年） |
| `user_menu_sheet.dart` | **用戶選單底部彈窗** - 顯示用戶資訊、設定入口（含外觀切換）、登出等選項 |
| `year_month_picker.dart` | **年月選擇器** - 快速切換年份和月份 |

##### 行事曆工具 (`calendar/utils/`)

| 文件 | 說明 |
|------|------|
| `calendar_utils.dart` | **行事曆工具函數** - 日期計算、格式化等輔助函數 |

#### 5.3 備忘錄畫面 (`memo/`)

| 文件 | 說明 |
|------|------|
| `memo_screen.dart` | **備忘錄畫面** - 顯示和管理備忘錄列表 |

#### 5.4 通知畫面 (`notification/`)

| 文件 | 說明 |
|------|------|
| `notification_screen.dart` | **通知畫面** - 顯示推播通知歷史和設定 |

#### 5.5 語音畫面 (`voice/`)

| 文件 | 說明 |
|------|------|
| `voice_input_screen.dart` | **語音輸入畫面** - 錄音介面，顯示錄音波形和處理進度 |
| `voice_input_sheet.dart` | **語音輸入底部彈窗** - 底部彈窗形式的錄音介面，提供更便捷的語音輸入體驗 |


---

### 6. 主題系統 (`theme/`)

| 文件 | 說明 |
|------|------|
| `app_colors.dart` | **語意化顏色系統** - 使用 ThemeExtension 定義深淺色主題的統一顏色，包含背景、文字、邊框、互動、狀態等分類，提供 `context.colors` 便捷存取方式 |

---

### 7. 工具常數 (`utils/`)

| 文件 | 說明 |
|------|------|
| `constants.dart` | **常數定義** - 定義全域常數，包含：API URL、Firebase Collection 名稱、預設值、UI 顏色值、間距值、動畫時長、錯誤訊息、日期格式、正則表達式等 |

---

## 🔥 Firebase Cloud Functions (`firebase/functions/src/`)

| 文件 | 說明 |
|------|------|
| `index.ts` | **函數入口** - 初始化 Firebase Admin SDK，匯出所有 Cloud Functions |
| `voiceHandler.ts` | **語音處理函數** - 監聽 `voiceProcessing` 文檔建立事件，呼叫 Zeabur API 進行語音辨識和解析，將解析結果寫入 Firestore `events` 集合，更新處理狀態（成功/失敗） |
| `notificationHandler.ts` | **推播通知函數** - 監聽 `events` 文檔建立事件，排程行程提醒推播通知，透過 FCM 發送通知到用戶裝置，包含測試推播 HTTP 函數 |

---

## 🌐 Zeabur 語音處理 API (`zeabur_api/app/`)

### 1. 主應用程式

| 文件 | 說明 |
|------|------|
| `main.py` | **FastAPI 主程式** - 建立 FastAPI 應用程式，設定 CORS、註冊路由、健康檢查端點、啟動/關閉事件處理 |
| `__init__.py` | 模組初始化檔案 |

---

### 2. 資料模型 (`models/`)

| 文件 | 說明 |
|------|------|
| `schemas.py` | **Pydantic Schema** - 定義 API 請求/回應模型：`VoiceParseRequest`（語音解析請求）、`VoiceParseResponse`（解析結果回應）、`EventResult`（行程資料）、`ErrorResponse`（錯誤回應） |
| `__init__.py` | 模組初始化檔案 |

---

### 3. API 路由 (`routes/`)

| 文件 | 說明 |
|------|------|
| `voice.py` | **語音 API 路由** - 提供 `/api/voice/parse` 端點，處理流程：下載音檔 → Whisper 語音辨識 → GPT 語意解析 → NLP 增強 → 返回結構化行程資料 |
| `__init__.py` | 模組初始化檔案 |

---

### 4. 服務層 (`services/`)

| 文件 | 說明 |
|------|------|
| `whisper_service.py` | **Whisper 語音辨識服務** - 使用 OpenAI Whisper API 將語音轉換為文字，支援從 URL 下載音檔進行轉錄，指定中文語言辨識 |
| `gpt_service.py` | **GPT 語意解析服務** - 使用 OpenAI GPT-4 API 將口語化文字解析為結構化行程資料（JSON），包含詳細的 Prompt 定義時間推斷規則（今天/明天/下週X、早上/下午/晚上等） |
| `nlp_service.py` | **NLP 增強服務** - 使用 spaCy 和 dateparser 進行實體抽取和日期解析，增強辨識準確性 |
| `__init__.py` | 模組初始化檔案 |

---

## 📋 設定與配置文件

### Firebase 設定 (`firebase/`)

| 文件 | 說明 |
|------|------|
| `firebase.json` | Firebase 專案設定（Hosting、Functions、Firestore 等） |
| `firestore.rules` | Firestore 安全規則 |
| `firestore.indexes.json` | Firestore 索引設定 |
| `storage.rules` | Firebase Storage 安全規則 |

### Zeabur API 設定 (`zeabur_api/`)

| 文件 | 說明 |
|------|------|
| `Dockerfile` | Docker 容器化設定 |
| `requirements.txt` | Python 依賴套件列表 |

### Flutter 設定 (`flutter_app/`)

| 文件 | 說明 |
|------|------|
| `pubspec.yaml` | Flutter 專案設定及依賴套件 |
| `analysis_options.yaml` | Dart 分析器設定 |

---

## 🔄 資料流程簡述

### 語音建立行程流程

```
1. 用戶錄音 (voice_service.dart)
      ↓
2. 上傳音檔至 Firebase Storage
      ↓
3. 建立 voiceProcessing 文檔
      ↓
4. Cloud Function 監聽觸發 (voiceHandler.ts)
      ↓
5. 呼叫 Zeabur API (voice.py)
      ↓
6. Whisper 語音辨識 → GPT 語意解析 → NLP 增強
      ↓
7. 寫入 events 文檔
      ↓
8. 更新 voiceProcessing 狀態
      ↓
9. Flutter 監聽狀態變化，顯示結果
```

### 推播通知流程

```
1. 新行程建立 (event 文檔)
      ↓
2. Cloud Function 監聽觸發 (notificationHandler.ts)
      ↓
3. 計算提醒時間
      ↓
4. 發送 FCM 推播至用戶裝置
```

---

## 📝 備註

- **狀態管理**：使用 Riverpod 框架
- **後端架構**：Firebase + Zeabur（獨立部署的語音處理 API）
- **語音辨識**：OpenAI Whisper API
- **語意解析**：OpenAI GPT-4 API
- **推播通知**：Firebase Cloud Messaging (FCM)
- **資料庫**：Cloud Firestore
- **檔案儲存**：Firebase Storage

