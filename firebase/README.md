# Firebase 設定

這個資料夾包含 Firebase 專案的設定檔案和 Cloud Functions。

## 📁 檔案結構

```
firebase/
├── functions/              # Cloud Functions 程式碼
│   ├── src/
│   │   ├── index.ts       # 主要入口
│   │   ├── voiceHandler.ts # 語音處理函數
│   │   └── notificationHandler.ts # 推播通知函數
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules        # Firestore 安全規則
├── firestore.indexes.json # Firestore 索引設定
├── storage.rules          # Storage 安全規則
└── firebase.json          # Firebase 專案設定
```

## 🚀 部署步驟

### 1. 安裝 Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. 登入 Firebase

```bash
firebase login
```

### 3. 初始化專案（如果尚未初始化）

```bash
firebase init
```

選擇以下服務：
- Firestore
- Functions
- Storage

### 4. 安裝 Functions 依賴

```bash
cd functions
npm install
cd ..
```

### 5. 設定環境變數

設定 Zeabur API URL：

```bash
firebase functions:config:set zeabur.api_url="https://your-zeabur-api.zeabur.app"
```

### 6. 部署 Firestore 規則

```bash
firebase deploy --only firestore:rules
```

### 7. 部署 Storage 規則

```bash
firebase deploy --only storage
```

### 8. 部署 Cloud Functions

```bash
firebase deploy --only functions
```

或一次性部署所有資源：

```bash
firebase deploy
```

## 🧪 本地測試

### 使用 Firebase Emulators

```bash
# 啟動模擬器
firebase emulators:start

# 或僅啟動特定服務
firebase emulators:start --only functions,firestore
```

模擬器 UI 會在 http://localhost:4000 啟動。

### 測試 Functions

```bash
cd functions
npm run serve
```

## 📝 Cloud Functions 說明

### processVoiceInput

**觸發條件**：當 `voiceProcessing` 集合中建立新文檔時

**功能**：
1. 接收語音檔案 URL
2. 呼叫 Zeabur API 進行語音辨識和解析
3. 將解析結果寫入 `events` 集合
4. 更新處理狀態

**必要環境變數**：
- `zeabur.api_url`：Zeabur API 的基礎 URL

### scheduleEventReminders

**觸發條件**：當 `events` 集合中建立新文檔時

**功能**：
1. 取得行程資訊
2. 排程提醒推播（需要整合 Cloud Scheduler）
3. 在提醒時間發送推播給用戶

### sendTestNotification (HTTP)

**端點**：`https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendTestNotification`

**方法**：POST

**請求體**：
```json
{
  "userId": "USER_ID",
  "message": "測試訊息"
}
```

**功能**：發送測試推播通知

## 🔒 安全規則說明

### Firestore Rules

- **users**：用戶只能讀寫自己的資料
- **events**：用戶只能讀寫自己的行程
- **voiceProcessing**：用戶只能建立和讀取自己的處理記錄

### Storage Rules

- **voice_recordings/{userId}**：用戶只能上傳、讀取和刪除自己的語音檔案
- 檔案大小限制：10 MB
- 檔案類型限制：僅允許音訊檔案

## 📊 監控與除錯

### 查看 Functions 日誌

```bash
firebase functions:log
```

### 查看特定 Function 日誌

```bash
firebase functions:log --only processVoiceInput
```

### 即時監控

在 Firebase Console > Functions 中可以查看：
- 執行次數
- 執行時間
- 錯誤率
- 日誌

## ⚠️ 注意事項

1. **成本控制**：Cloud Functions 按執行次數和執行時間計費，請注意用量
2. **超時設定**：預設超時時間為 60 秒，如需調整請在函數設定中修改
3. **並發限制**：免費方案有並發執行限制
4. **環境變數**：部署前請確保所有必要的環境變數都已設定
5. **測試**：建議先在模擬器環境測試再部署到生產環境

