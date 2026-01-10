import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// 行事曆標題區域元件
/// 
/// 包含：
/// - 上一頁按鈕（根據視圖格式：上個月/前兩週/上一週）
/// - 標題（根據視圖格式：月份/日期範圍）
/// - 格式切換按鈕（月/雙週/週）
/// - 下一頁按鈕
class CalendarHeader extends StatelessWidget {
  /// 當前焦點日期（決定顯示哪個月份/週）
  final DateTime focusedDay;
  
  /// 當前行事曆格式（月/雙週/週）
  final CalendarFormat calendarFormat;
  
  /// 切換到上一頁的回調
  final VoidCallback onPreviousMonth;
  
  /// 切換到下一頁的回調
  final VoidCallback onNextMonth;
  
  /// 切換格式的回調
  final ValueChanged<CalendarFormat> onFormatChanged;
  
  /// 點擊標題的回調（通常用於顯示年月選擇器）
  final VoidCallback onTitleTap;
  
  /// 週起始日（0=週日, 1=週一, 6=週六）
  /// 用於計算週視圖/雙週視圖的日期範圍
  final int weekStartDay;

  const CalendarHeader({
    super.key,
    required this.focusedDay,
    required this.calendarFormat,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onFormatChanged,
    required this.onTitleTap,
    this.weekStartDay = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 根據視圖格式決定標題文字
    final title = _getTitle();
    
    // 格式切換按鈕的文字
    String formatButtonText;
    switch (calendarFormat) {
      case CalendarFormat.month:
        formatButtonText = '月';
        break;
      case CalendarFormat.twoWeeks:
        formatButtonText = '2週';
        break;
      case CalendarFormat.week:
        formatButtonText = '週';
        break;
    }
    
    // 導航按鈕的 tooltip
    String prevTooltip;
    String nextTooltip;
    switch (calendarFormat) {
      case CalendarFormat.month:
        prevTooltip = '上個月';
        nextTooltip = '下個月';
        break;
      case CalendarFormat.twoWeeks:
        prevTooltip = '前兩週';
        nextTooltip = '後兩週';
        break;
      case CalendarFormat.week:
        prevTooltip = '上一週';
        nextTooltip = '下一週';
        break;
    }
    
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // 上一頁按鈕
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: prevTooltip,
            onPressed: onPreviousMonth,
          ),
          
          // 標題（可點擊顯示年月選擇器）
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // 格式切換按鈕
          TextButton(
            onPressed: () {
              // 循環切換格式：月 -> 雙週 -> 週 -> 月
              CalendarFormat newFormat;
              switch (calendarFormat) {
                case CalendarFormat.month:
                  newFormat = CalendarFormat.twoWeeks;
                  break;
                case CalendarFormat.twoWeeks:
                  newFormat = CalendarFormat.week;
                  break;
                case CalendarFormat.week:
                  newFormat = CalendarFormat.month;
                  break;
              }
              onFormatChanged(newFormat);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            child: Text(
              formatButtonText,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          
          // 下一頁按鈕
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: nextTooltip,
            onPressed: onNextMonth,
          ),
        ],
      ),
    );
  }
  
  /// 根據視圖格式取得標題文字
  /// 
  /// - 月視圖：顯示 "YYYY年MM月"
  /// - 週視圖/雙週視圖：顯示日期範圍
  String _getTitle() {
    switch (calendarFormat) {
      case CalendarFormat.month:
        return DateFormat('yyyy年MM月', 'zh_TW').format(focusedDay);
        
      case CalendarFormat.twoWeeks:
        // 計算週的起始和結束日期（根據週起始日設定）
        final weekStart = _getWeekStart(focusedDay);
        final weekEnd = weekStart.add(const Duration(days: 13)); // 兩週
        return _formatDateRange(weekStart, weekEnd);
        
      case CalendarFormat.week:
        // 計算週的起始和結束日期（根據週起始日設定）
        final weekStart = _getWeekStart(focusedDay);
        final weekEnd = weekStart.add(const Duration(days: 6));
        return _formatDateRange(weekStart, weekEnd);
    }
  }
  
  /// 取得指定日期所在週的起始日
  /// 
  /// 根據 weekStartDay 設定計算
  DateTime _getWeekStart(DateTime date) {
    // Dart: weekday 1=星期一, 7=星期日
    // 轉換為：0=週日, 1=週一, ..., 6=週六
    final weekday = date.weekday % 7;
    // 計算需要回退多少天到週起始日
    final daysToSubtract = (weekday - weekStartDay + 7) % 7;
    return DateTime(date.year, date.month, date.day - daysToSubtract);
  }
  
  /// 格式化日期範圍
  /// 
  /// 根據起始和結束日期是否在同一個月/年來決定顯示格式
  String _formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year) {
      if (start.month == end.month) {
        // 同年同月：MM月DD日 - DD日
        return '${start.month}月${start.day}日 - ${end.day}日';
      } else {
        // 同年不同月：MM月DD日 - MM月DD日
        return '${start.month}月${start.day}日 - ${end.month}月${end.day}日';
      }
    } else {
      // 不同年：YYYY/MM/DD - YYYY/MM/DD
      return '${start.year}/${start.month}/${start.day} - ${end.year}/${end.month}/${end.day}';
    }
  }
}

/// 星期列標題元件
/// 
/// 根據週起始日設定動態顯示星期標題
/// 支援：週日開始（0）、週一開始（1）、週六開始（6）
class DaysOfWeekHeader extends StatelessWidget {
  /// 週起始日（0=週日, 1=週一, 6=週六）
  final int weekStartDay;
  
  const DaysOfWeekHeader({
    super.key,
    this.weekStartDay = 0,
  });
  
  /// 基礎星期標題列表（從週日開始）
  static const _baseWeekDays = ['週日', '週一', '週二', '週三', '週四', '週五', '週六'];

  @override
  Widget build(BuildContext context) {
    // 根據週起始日重新排列星期標題
    final weekDays = _getOrderedWeekDays();
    
    return SizedBox(
      height: 30,
      child: Row(
        children: weekDays.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  /// 根據週起始日取得排序後的星期標題列表
  List<String> _getOrderedWeekDays() {
    // 處理特殊情況：週六開始 (6)
    // 其他情況使用標準邏輯
    final startIndex = weekStartDay;
    
    final result = <String>[];
    for (int i = 0; i < 7; i++) {
      result.add(_baseWeekDays[(startIndex + i) % 7]);
    }
    return result;
  }
}

