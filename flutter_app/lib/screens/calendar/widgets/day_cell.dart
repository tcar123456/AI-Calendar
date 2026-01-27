import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart' show Solar;
import 'package:table_calendar/table_calendar.dart';
import '../../../models/event_model.dart';
import '../../../models/holiday_model.dart';
import '../../../utils/constants.dart';
import '../utils/calendar_utils.dart';

/// 行程拖曳資料
///
/// 用於在拖曳過程中傳遞行程資訊
class EventDragData {
  final CalendarEvent event;
  final DateTime sourceDate;

  const EventDragData({
    required this.event,
    required this.sourceDate,
  });
}

/// 日期單元格元件
///
/// 顯示單個日期的內容，包括：
/// - 日期數字（今天會有特殊樣式）
/// - 節日（作為行程顯示，使用紅色背景）
/// - 單日事件列表（填入跨日事件之間的空白插槽）
///
/// 設計說明：
/// - 跨日事件橫條由上層 Stack 繪製，不在此元件中處理
/// - 節日會作為第一個事件項目顯示，使用紅色背景（類似 TimeTree）
/// - 單日事件會根據 occupiedRows 來決定放置位置
/// - 點擊整個日期單元格（無論是空白區域還是事件）都會觸發 onDaySelected
/// - 用戶需要先開啟日期列表，再點擊列表中的行程進入編輯
/// - 支援長按行程拖曳到其他日期
class DayCell extends StatelessWidget {
  /// 當天日期
  final DateTime day;

  /// 當天的單日事件列表
  final List<CalendarEvent> singleDayEvents;

  /// 所有事件（用於計算）
  final List<CalendarEvent> allEvents;

  /// 被跨日事件佔據的行索引
  final Set<int> occupiedRows;

  /// 跨日事件總行數
  final int totalMultiDayRows;

  /// 焦點月份（用於判斷是否為當月日期）
  final DateTime focusedMonth;

  /// 選中的日期
  final DateTime selectedDay;

  /// 跨日事件行分配表
  final Map<String, int> rowAllocation;

  /// 點擊日期的回調（統一開啟列表）
  final ValueChanged<DateTime> onDaySelected;

  /// 點擊事件的回調（目前不再直接使用，保留以維持 API 相容性）
  final ValueChanged<CalendarEvent> onEventTap;

  /// 行程拖曳放置回調
  ///
  /// 當行程被拖曳到此日期並放開時觸發
  /// 參數：(被拖曳的行程, 來源日期, 目標日期)
  final void Function(CalendarEvent event, DateTime sourceDate, DateTime targetDate)? onEventDrop;

  /// 拖曳開始回調
  final VoidCallback? onDragStarted;

  /// 拖曳結束回調
  final VoidCallback? onDragEnded;

  /// 當前行事曆格式（月/雙週/週）
  /// 用於決定是否需要反灰非當月日期
  final CalendarFormat calendarFormat;

  /// 是否顯示節日
  final bool showHolidays;

  /// 節日地區列表（複選）
  final List<String> holidayRegions;

  /// 是否顯示農曆
  final bool showLunar;

  /// 日期數字區域高度（不含農曆）
  static const double dateNumberHeight = 24.0;

  /// 農曆文字高度
  static const double lunarTextHeight = 12.0;

  /// 事件項目高度
  static const double eventItemHeight = 14.0;

  /// 事件項目間距
  static const double eventItemGap = 1.0;

  /// 最大顯示行數
  static const int maxDisplayRows = 4;

  const DayCell({
    super.key,
    required this.day,
    required this.singleDayEvents,
    required this.allEvents,
    required this.occupiedRows,
    required this.totalMultiDayRows,
    required this.focusedMonth,
    required this.selectedDay,
    required this.rowAllocation,
    required this.onDaySelected,
    required this.onEventTap,
    this.onEventDrop,
    this.onDragStarted,
    this.onDragEnded,
    this.calendarFormat = CalendarFormat.month,
    this.showHolidays = true,
    this.holidayRegions = const ['taiwan'],
    this.showLunar = false,
  });

