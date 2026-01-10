import 'package:cloud_firestore/cloud_firestore.dart';

/// 用戶設定模型
/// 儲存用戶的個人偏好設定
class UserSettings {
  /// 預設提醒時間（分鐘）
  final int defaultReminderMinutes;
  
  /// 語言設定（例如：'zh-TW', 'en-US'）
  final String language;
  
  /// 是否啟用推播通知
  final bool notificationsEnabled;
  
  /// 通知時間（小時，預設 8:00）
  final int notificationHour;
  
  /// 通知時間（分鐘，預設 0）
  final int notificationMinute;
  
  /// 行事曆週起始日（0=週日, 1=週一, 6=週六）
  final int weekStartDay;
  
  /// 時區設定（例如：'Asia/Taipei', 'America/New_York'）
  /// 使用 IANA 時區標識符
  final String timezone;
  
  /// 是否顯示節日
  final bool showHolidays;
  
  /// 節日地區列表（複選）
  /// 可選值：'taiwan', 'japan', 'usa', 'china' 等
  /// 目前只實作台灣
  final List<String> holidayRegions;

  UserSettings({
    this.defaultReminderMinutes = 15,
    this.language = 'zh-TW',
    this.notificationsEnabled = true,
    this.notificationHour = 8,
    this.notificationMinute = 0,
    this.weekStartDay = 0, // 預設週日開始
    this.timezone = 'Asia/Taipei', // 預設台北時區
    this.showHolidays = true, // 預設顯示節日
    this.holidayRegions = const ['taiwan'], // 預設顯示台灣節日
  });

  /// 從 JSON 建立物件
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    // 處理 holidayRegions 欄位，支援舊資料格式（無此欄位時預設為台灣）
    List<String> regions = const ['taiwan'];
    if (json['holidayRegions'] != null) {
      regions = List<String>.from(json['holidayRegions'] as List);
    }
    
    return UserSettings(
      defaultReminderMinutes: json['defaultReminderMinutes'] as int? ?? 15,
      language: json['language'] as String? ?? 'zh-TW',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      notificationHour: json['notificationHour'] as int? ?? 8,
      notificationMinute: json['notificationMinute'] as int? ?? 0,
      weekStartDay: json['weekStartDay'] as int? ?? 0,
      timezone: json['timezone'] as String? ?? 'Asia/Taipei',
      showHolidays: json['showHolidays'] as bool? ?? true,
      holidayRegions: regions,
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'defaultReminderMinutes': defaultReminderMinutes,
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'notificationHour': notificationHour,
      'notificationMinute': notificationMinute,
      'weekStartDay': weekStartDay,
      'timezone': timezone,
      'showHolidays': showHolidays,
      'holidayRegions': holidayRegions,
    };
  }

  /// 複製物件並允許修改部分欄位
  UserSettings copyWith({
    int? defaultReminderMinutes,
    String? language,
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
    int? weekStartDay,
    String? timezone,
    bool? showHolidays,
    List<String>? holidayRegions,
  }) {
    return UserSettings(
      defaultReminderMinutes: defaultReminderMinutes ?? this.defaultReminderMinutes,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      timezone: timezone ?? this.timezone,
      showHolidays: showHolidays ?? this.showHolidays,
      holidayRegions: holidayRegions ?? this.holidayRegions,
    );
  }
  
  /// 取得格式化的通知時間字串
  String getFormattedNotificationTime() {
    final hour = notificationHour.toString().padLeft(2, '0');
    final minute = notificationMinute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  /// 取得週起始日的名稱
  String getWeekStartDayName() {
    switch (weekStartDay) {
      case 0:
        return '星期日';
      case 1:
        return '星期一';
      case 6:
        return '星期六';
      default:
        return '星期日';
    }
  }
  
  /// 取得時區的顯示名稱（包含 UTC 偏移量）
  String getTimezoneDisplayName() {
    // 常見時區的顯示名稱對照表
    const timezoneDisplayNames = <String, String>{
      'Asia/Taipei': '台北 (GMT+8)',
      'Asia/Tokyo': '東京 (GMT+9)',
      'Asia/Shanghai': '上海 (GMT+8)',
      'Asia/Hong_Kong': '香港 (GMT+8)',
      'Asia/Singapore': '新加坡 (GMT+8)',
      'Asia/Seoul': '首爾 (GMT+9)',
      'America/New_York': '紐約 (GMT-5/-4)',
      'America/Los_Angeles': '洛杉磯 (GMT-8/-7)',
      'America/Chicago': '芝加哥 (GMT-6/-5)',
      'Europe/London': '倫敦 (GMT+0/+1)',
      'Europe/Paris': '巴黎 (GMT+1/+2)',
      'Europe/Berlin': '柏林 (GMT+1/+2)',
      'Australia/Sydney': '雪梨 (GMT+10/+11)',
      'Pacific/Auckland': '奧克蘭 (GMT+12/+13)',
      'UTC': 'UTC (GMT+0)',
    };
    
    return timezoneDisplayNames[timezone] ?? timezone;
  }
}

/// 用戶模型
/// 代表一個完整的用戶資料結構
class UserModel {
  /// 用戶唯一識別碼（Firebase Auth UID）
  final String id;
  
  /// 電子郵件地址
  final String email;
  
  /// 顯示名稱
  final String? displayName;
  
  /// 大頭照 URL
  final String? photoURL;
  
  /// 用戶建立時間
  final DateTime createdAt;
  
  /// 用戶個人設定
  final UserSettings settings;
  
  /// FCM 推播 Token（用於推播通知）
  final String? fcmToken;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    required this.settings,
    this.fcmToken,
  });

  /// 從 Firestore 文檔建立物件
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      email: data['email'] as String,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      settings: UserSettings.fromJson(data['settings'] as Map<String, dynamic>? ?? {}),
      fcmToken: data['fcmToken'] as String?,
    );
  }

  /// 從 JSON 建立物件
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      settings: UserSettings.fromJson(json['settings'] as Map<String, dynamic>? ?? {}),
      fcmToken: json['fcmToken'] as String?,
    );
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'settings': settings.toJson(),
      'fcmToken': fcmToken,
    };
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt.toIso8601String(),
      'settings': settings.toJson(),
      'fcmToken': fcmToken,
    };
  }

  /// 複製物件並允許修改部分欄位
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    UserSettings? settings,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      settings: settings ?? this.settings,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  /// 取得用戶顯示名稱（如果沒有設定則使用 email）
  String getDisplayName() {
    return displayName ?? email.split('@').first;
  }
}

