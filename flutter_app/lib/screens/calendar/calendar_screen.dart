import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/draggable_mic_button.dart';
import '../voice/voice_input_screen.dart';
import 'event_detail_screen.dart';

/// 行事曆主畫面
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// 行事曆格式
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  /// 選中的日期
  DateTime _selectedDay = DateTime.now();
  
  /// 焦點日期
  DateTime _focusedDay = DateTime.now();
  
  /// 日曆檢視模式（true: 顯示事件標題, false: 只顯示標記點）
  bool _showEventTitles = false;

  @override
  Widget build(BuildContext context) {
    // 取得當前用戶資料
    final currentUserData = ref.watch(currentUserDataProvider);
    
    // 取得所有行程
    final eventsAsync = ref.watch(eventsProvider);

    return Stack(
      children: [
        // Scaffold 主體
        Scaffold(
          appBar: AppBar(
            title: const Text('我的行事曆'),
            actions: [
              // 切換日曆檢視模式按鈕
              IconButton(
                icon: Icon(_showEventTitles ? Icons.calendar_view_month : Icons.calendar_today),
                tooltip: _showEventTitles ? '切換到簡潔模式' : '切換到事件標題模式',
                onPressed: () {
                  setState(() {
                    _showEventTitles = !_showEventTitles;
                  });
                },
              ),
              // 用戶資訊按鈕
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () => _showUserMenu(context),
              ),
            ],
          ),
          
          body: Column(
            children: [
              // 行事曆元件 - 佔據大部分空間
              Expanded(
                child: _buildCalendar(eventsAsync),
              ),
            ],
          ),
          
          // 底部導航欄
          bottomNavigationBar: _buildBottomNavigationBar(context),
        ),
        
        // 可拖動的麥克風懸浮按鈕（位於最上層）
        DraggableMicButton(
          onPressed: (buttonCenter) => _navigateToVoiceInput(context, buttonCenter),
          backgroundColor: const Color(kPrimaryColorValue),
          iconColor: Colors.white,
        ),
      ],
    );
  }

  /// 建立行事曆元件
  Widget _buildCalendar(AsyncValue<List<CalendarEvent>> eventsAsync) {
    return Card(
      margin: const EdgeInsets.all(kPaddingMedium),
      child: TableCalendar(
        // 基本設定
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        
        // 事件載入器
        eventLoader: (day) {
          return eventsAsync.when(
            data: (events) => events.where((e) => e.isOnDate(day)).toList(),
            loading: () => [],
            error: (_, __) => [],
          );
        },
        
        // 本地化設定
        locale: 'zh_TW',
        
        // 行事曆樣式
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: const Color(kPrimaryColorValue).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Color(kPrimaryColorValue),
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Color(kSuccessColorValue),
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          // 如果顯示事件標題，需要更多高度
          cellMargin: _showEventTitles 
              ? const EdgeInsets.all(2)
              : const EdgeInsets.all(6),
        ),
        
        // 自定義單元格建構器
        // 當 _showEventTitles 為 true 時，使用自定義建構器顯示事件標題
        // 當為 false 時，使用空的 CalendarBuilders 以使用預設行為
        calendarBuilders: _showEventTitles ? CalendarBuilders(
          // 自定義單元格內容
          defaultBuilder: (context, day, focusedDay) {
            return _buildDayCellWithEvents(context, day, eventsAsync);
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildDayCellWithEvents(context, day, eventsAsync, isToday: true);
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildDayCellWithEvents(context, day, eventsAsync, isSelected: true);
          },
        ) : CalendarBuilders(),
        
        // 標題樣式
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
        ),
        
        // 回調函數
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          
          // 點擊日期後彈出該日的行程列表
          _showDayEventsBottomSheet(context, selectedDay, eventsAsync);
        },
        
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  /// 建立帶有事件標題的日期單元格
  Widget _buildDayCellWithEvents(
    BuildContext context,
    DateTime day,
    AsyncValue<List<CalendarEvent>> eventsAsync, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    // 取得當天的事件
    final dayEvents = eventsAsync.when(
      data: (events) => events
          .where((e) => e.isOnDate(day))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime)),
      loading: () => <CalendarEvent>[],
      error: (_, __) => <CalendarEvent>[],
    );

    // 決定背景顏色
    Color? backgroundColor;
    if (isSelected) {
      backgroundColor = const Color(kPrimaryColorValue);
    } else if (isToday) {
      backgroundColor = const Color(kPrimaryColorValue).withOpacity(0.3);
    }

    // 決定文字顏色
    final textColor = isSelected ? Colors.white : Colors.black87;
    final eventTextColor = isSelected ? Colors.white70 : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday && !isSelected
            ? Border.all(color: const Color(kPrimaryColorValue), width: 2)
            : null,
      ),
      child: Column(
        children: [
          // 日期數字
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          
          // 事件標題（最多顯示2個）
          if (dayEvents.isNotEmpty) ...[
            const SizedBox(height: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    for (var i = 0; i < (dayEvents.length > 2 ? 2 : dayEvents.length); i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.white.withOpacity(0.2)
                              : const Color(kSuccessColorValue).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          dayEvents[i].title,
                          style: TextStyle(
                            fontSize: 9,
                            color: eventTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // 如果還有更多事件，顯示 +N
                    if (dayEvents.length > 2)
                      Text(
                        '+${dayEvents.length - 2}',
                        style: TextStyle(
                          fontSize: 8,
                          color: eventTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 建立行程列表
  Widget _buildEventList(AsyncValue<List<CalendarEvent>> eventsAsync) {
    return eventsAsync.when(
      // 載入中
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      
      // 發生錯誤
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('載入失敗：$error'),
          ],
        ),
      ),
      
      // 載入完成
      data: (events) {
        // 篩選選中日期的行程
        final selectedDayEvents = events
            .where((e) => e.isOnDate(_selectedDay))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        if (selectedDayEvents.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(kPaddingMedium),
          itemCount: selectedDayEvents.length,
          itemBuilder: (context, index) {
            return _buildEventCard(selectedDayEvents[index]);
          },
        );
      },
    );
  }

  /// 建立空狀態提示
  Widget _buildEmptyState() {
    final dateStr = DateFormat('yyyy年MM月dd日').format(_selectedDay);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '$dateStr\n沒有安排行程',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToVoiceInput(context),
            icon: const Icon(Icons.mic),
            label: const Text('使用語音建立行程'),
          ),
        ],
      ),
    );
  }

  /// 建立行程卡片
  Widget _buildEventCard(CalendarEvent event) {
    final timeRange = '${DateFormat('HH:mm').format(event.startTime)} - '
        '${DateFormat('HH:mm').format(event.endTime)}';
    
    // 根據行程狀態決定顏色
    Color statusColor;
    IconData statusIcon;
    
    if (event.isPast()) {
      statusColor = Colors.grey;
      statusIcon = Icons.check_circle_outline;
    } else if (event.isOngoing()) {
      statusColor = const Color(kSuccessColorValue);
      statusIcon = Icons.circle;
    } else if (event.isUpcoming()) {
      statusColor = const Color(kWarningColorValue);
      statusIcon = Icons.notification_important;
    } else {
      statusColor = const Color(kPrimaryColorValue);
      statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: kPaddingMedium),
      child: InkWell(
        onTap: () => _navigateToEventDetail(context, event),
        borderRadius: BorderRadius.circular(kBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(kPaddingMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 狀態指示器
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(width: kPaddingMedium),
              
              // 行程資訊
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        // 語音建立標記
                        if (event.metadata.createdBy == 'voice')
                          const Icon(
                            Icons.mic,
                            size: 16,
                            color: Color(kPrimaryColorValue),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // 時間
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          timeRange,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    
                    // 地點
                    if (event.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顯示用戶選單
  void _showUserMenu(BuildContext context) {
    final currentUserData = ref.read(currentUserDataProvider);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 用戶資訊
            currentUserData.when(
              data: (user) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user?.getDisplayName() ?? '用戶'),
                subtitle: Text(user?.email ?? ''),
              ),
              loading: () => const ListTile(
                leading: CircularProgressIndicator(),
                title: Text('載入中...'),
              ),
              error: (_, __) => const ListTile(
                leading: Icon(Icons.error),
                title: Text('載入失敗'),
              ),
            ),
            
            const Divider(),
            
            // 設定（未來功能）
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('設定'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('設定功能開發中')),
                );
              },
            ),
            
            // 登出
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('登出', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authControllerProvider.notifier).signOut();
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 導航到語音輸入畫面（從麥克風按鈕位置展開）
  /// [buttonCenter] 可選參數：按鈕的中心位置，用於圓形展開動畫
  /// 如果未提供，則使用螢幕中心作為展開起點
  void _navigateToVoiceInput(BuildContext context, [Offset? buttonCenter]) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const VoiceInputScreen();
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 獲取螢幕尺寸
          final screenSize = MediaQuery.of(context).size;
          
          // 如果沒有提供 buttonCenter，使用螢幕中心
          final center = buttonCenter ?? Offset(screenSize.width / 2, screenSize.height / 2);
          
          // 螢幕中心點
          final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
          
          // 縮放動畫
          final scaleAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInSine,  // ✅ 無回彈
          ));
          
          // 位置動畫（從按鈕位置移動到螢幕中心）
          final positionAnimation = Tween<Offset>(
            begin: center - screenCenter,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          
          // 淡入動畫（快速淡入，不要太明顯）
          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
          ));
          
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.translate(
                offset: positionAnimation.value,
                child: Transform.scale(
                  scale: scaleAnimation.value,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: fadeAnimation.value,
                    child: child,
                  ),
                ),
              );
            },
            child: child,
          );
        },
      ),
    );
  }

  /// 導航到行程詳情畫面
  void _navigateToEventDetail(BuildContext context, CalendarEvent? event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(
          event: event,
          defaultDate: _selectedDay,
        ),
      ),
    );
  }

  /// 建立底部導航欄（5個區塊）
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 第一個位置：行事曆（當前頁面）
              _buildBottomNavItem(
                icon: Icons.calendar_today,
                label: '行事曆',
                isActive: true,
                onTap: () {
                  // 當前頁面，無需操作
                },
              ),
              
              // 第二個位置：待開發功能
              _buildBottomNavItem(
                icon: Icons.notifications_outlined,
                label: '通知',
                isActive: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('通知功能開發中')),
                  );
                },
              ),
              
              // 第三個位置：中間的新增按鈕（加大）
              InkWell(
                onTap: () => _navigateToEventDetail(context, null),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(kPrimaryColorValue),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(kPrimaryColorValue).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              
              // 第四個位置：待開發功能
              _buildBottomNavItem(
                icon: Icons.search,
                label: '搜尋',
                isActive: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('搜尋功能開發中')),
                  );
                },
              ),
              
              // 第五個位置：個人資料
              _buildBottomNavItem(
                icon: Icons.person_outline,
                label: '我的',
                isActive: false,
                onTap: () => _showUserMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 建立底部導航項目
  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive 
        ? const Color(kPrimaryColorValue) 
        : Colors.grey[600]!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顯示該日行程列表的底部面板
  void _showDayEventsBottomSheet(
    BuildContext context,
    DateTime selectedDay,
    AsyncValue<List<CalendarEvent>> eventsAsync,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // 拖動指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // 標題
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kPaddingLarge,
                    vertical: kPaddingMedium,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        color: const Color(kPrimaryColorValue),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('yyyy年MM月dd日 EEEE', 'zh_TW').format(selectedDay),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // 行程時間軸列表
                Expanded(
                  child: eventsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Text('載入失敗：$error'),
                        ],
                      ),
                    ),
                    data: (events) {
                      // 篩選選中日期的行程並按時間排序
                      final selectedDayEvents = events
                          .where((e) => e.isOnDate(selectedDay))
                          .toList()
                        ..sort((a, b) => a.startTime.compareTo(b.startTime));

                      if (selectedDayEvents.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '這天沒有安排行程',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _navigateToEventDetail(context, null);
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('新增行程'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(kPaddingLarge),
                        itemCount: selectedDayEvents.length,
                        itemBuilder: (context, index) {
                          return _buildTimelineEventCard(
                            selectedDayEvents[index],
                            isFirst: index == 0,
                            isLast: index == selectedDayEvents.length - 1,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 建立時間軸樣式的行程卡片
  Widget _buildTimelineEventCard(
    CalendarEvent event, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final timeRange = DateFormat('HH:mm').format(event.startTime);
    final endTime = DateFormat('HH:mm').format(event.endTime);
    
    // 根據行程狀態決定顏色
    Color statusColor;
    IconData statusIcon;
    
    if (event.isPast()) {
      statusColor = Colors.grey;
      statusIcon = Icons.check_circle;
    } else if (event.isOngoing()) {
      statusColor = const Color(kSuccessColorValue);
      statusIcon = Icons.circle;
    } else if (event.isUpcoming()) {
      statusColor = const Color(kWarningColorValue);
      statusIcon = Icons.access_time;
    } else {
      statusColor = const Color(kPrimaryColorValue);
      statusIcon = Icons.schedule;
    }

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _navigateToEventDetail(context, event);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 時間軸左側
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                Text(
                  endTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 時間軸中間的線和點
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 12,
                  color: Colors.grey[300],
                ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 90,
                  color: Colors.grey[300],
                ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // 行程卡片
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(kPaddingMedium),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // 語音建立標記
                      if (event.metadata.createdBy == 'voice')
                        Icon(
                          Icons.mic,
                          size: 16,
                          color: statusColor,
                        ),
                    ],
                  ),
                  
                  // 地點
                  if (event.location != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // 備註
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
