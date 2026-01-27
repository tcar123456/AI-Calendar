import 'package:cloud_firestore/cloud_firestore.dart';

/// 成員角色列舉
enum MemberRole {
  /// 擁有者（可完全控制行事曆）
  owner,
  /// 編輯者（可新增/編輯行程）
  editor,
  /// 檢視者（只能查看行程）
  viewer,
}

/// 成員角色擴充方法
extension MemberRoleExtension on MemberRole {
  /// 轉換為字串
  String toJson() {
    switch (this) {
      case MemberRole.owner:
        return 'owner';
      case MemberRole.editor:
        return 'editor';
      case MemberRole.viewer:
        return 'viewer';
    }
  }

  /// 從字串建立
  static MemberRole fromJson(String value) {
    switch (value) {
      case 'owner':
        return MemberRole.owner;
      case 'editor':
        return MemberRole.editor;
      case 'viewer':
        return MemberRole.viewer;
      default:
        return MemberRole.viewer;
    }
  }

  /// 取得顯示名稱
  String get displayName {
    switch (this) {
      case MemberRole.owner:
        return '擁有者';
      case MemberRole.editor:
        return '編輯者';
      case MemberRole.viewer:
        return '檢視者';
    }
  }
}

/// 行事曆成員模型
///
/// 代表一個行事曆的成員資料
class CalendarMember {
  /// 成員記錄唯一識別碼
  final String id;

  /// 所屬行事曆 ID
  final String calendarId;

  /// 成員用戶 ID
  final String userId;

  /// 成員角色
  final MemberRole role;

  /// 邀請者用戶 ID
  final String invitedBy;

  /// 加入時間
  final DateTime joinedAt;

  CalendarMember({
    required this.id,
    required this.calendarId,
    required this.userId,
    required this.role,
    required this.invitedBy,
    required this.joinedAt,
  });

  /// 從 Firestore 文檔建立物件
  factory CalendarMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CalendarMember(
      id: doc.id,
      calendarId: data['calendarId'] as String,
      userId: data['userId'] as String,
      role: MemberRoleExtension.fromJson(data['role'] as String? ?? 'viewer'),
      invitedBy: data['invitedBy'] as String,
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
    );
  }

  /// 從 JSON 建立物件
  factory CalendarMember.fromJson(Map<String, dynamic> json) {
    return CalendarMember(
      id: json['id'] as String,
      calendarId: json['calendarId'] as String,
      userId: json['userId'] as String,
      role: MemberRoleExtension.fromJson(json['role'] as String? ?? 'viewer'),
      invitedBy: json['invitedBy'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'calendarId': calendarId,
      'userId': userId,
      'role': role.toJson(),
      'invitedBy': invitedBy,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'calendarId': calendarId,
      'userId': userId,
      'role': role.toJson(),
      'invitedBy': invitedBy,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  /// 複製物件並允許修改部分欄位
  CalendarMember copyWith({
    String? id,
    String? calendarId,
    String? userId,
    MemberRole? role,
    String? invitedBy,
    DateTime? joinedAt,
  }) {
    return CalendarMember(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      invitedBy: invitedBy ?? this.invitedBy,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
