/// 重複行程規則模型
///
/// 用於定義行程的重複規則，支援每日、每週、每月、每年重複
class RecurrenceRule {
  /// 重複類型：daily | weekly | monthly | yearly
  final String type;

  /// 重複間隔（每 N 天/週/月/年）
  final int interval;

  /// 週重複時選擇的星期幾（1=週一, 7=週日）
  final List<int> weekdays;

  /// 月重複時指定的日期（1-31）
  final int? monthDay;

  /// 重複結束日期（null 表示永不結束）
  final DateTime? endDate;

  const RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.weekdays = const [],
    this.monthDay,
    this.endDate,
  });

  /// 從 JSON 建立物件
  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      type: json['type'] as String,
      interval: json['interval'] as int? ?? 1,
      weekdays: (json['weekdays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      monthDay: json['monthDay'] as int?,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
    );
  }

  /// 從 Firestore 格式建立物件
  factory RecurrenceRule.fromFirestore(Map<String, dynamic> data) {
    return RecurrenceRule(
      type: data['type'] as String,
      interval: data['interval'] as int? ?? 1,
      weekdays: (data['weekdays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      monthDay: data['monthDay'] as int?,
      endDate: data['endDate'] != null
          ? (data['endDate'] as dynamic).toDate()
          : null,
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'interval': interval,
      'weekdays': weekdays,
      'monthDay': monthDay,
      'endDate': endDate?.toIso8601String(),
    };
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'interval': interval,
      'weekdays': weekdays,
      'monthDay': monthDay,
      'endDate': endDate,
    };
  }

  /// 複製物件並允許修改部分欄位
  RecurrenceRule copyWith({
    String? type,
    int? interval,
    List<int>? weekdays,
    int? monthDay,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      monthDay: monthDay ?? this.monthDay,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  /// 取得重複類型的中文顯示名稱
  String get typeDisplayName {
    switch (type) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每週';
      case 'monthly':
        return '每月';
      case 'yearly':
        return '每年';
      default:
        return type;
    }
  }

  /// 取得完整的重複規則描述
  String get displayDescription {
    final buffer = StringBuffer();

    // 基本頻率
    if (interval == 1) {
      buffer.write(typeDisplayName);
    } else {
      final unit = {
        'daily': '天',
        'weekly': '週',
        'monthly': '個月',
        'yearly': '年',
      }[type] ?? '';
      buffer.write('每 $interval $unit');
    }

    // 週重複的星期幾
    if (type == 'weekly' && weekdays.isNotEmpty) {
      final weekdayNames = weekdays.map(_weekdayName).join('、');
      buffer.write('（$weekdayNames）');
    }

    // 月重複的日期
    if (type == 'monthly' && monthDay != null) {
      buffer.write('（$monthDay 日）');
    }

    // 結束日期
    if (endDate != null) {
      final endStr =
          '${endDate!.year}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.day.toString().padLeft(2, '0')}';
      buffer.write('，直到 $endStr');
    }

    return buffer.toString();
  }

  /// 將星期幾數字轉換為中文名稱
  String _weekdayName(int weekday) {
    const names = ['', '週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    return weekday >= 1 && weekday <= 7 ? names[weekday] : '';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RecurrenceRule) return false;
    return type == other.type &&
        interval == other.interval &&
        _listEquals(weekdays, other.weekdays) &&
        monthDay == other.monthDay &&
        endDate == other.endDate;
  }

  @override
  int get hashCode {
    return Object.hash(type, interval, Object.hashAll(weekdays), monthDay, endDate);
  }

  /// 比較兩個列表是否相等
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 編輯重複行程時的選項
enum RecurrenceEditChoice {
  /// 僅此行程
  thisOnly,

  /// 此行程及之後所有
  thisAndFollowing,

  /// 所有行程
  all,
}

/// 刪除重複行程時的選項
enum RecurrenceDeleteChoice {
  /// 僅此行程
  thisOnly,

  /// 此行程及之後所有
  thisAndFollowing,

  /// 所有行程
  all,
}
