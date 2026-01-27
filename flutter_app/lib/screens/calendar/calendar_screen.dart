import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/event_model.dart';
import '../../models/holiday_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../utils/constants.dart';
import '../memo/memo_screen.dart';
import '../notification/notification_screen.dart';
import '../voice/voice_input_sheet.dart';
import 'event_detail_screen.dart';

// 引入拆分後的元件
import 'utils/calendar_utils.dart';
import 'widgets/calendar_header.dart';
import 'widgets/day_cell.dart';
import 'widgets/multi_day_event_bar.dart';
import 'widgets/day_events_bottom_sheet.dart';
import 'widgets/year_month_picker.dart';
import 'widgets/calendar_settings_sheet.dart';
import 'widgets/label_filter_sheet.dart';
import 'widgets/app_bottom_nav.dart';
import 'widgets/user_menu_sheet.dart';
import 'widgets/event_search_sheet.dart';

/// 行事曆主畫面
/// 
/// 重構後的主畫面，負責：
/// 1. 管理頁面狀態（選中日期、焦點日期、行事曆格式）
/// 2. 組合各個子元件
/// 3. 處理導航邏輯
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// 行事曆格式（月/雙週/週）
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  /// 選中的日期
  DateTime _selectedDay = DateTime.now();
  
  /// 焦點日期（決定顯示哪個月份/週）
  DateTime _focusedDay = DateTime.now();
  
  /// 跨日事件的行分配表
  Map<String, int> _multiDayEventRowAllocation = {};
  
  /// PageView 控制器（用於 Google Calendar 風格的滑動切換）
  /// 使用一個很大的初始頁面索引，讓用戶可以向前後滑動
  late PageController _pageController;
  
  /// 基準日期（用於計算頁面對應的日期）
  final DateTime _baseDate = DateTime.now();
  
  /// 初始頁面索引（設為大數值以允許向前滑動）
  static const int _initialPage = 1000;
  
  /// PageView 的 Key（用於在格式切換時強制重建）
  /// 每次切換格式時會更新這個值，強制 PageView 完全重建
  int _pageViewKey = 0;

  /// 底部導覽列當前選中的索引
  /// 0: 行事曆, 1: 通知, 2: 語音輸入, 3: 備忘錄, 4: 我的帳號
  int _selectedNavIndex = 0;

  /// 是否正在拖曳行程
  bool _isDragging = false;
  
  /// 取得用戶設定的週起始日
  /// 
  /// 監聯用戶資料中的 weekStartDay 設定
  /// 預設為 0（週日）
  int get _weekStartDay {
    final userDataAsync = ref.watch(currentUserDataProvider);
    return userDataAsync.when(
      data: (user) => user?.settings.weekStartDay ?? 0,
      loading: () => 0,
      error: (_, __) => 0,
    );
  }
  
  /// 取得節日顯示設定
  ///
  /// 總覽模式：預設開啟節日，使用台灣地區
  /// 非總覽模式：使用選中行事曆的設定
  bool get _showHolidays {
    final settings = ref.watch(effectiveHolidaySettingsProvider);
    return settings.showHolidays;
  }

  /// 取得節日地區列表
  ///
  /// 總覽模式：預設使用台灣地區
  /// 非總覽模式：使用選中行事曆的設定
  List<String> get _holidayRegions {
    final settings = ref.watch(effectiveHolidaySettingsProvider);
    return settings.holidayRegions;
  }

  /// 取得農曆顯示設定
  ///
  /// 總覽模式：預設關閉農曆
  /// 非總覽模式：使用選中行事曆的設定
  bool get _showLunar {
    return ref.watch(effectiveShowLunarProvider);
  }

  @override
  void initState() {
    super.initState();
    // 初始化 PageController，設定初始頁面
    _pageController = PageController(initialPage: _initialPage);

    // 預載入當前年份和下一年的節日資料
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadHolidays();
      _checkNetworkStatus();
    });
  }

  /// 檢查網路狀態
  ///
  /// 若為離線狀態，顯示提示訊息告知用戶無法使用語音建立功能
  Future<void> _checkNetworkStatus() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('您目前為離線狀態，將無法使用語音建立功能'),
          backgroundColor: Color(0xFF333333),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// 預載入節日資料
  ///
  /// 載入當前年份和下一年的節日，並更新 HolidayManager 快取
  Future<void> _preloadHolidays() async {
    final currentYear = DateTime.now().year;
    final holidayService = ref.read(holidayServiceProvider);

    // 預載入當年和下一年
    for (final year in [currentYear, currentYear + 1]) {
      try {
        final holidays = await holidayService.getHolidaysForYear(year);
        HolidayManager.updateCache(year, holidays);
      } catch (e) {
        debugPrint('預載入 $year 年節日失敗: $e');
      }
    }
  }

  @override
  void dispose() {
    // 釋放 PageController 資源
    _pageController.dispose();
    super.dispose();
  }
  
  /// 切換行事曆格式時重置 PageController
  ///
  /// 因為不同格式的頁面索引計算方式不同，
  /// 切換格式時需要重新建立 PageController 並跳轉到對應頁面
  ///
  /// 切換邏輯：
  /// - 使用當前選中的日期（_selectedDay）作為目標，確保切換後顯示該日期
  void _onFormatChanged(CalendarFormat newFormat) {
    if (newFormat == _calendarFormat) return;

    // 使用選中的日期作為目標，確保切換視圖後導航到該日期
    final targetDate = _selectedDay;

    // 使用新格式的 _initialPage 作為基準，計算目標日期對應的頁面索引
    final newPageIndex = _getPageIndexFromDateForNewFormat(targetDate, newFormat);

    // 計算新格式下的焦點日期（頁面的起始日期）
    final newFocusedDay = _getDateFromPageIndexForFormat(newPageIndex, newFormat);

    setState(() {
      _calendarFormat = newFormat;
      _focusedDay = newFocusedDay;
      // 更新 PageView 的 Key 以強制完全重建
      _pageViewKey++;
      // 重建 PageController 並跳轉到對應頁面
      _pageController.dispose();
      _pageController = PageController(initialPage: newPageIndex);
    });
  }
  
  /// 為新格式計算頁面索引（用於格式切換）
  /// 
  /// 這個方法確保頁面索引總是相對於 _initialPage 計算
  int _getPageIndexFromDateForNewFormat(DateTime date, CalendarFormat format) {
    switch (format) {
      case CalendarFormat.month:
        // 月視圖：計算與 baseDate 的月份差
        final monthDiff = (date.year - _baseDate.year) * 12 + (date.month - _baseDate.month);
        return _initialPage + monthDiff;
        
      case CalendarFormat.twoWeeks:
      case CalendarFormat.week:
        // 週視圖：計算與 baseDate 所在週的週數差
        final baseWeekStart = _getWeekStartForDate(_baseDate);
        final targetWeekStart = _getWeekStartForDate(date);
        final daysDiff = targetWeekStart.difference(baseWeekStart).inDays;
        final weeksDiff = (daysDiff / 7).floor();
        
        if (format == CalendarFormat.twoWeeks) {
          // 雙週視圖：每2週一頁
          return _initialPage + (weeksDiff / 2).floor();
        } else {
          // 週視圖：每1週一頁
          return _initialPage + weeksDiff;
        }
    }
  }
  
  /// 為指定格式計算頁面對應的日期
  /// 
  /// 這是 _getDateFromPageIndex 的獨立版本，不依賴當前 _calendarFormat
  DateTime _getDateFromPageIndexForFormat(int pageIndex, CalendarFormat format) {
    final offset = pageIndex - _initialPage;
    
    switch (format) {
      case CalendarFormat.month:
        return DateTime(_baseDate.year, _baseDate.month + offset, 1);
        
      case CalendarFormat.twoWeeks:
        final baseWeekStart = _getWeekStartForDate(_baseDate);
        return baseWeekStart.add(Duration(days: offset * 14));
        
      case CalendarFormat.week:
        final baseWeekStart = _getWeekStartForDate(_baseDate);
        return baseWeekStart.add(Duration(days: offset * 7));
    }
  }
  
  /// 取得指定日期所在週的起始日（不依賴 _weekStartDay getter）
  /// 
  /// 用於格式切換時的計算，避免在計算過程中觸發 ref.watch
  DateTime _getWeekStartForDate(DateTime date) {
    final weekday = date.weekday % 7;
    final weekStartDay = _weekStartDay;
    final daysToSubtract = (weekday - weekStartDay + 7) % 7;
    return DateTime(date.year, date.month, date.day - daysToSubtract);
  }

  /// 根據當前選中的導覽項目建立對應的 AppBar
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    dynamic selectedCalendar,
    bool isOverviewMode,
  ) {
    // 根據當前頁面顯示不同的 AppBar
    switch (_selectedNavIndex) {
      case 1: // 通知頁面
        return AppBar(
          title: const Text('通知'),
          centerTitle: false,
        );
      case 3: // 備忘錄頁面
        return AppBar(
          title: const Text('備忘錄'),
          centerTitle: false,
        );
      default: // 行事曆頁面
        return AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 總覽模式時隱藏圓點色塊
              if (!isOverviewMode && selectedCalendar != null)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: selectedCalendar.color,
                    shape: BoxShape.circle,
                  ),
                ),
              // 總覽模式時顯示「總覽」，否則顯示行事曆名稱
              Text(isOverviewMode ? '總覽' : (selectedCalendar?.name ?? '我的行事曆')),
            ],
          ),
          centerTitle: false,
          actions: [
            // 篩選標籤按鈕（非總覽模式時顯示）
            if (!isOverviewMode)
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: '篩選標籤',
                onPressed: () => LabelFilterSheet.show(context),
              ),
            // 新增行程按鈕
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新增行程',
              onPressed: () => _navigateToEventDetail(context, null),
            ),
            // 根據模式顯示不同按鈕
            if (isOverviewMode)
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: '搜尋行程',
                onPressed: () => EventSearchSheet.show(context),
              )
            else
              IconButton(
                icon: const Icon(Icons.space_dashboard),
                tooltip: '行事曆設定',
                onPressed: () => CalendarSettingsSheet.show(context),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 取得所有行程
    final eventsAsync = ref.watch(eventsProvider);
    // 取得當前選擇的行事曆
    final selectedCalendar = ref.watch(selectedCalendarProvider);
    // 取得總覽模式狀態
    final isOverviewMode = ref.watch(isOverviewModeProvider);

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: _buildAppBar(context, selectedCalendar, isOverviewMode),

          body: IndexedStack(
            index: _selectedNavIndex == 3 ? 2 : (_selectedNavIndex == 1 ? 1 : 0),
            children: [
              // 索引 0: 行事曆頁面
              Column(
                children: [
                  Expanded(
                    child: _buildCalendar(eventsAsync),
                  ),
                ],
              ),
              // 索引 1: 通知頁面
              const NotificationScreen(embedded: true),
              // 索引 2: 備忘錄頁面
              const MemoScreen(embedded: true),
            ],
          ),

          // 底部導航欄
          bottomNavigationBar: AppBottomNav(
            currentIndex: _selectedNavIndex,
            onItemTap: (index) => _handleBottomNavTap(context, index),
          ),
        ),
        // 拖曳時顯示的垃圾桶（覆蓋在導航列麥克風位置）
        if (_isDragging)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 8,
            left: 0,
            right: 0,
            child: Center(child: _buildDeleteDropZone()),
          ),
      ],
    );
  }

  /// 建立行事曆元件
  Widget _buildCalendar(AsyncValue<List<CalendarEvent>> eventsAsyncValue) {
    return Container(
      margin: const EdgeInsets.all(kPaddingSmall),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: Column(
        children: [
          // 月份/週標題區域
          CalendarHeader(
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            onPreviousMonth: _goToPreviousPage,
            onNextMonth: _goToNextPage,
            onFormatChanged: _onFormatChanged,
            onTitleTap: () => _showYearMonthPicker(context),
            weekStartDay: _weekStartDay,
          ),
          
          // 星期列標題（根據用戶設定的週起始日動態調整）
          DaysOfWeekHeader(weekStartDay: _weekStartDay),
          
          // 日期 Grid
          Expanded(
            child: _buildDateGrid(eventsAsyncValue),
          ),
        ],
      ),
    );
  }


  /// 建立日期 Grid（使用 PageView 實現 Google Calendar 風格的滑動切換）
  /// 
  /// 根據行事曆格式決定滑動單位：
  /// - 月視圖：滑一頁 = 一個月
  /// - 雙週視圖：滑一頁 = 兩週
  /// - 週視圖：滑一頁 = 一週
  Widget _buildDateGrid(AsyncValue<List<CalendarEvent>> eventsAsync) {
    final allEvents = eventsAsync.when(
      data: (events) => events,
      loading: () => <CalendarEvent>[],
      error: (_, __) => <CalendarEvent>[],
    );
    
    // 為跨日事件分配行索引
    _multiDayEventRowAllocation = CalendarUtils.allocateMultiDayEventRows(allEvents);
    
    return PageView.builder(
      // 使用 Key 在格式切換時強制 PageView 完全重建
      // 這確保 PageController 的狀態與 PageView 完全同步
      key: ValueKey('pageview_$_pageViewKey'),
      controller: _pageController,
      // 當頁面切換完成時更新 focusedDay
      onPageChanged: (pageIndex) {
        setState(() {
          // 根據當前格式計算新的焦點日期
          final newDate = _getDateFromPageIndexForFormat(pageIndex, _calendarFormat);
          _focusedDay = newDate;
        });
      },
      // 無限滑動（使用大範圍的頁面索引）
      itemBuilder: (context, pageIndex) {
        // 根據視圖格式取得要顯示的週
        final displayWeeks = _getWeeksForPage(pageIndex, _calendarFormat);
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final rowHeight = constraints.maxHeight / displayWeeks.length;
            
            return Column(
              key: ValueKey('${_calendarFormat}_$pageIndex'),
              children: displayWeeks.map((week) {
                return SizedBox(
                  height: rowHeight,
                  child: _buildWeekRow(week, allEvents, rowHeight),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
  
  /// 根據頁面索引和視圖格式取得要顯示的週列表
  /// 
  /// - 月視圖：返回整個月的所有週
  /// - 雙週視圖：返回 2 週
  /// - 週視圖：返回 1 週
  List<List<DateTime>> _getWeeksForPage(int pageIndex, CalendarFormat format) {
    final pageStartDate = _getDateFromPageIndexForFormat(pageIndex, format);
    
    switch (format) {
      case CalendarFormat.month:
        // 月視圖：取得該月的所有週（使用用戶設定的週起始日）
        return CalendarUtils.getWeeksInMonth(pageStartDate, weekStartDay: _weekStartDay);
        
      case CalendarFormat.twoWeeks:
        // 雙週視圖：取得連續 2 週
        return _getConsecutiveWeeks(pageStartDate, 2);
        
      case CalendarFormat.week:
        // 週視圖：取得 1 週
        return _getConsecutiveWeeks(pageStartDate, 1);
    }
  }
  
  /// 取得從指定日期開始的連續若干週
  /// 
  /// [startDate] 應該是一週的起始日（週日）
  /// [weekCount] 要取得的週數
  List<List<DateTime>> _getConsecutiveWeeks(DateTime startDate, int weekCount) {
    final List<List<DateTime>> weeks = [];
    DateTime currentDay = startDate;
    
    for (int w = 0; w < weekCount; w++) {
      final List<DateTime> week = [];
      for (int d = 0; d < 7; d++) {
        week.add(currentDay);
        currentDay = currentDay.add(const Duration(days: 1));
      }
      weeks.add(week);
    }
    
    return weeks;
  }


  /// 建立單週行（使用 Stack 支援跨日事件橫條）
  Widget _buildWeekRow(
    List<DateTime> week, 
    List<CalendarEvent> allEvents,
    double rowHeight,
  ) {
    final multiDayEventsInWeek = CalendarUtils.getMultiDayEventsForWeek(week, allEvents);
    
    // 計算最大行索引
    int maxRowIndex = -1;
    for (final event in multiDayEventsInWeek) {
      final rowIndex = _multiDayEventRowAllocation[event.id] ?? 0;
      if (rowIndex > maxRowIndex) {
        maxRowIndex = rowIndex;
      }
    }
    final displayMultiDayRows = (maxRowIndex + 1).clamp(0, 4);
    
    // 建立每日單日事件 Map
    final singleDayEventsMap = <DateTime, List<CalendarEvent>>{};
    for (final day in week) {
      final dayKey = DateTime(day.year, day.month, day.day);
      singleDayEventsMap[dayKey] = allEvents
          .where((e) => !e.isMultiDay() && e.isOnDate(day))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        
        return Stack(
          children: [
            // 底層：7 個日期單元格
            Row(
              children: week.map((day) {
                final dayKey = DateTime(day.year, day.month, day.day);
                final singleDayEvents = singleDayEventsMap[dayKey] ?? [];
                final occupiedRows = CalendarUtils.getOccupiedRowsForDate(
                  day, allEvents, _multiDayEventRowAllocation);
                
                return Expanded(
                  child: DayCell(
                    day: day,
                    singleDayEvents: singleDayEvents,
                    allEvents: allEvents,
                    occupiedRows: occupiedRows,
                    totalMultiDayRows: displayMultiDayRows,
                    focusedMonth: _focusedDay,
                    selectedDay: _selectedDay,
                    rowAllocation: _multiDayEventRowAllocation,
                    calendarFormat: _calendarFormat,
                    showHolidays: _showHolidays,
                    holidayRegions: _holidayRegions,
                    showLunar: _showLunar,
                    onDaySelected: (selectedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        if (selectedDay.month != _focusedDay.month) {
                          _focusedDay = DateTime(selectedDay.year, selectedDay.month, 1);
                        }
                      });
                      // 顯示該日行程列表（使用 Provider 監聽事件變化）
                      DayEventsBottomSheet.show(
                        context: context,
                        selectedDay: selectedDay,
                        onAddEvent: () => _navigateToEventDetail(context, null),
                        onEventTap: (event) => _navigateToEventDetail(context, event),
                      );
                    },
                    onEventTap: (event) => _navigateToEventDetail(context, event),
                    onEventDrop: (event, sourceDate, targetDate) {
                      _showMoveOrCopyDialog(context, event, sourceDate, targetDate);
                    },
                    onDragStarted: () {
                      setState(() => _isDragging = true);
                    },
                    onDragEnded: () {
                      setState(() => _isDragging = false);
                    },
                  ),
                );
              }).toList(),
            ),
            
            // 上層：跨日事件橫條
            // 點擊跨日事件時，會根據點擊位置開啟對應日期的列表
            for (final event in multiDayEventsInWeek)
              if ((_multiDayEventRowAllocation[event.id] ?? 0) < 4)
                MultiDayEventBar(
                  week: week,
                  event: event,
                  cellWidth: cellWidth,
                  dateNumberHeight: _showLunar
                      ? DayCell.dateNumberHeight + DayCell.lunarTextHeight
                      : DayCell.dateNumberHeight,
                  eventItemHeight: DayCell.eventItemHeight,
                  eventItemGap: DayCell.eventItemGap,
                  rowAllocation: _multiDayEventRowAllocation,
                  // 點擊跨日事件時開啟對應日期的列表
                  onDaySelected: (selectedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      if (selectedDay.month != _focusedDay.month) {
                        _focusedDay = DateTime(selectedDay.year, selectedDay.month, 1);
                      }
                    });
                    // 顯示該日行程列表（使用 Provider 監聯事件變化）
                    DayEventsBottomSheet.show(
                      context: context,
                      selectedDay: selectedDay,
                      onAddEvent: () => _navigateToEventDetail(context, null),
                      onEventTap: (event) => _navigateToEventDetail(context, event),
                    );
                  },
                  onDragStarted: () {
                    setState(() => _isDragging = true);
                  },
                  onDragEnded: () {
                    setState(() => _isDragging = false);
                  },
                ),
          ],
        );
      },
    );
  }

  // ==================== 導航方法 ====================

  /// 切換到上一頁（使用 PageController 動畫切換）
  /// 
  /// 根據視圖格式：
  /// - 月視圖：切換到上個月
  /// - 雙週視圖：切換到前兩週
  /// - 週視圖：切換到上一週
  void _goToPreviousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 切換到下一頁（使用 PageController 動畫切換）
  /// 
  /// 根據視圖格式：
  /// - 月視圖：切換到下個月
  /// - 雙週視圖：切換到後兩週
  /// - 週視圖：切換到下一週
  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 跳轉到今天（使用 PageController 動畫跳轉）
  void _jumpToToday() {
    final today = DateTime.now();
    final targetPage = _getPageIndexFromDateForNewFormat(today, _calendarFormat);
    
    // 使用動畫跳轉到今天所在的頁面
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });
  }

  /// 顯示年月選擇器
  void _showYearMonthPicker(BuildContext context) {
    YearMonthPicker.show(
      context: context,
      currentDate: _focusedDay,
      onDateSelected: (date) {
        // 使用 PageController 跳轉到選擇的日期
        final targetPage = _getPageIndexFromDateForNewFormat(date, _calendarFormat);
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() {
          _selectedDay = date;
          _focusedDay = date;
        });
      },
    );
  }

  /// 處理底部導航欄點擊
  void _handleBottomNavTap(BuildContext context, int index) {
    switch (index) {
      case 0: // 行事曆
        if (_selectedNavIndex == 0) {
          // 如果已經在行事曆頁面，點擊則跳到今天
          _jumpToToday();
        } else {
          // 切換到行事曆頁面
          setState(() {
            _selectedNavIndex = 0;
          });
        }
        break;
      case 1: // 通知（切換頁面，不導航）
        setState(() {
          _selectedNavIndex = 1;
        });
        // 標記通知為已讀，清除紅點
        ref.read(notificationLastViewedProvider.notifier).state = DateTime.now();
        break;
      case 2: // 語音輸入（顯示底部面板）
        _showVoiceInputSheet(context);
        break;
      case 3: // 備忘錄（切換頁面，不導航）
        setState(() {
          _selectedNavIndex = 3;
        });
        break;
      case 4: // 我的帳號
        _showUserMenu(context);
        break;
    }
  }

  /// 顯示語音輸入底部面板
  void _showVoiceInputSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const VoiceInputSheet(),
    );
  }

  /// 導航到行程詳情畫面
  ///
  /// 使用 BottomSheet 方式，支援下滑關閉
  /// PopScope 會處理有未儲存變更時的情況
  Future<void> _navigateToEventDetail(BuildContext context, CalendarEvent? event) async {
    final isViewMode = event != null; // 點擊現有行程進入檢視模式，新增行程進入編輯模式

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允許佔滿螢幕
      backgroundColor: Colors.transparent,
      isDismissible: true, // 允許點擊外部關閉（PopScope 會攔截有變更的情況）
      enableDrag: true, // 允許下滑關閉（PopScope 會攔截有變更的情況）
      builder: (context) => EventDetailScreen(
        event: event,
        defaultDate: _selectedDay,
        isViewMode: isViewMode,
      ),
    );
  }

  /// 顯示用戶選單
  ///
  /// UserMenuSheet 內部會自動監聽用戶資料，不需要從外部傳入
  void _showUserMenu(BuildContext context) {
    UserMenuSheet.show(
      context: context,
      onSettings: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定功能開發中')),
        );
      },
      onSignOut: () {
        ref.read(authControllerProvider.notifier).signOut();
      },
    );
  }

  /// 顯示移動/複製選單
  ///
  /// 當行程被拖曳到新日期時顯示此選單
  /// [event] 被拖曳的行程
  /// [sourceDate] 來源日期
  /// [targetDate] 目標日期
  void _showMoveOrCopyDialog(
    BuildContext context,
    CalendarEvent event,
    DateTime sourceDate,
    DateTime targetDate,
  ) {
    // 如果目標日期與來源日期相同，不做任何操作
    final sourceDateOnly = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
    final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (sourceDateOnly == targetDateOnly) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 標題
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '「${event.title}」',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              // 移動選項
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('移動'),
                onTap: () {
                  Navigator.pop(context);
                  _moveEventToDate(event, sourceDate, targetDate);
                },
              ),
              // 複製選項
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('複製'),
                onTap: () {
                  Navigator.pop(context);
                  _copyEventToDate(event, targetDate);
                },
              ),
              const Divider(height: 1),
              // 取消選項
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 移動行程到新日期
  ///
  /// 保持行程時長不變，只更新開始和結束日期
  Future<void> _moveEventToDate(
    CalendarEvent event,
    DateTime sourceDate,
    DateTime targetDate,
  ) async {
    // 計算日期差異
    final sourceDateOnly = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
    final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final daysDiff = targetDateOnly.difference(sourceDateOnly).inDays;

    // 計算新的開始和結束時間
    final newStartTime = event.startTime.add(Duration(days: daysDiff));
    final newEndTime = event.endTime.add(Duration(days: daysDiff));

    // 建立更新後的行程
    final updatedEvent = event.copyWith(
      startTime: newStartTime,
      endTime: newEndTime,
      updatedAt: DateTime.now(),
    );

    // 更新行程
    final success = await ref
        .read(eventControllerProvider.notifier)
        .updateEvent(event.id, updatedEvent);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '行程已移動' : '移動失敗'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// 複製行程到新日期
  ///
  /// 建立新行程，保持時長和其他屬性
  Future<void> _copyEventToDate(CalendarEvent event, DateTime targetDate) async {
    // 計算日期差異
    final sourceDateOnly = DateTime(
      event.startTime.year,
      event.startTime.month,
      event.startTime.day,
    );
    final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final daysDiff = targetDateOnly.difference(sourceDateOnly).inDays;

    // 計算新的開始和結束時間
    final newStartTime = event.startTime.add(Duration(days: daysDiff));
    final newEndTime = event.endTime.add(Duration(days: daysDiff));

    // 建立新行程（複製所有屬性，但使用新的時間和 ID）
    final newEvent = CalendarEvent(
      id: '', // 由 Firestore 自動產生
      userId: event.userId,
      calendarId: event.calendarId,
      title: event.title,
      startTime: newStartTime,
      endTime: newEndTime,
      location: event.location,
      description: event.description,
      participants: event.participants,
      reminderMinutes: event.reminderMinutes,
      isAllDay: event.isAllDay,
      labelId: event.labelId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: EventMetadata(createdBy: 'manual'),
    );

    // 建立新行程
    final eventId = await ref
        .read(eventControllerProvider.notifier)
        .createEvent(newEvent);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eventId != null ? '行程已複製' : '複製失敗'),
          backgroundColor: eventId != null ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// 建立刪除區域（垃圾桶圖示）
  ///
  /// 拖曳行程時顯示在底部，放開可刪除行程
  Widget _buildDeleteDropZone() {
    return DragTarget<EventDragData>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _deleteEventByDrag(details.data.event);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: isHovering ? Colors.red.shade700 : Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.delete_outline,
            size: 30,
            color: Colors.white,
          ),
        );
      },
    );
  }

  /// 透過拖曳刪除行程
  Future<void> _deleteEventByDrag(CalendarEvent event) async {
    // 先結束拖曳狀態
    setState(() => _isDragging = false);

    // 顯示確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${event.title}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(eventControllerProvider.notifier)
          .deleteEvent(event.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '行程已刪除' : '刪除失敗'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
