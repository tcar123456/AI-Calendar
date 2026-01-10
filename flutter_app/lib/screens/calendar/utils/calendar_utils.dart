import 'package:flutter/material.dart';
import '../../../models/event_model.dart';
import '../../../models/event_label_model.dart';

/// 行事曆工具類別
/// 
/// 提供行事曆相關的計算邏輯，包括：
/// - 週/月份日期計算
/// - 跨日事件行分配算法
/// - 事件顏色分配（根據標籤）
class CalendarUtils {
  /// 預設的行程顏色列表（備用，當事件沒有標籤時使用）
  /// 用於區分不同的跨日事件
  static const List<Color> eventColors = [
    Color(0xFF4CAF50), // 綠色
    Color(0xFF2196F3), // 藍色
    Color(0xFFFF9800), // 橙色
    Color(0xFF9C27B0), // 紫色
    Color(0xFFF44336), // 紅色
    Color(0xFF00BCD4), // 青色
    Color(0xFFFFEB3B), // 黃色
    Color(0xFF795548), // 棕色
    Color(0xFFE91E63), // 粉紅色
    Color(0xFF607D8B), // 灰藍色
  ];

  /// 取得當月的所有週（每週為一個 List<DateTime>）
  /// 
  /// [month] - 目標月份
  /// [weekStartDay] - 週起始日（0=週日, 1=週一, 6=週六），預設為週日
  /// 
  /// 每週從指定的起始日開始，包含上個月末尾和下個月開頭的日期
  static List<List<DateTime>> getWeeksInMonth(DateTime month, {int weekStartDay = 0}) {
    final List<List<DateTime>> weeks = [];
    
    // 取得當月第一天
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    // 取得當月最後一天
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    
    // 找到第一週的起始日（可能是上個月的日期）
    // Dart: weekday 1=星期一, 7=星期日
    // 轉換為：0=星期日, 1=星期一, ..., 6=星期六
    final firstDayWeekday = firstDayOfMonth.weekday % 7;
    
    // 計算需要回退多少天到週起始日
    int daysToSubtract = (firstDayWeekday - weekStartDay + 7) % 7;
    final firstWeekStart = firstDayOfMonth.subtract(Duration(days: daysToSubtract));
    
    // 從週起始日開始，逐週建立日期列表
    DateTime currentDay = firstWeekStart;
    while (currentDay.isBefore(lastDayOfMonth) || 
           currentDay.isAtSameMomentAs(lastDayOfMonth) ||
           weeks.isEmpty ||
           (weeks.isNotEmpty && weeks.last.last.month == month.month)) {
      final List<DateTime> week = [];
      for (int i = 0; i < 7; i++) {
        week.add(currentDay);
        currentDay = currentDay.add(const Duration(days: 1));
      }
      weeks.add(week);
      
      // 如果已經超過當月最後一天，且當前週已包含下個月的日期，就停止
      if (currentDay.month != month.month && 
          weeks.last.any((day) => day.month != month.month && day.isAfter(lastDayOfMonth))) {
        break;
      }
    }
    
    return weeks;
  }

  /// 為所有跨日事件分配行索引
  /// 
  /// 算法說明：
  /// 1. 按開始時間排序所有跨日事件
  /// 2. 對每個事件，使用貪婪算法分配到第一個可用的行
  /// 3. 「可用」的定義：沒有其他事件在這個行中與當前事件的時間範圍重疊
  /// 
  /// 這樣可以確保：
  /// - 跨日事件在整個期間內保持相同的垂直位置
  /// - 重疊的跨日事件會被分配到不同的行
  /// - 行分配是最優化的（使用最少的行數）
  static Map<String, int> allocateMultiDayEventRows(List<CalendarEvent> allEvents) {
    // 篩選出所有跨日事件並按開始時間排序
    final multiDayEvents = allEvents
        .where((e) => e.isMultiDay())
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    
    // 行分配表
    final Map<String, int> rowAllocation = {};
    
    // 追踪每個行的結束時間（用於判斷該行是否可用）
    // key: 行索引, value: 該行最後一個事件的結束日期
    final Map<int, DateTime> rowEndDates = {};
    
    for (final event in multiDayEvents) {
      final eventStartDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      
      // 找到第一個可用的行（該行的結束時間早於當前事件的開始時間）
      int assignedRow = 0;
      while (rowEndDates.containsKey(assignedRow)) {
        final rowEnd = rowEndDates[assignedRow]!;
        // 如果該行的最後事件結束日期早於當前事件開始日期，則該行可用
        if (rowEnd.isBefore(eventStartDate)) {
          break;
        }
        assignedRow++;
      }
      
      // 分配行索引
      rowAllocation[event.id] = assignedRow;
      
      // 更新該行的結束時間
      final eventEndDate = DateTime(
        event.endTime.year,
        event.endTime.month,
        event.endTime.day,
      );
      rowEndDates[assignedRow] = eventEndDate;
    }
    
    return rowAllocation;
  }

