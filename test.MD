

測試環境設定

🖥️ Web 測試（Windows）
□ 步驟 1：開啟 CMD
□ 步驟 2：切換到 flutter_app 目錄
   cd "c:\Users\User\Desktop\work\APP\AI calendar\AI calendar\flutter_app"
□ 步驟 3：執行 flutter run -d edge /  flutter run (安卓)
□ 步驟 4：等待 1-3 分鐘編譯完成
□ 步驟 5：看到 "Built build\web" 訊息
□ 步驟 6：Edge 自動開啟（或手動開啟 localhost:XXXXX）
□ 步驟 7：看到登入畫面

📱 Android 測試（Windows）
□ 步驟 1：開啟 Android 模擬器或連接實體手機
□ 步驟 2：切換到 flutter_app 目錄
   cd "c:\Users\User\Desktop\work\APP\AI calendar\AI calendar\flutter_app"
□ 步驟 3：執行 flutter run
□ 步驟 4：等待編譯完成（第一次可能需要 5-10 分鐘）
□ 步驟 5：APP 自動安裝並啟動
□ 步驟 6：看到登入畫面

🍎 iOS 測試（需要 Mac）
□ 步驟 1：確認環境
   ✓ Mac 電腦（macOS 12.0+）
   ✓ Xcode 已安裝（14.0+）
   ✓ iOS 模擬器或實體 iPhone
   ✓ Flutter SDK 已安裝
   
□ 步驟 2：初始化 iOS 專案（首次執行）
   cd "專案路徑/flutter_app"
   flutter create --platforms=ios .
   # 這會生成完整的 iOS/Xcode 專案結構
   
□ 步驟 3：安裝 CocoaPods 依賴
   cd ios
   pod install
   cd ..
   # 這會下載所有 iOS 原生插件依賴
   
□ 步驟 4：確認 GoogleService-Info.plist 已就位
   # 檔案位置：ios/Runner/GoogleService-Info.plist
   # 如果沒有，請從 Firebase Console 下載
   
□ 步驟 5：設定 Xcode 簽章（實體裝置測試必須）
   ⚠️ 開啟 Xcode：open ios/Runner.xcworkspace
   ⚠️ 選擇 Runner > Signing & Capabilities
   ⚠️ 選擇您的 Apple Developer Team
   ⚠️ Bundle Identifier 必須是：com.example.aiCalendarApp
   
□ 步驟 6：啟動 iOS 模擬器
   # 方式一：透過 Xcode 啟動（Xcode > Open Developer Tool > Simulator）
   # 方式二：透過指令啟動
   open -a Simulator
   
□ 步驟 7：查看可用裝置
   flutter devices
   # 應該會看到類似：
   # iPhone 15 (mobile) • xxxxx • ios • com.apple.CoreSimulator.SimRuntime.iOS-17-0
   
□ 步驟 8：執行 Flutter APP
   flutter run -d ios
   # 或指定特定裝置：flutter run -d "iPhone 15"
   
□ 步驟 9：等待編譯與安裝（首次需要 5-10 分鐘）
   # 會看到以下訊息：
   # - Running pod install...
   # - Xcode build done. 
   # - Installing and launching...
   
□ 步驟 10：APP 啟動，看到登入畫面



測試內容
□ 應用程式成功啟動（http://localhost:8080）
□ 看到登入畫面
□ 成功註冊新帳號
□ Firebase Authentication 有用戶記錄
□ 成功登入
□ 看到行事曆主畫面
□ 行事曆正常顯示（中文日期）
□ 可以選擇不同日期
□ 可以建立新行程
□ 行程出現在行事曆上
□ 可以查看行程詳情
□ 可以編輯行程
□ 修改後的資訊正確顯示
□ 可以刪除行程
□ 刪除後行程消失
□ Firestore 有行程資料
□ 可以成功登出
□ 可以重新登入
□ 響應式設計正常（手機/平板/桌面）
□ 沒有紅色錯誤訊息

🎤 Web 錄音功能測試（新增）
□ 進入語音輸入畫面
□ 點擊錄音按鈕
□ 瀏覽器顯示麥克風權限請求
□ 允許麥克風權限
□ 開始錄音（沒有 MissingPluginException 錯誤）
□ 看到錄音中的動畫/計時器
□ 說話測試（例如：「明天下午三點開會」）
□ 停止錄音
□ 錄音數據成功上傳到 Firebase Storage
□ 語音處理記錄建立成功
□ 等待 AI 處理結果（需要先部署 Cloud Functions）

