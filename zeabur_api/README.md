# AI Calendar - Zeabur API

AI 語音處理服務，負責將語音轉換為結構化的行程資料。

## 🎯 功能

- **語音辨識**：使用 OpenAI Whisper API 將語音轉文字
- **語意解析**：使用 GPT-4 將口語化描述轉換為結構化資料
- **NLP 增強**：使用 spaCy 和 dateparser 提升辨識準確度

## 🏗️ 技術架構

- **框架**：FastAPI
- **語音辨識**：OpenAI Whisper API
- **語意理解**：OpenAI GPT-4
- **NLP 工具**：spaCy (中文模型)、dateparser
- **部署平台**：Zeabur (Docker)

## 📁 專案結構

```
zeabur_api/
├── app/
│   ├── __init__.py
│   ├── main.py                    # FastAPI 應用程式入口
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py             # Pydantic 資料模型
│   ├── routes/
│   │   ├── __init__.py
│   │   └── voice.py               # 語音處理路由
│   └── services/
│       ├── __init__.py
│       ├── whisper_service.py     # Whisper 語音辨識
│       ├── gpt_service.py         # GPT 語意解析
│       └── nlp_service.py         # NLP 增強處理
├── requirements.txt               # Python 依賴
├── Dockerfile                     # Docker 映像設定
├── .env.example                   # 環境變數範例
└── README.md
```

## 🚀 快速開始

### 1. 安裝依賴

```bash
pip install -r requirements.txt
```

### 2. 下載 spaCy 中文模型

```bash
python -m spacy download zh_core_web_sm
```

### 3. 設定環境變數

複製 `.env.example` 為 `.env`：

```bash
cp .env.example .env
```

編輯 `.env` 檔案，設定您的 OpenAI API 金鑰：

```env
OPENAI_API_KEY=sk-your-openai-api-key-here
ENVIRONMENT=development
LOG_LEVEL=INFO
CORS_ORIGINS=*
```

### 4. 啟動服務

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

服務會在 http://localhost:8000 啟動。

### 5. 查看 API 文檔

開啟瀏覽器訪問：

- **Swagger UI**：http://localhost:8000/docs
- **ReDoc**：http://localhost:8000/redoc

## 📡 API 端點

### POST /api/voice/parse

解析語音檔案並回傳結構化行程資料。

**請求體**：

```json
{
  "audioUrl": "https://storage.googleapis.com/your-bucket/audio.m4a",
  "userId": "user123"
}
```

**回應**：

```json
{
  "transcription": "明天下午兩點在公司會議室開會，記得帶筆電",
  "title": "公司會議",
  "startTime": "2025-10-02T14:00:00",
  "endTime": "2025-10-02T15:00:00",
  "location": "公司會議室",
  "description": "記得帶筆電",
  "isAllDay": false,
  "participants": []
}
```

### GET /api/voice/test

測試 API 是否正常運作。

**回應**：

```json
{
  "status": "ok",
  "message": "Voice API is running",
  "services": {
    "whisper": "OpenAI Whisper API",
    "gpt": "OpenAI GPT-4",
    "nlp": "spaCy + dateparser"
  }
}
```

## 🐳 Docker 部署

### 建立映像

```bash
docker build -t ai-calendar-voice-api .
```

### 執行容器

```bash
docker run -d \
  -p 8000:8000 \
  -e OPENAI_API_KEY=your_api_key_here \
  --name voice-api \
  ai-calendar-voice-api
```

## ☁️ Zeabur 部署

### 1. 安裝 Zeabur CLI（選用）

```bash
npm install -g zeabur
```

### 2. 登入 Zeabur

```bash
zeabur login
```

### 3. 部署專案

在 Zeabur Dashboard 中：

1. 建立新專案
2. 連接 GitHub 儲存庫
3. 選擇 `zeabur_api` 資料夾
4. 設定環境變數（OPENAI_API_KEY）
5. 部署

Zeabur 會自動偵測 Dockerfile 並建立映像。

### 4. 設定環境變數

在 Zeabur 專案設定中新增：

```
OPENAI_API_KEY=your_openai_api_key
ENVIRONMENT=production
LOG_LEVEL=INFO
```

### 5. 取得 API URL

部署完成後，Zeabur 會提供一個 URL，例如：

```
https://your-project.zeabur.app
```

## 🧪 測試

### 使用 curl 測試

```bash
curl -X POST "http://localhost:8000/api/voice/parse" \
  -H "Content-Type: application/json" \
  -d '{
    "audioUrl": "https://your-audio-url.com/audio.m4a",
    "userId": "test-user"
  }'
```

### 使用 Python 測試

```python
import requests

url = "http://localhost:8000/api/voice/parse"
data = {
    "audioUrl": "https://your-audio-url.com/audio.m4a",
    "userId": "test-user"
}

response = requests.post(url, json=data)
print(response.json())
```

## 📊 處理流程

```
1. 接收請求
   ↓
2. 下載語音檔案（從 Firebase Storage）
   ↓
3. Whisper API 語音轉文字
   ↓
4. GPT-4 語意解析
   - 提取標題
   - 解析時間
   - 識別地點
   - 整理備註
   ↓
5. NLP 增強
   - dateparser 處理相對時間
   - spaCy 提取地點實體
   ↓
6. 回傳結構化資料
```

## 💡 語意解析範例

### 輸入範例

| 語音內容 | 解析結果 |
|---------|---------|
| "明天下午兩點跟 Amy 在咖啡廳開會" | 標題：跟 Amy 開會<br>時間：明天 14:00-15:00<br>地點：咖啡廳 |
| "下週一早上九點半公司會議，記得帶筆電" | 標題：公司會議<br>時間：下週一 09:30-10:30<br>備註：記得帶筆電 |
| "後天全天休假" | 標題：休假<br>全天：是 |

## ⚠️ 注意事項

1. **API 金鑰安全**：
   - 不要將 API 金鑰提交到 Git
   - 使用環境變數管理敏感資訊
   
2. **成本控制**：
   - Whisper API：$0.006/分鐘
   - GPT-4 API：$0.03/1K tokens
   - 建議設定每月使用上限

3. **錯誤處理**：
   - 語音檔案過大（>10MB）會失敗
   - 網路超時設定為 60 秒
   - 建議加入重試機制

4. **效能優化**：
   - 考慮加入快取機制
   - 使用 GPT-3.5-turbo 降低成本
   - 批次處理請求

## 🔧 疑難排解

### spaCy 模型載入失敗

```bash
python -m spacy download zh_core_web_sm
```

### OpenAI API 錯誤

檢查：
- API 金鑰是否正確
- 是否有足夠的配額
- 網路連線是否正常

### Docker 建立失敗

確保：
- Dockerfile 路徑正確
- requirements.txt 包含所有依賴
- spaCy 模型在建立時下載

## 📝 授權

MIT License

