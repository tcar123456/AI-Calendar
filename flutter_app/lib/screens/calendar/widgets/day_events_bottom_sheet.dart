import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/event_model.dart';
import '../../../models/event_label_model.dart';
import '../../../models/holiday_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../utils/constants.dart';

/// 行程檢視模式
/// 
/// - card: 卡片模式（類似 TimeTree）
/// - timeline: 時間軸模式（類似 Apple Calendar）
enum EventViewMode {
  card,
  timeline,
}

/// 顯示該日行程列表的底部面板
/// 
/// 功能說明：
/// 1. 初始顯示半屏（50%），用戶可以往上滑展開成全屏
/// 2. 點擊面板外部區域可以收起面板
/// 3. 使用 snap 功能，讓滑動時自動吸附到半屏或全屏位置
/// 4. 標題區域和內容區域都可以拖動來展開/收起面板
/// 5. 支援卡片模式和時間軸模式切換
/// 6. 使用 Riverpod 監聽事件變化，自動刷新資料
class DayEventsBottomSheet extends ConsumerStatefulWidget {
  /// 選中的日期
  final DateTime selectedDay;
  
  /// 點擊新增行程的回調（返回 Future，等待導航完成）
  final Future<void> Function() onAddEvent;
  
  /// 點擊行程的回調（返回 Future，等待導航完成）
  final Future<void> Function(CalendarEvent) onEventTap;

  const DayEventsBottomSheet({
    super.key,
    required this.selectedDay,
    required this.onAddEvent,
    required this.onEventTap,
  });

  /// 顯示底部面板的靜態方法
  /// 
  /// 點擊行程時不會關閉底部面板，而是等待詳情頁面返回後自動刷新資料
  static void show({
    required BuildContext context,
    required DateTime selectedDay,
    required Future<void> Function() onAddEvent,
    required Future<void> Function(CalendarEvent) onEventTap,
  }) {
    showModalBottomSheet(
      context: context,
      // 允許控制面板高度
      isScrollControlled: true,
      // 背景透明，讓圓角效果可見
      backgroundColor: Colors.transparent,
      // 點擊外部區域可以收起面板
      isDismissible: true,
      // 允許用戶通過滑動關閉面板
      enableDrag: true,
      // 設置外部遮罩顏色（半透明黑色，點擊此區域可關閉）
      barrierColor: Colors.black.withOpacity(0.5),
      // 設定進場和退場動畫曲線（與 snap 動畫一致）
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeInOut,
      ),
      builder: (sheetContext) => GestureDetector(
        // 防止點擊面板內部時關閉（只有點擊外部遮罩才會關閉）
        onTap: () {},
        child: DayEventsBottomSheet(
          selectedDay: selectedDay,
          onAddEvent: onAddEvent,
          onEventTap: onEventTap,
        ),
      ),
    );
  }

  @override
  ConsumerState<DayEventsBottomSheet> createState() => _DayEventsBottomSheetState();
}

class _DayEventsBottomSheetState extends ConsumerState<DayEventsBottomSheet> {
  /// 當前檢視模式（預設為卡片模式）
  EventViewMode _viewMode = EventViewMode.card;