🍎 iOS 專屬測試項目
□ 應用程式權限測試
  □ 首次啟動顯示麥克風權限請求
  □ 允許麥克風權限後能正常錄音
  □ 到「設定」>「隱私權」>「麥克風」確認權限已授予
  □ 推播通知權限請求正常顯示
  □ 允許推播通知

□ iOS 語音錄製測試
  □ 點擊語音輸入按鈕
  □ 麥克風圖示正常顯示
  □ 開始錄音時有視覺回饋（動畫/波形）
  □ 說話時音訊正常捕捉
  □ 停止錄音後檔案正常保存
  □ 錄音檔案上傳到 Firebase Storage
  □ 沒有 iOS 特定的錄音錯誤

□ iOS UI/UX 測試
  □ 狀態列樣式正確（深色/淺色）
  □ 安全區域（notch/dynamic island）正常處理
  □ 鍵盤彈出時畫面自動調整
  □ 返回手勢（左邊緣滑動）正常運作
  □ 旋轉螢幕時佈局正確（如果支援）
  □ iOS 字體大小調整正常適應
  □ 深色模式/淺色模式切換正常

□ iOS 推播通知測試
  □ 接收遠端推播通知
  □ 通知內容正確顯示
  □ 點擊通知能開啟對應行程
  □ 應用程式在背景時通知正常
  □ 應用程式關閉時通知正常
  
□ iOS 效能測試
  □ APP 啟動時間 < 3 秒
  □ 頁面切換流暢（60fps）
  □ 記憶體使用合理（< 150MB）
  □ 錄音時不影響其他功能
  □ 長時間使用無明顯卡頓

□ iOS 特殊場景測試
  □ 接聽電話時錄音正常暫停
  □ 其他 APP 播放音樂時錄音正常
  □ 螢幕鎖定時推播正常接收
  □ APP 切換到背景再回來狀態正確
  □ 網路斷線時有適當提示
  □ 網路恢復後自動重試上傳

□ iOS 實體裝置額外測試（如果有）
  □ Face ID / Touch ID 登入（如果已實作）
  □ 震動回饋正常運作
  □ 相機/相簿存取正常（如果有功能）
  □ GPS 定位正常（如果有功能）



📊 目前部署進度
階段	項目	狀態
第一階段	Flutter 環境設定	✅ 完成
Firebase 專案設定	✅ 完成
Flutter App 設定	✅ 完成
Web 應用程式啟動	✅ 完成
第二階段	Firestore 索引	✅ 完成
Firestore 安全規則	✅ 完成
Storage 安全規則	✅ 完成
基本功能測試	✅ 完成
第三階段	Cloud Functions 部署	✅ 完成
Zeabur API 部署	✅ 完成
語音功能測試	✅ 完成



步驟 2：部署 Firebase Cloud Functions
# 在 firebase/functions 目錄cd functions# 安裝依賴npm install# 設定 Zeabur API URL（暫時使用預設值）firebase functions:config:set zeabur.api_url="https://temp-url.com"# 部署 Functionscd ..firebase deploy --only functions
用途：
🎤 處理語音辨識請求
📝 將語音轉換為行程資料
🔔 發送推播通知
步驟 3：部署 Zeabur API（語音服務）
這是 AI 語音辨識的核心服務，需要：
準備 OpenAI API Key
前往 https://platform.openai.com/api-keys
建立新的 API Key
部署到 Zeabur
前往 https://zeabur.com/
連接 GitHub 儲存庫
選擇 zeabur_api 目錄
設定環境變數：OPENAI_API_KEY
更新 Zeabur URL
部署完成後取得 URL
更新 flutter_app/lib/utils/constants.dart
更新 Firebase Functions 設定



═══════════════════════════════════════════════
📱 iOS 測試完整指南與疑難排解
═══════════════════════════════════════════════

🔧 前置要求

1. 硬體需求
   ✓ Mac 電腦（不能在 Windows 上開發 iOS）
   ✓ macOS 12.0 (Monterey) 或更新版本
   ✓ 至少 8GB RAM（建議 16GB）
   ✓ 至少 50GB 可用儲存空間

