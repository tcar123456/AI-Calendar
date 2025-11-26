import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../utils/constants.dart';
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

  @override
  Widget build(BuildContext context) {
    // 取得當前用戶資料
    final currentUserData = ref.watch(currentUserDataProvider);
    
    // 取得所有行程
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的行事曆'),
        actions: [
          // 用戶資訊按鈕
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showUserMenu(context),
          ),
        ],
      ),
      
      body: Column(
        children: [
          // 行事曆元件
          _buildCalendar(eventsAsync),
          
          const SizedBox(height: 8),
          
          // 行程列表
          Expanded(
            child: _buildEventList(eventsAsync),
          ),
        ],
      ),
      
      // 浮動按鈕：語音輸入
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 語音建立行程按鈕
          FloatingActionButton.extended(
            onPressed: () => _navigateToVoiceInput(context),
            backgroundColor: const Color(kPrimaryColorValue),
            icon: const Icon(Icons.mic),
            label: const Text('語音建立'),
            heroTag: 'voice',
          ),
          
          const SizedBox(height: 12),
          
          // 手動建立行程按鈕
          FloatingActionButton(
            onPressed: () => _navigateToEventDetail(context, null),
            backgroundColor: Colors.white,
            foregroundColor: const Color(kPrimaryColorValue),
            child: const Icon(Icons.add),
            heroTag: 'manual',
          ),
        ],
      ),
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
        ),
        
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

  /// 導航到語音輸入畫面
  void _navigateToVoiceInput(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const VoiceInputScreen(),
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
}

