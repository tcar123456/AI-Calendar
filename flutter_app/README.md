# AI Calendar App - Flutter 前端

## 📱 專案說明

這是 AI 語音行事曆的 Flutter 前端應用程式。

## 🛠️ 開發環境設定

### 1. 安裝依賴套件

```bash
flutter pub get
```

### 2. Firebase 設定

您需要提供以下 Firebase 設定檔：

#### Android
- `android/app/google-services.json`

#### iOS  
- `ios/Runner/GoogleService-Info.plist`

#### Web
- 在 `lib/firebase_options.dart` 中設定 Firebase Web 配置

### 3. 執行應用程式

```bash
# Android
flutter run

# iOS (需要 Mac)
flutter run -d ios

# Web
flutter run -d chrome
```

## 📁 專案結構

```
lib/
├── main.dart                 # 應用程式入口
├── models/                   # 資料模型
│   ├── event_model.dart      # 行程模型
│   └── user_model.dart       # 用戶模型
├── providers/                # Riverpod 狀態管理
│   ├── auth_provider.dart
│   ├── event_provider.dart
│   └── voice_provider.dart
├── services/                 # 服務層
│   ├── firebase_service.dart
│   ├── voice_service.dart
│   └── notification_service.dart
├── screens/                  # 頁面
│   ├── auth/
│   │   └── login_screen.dart
│   ├── calendar/
│   │   └── calendar_screen.dart
│   └── voice/
│       └── voice_input_screen.dart
├── widgets/                  # 共用元件
│   ├── calendar_widget.dart
│   └── event_card.dart
└── utils/                    # 工具函數
    └── constants.dart
```

## 🔑 需要的 API Keys

請在專案中設定以下環境變數或配置：

1. **Firebase 專案設定** (google-services.json / GoogleService-Info.plist)
2. **Zeabur API URL** (語音處理服務)

## 📝 開發注意事項

- 所有程式碼都包含詳細的中文註解
- 使用 Riverpod 進行狀態管理
- 遵循 Material Design 3 設計規範