2. 軟體安裝
   ✓ Xcode 14.0+ （從 Mac App Store 安裝）
   ✓ Xcode Command Line Tools
   ✓ CocoaPods （iOS 套件管理工具）
   ✓ Flutter SDK
   ✓ 終端機（Terminal）

3. 帳號需求
   ✓ Apple ID（免費，用於模擬器測試）
   ✓ Apple Developer Account（$99/年，僅實體裝置測試必須）



📝 詳細安裝步驟

步驟 1：安裝 Xcode
--------------------------------------------------
1. 開啟 Mac App Store
2. 搜尋「Xcode」
3. 點擊「取得」或「下載」（檔案大小約 12GB，需要等待）
4. 安裝完成後首次開啟 Xcode
5. 同意授權條款
6. 等待額外元件安裝完成

# 或使用終端機檢查是否已安裝
xcode-select -p
# 如果顯示路徑（例如 /Applications/Xcode.app/Contents/Developer）代表已安裝


步驟 2：安裝 Xcode Command Line Tools
--------------------------------------------------
# 在終端機執行
xcode-select --install

# 點擊彈出視窗的「安裝」按鈕
# 等待安裝完成（約 5-10 分鐘）


步驟 3：安裝 CocoaPods
--------------------------------------------------
# 檢查是否已安裝
pod --version

# 如果沒有安裝，執行以下指令
sudo gem install cocoapods

# 等待安裝完成後驗證
pod --version
# 應該顯示類似：1.15.0


步驟 4：安裝 Flutter SDK（如果尚未安裝）
--------------------------------------------------
# 方式一：使用官方安裝包
1. 前往 https://docs.flutter.dev/get-started/install/macos
2. 下載 Flutter SDK
3. 解壓縮到指定位置（例如：~/development/flutter）
4. 設定環境變數

# 編輯 ~/.zshrc 或 ~/.bash_profile
export PATH="$PATH:$HOME/development/flutter/bin"

# 重新載入配置
source ~/.zshrc

# 驗證安裝
flutter doctor

# 方式二：使用 Homebrew（推薦）
brew install flutter

# 驗證安裝
flutter doctor -v



🚀 初始化 iOS 專案

步驟 1：在 Mac 上複製專案
--------------------------------------------------
# 使用 Git 複製專案（推薦）
git clone <你的儲存庫 URL>
cd "AI calendar/flutter_app"

# 或從 Windows 電腦傳輸專案檔案到 Mac
# 可使用 OneDrive、Google Drive、或 AirDrop


步驟 2：產生 iOS 專案檔案
--------------------------------------------------
# 確認目前在 flutter_app 目錄
pwd
# 應該顯示：/Users/你的用戶名/.../AI calendar/flutter_app

# 產生 iOS 專案結構（如果專案中沒有完整的 ios 目錄）
flutter create --platforms=ios .

# 這會建立：
# - ios/Runner.xcodeproj
# - ios/Runner.xcworkspace
# - ios/Podfile
# - 其他必要的 iOS 檔案


步驟 3：安裝 Flutter 依賴
--------------------------------------------------
flutter pub get

# 應該看到類似訊息：
# Running "flutter pub get" in flutter_app...
# Got dependencies!


步驟 4：安裝 iOS 原生依賴（CocoaPods）
--------------------------------------------------
# 切換到 ios 目錄
cd ios

# 清理快取（首次安裝建議執行）
pod repo update
pod cache clean --all

# 安裝依賴（會下載 Firebase、語音相關的原生套件）
pod install

# ⚠️ 這步驟可能需要 10-30 分鐘，取決於網路速度
# 應該看到類似訊息：
# Analyzing dependencies
# Downloading dependencies
# Installing Firebase... (X.X.X)
# Installing speech_to_text... (X.X.X)
# Generating Pods project
# Pod installation complete! XX pods installed.

# 返回專案根目錄
cd ..


步驟 5：確認 Firebase 設定檔
--------------------------------------------------
# 檢查檔案是否存在
ls -la ios/Runner/GoogleService-Info.plist