  @override
  Widget build(BuildContext context) {
    // 判斷日期狀態
    final now = DateTime.now();
    final isToday = day.year == now.year && 
                    day.month == now.month && 
                    day.day == now.day;
    final isSelected = isSameDay(selectedDay, day);
    
    // 只有在月視圖中才需要反灰非當月日期
    // 週視圖和雙週視圖中所有日期都應該正常顯示
    final isOutside = calendarFormat == CalendarFormat.month && 
                      day.month != focusedMonth.month;
    
    // 決定文字顏色
    final textColor = isOutside ? Colors.grey[400]! : Colors.black87;
    
    // 選中時的背景色
    Color? containerBackgroundColor;
    if (isSelected) {
      containerBackgroundColor = Colors.black.withOpacity(0.15);
    }
    
    // 取得當日的節日列表（根據選擇的地區）
    final holidays = showHolidays 
        ? HolidayManager.getHolidaysForDate(day, holidayRegions)
        : <Holiday>[];
    
    // 判斷是否為國定假日或傳統節日（用於日期數字顏色）
    final hasNationalOrTraditionalHoliday = holidays.any(
      (h) => h.type == HolidayType.national || h.type == HolidayType.traditional
    );
    
    // 計算單日事件應該填入哪些插槽
    // 找出跨日事件之間的空白插槽
    final availableSlots = <int>[];
    for (int i = 0; i < maxDisplayRows; i++) {
      if (!occupiedRows.contains(i)) {
        availableSlots.add(i);
      }
    }

    // 計算農曆日期（初一顯示月份名稱，其他顯示日）
    String? lunarDayText;
    if (showLunar) {
      final solar = Solar.fromDate(day);
      final lunar = solar.getLunar();
      // 初一顯示月份名稱（如：正月、二月），其他顯示日（如：初二、十五）
      if (lunar.getDay() == 1) {
        lunarDayText = lunar.getMonthInChinese();
      } else {
        lunarDayText = lunar.getDayInChinese();
      }
    }

    // 計算日期區域總高度
    final totalDateHeight = showLunar
        ? dateNumberHeight + lunarTextHeight
        : dateNumberHeight;

    return DragTarget<EventDragData>(
      onWillAcceptWithDetails: (details) {
        // 接受所有行程拖曳
        return true;
      },
      onAcceptWithDetails: (details) {
        // 行程被放置到此日期
        if (onEventDrop != null) {
          onEventDrop!(details.data.event, details.data.sourceDate, day);
        }
      },
      builder: (context, candidateData, rejectedData) {
        // 當有行程拖曳到此日期時高亮顯示
        final isHovering = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: () => onDaySelected(day),
          child: Container(
            margin: const EdgeInsets.all(1),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: isHovering
                  ? Colors.blue.withOpacity(0.2)
                  : containerBackgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: isHovering
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期數字區域（含農曆）
            SizedBox(
              height: totalDateHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 西曆日期
                  isToday
                      ? Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            // 國定假日或傳統節日日期數字顯示紅色
                            color: hasNationalOrTraditionalHoliday && !isOutside
                                ? Colors.red
                                : textColor,
                          ),
                        ),
                  // 農曆日期
                  if (showLunar && lunarDayText != null)
                    Text(
                      lunarDayText,
                      style: TextStyle(
                        fontSize: 9,
                        color: isOutside ? Colors.grey[400] : Colors.grey[600],
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),

            // 事件區域（跨日事件由上層 Stack 繪製，這裡繪製節日和單日事件）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 計算可顯示的插槽數
                    final maxSlotsInView = ((constraints.maxHeight) / (eventItemHeight + eventItemGap)).floor();
                    final displaySlots = maxSlotsInView.clamp(0, maxDisplayRows);
                    
                    final eventWidgets = <Widget>[];
                    int slotIndexUsed = 0;
                    int displayedItems = 0;
                    
                    // 首先顯示節日（紅色背景，類似 TimeTree）
                    for (final holiday in holidays) {
                      if (slotIndexUsed >= displaySlots) break;
                      
                      // 找下一個可用的插槽
                      while (slotIndexUsed < displaySlots && !availableSlots.contains(slotIndexUsed)) {
                        slotIndexUsed++;
                      }
                      
                      if (slotIndexUsed < displaySlots) {
                        eventWidgets.add(
                          Positioned(
                            left: 0,
                            right: 0,
                            top: slotIndexUsed * (eventItemHeight + eventItemGap),
                            height: eventItemHeight - 1,
                            child: _HolidayEventItem(
                              holiday: holiday,
                              isOutside: isOutside,
                            ),
                          ),
                        );
                        slotIndexUsed++;
                        displayedItems++;
                      }
                    }
                    
                    // 然後顯示單日事件
                    int singleEventIndex = 0;
                    int displayedSingleEvents = 0;
                    
                    while (slotIndexUsed < displaySlots && singleEventIndex < singleDayEvents.length) {
                      // 找下一個可用的插槽
                      while (slotIndexUsed < displaySlots && !availableSlots.contains(slotIndexUsed)) {
                        slotIndexUsed++;
                      }
                      
                      if (slotIndexUsed < displaySlots) {
                        final event = singleDayEvents[singleEventIndex];
                        eventWidgets.add(
                          Positioned(
                            left: 0,
                            right: 0,
                            top: slotIndexUsed * (eventItemHeight + eventItemGap),
                            height: eventItemHeight - 1,
                            child: _DraggableSingleDayEventItem(
                              event: event,
                              isOutside: isOutside,
                              rowAllocation: rowAllocation,
                              sourceDate: day,
                              onDragStarted: onDragStarted,
                              onDragEnded: onDragEnded,
                            ),
                          ),
                        );
                        slotIndexUsed++;
                        singleEventIndex++;
                        displayedSingleEvents++;
                      }
                    }
                    
                    // 計算還有多少未顯示的事件（包括節日和行程）
                    final remainingHolidays = holidays.length - (displayedItems);
                    final remainingEvents = singleDayEvents.length - displayedSingleEvents + 
                        (remainingHolidays > 0 ? remainingHolidays : 0);
                    
                    return Stack(
                      children: [
                        ...eventWidgets,
                        // 如果有更多事件，顯示 +N
                        if (remainingEvents > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 10,
                            child: Container(
                              alignment: Alignment.center,
                              child: Text(
                                '+$remainingEvents',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isOutside ? Colors.grey[400] : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }
}

/// 節日事件項目元件
/// 
/// 以紅色背景顯示節日（類似 TimeTree）
class _HolidayEventItem extends StatelessWidget {
  final Holiday holiday;
  final bool isOutside;

  const _HolidayEventItem({
    required this.holiday,
    required this.isOutside,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        // 節日紅色
        color: isOutside 
            ? Colors.grey.withOpacity(0.3)
            : Colors.red.withOpacity(0.85),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: Text(
        holiday.name,
        style: TextStyle(
          fontSize: 10,
          color: isOutside ? Colors.grey[500] : Colors.white,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 可拖曳的單日事件項目元件
///
/// 使用 LongPressDraggable 包裝 _SingleDayEventItem
/// 長按後可以拖曳到其他日期
class _DraggableSingleDayEventItem extends StatelessWidget {
  final CalendarEvent event;
  final bool isOutside;
  final Map<String, int> rowAllocation;
  final DateTime sourceDate;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  const _DraggableSingleDayEventItem({
    required this.event,
    required this.isOutside,
    required this.rowAllocation,
    required this.sourceDate,
    this.onDragStarted,
    this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    final eventColor = CalendarUtils.getEventColor(event, rowAllocation);

    return LongPressDraggable<EventDragData>(
      data: EventDragData(event: event, sourceDate: sourceDate),
      delay: const Duration(milliseconds: 300),
      hapticFeedbackOnStart: true,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnded?.call(),
      // 拖曳時顯示的預覽
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: eventColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            event.title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      // 拖曳時原位置顯示的佔位符
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _SingleDayEventItem(
          event: event,
          isOutside: isOutside,
          rowAllocation: rowAllocation,
        ),
      ),
      child: _SingleDayEventItem(
        event: event,
        isOutside: isOutside,
        rowAllocation: rowAllocation,
      ),
    );
  }
}

/// 單日事件項目元件
///
/// 純顯示元件，不處理點擊事件
/// 點擊事件由父層 DayCell 的 GestureDetector 統一處理
/// 點擊後會開啟日期列表，而不是直接進入編輯
class _SingleDayEventItem extends StatelessWidget {
  final CalendarEvent event;
  final bool isOutside;
  final Map<String, int> rowAllocation;

  const _SingleDayEventItem({
    required this.event,
    required this.isOutside,
    required this.rowAllocation,
  });

  @override
  Widget build(BuildContext context) {
    final eventColor = CalendarUtils.getEventColor(event, rowAllocation);
    
    // 純顯示元件，不使用 GestureDetector
    // 點擊事件會穿透到父層的 DayCell
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isOutside 
            ? Colors.grey.withOpacity(0.3)
            : eventColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(2),
      ),
      // 文字置中顯示
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 重複行程標記
          if (event.isRecurring)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.repeat,
                size: 8,
                color: isOutside ? Colors.grey[500] : Colors.white,
              ),
            ),
          Flexible(
            child: Text(
              event.title,
              style: TextStyle(
                fontSize: 10,
                color: isOutside ? Colors.grey[500] : Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

