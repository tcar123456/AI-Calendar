import 'package:cloud_firestore/cloud_firestore.dart';

/// 備忘錄模型
/// 
/// 代表一個完整的備忘錄資料結構
/// 與行程不同，備忘錄沒有特定的時間範圍，只有提醒時間（可選）
class Memo {
  /// 備忘錄唯一識別碼
  final String id;
  
  /// 備忘錄擁有者的用戶 ID
  final String userId;
  
  /// 備忘錄標題
  final String title;
  
  /// 備忘錄內容
  final String? content;
  
  /// 是否已完成
  final bool isCompleted;
  
  /// 是否已釘選（置頂）
  final bool isPinned;
  
  /// 提醒時間（可選）
  final DateTime? reminderTime;
  
  /// 標籤列表（用於分類）
  final List<String> tags;
  
  /// 優先級：0=普通, 1=重要, 2=緊急
  final int priority;
  
  /// 建立時間
  final DateTime createdAt;
  
  /// 最後更新時間
  final DateTime updatedAt;

  Memo({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    this.isCompleted = false,
    this.isPinned = false,
    this.reminderTime,
    this.tags = const [],
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 從 Firestore 文檔建立物件
  factory Memo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Memo(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      content: data['content'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      isPinned: data['isPinned'] as bool? ?? false,
      reminderTime: data['reminderTime'] != null 
          ? (data['reminderTime'] as Timestamp).toDate() 
          : null,
      tags: List<String>.from(data['tags'] ?? []),
      priority: data['priority'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// 從 JSON 建立物件
  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      reminderTime: json['reminderTime'] != null 
          ? DateTime.parse(json['reminderTime'] as String) 
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      priority: json['priority'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'isCompleted': isCompleted,
      'isPinned': isPinned,
      'reminderTime': reminderTime != null 
          ? Timestamp.fromDate(reminderTime!) 
          : null,
      'tags': tags,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'isCompleted': isCompleted,
      'isPinned': isPinned,
      'reminderTime': reminderTime?.toIso8601String(),
      'tags': tags,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 複製物件並允許修改部分欄位
  Memo copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    bool? isCompleted,
    bool? isPinned,
    DateTime? reminderTime,
    List<String>? tags,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Memo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      isPinned: isPinned ?? this.isPinned,
      reminderTime: reminderTime ?? this.reminderTime,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 取得優先級文字
  String getPriorityText() {
    switch (priority) {
      case 2:
        return '緊急';
      case 1:
        return '重要';
      default:
        return '普通';
    }
  }

  /// 檢查是否有提醒
  bool hasReminder() {
    return reminderTime != null;
  }

  /// 檢查提醒是否已過期
  bool isReminderPast() {
    if (reminderTime == null) return false;
    return reminderTime!.isBefore(DateTime.now());
  }
}