# 如果檔案不存在，請執行以下步驟：
1. 前往 Firebase Console (https://console.firebase.google.com/)
2. 選擇你的專案：ai-calendar-app-3b976
3. 進入「專案設定」
4. 滾動到「您的應用程式」區塊
5. 找到 iOS 應用程式（Bundle ID: com.example.aiCalendarApp）
6. 如果沒有 iOS 應用程式，點擊「新增應用程式」> iOS
7. 下載 GoogleService-Info.plist
8. 將檔案放到 ios/Runner/ 目錄

# ⚠️ 重要：如果是透過 Xcode 添加檔案，必須勾選「Copy items if needed」



🏃‍♂️ 執行 iOS APP

方式一：使用 Flutter 命令（推薦初學者）
--------------------------------------------------
# 1. 啟動 iOS 模擬器（會自動開啟 iPhone 模擬器）
flutter emulators --launch apple_ios_simulator

# 或手動開啟模擬器
open -a Simulator

# 2. 等待模擬器完全啟動（約 30-60 秒）

# 3. 確認裝置已連接
flutter devices

# 應該看到類似：
# iPhone 15 (mobile) • XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX • ios • 
# com.apple.CoreSimulator.SimRuntime.iOS-17-0 (simulator)

# 4. 執行 APP
flutter run

# 或指定裝置 ID
flutter run -d XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX

# 5. 首次編譯需要 5-10 分鐘，會看到以下訊息：
# Launching lib/main.dart on iPhone 15 in debug mode...
# Running pod install...                                             XX.Xs
# Running Xcode build...                                             
#  └─Compiling, linking and signing...                           XXX.Xs
# Xcode build done.                                              XXX.Xs
# Installing and launching...                                     X.Xs
# Syncing files to device iPhone 15...                           XXXms
# 
# Flutter run key commands.
# r Hot reload.
# R Hot restart.
# ...


方式二：使用 Xcode（進階用戶）
--------------------------------------------------
# 1. 開啟 Xcode workspace（不是 .xcodeproj！）
open ios/Runner.xcworkspace

# 2. 在 Xcode 中：
#    - 左上角選擇目標裝置（例如：iPhone 15）
#    - 點擊播放按鈕（▶️）或按 Cmd+R
#    - 等待編譯與安裝

# 3. 優點：
#    - 可以看到更詳細的編譯錯誤
#    - 可以使用 Xcode 的除錯工具
#    - 可以檢查 iOS 特定的設定



🔧 iOS 常見問題與解決方案

問題 1：CocoaPods 安裝失敗
--------------------------------------------------
錯誤訊息：
ERROR:  While executing gem ... (Gem::FilePermissionError)
You don't have write permissions for the /Library/Ruby/Gems/2.6.0 directory.

解決方法：
# 使用 Homebrew 安裝 Ruby（避免系統 Ruby 權限問題）
brew install ruby

# 將 Homebrew Ruby 加入 PATH（編輯 ~/.zshrc）
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# 重新載入配置
source ~/.zshrc

# 重新安裝 CocoaPods
gem install cocoapods


問題 2：pod install 失敗
--------------------------------------------------
錯誤訊息：
[!] Unable to find a specification for `Firebase/CoreOnly`

解決方法：
# 清理 CocoaPods 快取
cd ios
pod deintegrate
pod cache clean --all
rm -rf Pods
rm Podfile.lock

# 更新 CocoaPods 儲存庫
pod repo update

# 重新安裝
pod install


問題 3：Xcode 簽章錯誤
--------------------------------------------------
錯誤訊息：
Signing for "Runner" requires a development team. Select a development team in 
the Signing & Capabilities editor.

解決方法：
1. 開啟 ios/Runner.xcworkspace（在 Xcode）
2. 選擇左側 Runner 專案
3. 選擇 TARGETS > Runner
4. 點擊「Signing & Capabilities」標籤
5. 在「Team」下拉選單：
   - 選擇你的 Apple ID（免費，用於模擬器）
   - 或選擇付費 Apple Developer 帳號（實體裝置必須）
6. 確認「Bundle Identifier」正確：com.example.aiCalendarApp


問題 4：GoogleService-Info.plist 找不到
--------------------------------------------------
錯誤訊息：
FirebaseCore could not locate configuration file: 'GoogleService-Info.plist'

解決方法：
# 方式一：透過 Xcode 添加（推薦）
1. 開啟 ios/Runner.xcworkspace
2. 右鍵點擊 Runner 資料夾
3. 選擇「Add Files to "Runner"...」
4. 選擇 GoogleService-Info.plist
5. ⚠️ 確保勾選「Copy items if needed」
6. ⚠️ 確保勾選「Runner」target
7. 點擊「Add」

# 方式二：手動複製（需要確認檔案位置）
cp ~/Downloads/GoogleService-Info.plist ios/Runner/

# 驗證檔案已正確放置
ls -la ios/Runner/GoogleService-Info.plist


問題 5：iOS 模擬器啟動失敗
--------------------------------------------------
錯誤訊息：
Unable to boot device in current state: Booted

解決方法：
# 關閉所有模擬器
killall Simulator

# 重置模擬器（會清除所有資料）
xcrun simctl erase all

# 重新啟動
open -a Simulator


問題 6：編譯錯誤：Module 'xxx' not found
--------------------------------------------------
錯誤訊息：
Module 'firebase_core' not found
Module 'speech_to_text' not found

解決方法：
# 清理並重新建置
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
flutter run


問題 7：麥克風權限無法請求
--------------------------------------------------
問題：APP 無法請求麥克風權限

解決方法：
# 確認 Info.plist 包含權限描述
1. 開啟 ios/Runner/Info.plist（使用文字編輯器或 Xcode）
2. 檢查是否有以下內容：

<key>NSMicrophoneUsageDescription</key>
<string>需要使用麥克風來錄製語音建立行程</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>需要使用語音辨識來建立行程</string>

# 如果沒有，手動添加這些行
# 然後重新編譯 APP


問題 8：實體裝置無法安裝
--------------------------------------------------
錯誤訊息：
Could not launch "Runner" - The application could not be installed on the device.

解決方法：
1. 確認裝置已用 USB 連接到 Mac
2. 在 iPhone 上信任這台電腦（會彈出提示）
3. 在 iPhone 的「設定」>「一般」>「VPN 與裝置管理」
4. 信任開發者憑證
5. 重新執行 flutter run


問題 9：編譯速度太慢
--------------------------------------------------
優化方法：
# 方式一：使用 Debug 模式（開發時預設）
flutter run --debug

# 方式二：使用 Profile 模式（測試效能）
flutter run --profile

# 方式三：只重新編譯變更的檔案（熱重載）
# 在 APP 執行時按 'r' 鍵

# 方式四：增加 Xcode 編譯執行緒
# 在 Xcode > Preferences > Locations > Derived Data > Advanced
# 選擇「Custom」> 設定為「Relative to Workspace」



📱 在實體 iPhone 上測試

步驟 1：準備實體裝置
--------------------------------------------------
1. 使用原廠 Lightning/USB-C 線連接 iPhone 到 Mac
2. 在 iPhone 上解鎖螢幕
3. 點擊「信任」（首次連接會提示）
4. 輸入 iPhone 密碼確認


步驟 2：在 Xcode 設定簽章
--------------------------------------------------
1. 開啟 ios/Runner.xcworkspace
2. 選擇 Runner > Signing & Capabilities
3. Team 選擇你的 Apple ID
4. 確認「Automatically manage signing」已勾選
5. Bundle Identifier 保持：com.example.aiCalendarApp

⚠️ 免費 Apple ID 限制：
- 每個 Bundle ID 只能在 3 台裝置上使用
- 每 7 天需要重新簽章一次
- 不能發佈到 App Store


步驟 3：執行到實體裝置
--------------------------------------------------
# 查看連接的裝置
flutter devices

# 應該會看到你的 iPhone
# 例如：iPhone 14 Pro (mobile) • 00008xxx-xxxxxx • ios • iOS 17.0

# 執行到指定裝置
flutter run -d 00008xxx-xxxxxx

# 首次安裝需要在 iPhone 上信任開發者
# 「設定」>「一般」>「VPN 與裝置管理」> 信任你的開發者憑證


步驟 4：測試實體裝置特有功能
--------------------------------------------------
□ Face ID / Touch ID（如果 APP 有整合）
□ 真實的 GPS 定位
□ 實際的麥克風錄音品質
□ 真實的網路環境（4G/5G/WiFi）
□ 推播通知在真實環境
□ 震動回饋
□ 相機/相簿存取（如果有功能）



🎯 iOS 效能測試工具

使用 Xcode Instruments
--------------------------------------------------
1. 開啟 Xcode
2. 選擇 Product > Profile（或按 Cmd+I）
3. 選擇測試範本：
   - Time Profiler（CPU 使用率）
   - Allocations（記憶體使用）
   - Leaks（記憶體洩漏）
   - Energy Log（電池消耗）
4. 點擊紅色錄製按鈕開始測試
5. 操作 APP 進行各項功能測試
6. 停止錄製，分析結果

使用 Flutter DevTools
--------------------------------------------------
# 在 APP 執行時開啟 DevTools
flutter pub global activate devtools
flutter pub global run devtools

# 在瀏覽器開啟顯示的 URL
# 可以查看：
# - Widget 樹狀圖
# - 效能時間軸
# - 記憶體使用
# - 網路請求
# - Logging



✅ iOS 測試檢查清單（完整版）

基礎功能
□ APP 成功安裝到模擬器
□ APP 成功安裝到實體裝置
□ 啟動時間 < 3 秒
□ 無崩潰錯誤

登入功能
□ 註冊新帳號
□ Email 登入
□ Google 登入（如果已實作）
□ Apple 登入（iOS 必須，如果已實作）
□ 登出功能

行事曆功能
□ 顯示當月行事曆
□ 選擇不同日期
□ 建立新行程
□ 編輯行程
□ 刪除行程
□ 行程資料與 Firestore 同步

語音功能
□ 麥克風權限請求正常
□ 允許權限後能開始錄音
□ 錄音時有視覺回饋
□ 錄音檔案正常上傳
□ AI 處理結果正確
□ 自動建立行程

推播通知
□ 推播權限請求正常
□ 接收測試推播
□ 點擊推播開啟對應行程
□ 背景/前景都能接收

UI/UX
□ 深色模式正常
□ 淺色模式正常
□ 安全區域（notch）正常處理
□ 鍵盤彈出時畫面調整正確
□ 左邊緣滑動返回手勢正常
□ 字體大小調整適應正常

效能
□ 頁面切換流暢（60fps）
□ 無明顯記憶體洩漏
□ 電池消耗合理
□ 網路請求正常
□ 離線處理適當

特殊場景
□ 接聽電話時錄音暫停
□ APP 切換到背景再回來正常
□ 網路斷線有適當提示
□ 網路恢復自動重試



📚 參考資源

官方文件
--------------------------------------------------
- Flutter iOS 部署：https://docs.flutter.dev/deployment/ios
- Firebase iOS 設定：https://firebase.google.com/docs/ios/setup
- Xcode 下載：https://developer.apple.com/xcode/
- Apple Developer：https://developer.apple.com/

社群資源
--------------------------------------------------
- Flutter 中文社群：https://flutter.cn/
- Stack Overflow Flutter 標籤：https://stackoverflow.com/questions/tagged/flutter
- Flutter Discord：https://discord.gg/N7Yshp4



🆘 還是遇到問題？

Debug 檢查清單
--------------------------------------------------
1. ✓ 確認 Xcode 版本 >= 14.0
2. ✓ 確認 Flutter doctor 沒有錯誤
3. ✓ 確認 CocoaPods 已正確安裝
4. ✓ 確認 GoogleService-Info.plist 存在且正確
5. ✓ 確認 Bundle Identifier 一致
6. ✓ 確認已執行 pod install
7. ✓ 確認使用 .xcworkspace 而非 .xcodeproj
8. ✓ 確認 Info.plist 包含所需權限描述

查看詳細錯誤日誌
--------------------------------------------------
# Flutter 日誌
flutter run -v

# iOS 系統日誌（在 Mac 終端機）
log stream --predicate 'processImagePath contains "Runner"' --level debug

# Xcode 日誌
# 在 Xcode 中：View > Debug Area > Show Debug Area (Cmd+Shift+Y)

獲取幫助
--------------------------------------------------
1. 查看 Flutter 官方文件
2. 搜尋 Stack Overflow
3. 查看專案的 GitHub Issues
4. 詢問 Flutter 社群（Discord/Reddit）


列出模擬器（看id） flutter emulators
列出已連線實機     flutter devices

指定裝置 flutter run -d <DEVICE_ID>


flutter emulators --launch Pixel_6 (ID)
flutter run