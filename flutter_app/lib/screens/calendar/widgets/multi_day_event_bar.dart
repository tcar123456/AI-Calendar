import 'package:flutter/material.dart';
import '../../../models/event_model.dart';
import '../../../theme/app_colors.dart';
import '../utils/calendar_utils.dart';
import 'day_cell.dart' show EventDragData;

/// 跨日事件橫條元件
/// 
/// 用於在週視圖中顯示跨越多天的事件橫條
/// 
/// 設計說明：
/// - 使用 Positioned 定位，需要放在 Stack 中
/// - 根據事件的行分配來決定垂直位置
/// - 根據事件的日期範圍來決定水平寬度
/// - 圓角根據事件是否延續到上週/下週而變化
/// - 點擊時開啟點擊位置對應日期的列表（由父層處理）
class MultiDayEventBar extends StatelessWidget {
  /// 當週的日期列表
  final List<DateTime> week;
  
  /// 跨日事件
  final CalendarEvent event;
  
  /// 單個日期單元格的寬度
  final double cellWidth;
  
  /// 日期數字區域的高度
  final double dateNumberHeight;
  
  /// 事件項目高度
  final double eventItemHeight;
  
  /// 事件項目間距
  final double eventItemGap;
  
  /// 跨日事件行分配表
  final Map<String, int> rowAllocation;
  
  /// 點擊日期的回調（用於開啟日期列表）
  final ValueChanged<DateTime>? onDaySelected;

  /// 拖曳開始回調
  final VoidCallback? onDragStarted;

  /// 拖曳結束回調
  final VoidCallback? onDragEnded;

  const MultiDayEventBar({
    super.key,
    required this.week,
    required this.event,
    required this.cellWidth,
    required this.dateNumberHeight,
    required this.eventItemHeight,
    required this.eventItemGap,
    required this.rowAllocation,
    this.onDaySelected,
    this.onDragStarted,
    this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 取得事件的行索引（從全局分配表）
    final rowIndex = rowAllocation[event.id] ?? 0;
    
    // 取得事件顏色
    final eventColor = CalendarUtils.getEventColor(event, rowAllocation);
    
    // 計算事件在這一週的開始位置和結束位置
    final weekStart = DateTime(week.first.year, week.first.month, week.first.day);
    final weekEnd = DateTime(week.last.year, week.last.month, week.last.day);
    final eventStart = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
    final eventEnd = DateTime(event.endTime.year, event.endTime.month, event.endTime.day);
    
    // 計算開始列索引（0-6）
    int startCol;
    if (eventStart.isBefore(weekStart)) {
      startCol = 0; // 事件從上一週延續過來
    } else {
      startCol = eventStart.difference(weekStart).inDays;
    }
    
    // 計算結束列索引（0-6）
    int endCol;
    if (eventEnd.isAfter(weekEnd)) {
      endCol = 6; // 事件延續到下一週
    } else {
      endCol = eventEnd.difference(weekStart).inDays;
    }
    
    // 確保索引在有效範圍內
    startCol = startCol.clamp(0, 6);
    endCol = endCol.clamp(0, 6);
    
    // 計算橫條的位置和寬度
    final left = startCol * cellWidth + 2; // 左邊留 2px 間距
    final width = (endCol - startCol + 1) * cellWidth - 4; // 左右各留 2px 間距
    // 橫條位置：日期數字下方 + 根據全局行索引計算的垂直位置
    final top = dateNumberHeight + 2 + (rowIndex * (eventItemHeight + eventItemGap));
    
    // 判斷橫條的圓角（是否從上一週延續、是否延續到下一週）
    final isStartInThisWeek = !eventStart.isBefore(weekStart);
    final isEndInThisWeek = !eventEnd.isAfter(weekEnd);
    
    BorderRadius borderRadius;
    if (isStartInThisWeek && isEndInThisWeek) {
      // 事件完全在這一週內：兩端都有圓角
      borderRadius = BorderRadius.circular(3);
    } else if (isStartInThisWeek) {
      // 事件從這週開始，延續到下週：只有左邊圓角
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(3),
        bottomLeft: Radius.circular(3),
      );
    } else if (isEndInThisWeek) {
      // 事件從上週延續，在這週結束：只有右邊圓角
      borderRadius = const BorderRadius.only(
        topRight: Radius.circular(3),
        bottomRight: Radius.circular(3),
      );
    } else {
      // 事件從上週延續到下週：沒有圓角
      borderRadius = BorderRadius.zero;
    }
    
    // 只在開始的那一週顯示標題
    final showTitle = isStartInThisWeek;
    
    // 計算拖曳來源日期（事件的開始日期）
    final sourceDateForDrag = DateTime(
      event.startTime.year,
      event.startTime.month,
      event.startTime.day,
    );

    // 跨日行程條的顯示內容
    Widget barContent = Container(
      decoration: BoxDecoration(
        color: eventColor,
        borderRadius: borderRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // 文字置中顯示
      alignment: Alignment.center,
      child: showTitle
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 重複行程標記
                if (event.isRecurring)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(
                      Icons.repeat,
                      size: 10,
                      color: colors.textOnPrimary,
                    ),
                  ),
                Flexible(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textOnPrimary,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : null,
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: eventItemHeight - 1, // 減1留出間距
      child: LongPressDraggable<EventDragData>(
        data: EventDragData(event: event, sourceDate: sourceDateForDrag),
        delay: const Duration(milliseconds: 300),
        hapticFeedbackOnStart: true,
        onDragStarted: onDragStarted,
        onDragEnd: (_) => onDragEnded?.call(),
        // 拖曳時顯示的預覽
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: eventColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (event.isRecurring)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.repeat, size: 10, color: colors.textOnPrimary),
                  ),
                Flexible(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textOnPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 拖曳時原位置顯示的佔位符
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: barContent,
        ),
        child: GestureDetector(
          // 點擊時根據點擊位置計算對應的日期，然後開啟該日期的列表
          onTapUp: (details) {
            if (onDaySelected == null) return;

            // 根據點擊位置計算對應的日期列索引
            final tapX = details.localPosition.dx;
            final columnIndex = (tapX / cellWidth).floor();
            final actualColumnIndex = (startCol + columnIndex).clamp(0, 6);
            final tappedDay = week[actualColumnIndex];

            onDaySelected!(tappedDay);
          },
          child: barContent,
        ),
      ),
    );
  }
}

