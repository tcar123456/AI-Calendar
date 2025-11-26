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
  
  /// 行事曆週起始日（0=週日, 1=週一）
  final int weekStartDay;

  UserSettings({
    this.defaultReminderMinutes = 15,
    this.language = 'zh-TW',
    this.notificationsEnabled = true,
    this.weekStartDay = 1, // 預設週一開始
  });

  /// 從 JSON 建立物件
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      defaultReminderMinutes: json['defaultReminderMinutes'] as int? ?? 15,
      language: json['language'] as String? ?? 'zh-TW',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      weekStartDay: json['weekStartDay'] as int? ?? 1,
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'defaultReminderMinutes': defaultReminderMinutes,
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'weekStartDay': weekStartDay,
    };
  }

  /// 複製物件並允許修改部分欄位
  UserSettings copyWith({
    int? defaultReminderMinutes,
    String? language,
    bool? notificationsEnabled,
    int? weekStartDay,
  }) {
    return UserSettings(
      defaultReminderMinutes: defaultReminderMinutes ?? this.defaultReminderMinutes,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      weekStartDay: weekStartDay ?? this.weekStartDay,
    );
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

