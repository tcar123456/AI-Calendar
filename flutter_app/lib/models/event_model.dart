import 'package:cloud_firestore/cloud_firestore.dart';

/// 行程元數據
/// 記錄行程的建立方式和相關資訊
class EventMetadata {
  /// 建立方式：'voice' (語音) 或 'manual' (手動)
  final String createdBy;
  
  /// 原始語音轉換的文字內容（僅語音建立時有值）
  final String? originalVoiceText;
  
  /// 語音檔案的 Storage URL（僅語音建立時有值）
  final String? voiceFileUrl;

  EventMetadata({
    required this.createdBy,
    this.originalVoiceText,
    this.voiceFileUrl,
  });

  /// 從 JSON 建立物件
  factory EventMetadata.fromJson(Map<String, dynamic> json) {
    return EventMetadata(
      createdBy: json['createdBy'] as String,
      originalVoiceText: json['originalVoiceText'] as String?,
      voiceFileUrl: json['voiceFileUrl'] as String?,
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'createdBy': createdBy,
      'originalVoiceText': originalVoiceText,
      'voiceFileUrl': voiceFileUrl,
    };
  }

  /// 複製物件並允許修改部分欄位
  EventMetadata copyWith({
    String? createdBy,
    String? originalVoiceText,
    String? voiceFileUrl,
  }) {
    return EventMetadata(
      createdBy: createdBy ?? this.createdBy,
      originalVoiceText: originalVoiceText ?? this.originalVoiceText,
      voiceFileUrl: voiceFileUrl ?? this.voiceFileUrl,
    );
  }
}

/// 行事曆行程模型
/// 代表一個完整的行程資料結構
class CalendarEvent {
  /// 行程唯一識別碼
  final String id;
  
  /// 行程擁有者的用戶 ID
  final String userId;
  
  /// 行程標題（例如：「跟 Amy 開會」）
  final String title;
  
  /// 行程開始時間
  final DateTime startTime;
  
  /// 行程結束時間
  final DateTime endTime;
  
  /// 行程地點（可選）
  final String? location;
  
  /// 行程詳細描述或備註（例如：「記得帶筆電」）
  final String? description;
  
  /// 參與者列表（用戶 ID 或名稱）
  final List<String> participants;
  
  /// 提醒時間（提前多少分鐘提醒，預設 15 分鐘）
  final int reminderMinutes;
  
  /// 是否為全天行程
  final bool isAllDay;
  
  /// 行程建立時間
  final DateTime createdAt;
  
  /// 行程最後更新時間
  final DateTime updatedAt;
  
  /// 行程元數據（建立方式等資訊）
  final EventMetadata metadata;

  CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    this.participants = const [],
    this.reminderMinutes = 15,
    this.isAllDay = false,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  /// 從 Firestore 文檔建立物件
  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CalendarEvent(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      location: data['location'] as String?,
      description: data['description'] as String?,
      participants: List<String>.from(data['participants'] ?? []),
      reminderMinutes: data['reminderMinutes'] as int? ?? 15,
      isAllDay: data['isAllDay'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      metadata: EventMetadata.fromJson(data['metadata'] as Map<String, dynamic>),
    );
  }

  /// 從 JSON 建立物件（用於 API 回傳資料）
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String?,
      description: json['description'] as String?,
      participants: List<String>.from(json['participants'] ?? []),
      reminderMinutes: json['reminderMinutes'] as int? ?? 15,
      isAllDay: json['isAllDay'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: EventMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'description': description,
      'participants': participants,
      'reminderMinutes': reminderMinutes,
      'isAllDay': isAllDay,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata.toJson(),
    };
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'description': description,
      'participants': participants,
      'reminderMinutes': reminderMinutes,
      'isAllDay': isAllDay,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata.toJson(),
    };
  }

  /// 複製物件並允許修改部分欄位
  CalendarEvent copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
    List<String>? participants,
    int? reminderMinutes,
    bool? isAllDay,
    DateTime? createdAt,
    DateTime? updatedAt,
    EventMetadata? metadata,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      description: description ?? this.description,
      participants: participants ?? this.participants,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isAllDay: isAllDay ?? this.isAllDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 檢查行程是否在指定日期
  bool isOnDate(DateTime date) {
    final eventDate = DateTime(startTime.year, startTime.month, startTime.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    return eventDate.isAtSameMomentAs(checkDate);
  }

  /// 取得行程持續時間（分鐘）
  int getDurationInMinutes() {
    return endTime.difference(startTime).inMinutes;
  }

  /// 檢查行程是否已過期
  bool isPast() {
    return endTime.isBefore(DateTime.now());
  }

  /// 檢查行程是否正在進行中
  bool isOngoing() {
    final now = DateTime.now();
    return startTime.isBefore(now) && endTime.isAfter(now);
  }

  /// 檢查行程是否即將開始（15分鐘內）
  bool isUpcoming() {
    final now = DateTime.now();
    final difference = startTime.difference(now).inMinutes;
    return difference > 0 && difference <= 15;
  }
}

