/// 應用程式常數定義

// ==================== API 相關 ====================

/// Zeabur API 基礎 URL
/// ⚠️ 部署後需要替換為實際的 Zeabur API URL
const String kZeaburApiBaseUrl = 'https://aicalendar-api.zeabur.app';

/// 語音解析 API 端點
const String kVoiceParseEndpoint = '/api/voice/parse';

// ==================== Firebase Collection 名稱 ====================

/// 用戶資料集合
const String kUsersCollection = 'users';

/// 行程資料集合
const String kEventsCollection = 'events';

/// 語音處理記錄集合
const String kVoiceProcessingCollection = 'voiceProcessing';

/// 備忘錄集合
const String kMemosCollection = 'memos';

/// 行事曆集合
const String kCalendarsCollection = 'calendars';

// ==================== Storage 路徑 ====================

/// 語音檔案儲存路徑格式：voice_recordings/{userId}/{timestamp}.m4a
const String kVoiceStoragePath = 'voice_recordings';

// ==================== 預設值 ====================

/// 預設提醒時間（分鐘）
const int kDefaultReminderMinutes = 15;

/// 預設行程持續時間（分鐘）
const int kDefaultEventDuration = 60;

/// 最大錄音時長（秒）
const int kMaxRecordingDuration = 120; // 2 分鐘

/// 語音檔案最大大小（bytes）
const int kMaxVoiceFileSize = 10 * 1024 * 1024; // 10 MB

// ==================== UI 相關 ====================

/// 主題色
const int kPrimaryColorValue = 0xFF6366F1; // Indigo

/// 成功色
const int kSuccessColorValue = 0xFF10B981; // Green

/// 錯誤色
const int kErrorColorValue = 0xFFEF4444; // Red

/// 警告色
const int kWarningColorValue = 0xFFF59E0B; // Amber

/// 圓角大小
const double kBorderRadius = 12.0;

/// 卡片高度
const double kCardElevation = 2.0;

/// 標準間距
const double kPaddingSmall = 8.0;
const double kPaddingMedium = 16.0;
const double kPaddingLarge = 24.0;

// ==================== 動畫時長 ====================

/// 短動畫時長（毫秒）
const int kAnimationDurationShort = 200;

/// 中等動畫時長（毫秒）
const int kAnimationDurationMedium = 300;

/// 長動畫時長（毫秒）
const int kAnimationDurationLong = 500;

// ==================== 錯誤訊息 ====================

/// 網路錯誤訊息
const String kNetworkErrorMessage = '網路連線失敗，請檢查您的網路設定';

/// 權限錯誤訊息
const String kPermissionErrorMessage = '需要麥克風權限才能使用語音功能';

/// 語音處理錯誤訊息
const String kVoiceProcessingErrorMessage = '語音處理失敗，請稍後再試';

/// 登入失敗訊息
const String kLoginErrorMessage = '登入失敗，請重試';

/// 未知錯誤訊息
const String kUnknownErrorMessage = '發生未知錯誤，請稍後再試';

// ==================== 日期格式 ====================

/// 完整日期時間格式（例如：2025年10月1日 14:30）
const String kFullDateTimeFormat = 'yyyy年MM月dd日 HH:mm';

/// 簡短日期格式（例如：10/01）
const String kShortDateFormat = 'MM/dd';

/// 時間格式（例如：14:30）
const String kTimeFormat = 'HH:mm';

/// 星期格式（例如：週一）
const String kWeekdayFormat = 'EEEE';

// ==================== 正則表達式 ====================

/// Email 驗證正則
final RegExp kEmailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

// ==================== 功能開關 ====================

/// 注意：kDebugMode 已由 Flutter 框架提供（flutter/foundation.dart）
/// 如需使用請 import 'package:flutter/foundation.dart';

/// 是否啟用語音檔案快取
const bool kEnableVoiceCache = true;

/// 是否啟用離線模式
const bool kEnableOfflineMode = false;