  /// 取得事件的顏色
  /// 
  /// 優先根據事件的標籤來決定顏色，
  /// 如果沒有標籤則使用備用的顏色分配邏輯
  static Color getEventColor(CalendarEvent event, Map<String, int> rowAllocation) {
    // 優先使用標籤顏色
    if (event.labelId != null) {
      final label = DefaultEventLabels.getById(event.labelId!);
      if (label != null) {
        return label.color;
      }
    }
    
    // 備用邏輯：根據事件的行分配索引來決定顏色
    if (event.isMultiDay()) {
      // 跨日事件根據行分配使用不同顏色
      final rowIndex = rowAllocation[event.id] ?? 0;
      return eventColors[rowIndex % eventColors.length];
    } else {
      // 單日事件使用較淺的顏色
      return eventColors[event.id.hashCode.abs() % eventColors.length];
    }
  }
  
  /// 根據標籤列表取得事件顏色
  /// 
  /// 使用自訂標籤列表來獲取顏色（支援用戶自訂的標籤名稱）
  static Color getEventColorWithLabels(
    CalendarEvent event, 
    Map<String, int> rowAllocation,
    List<EventLabel> labels,
  ) {
    // 優先使用標籤顏色
    if (event.labelId != null) {
      try {
        final label = labels.firstWhere((l) => l.id == event.labelId);
        return label.color;
      } catch (_) {
        // 找不到對應標籤，嘗試使用預設標籤
        final defaultLabel = DefaultEventLabels.getById(event.labelId!);
        if (defaultLabel != null) {
          return defaultLabel.color;
        }
      }
    }
    
    // 備用邏輯
    if (event.isMultiDay()) {
      final rowIndex = rowAllocation[event.id] ?? 0;
      return eventColors[rowIndex % eventColors.length];
    } else {
      return eventColors[event.id.hashCode.abs() % eventColors.length];
    }
  }

  /// 計算指定日期被跨日事件佔據的行索引列表
  /// 
  /// 這用於讓單日事件可以填補跨日事件之間的空白
  static Set<int> getOccupiedRowsForDate(
    DateTime date,
    List<CalendarEvent> allEvents,
    Map<String, int> rowAllocation,
  ) {
    final occupiedRows = <int>{};
    
    for (final event in allEvents) {
      if (event.isMultiDay() && event.isOnDate(date)) {
        final rowIndex = rowAllocation[event.id];
        if (rowIndex != null) {
          occupiedRows.add(rowIndex);
        }
      }
    }
    
    return occupiedRows;
  }

  /// 取得這一週的跨日事件
  /// 
  /// 返回在這一週內有顯示的跨日事件列表
  /// 按照事件開始時間排序
  static List<CalendarEvent> getMultiDayEventsForWeek(
    List<DateTime> week, 
    List<CalendarEvent> allEvents,
  ) {
    final weekStart = DateTime(week.first.year, week.first.month, week.first.day);
    final weekEnd = DateTime(week.last.year, week.last.month, week.last.day, 23, 59, 59);
    
    return allEvents
        .where((event) {
          // 必須是跨日事件
          if (!event.isMultiDay()) return false;
          
          // 事件的日期範圍
          final eventStart = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
          final eventEnd = DateTime(event.endTime.year, event.endTime.month, event.endTime.day);
          
          // 檢查事件是否與這一週有交集
          return !eventEnd.isBefore(weekStart) && !eventStart.isAfter(weekEnd);
        })
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 判斷兩個日期是否為同一天
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