  @override
  Widget build(BuildContext context) {
    // 監聽事件 Provider，當資料變化時自動重建
    final eventsAsync = ref.watch(eventsProvider);
    
    // 監聽用戶設定以取得節日相關設定
    final userDataAsync = ref.watch(currentUserDataProvider);
    final showHolidays = userDataAsync.when(
      data: (user) => user?.settings.showHolidays ?? true,
      loading: () => true,
      error: (_, __) => true,
    );
    final holidayRegions = userDataAsync.when(
      data: (user) => user?.settings.holidayRegions ?? ['taiwan'],
      loading: () => ['taiwan'],
      error: (_, __) => ['taiwan'],
    );
    
    // 取得當日節日列表
    final holidays = showHolidays 
        ? HolidayManager.getHolidaysForDate(widget.selectedDay, holidayRegions)
        : <Holiday>[];
    
    // 取得事件列表
    final allEvents = eventsAsync.when(
      data: (events) => events,
      loading: () => <CalendarEvent>[],
      error: (_, __) => <CalendarEvent>[],
    );
    
    // 篩選選中日期的行程並按時間排序
    final selectedDayEvents = allEvents
        .where((e) => e.isOnDate(widget.selectedDay))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return DraggableScrollableSheet(
      // 初始顯示半屏（50%）
      initialChildSize: 0.5,
      // 最小尺寸（關閉閾值）
      minChildSize: 0.25,
      // 最大尺寸：全屏（1.0）
      maxChildSize: 1.0,
      // 關鍵：設為 false 才能讓點擊外部關閉生效
      expand: false,
      // 啟用 snap 功能：滑動時自動吸附到指定位置
      snap: true,
      // 定義吸附點：半屏(0.5) 和 全屏(1.0)
      snapSizes: const [0.5, 1.0],
      // 設定 snap 動畫時間
      snapAnimationDuration: const Duration(milliseconds: 100),
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          // 使用 CustomScrollView 讓整個內容區域（包括標題）都可以拖動
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // 拖動指示器和標題區域（可拖動）
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // 拖動指示器
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    
                    // 標題區域（含新增按鈕和切換按鈕）
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kPaddingLarge,
                        vertical: kPaddingMedium / 2,
                      ),
                      child: Row(
                        children: [
                          // 日曆圖標
                          const Icon(
                            Icons.event,
                            color: Color(kPrimaryColorValue),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          // 日期標題
                          Expanded(
                            child: Text(
                              DateFormat('yyyy年MM月dd日 EEEE', 'zh_TW').format(widget.selectedDay),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // 新增行程按鈕
                          _buildAddEventButton(),
                          const SizedBox(width: 8),
                          // 檢視模式切換按鈕
                          _buildViewModeToggle(),
                        ],
                      ),
                    ),
                    
                    const Divider(height: 1),
                    
                    // 節日顯示區域（在分隔線下方）
                    if (holidays.isNotEmpty)
                      _buildHolidaySection(holidays),
                  ],
                ),
              ),
              
