import '../models/event_model.dart';
import '../models/recurrence_rule.dart';

/// 重複行程服務
///
/// 負責根據重複規則展開行程實例
class RecurrenceService {
  // ==================== 單例模式 ====================

  static final RecurrenceService _instance = RecurrenceService._internal();
  factory RecurrenceService() => _instance;
  RecurrenceService._internal();

  /// 預設展開範圍（6 個月）
  static const int defaultExpandMonths = 6;

  /// 根據主行程和重複規則展開實例
  ///
  /// [masterEvent] 主行程（包含重複規則）
  /// [expandUntil] 展開到的結束日期（預設為 6 個月後）
  ///
  /// 回傳：實例行程列表（不包含主行程本身）
  List<CalendarEvent> expandInstances(
    CalendarEvent masterEvent, {
    DateTime? expandUntil,
  }) {
    final rule = masterEvent.recurrenceRule;
    if (rule == null) return [];

    // 計算展開結束日期
    final now = DateTime.now();
    final defaultEnd = DateTime(now.year, now.month + defaultExpandMonths, now.day);
    DateTime endDate = expandUntil ?? defaultEnd;

    // 如果規則有結束日期，取較早的那個
    if (rule.endDate != null && rule.endDate!.isBefore(endDate)) {
      endDate = rule.endDate!;
    }

    final instances = <CalendarEvent>[];
    DateTime currentDate = masterEvent.startTime;

    // 跳過第一個日期（主行程本身）
    currentDate = _getNextOccurrence(currentDate, rule);

    // 展開實例
    while (currentDate.isBefore(endDate) || _isSameDay(currentDate, endDate)) {
      final instance = _createInstance(masterEvent, currentDate);
      instances.add(instance);

      // 取得下一個日期
      currentDate = _getNextOccurrence(currentDate, rule);

      // 安全檢查：避免無限循環
      if (instances.length > 1000) break;
    }

    return instances;
  }

  /// 計算下一個重複日期
  ///
  /// [currentDate] 當前日期
  /// [rule] 重複規則
  DateTime _getNextOccurrence(DateTime currentDate, RecurrenceRule rule) {
    switch (rule.type) {
      case 'daily':
        return _getNextDailyOccurrence(currentDate, rule.interval);
      case 'weekly':
        return _getNextWeeklyOccurrence(currentDate, rule.interval, rule.weekdays);
      case 'monthly':
        return _getNextMonthlyOccurrence(currentDate, rule.interval, rule.monthDay);
      case 'yearly':
        return _getNextYearlyOccurrence(currentDate, rule.interval);
      default:
        return currentDate.add(const Duration(days: 1));
    }
  }

  /// 計算下一個每日重複日期
  DateTime _getNextDailyOccurrence(DateTime current, int interval) {
    return current.add(Duration(days: interval));
  }

  /// 計算下一個每週重複日期
  DateTime _getNextWeeklyOccurrence(
    DateTime current,
    int interval,
    List<int> weekdays,
  ) {
    if (weekdays.isEmpty) {
      // 沒有指定星期幾，直接加 N 週
      return current.add(Duration(days: 7 * interval));
    }

    // 排序星期幾列表
    final sortedWeekdays = List<int>.from(weekdays)..sort();

    // 找當前週的下一個符合的星期幾
    final currentWeekday = current.weekday; // 1=週一, 7=週日
    for (final weekday in sortedWeekdays) {
      if (weekday > currentWeekday) {
        final daysToAdd = weekday - currentWeekday;
        return DateTime(current.year, current.month, current.day + daysToAdd,
            current.hour, current.minute);
      }
    }

    // 沒有找到當週的下一個，跳到下 N 週的第一個符合的星期幾
    final daysToNextWeek = 7 - currentWeekday + sortedWeekdays.first;
    final daysToAdd = daysToNextWeek + (interval - 1) * 7;
    return DateTime(current.year, current.month, current.day + daysToAdd,
        current.hour, current.minute);
  }

  /// 計算下一個每月重複日期
  DateTime _getNextMonthlyOccurrence(
    DateTime current,
    int interval,
    int? monthDay,
  ) {
    final targetDay = monthDay ?? current.day;

    // 計算下 N 個月
    int newMonth = current.month + interval;
    int newYear = current.year;
    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }

    // 處理月底問題（例如：31 日在 2 月變成 28/29 日）
    final daysInMonth = DateTime(newYear, newMonth + 1, 0).day;
    final actualDay = targetDay > daysInMonth ? daysInMonth : targetDay;

    return DateTime(newYear, newMonth, actualDay, current.hour, current.minute);
  }

  /// 計算下一個每年重複日期
  DateTime _getNextYearlyOccurrence(DateTime current, int interval) {
    final newYear = current.year + interval;

    // 處理閏年 2/29 問題
    final isLeapDay = current.month == 2 && current.day == 29;
    if (isLeapDay && !_isLeapYear(newYear)) {
      return DateTime(newYear, 2, 28, current.hour, current.minute);
    }

    return DateTime(
        newYear, current.month, current.day, current.hour, current.minute);
  }

  /// 根據主行程建立單一實例
  ///
  /// [master] 主行程
  /// [instanceDate] 實例的開始日期
  CalendarEvent _createInstance(CalendarEvent master, DateTime instanceDate) {
    // 計算時間差（保持原始的時間長度）
    final duration = master.endTime.difference(master.startTime);

    // 計算實例的開始和結束時間
    final instanceStartTime = DateTime(
      instanceDate.year,
      instanceDate.month,
      instanceDate.day,
      master.startTime.hour,
      master.startTime.minute,
    );
    final instanceEndTime = instanceStartTime.add(duration);

    return CalendarEvent(
      id: '', // 會由 Firestore 自動產生
      userId: master.userId,
      calendarId: master.calendarId,
      title: master.title,
      startTime: instanceStartTime,
      endTime: instanceEndTime,
      location: master.location,
      description: master.description,
      participants: master.participants,
      reminderMinutes: master.reminderMinutes,
      isAllDay: master.isAllDay,
      labelId: master.labelId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: master.metadata,
      // 實例特有欄位
      isMasterEvent: false,
      masterEventId: master.id,
      originalDate: instanceDate,
      isException: false,
    );
  }

  /// 根據新的主行程建立實例（用於「此行程及之後」編輯）
  ///
  /// [newMaster] 新的主行程
  /// [fromDate] 從哪個日期開始展開
  /// [expandUntil] 展開到的結束日期
  List<CalendarEvent> expandInstancesFromDate(
    CalendarEvent newMaster,
    DateTime fromDate, {
    DateTime? expandUntil,
  }) {
    final rule = newMaster.recurrenceRule;
    if (rule == null) return [];

    final now = DateTime.now();
    final defaultEnd =
        DateTime(now.year, now.month + defaultExpandMonths, now.day);
    DateTime endDate = expandUntil ?? defaultEnd;

    if (rule.endDate != null && rule.endDate!.isBefore(endDate)) {
      endDate = rule.endDate!;
    }

    final instances = <CalendarEvent>[];
    DateTime currentDate = fromDate;

    // 跳過 fromDate 本身（因為 newMaster 就是那天的行程）
    currentDate = _getNextOccurrence(currentDate, rule);

    while (currentDate.isBefore(endDate) || _isSameDay(currentDate, endDate)) {
      final instance = _createInstance(newMaster, currentDate);
      instances.add(instance);

      currentDate = _getNextOccurrence(currentDate, rule);

      if (instances.length > 1000) break;
    }

    return instances;
  }

  /// 檢查是否為閏年
  bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// 檢查兩個日期是否為同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 從 UI 狀態建立 RecurrenceRule
  ///
  /// [type] 重複類型
  /// [interval] 重複間隔
  /// [weekdays] 週重複的星期幾
  /// [monthDay] 月重複的日期
  /// [endDate] 結束日期
  RecurrenceRule? createRuleFromUI({
    required String? type,
    required int interval,
    required Set<int> weekdays,
    required int? monthDay,
    required DateTime? endDate,
  }) {
    if (type == null) return null;

    return RecurrenceRule(
      type: type,
      interval: interval,
      weekdays: weekdays.toList()..sort(),
      monthDay: monthDay,
      endDate: endDate,
    );
  }
}
