import 'package:cloud_firestore/cloud_firestore.dart';
import 'recurrence_rule.dart';

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
  
  /// 所屬行事曆 ID（用於多行事曆功能）
  final String? calendarId;
  
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
  
  /// 行程標籤 ID（用於區分不同類型的行程，對應顏色）
  final String? labelId;
  
  /// 行程建立時間
  final DateTime createdAt;
  
  /// 行程最後更新時間
  final DateTime updatedAt;
  
  /// 行程元數據（建立方式等資訊）
  final EventMetadata metadata;

  // ==================== 重複行程相關欄位 ====================

  /// 是否為主行程（包含重複規則的原始行程）
  final bool isMasterEvent;

  /// 重複規則（僅主行程有值）
  final RecurrenceRule? recurrenceRule;

  /// 所屬主行程的 ID（實例行程才有值）
  final String? masterEventId;

  /// 原始預定日期（實例行程用於識別是哪一天的實例）
  final DateTime? originalDate;

  /// 是否為例外實例（被單獨修改過的實例）
  final bool isException;

  CalendarEvent({
    required this.id,
    required this.userId,
    this.calendarId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    this.participants = const [],
    this.reminderMinutes = 15,
    this.isAllDay = false,
    this.labelId,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
    // 重複行程欄位（預設值確保向後相容）
    this.isMasterEvent = false,
    this.recurrenceRule,
    this.masterEventId,
    this.originalDate,
    this.isException = false,
  });

  /// 從 Firestore 文檔建立物件
  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CalendarEvent(
      id: doc.id,
      userId: data['userId'] as String,
      calendarId: data['calendarId'] as String?,
      title: data['title'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      location: data['location'] as String?,
      description: data['description'] as String?,
      participants: List<String>.from(data['participants'] ?? []),
      reminderMinutes: data['reminderMinutes'] as int? ?? 15,
      isAllDay: data['isAllDay'] as bool? ?? false,
      labelId: data['labelId'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      metadata: EventMetadata.fromJson(data['metadata'] as Map<String, dynamic>),
      // 重複行程欄位
      isMasterEvent: data['isMasterEvent'] as bool? ?? false,
      recurrenceRule: data['recurrenceRule'] != null
          ? RecurrenceRule.fromFirestore(data['recurrenceRule'] as Map<String, dynamic>)
          : null,
      masterEventId: data['masterEventId'] as String?,
      originalDate: data['originalDate'] != null
          ? (data['originalDate'] as Timestamp).toDate()
          : null,
      isException: data['isException'] as bool? ?? false,
    );
  }

  /// 從 JSON 建立物件（用於 API 回傳資料）
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      userId: json['userId'] as String,
      calendarId: json['calendarId'] as String?,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String?,
      description: json['description'] as String?,
      participants: List<String>.from(json['participants'] ?? []),
      reminderMinutes: json['reminderMinutes'] as int? ?? 15,
      isAllDay: json['isAllDay'] as bool? ?? false,
      labelId: json['labelId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: EventMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      // 重複行程欄位
      isMasterEvent: json['isMasterEvent'] as bool? ?? false,
      recurrenceRule: json['recurrenceRule'] != null
          ? RecurrenceRule.fromJson(json['recurrenceRule'] as Map<String, dynamic>)
          : null,
      masterEventId: json['masterEventId'] as String?,
      originalDate: json['originalDate'] != null
          ? DateTime.parse(json['originalDate'] as String)
          : null,
      isException: json['isException'] as bool? ?? false,
    );
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'calendarId': calendarId,
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': location,
      'description': description,
      'participants': participants,
      'reminderMinutes': reminderMinutes,
      'isAllDay': isAllDay,
      'labelId': labelId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata.toJson(),
      // 重複行程欄位
      'isMasterEvent': isMasterEvent,
      'recurrenceRule': recurrenceRule?.toFirestore(),
      'masterEventId': masterEventId,
      'originalDate': originalDate != null ? Timestamp.fromDate(originalDate!) : null,
      'isException': isException,
    };
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'calendarId': calendarId,
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'description': description,
      'participants': participants,
      'reminderMinutes': reminderMinutes,
      'isAllDay': isAllDay,
      'labelId': labelId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata.toJson(),
      // 重複行程欄位
      'isMasterEvent': isMasterEvent,
      'recurrenceRule': recurrenceRule?.toJson(),
      'masterEventId': masterEventId,
      'originalDate': originalDate?.toIso8601String(),
      'isException': isException,
    };
  }

  /// 複製物件並允許修改部分欄位
  CalendarEvent copyWith({
    String? id,
    String? userId,
    String? calendarId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
    List<String>? participants,
    int? reminderMinutes,
    bool? isAllDay,
    String? labelId,
    DateTime? createdAt,
    DateTime? updatedAt,
    EventMetadata? metadata,
    // 重複行程欄位
    bool? isMasterEvent,
    RecurrenceRule? recurrenceRule,
    String? masterEventId,
    DateTime? originalDate,
    bool? isException,
    // 用於清除可選欄位
    bool clearRecurrenceRule = false,
    bool clearMasterEventId = false,
    bool clearOriginalDate = false,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      description: description ?? this.description,
      participants: participants ?? this.participants,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isAllDay: isAllDay ?? this.isAllDay,
      labelId: labelId ?? this.labelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      // 重複行程欄位
      isMasterEvent: isMasterEvent ?? this.isMasterEvent,
      recurrenceRule: clearRecurrenceRule ? null : (recurrenceRule ?? this.recurrenceRule),
      masterEventId: clearMasterEventId ? null : (masterEventId ?? this.masterEventId),
      originalDate: clearOriginalDate ? null : (originalDate ?? this.originalDate),
      isException: isException ?? this.isException,
    );
  }

  /// 檢查是否為重複行程（主行程或實例）
  bool get isRecurring => isMasterEvent || masterEventId != null;

  /// 檢查是否為重複行程的實例
  bool get isRecurrenceInstance => masterEventId != null;

  /// 檢查行程是否在指定日期
  /// 
  /// 支援跨日行程：如果日期在開始日期和結束日期之間（含），則返回 true
  bool isOnDate(DateTime date) {
    // 將所有日期標準化為當天的 00:00:00，只比較年月日
    final startDate = DateTime(startTime.year, startTime.month, startTime.day);
    final endDate = DateTime(endTime.year, endTime.month, endTime.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    
    // 檢查日期是否在行程期間內（包含開始和結束日期）
    return !checkDate.isBefore(startDate) && !checkDate.isAfter(endDate);
  }

  /// 檢查行程是否為跨日行程
  /// 
  /// 如果開始日期和結束日期不同，則為跨日行程
  bool isMultiDay() {
    final startDate = DateTime(startTime.year, startTime.month, startTime.day);
    final endDate = DateTime(endTime.year, endTime.month, endTime.day);
    return !startDate.isAtSameMomentAs(endDate);
  }

  /// 檢查指定日期是否為行程的開始日期
  bool isStartDate(DateTime date) {
    final startDate = DateTime(startTime.year, startTime.month, startTime.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    return startDate.isAtSameMomentAs(checkDate);
  }

  /// 檢查指定日期是否為行程的結束日期
  bool isEndDate(DateTime date) {
    final endDate = DateTime(endTime.year, endTime.month, endTime.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    return endDate.isAtSameMomentAs(checkDate);
  }

  /// 檢查指定日期是否為行程的中間日期（非開始、非結束）
  bool isMiddleDate(DateTime date) {
    return isOnDate(date) && !isStartDate(date) && !isEndDate(date);
  }

  /// 取得行程的持續天數
  int getDurationInDays() {
    final startDate = DateTime(startTime.year, startTime.month, startTime.day);
    final endDate = DateTime(endTime.year, endTime.month, endTime.day);
    return endDate.difference(startDate).inDays + 1;
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