              // 行程列表（根據模式切換）
              if (selectedDayEvents.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context),
                )
              else
                _viewMode == EventViewMode.card
                    ? _buildCardView(selectedDayEvents)
                    : _buildTimelineView(selectedDayEvents),
            ],
          ),
        );
      },
    );
  }
  
  /// 建立節日顯示區域
  /// 
  /// 在分隔線下方顯示深紅色圓角長方形的節日標籤
  /// 複數節日會平分寬度並排顯示
  Widget _buildHolidaySection(List<Holiday> holidays) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kPaddingLarge,
        vertical: kPaddingSmall - 2, // 稍微減少垂直間距
      ),
      child: Row(
        children: holidays.asMap().entries.map((entry) {
          final index = entry.key;
          final holiday = entry.value;
          
          return Expanded(
            child: Padding(
              // 節日之間的間距
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == holidays.length - 1 ? 0 : 4,
              ),
              child: Container(
                // 減少高度（原本 vertical: 6，現在 vertical: 4.5，約減少 1/4）
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  // 節日紅色
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  holiday.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    // 文字改為粗體
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 建立新增行程按鈕
  Widget _buildAddEventButton() {
    return Tooltip(
      message: '新增行程',
      child: InkWell(
        onTap: () => widget.onAddEvent(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(kPrimaryColorValue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.add,
            size: 22,
            color: Color(kPrimaryColorValue),
          ),
        ),
      ),
    );
  }

  /// 建立檢視模式切換按鈕（單一按鈕，點擊切換模式和圖標）
  Widget _buildViewModeToggle() {
    // 根據當前模式決定顯示的圖標和提示
    final isCardMode = _viewMode == EventViewMode.card;
    final icon = isCardMode ? Icons.view_agenda_outlined : Icons.schedule_outlined;
    final tooltip = isCardMode ? '切換至時間軸模式' : '切換至卡片模式';

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() {
            // 點擊切換模式
            _viewMode = isCardMode ? EventViewMode.timeline : EventViewMode.card;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 22,
              color: Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  /// 建立卡片模式視圖（類似 TimeTree）
  Widget _buildCardView(List<CalendarEvent> events) {
    return SliverPadding(
      padding: const EdgeInsets.all(kPaddingLarge),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _CardModeEventItem(
              event: events[index],
              selectedDay: widget.selectedDay,
              isFirst: index == 0,
              isLast: index == events.length - 1,
              onTap: () => widget.onEventTap(events[index]),
            );
          },
          childCount: events.length,
        ),
      ),
    );
  }

  /// 建立時間軸模式視圖（類似 Apple Calendar）
  Widget _buildTimelineView(List<CalendarEvent> events) {
    return SliverToBoxAdapter(
      child: _TimelineView(
        events: events,
        selectedDay: widget.selectedDay,
        onEventTap: widget.onEventTap,
      ),
    );
  }

  /// 建立空狀態（只顯示提示文字，新增按鈕在標題列）
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 56,
            color: Colors.grey[350],
          ),
          const SizedBox(height: 12),
          Text(
            '這天沒有安排行程',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片模式行程項目（類似 TimeTree 風格）
/// 
/// 簡潔卡片設計：左側顯示標籤顏色條，右側顯示行程資訊
class _CardModeEventItem extends StatelessWidget {
  final CalendarEvent event;
  final DateTime selectedDay;
  final bool isFirst;
  final bool isLast;
  /// 點擊行程的回調（返回 Future，等待導航完成後刷新）
  final Future<void> Function() onTap;

  const _CardModeEventItem({
    required this.event,
    required this.selectedDay,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 取得標籤顏色
    final labelColor = _getLabelColor();
    
    // 判斷跨日狀態
    final isMultiDayMiddle = event.isMultiDay() && event.isMiddleDate(selectedDay);
    final isMultiDayEnd = event.isMultiDay() && event.isEndDate(selectedDay);
    final isMultiDayStart = event.isMultiDay() && event.isStartDate(selectedDay);

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : 6,
        bottom: isLast ? 0 : 6,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 左側顏色條
                Container(
                  width: 5,
                  height: 70,
                  decoration: BoxDecoration(
                    color: labelColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                  ),
                ),
                
                // 右側內容區
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // 時間區域（顯示時間範圍）
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _buildTimeDisplay(
                            isMultiDayMiddle: isMultiDayMiddle,
                            isMultiDayEnd: isMultiDayEnd,
                            isMultiDayStart: isMultiDayStart,
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // 行程資訊
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 標題
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[850],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // 語音建立標記
                                  if (event.metadata.createdBy == 'voice')
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.mic,
                                        size: 14,
                                        color: labelColor,
                                      ),
                                    ),
                                ],
                              ),
                              
                              // 地點或備註（二選一顯示）
                              if (event.location != null && event.location!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        event.location!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (event.description != null && event.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  event.description!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // 右側箭頭
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 取得標籤顏色
  Color _getLabelColor() {
    // 優先使用標籤顏色
    if (event.labelId != null) {
      final label = DefaultEventLabels.getById(event.labelId!);
      if (label != null) {
        return label.color;
      }
    }
    // 預設使用主色
    return const Color(kPrimaryColorValue);
  }

  /// 建立時間顯示（時間範圍）
  List<Widget> _buildTimeDisplay({
    required bool isMultiDayMiddle,
    required bool isMultiDayEnd,
    required bool isMultiDayStart,
  }) {
    final timeStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey[600],
    );
    
    // 全天或跨日中間日期
    if (isMultiDayMiddle || event.isAllDay) {
      return [
        Text('全天', style: timeStyle),
      ];
    }
    
    // 跨日行程結束日期
    if (isMultiDayEnd) {
      return [
        Text('00:00', style: timeStyle),
        Text(
          DateFormat('HH:mm').format(event.endTime),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ];
    }
    
    // 跨日行程開始日期
    if (isMultiDayStart) {
      return [
        Text(DateFormat('HH:mm').format(event.startTime), style: timeStyle),
        Text(
          '23:59',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ];
    }
    
    // 一般行程：顯示開始和結束時間
    return [
      Text(DateFormat('HH:mm').format(event.startTime), style: timeStyle),
      Text(
        DateFormat('HH:mm').format(event.endTime),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ),
    ];
  }
}

/// 時間軸模式視圖（類似 Apple Calendar）
/// 
/// 以 24 小時時間軸形式顯示一天的行程
/// 支援重疊行程的橫向排列
class _TimelineView extends StatelessWidget {
  /// 該日的行程列表
  final List<CalendarEvent> events;
  
  /// 選中的日期
  final DateTime selectedDay;
  
  /// 點擊行程的回調（返回 Future，等待導航完成）
  final Future<void> Function(CalendarEvent) onEventTap;

  /// 每小時的高度（像素）
  static const double hourHeight = 60.0;
  
  /// 時間標籤寬度
  static const double timeColumnWidth = 55.0;
  
  /// 行程區域右側邊距
  static const double eventAreaRightPadding = 12.0;

  const _TimelineView({
    required this.events,
    required this.selectedDay,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    // 分離全天事件和時段事件
    final allDayEvents = events.where((e) => 
        e.isAllDay || (e.isMultiDay() && e.isMiddleDate(selectedDay))).toList();
    final timedEvents = events.where((e) => 
        !e.isAllDay && !(e.isMultiDay() && e.isMiddleDate(selectedDay))).toList();
    
    // 計算重疊行程的佈局資訊
    final layoutInfo = _calculateOverlapLayout(timedEvents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 全天行程區域
        if (allDayEvents.isNotEmpty) ...[
          _buildAllDaySection(allDayEvents),
          const Divider(height: 1),
        ],
        
        // 24 小時時間軸
        SizedBox(
          height: hourHeight * 24,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 計算可用於行程的寬度
              final eventAreaWidth = constraints.maxWidth - timeColumnWidth - eventAreaRightPadding;
              
              return Stack(
                children: [
                  // 背景時間線
                  _buildTimeGrid(),
                  
                  // 當前時間指示線
                  if (_isToday()) _buildCurrentTimeIndicator(),
                  
                  // 行程區塊（使用計算好的佈局資訊）
                  ...timedEvents.map((event) => _buildEventBlock(
                    event,
                    layoutInfo[event.id]!,
                    eventAreaWidth,
                  )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 計算重疊行程的佈局資訊
  /// 
  /// 返回一個 Map，key 為行程 ID，value 為 (columnIndex, totalColumns)
  /// - columnIndex: 行程所在的列（從 0 開始）
  /// - totalColumns: 重疊組中的總列數
  Map<String, _EventLayoutInfo> _calculateOverlapLayout(List<CalendarEvent> timedEvents) {
    if (timedEvents.isEmpty) return {};
    
    // 按開始時間排序
    final sortedEvents = List<CalendarEvent>.from(timedEvents)
      ..sort((a, b) => _getEventStartMinutes(a).compareTo(_getEventStartMinutes(b)));
    
    // 結果 Map
    final layoutInfo = <String, _EventLayoutInfo>{};
    
    // 用於追蹤重疊群組
    final List<List<CalendarEvent>> overlapGroups = [];
    
    for (final event in sortedEvents) {
      final eventStart = _getEventStartMinutes(event);
      final eventEnd = _getEventEndMinutes(event);
      
      // 尋找可以加入的重疊群組
      bool addedToGroup = false;
      for (final group in overlapGroups) {
        // 檢查是否與群組中的任何行程重疊
        bool overlapsWithGroup = group.any((groupEvent) {
          final groupStart = _getEventStartMinutes(groupEvent);
          final groupEnd = _getEventEndMinutes(groupEvent);
          // 兩個時間段重疊的條件
          return eventStart < groupEnd && eventEnd > groupStart;
        });
        
        if (overlapsWithGroup) {
          group.add(event);
          addedToGroup = true;
          break;
        }
      }
      
      // 如果沒有找到重疊群組，建立新群組
      if (!addedToGroup) {
        overlapGroups.add([event]);
      }
    }
    
    // 合併有間接重疊的群組
    final mergedGroups = _mergeOverlapGroups(overlapGroups);
    
    // 為每個群組中的行程分配列
    for (final group in mergedGroups) {
      _assignColumnsToGroup(group, layoutInfo);
    }
    
    return layoutInfo;
  }
  
  /// 合併有間接重疊的群組
  List<List<CalendarEvent>> _mergeOverlapGroups(List<List<CalendarEvent>> groups) {
    if (groups.length <= 1) return groups;
    
    final mergedGroups = <List<CalendarEvent>>[];
    final visited = <int>{};
    
    for (int i = 0; i < groups.length; i++) {
      if (visited.contains(i)) continue;
      
      final mergedGroup = List<CalendarEvent>.from(groups[i]);
      visited.add(i);
      
      bool changed = true;
      while (changed) {
        changed = false;
        for (int j = 0; j < groups.length; j++) {
          if (visited.contains(j)) continue;
          
          // 檢查是否有重疊
          bool hasOverlap = false;
          for (final eventA in mergedGroup) {
            for (final eventB in groups[j]) {
              final startA = _getEventStartMinutes(eventA);
              final endA = _getEventEndMinutes(eventA);
              final startB = _getEventStartMinutes(eventB);
              final endB = _getEventEndMinutes(eventB);
              
              if (startA < endB && endA > startB) {
                hasOverlap = true;
                break;
              }
            }
            if (hasOverlap) break;
          }
          
          if (hasOverlap) {
            mergedGroup.addAll(groups[j]);
            visited.add(j);
            changed = true;
          }
        }
      }
      
      mergedGroups.add(mergedGroup);
    }
    
    return mergedGroups;
  }
  
  /// 為群組中的行程分配列（使用貪婪演算法）
  void _assignColumnsToGroup(List<CalendarEvent> group, Map<String, _EventLayoutInfo> layoutInfo) {
    if (group.isEmpty) return;
    
    // 按開始時間排序
    group.sort((a, b) => _getEventStartMinutes(a).compareTo(_getEventStartMinutes(b)));
    
    // 每列的結束時間追蹤
    final columnEndTimes = <int>[];
    
    for (final event in group) {
      final eventStart = _getEventStartMinutes(event);
      final eventEnd = _getEventEndMinutes(event);
      
      // 尋找可以放入的列（該列的前一個行程已結束）
      int assignedColumn = -1;
      for (int col = 0; col < columnEndTimes.length; col++) {
        if (columnEndTimes[col] <= eventStart) {
          assignedColumn = col;
          columnEndTimes[col] = eventEnd;
          break;
        }
      }
      
      // 如果沒有找到可用的列，新增一列
      if (assignedColumn == -1) {
        assignedColumn = columnEndTimes.length;
        columnEndTimes.add(eventEnd);
      }
      
      layoutInfo[event.id] = _EventLayoutInfo(
        columnIndex: assignedColumn,
        totalColumns: 0, // 稍後更新
      );
    }
    
    // 更新總列數
    final totalColumns = columnEndTimes.length;
    for (final event in group) {
      final info = layoutInfo[event.id]!;
      layoutInfo[event.id] = _EventLayoutInfo(
        columnIndex: info.columnIndex,
        totalColumns: totalColumns,
      );
    }
  }

  /// 判斷選中日期是否為今天
  bool _isToday() {
    final now = DateTime.now();
    return selectedDay.year == now.year &&
           selectedDay.month == now.month &&
           selectedDay.day == now.day;
  }

  /// 建立全天行程區域
  Widget _buildAllDaySection(List<CalendarEvent> allDayEvents) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kPaddingMedium, vertical: kPaddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: timeColumnWidth,
                child: Text(
                  '全天',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allDayEvents.map((event) => _buildAllDayEventChip(event)).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 建立全天行程標籤
  Widget _buildAllDayEventChip(CalendarEvent event) {
    final color = _getEventColor(event);
    
    return GestureDetector(
      onTap: () => onEventTap(event),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          event.title,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 建立時間格線
  Widget _buildTimeGrid() {
    return Column(
      children: List.generate(24, (hour) {
        return SizedBox(
          height: hourHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 時間標籤
              SizedBox(
                width: timeColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 0),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              // 分隔線
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// 建立當前時間指示線
  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final top = (minutes / 60) * hourHeight;

    return Positioned(
      top: top,
      left: timeColumnWidth - 6,
      right: 0,
      child: Row(
        children: [
          // 紅色圓點
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          // 紅色線
          Expanded(
            child: Container(
              height: 2,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  /// 建立行程區塊（支援重疊行程的橫向排列）
  Widget _buildEventBlock(
    CalendarEvent event,
    _EventLayoutInfo layoutInfo,
    double eventAreaWidth,
  ) {
    // 計算行程在時間軸上的位置和高度
    final startMinutes = _getEventStartMinutes(event);
    final endMinutes = _getEventEndMinutes(event);
    
    // 計算頂部位置和高度
    final top = (startMinutes / 60) * hourHeight;
    final height = ((endMinutes - startMinutes) / 60) * hourHeight;
    
    // 確保最小高度
    final displayHeight = height.clamp(30.0, double.infinity);
    
    // 計算橫向位置和寬度（根據重疊情況）
    final totalColumns = layoutInfo.totalColumns;
    final columnIndex = layoutInfo.columnIndex;
    
    // 每列寬度（考慮間隙）
    const columnGap = 2.0;
    final columnWidth = (eventAreaWidth - (totalColumns - 1) * columnGap) / totalColumns;
    
    // 計算 left 位置
    final left = timeColumnWidth + 4 + columnIndex * (columnWidth + columnGap);
    
    final color = _getEventColor(event);

    return Positioned(
      top: top,
      left: left,
      width: columnWidth,
      height: displayHeight,
      child: GestureDetector(
        onTap: () => onEventTap(event),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2, right: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: color,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 標題
              Text(
                event.title,
                style: TextStyle(
                  fontSize: totalColumns > 2 ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.9),
                ),
                maxLines: totalColumns > 2 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 時間（如果高度足夠且列數不太多）
              if (displayHeight > 45 && totalColumns <= 2)
                Text(
                  '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.7),
                  ),
                ),
              // 地點（如果高度足夠且有地點且列數為 1）
              if (displayHeight > 65 && event.location != null && totalColumns == 1)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 10, color: color.withOpacity(0.6)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 取得行程開始時間（分鐘）
  int _getEventStartMinutes(CalendarEvent event) {
    // 跨日行程的非開始日從 00:00 開始顯示
    if (event.isMultiDay() && !event.isStartDate(selectedDay)) {
      return 0;
    }
    return event.startTime.hour * 60 + event.startTime.minute;
  }

  /// 取得行程結束時間（分鐘）
  int _getEventEndMinutes(CalendarEvent event) {
    // 跨日行程的非結束日到 23:59 結束顯示
    if (event.isMultiDay() && !event.isEndDate(selectedDay)) {
      return 24 * 60 - 1;
    }
    return event.endTime.hour * 60 + event.endTime.minute;
  }

  /// 取得行程顏色（優先使用標籤顏色）
  Color _getEventColor(CalendarEvent event) {
    // 優先使用標籤顏色
    if (event.labelId != null) {
      final label = DefaultEventLabels.getById(event.labelId!);
      if (label != null) {
        return label.color;
      }
    }
    // 預設使用主色
    return const Color(kPrimaryColorValue);
  }
}

/// 行程佈局資訊
/// 
/// 用於記錄行程在重疊群組中的位置資訊
class _EventLayoutInfo {
  /// 行程所在的列索引（從 0 開始）
  final int columnIndex;
  
  /// 重疊群組中的總列數
  final int totalColumns;

  const _EventLayoutInfo({
    required this.columnIndex,
    required this.totalColumns,
  });
}
