import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../calendar/event_detail_screen.dart';

/// 通知畫面
///
/// 顯示即將到來的行程提醒和通知
class NotificationScreen extends ConsumerStatefulWidget {
  /// 是否嵌入在其他頁面中（不顯示 AppBar）
  final bool embedded;

  const NotificationScreen({
    super.key,
    this.embedded = false,
  });

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // 進入通知頁面時，標記為已讀
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationLastViewedProvider.notifier).state = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 取得所有行事曆的行程（不篩選行事曆）
    final eventsAsync = ref.watch(allEventsProvider);

    // 嵌入模式：不顯示 Scaffold 和 AppBar
    if (widget.embedded) {
      return eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colors.error),
              const SizedBox(height: 16),
              Text('載入失敗：$error'),
            ],
          ),
        ),
        data: (events) => _buildNotificationContent(events),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        centerTitle: false,
        actions: [
          // 清除全部已讀按鈕（未來功能）
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: '全部標記已讀',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已全部標記為已讀')),
              );
            },
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colors.error),
              const SizedBox(height: 16),
              Text('載入失敗：$error'),
            ],
          ),
        ),
        data: (events) => _buildNotificationContent(events),
      ),
    );
  }

  /// 建立通知內容
  Widget _buildNotificationContent(List<CalendarEvent> events) {
    final colors = context.colors;
    // 分類行程
    final now = DateTime.now();

    // 即將開始的行程（15分鐘內）
    final upcomingEvents = events.where((e) => e.isUpcoming()).toList();

    // 正在進行的行程
    final ongoingEvents = events.where((e) => e.isOngoing()).toList();

    // 今日剩餘行程（今天還沒開始的行程）
    final todayEvents = events.where((e) {
      final eventDate =
          DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      final today = DateTime(now.year, now.month, now.day);
      return eventDate.isAtSameMomentAs(today) &&
          e.startTime.isAfter(now) &&
          !e.isUpcoming();
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 明天的行程
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowEvents = events.where((e) {
      final eventDate =
          DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      return eventDate.isAtSameMomentAs(tomorrow);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 本週剩餘行程（不含今天和明天）
    final weekEnd = now.add(Duration(days: 7 - now.weekday));
    final thisWeekEvents = events.where((e) {
      final eventDate =
          DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      final todayDate = DateTime(now.year, now.month, now.day);
      final tomorrowDate = DateTime(now.year, now.month, now.day + 1);
      return eventDate.isAfter(tomorrowDate) &&
          eventDate.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 計算總通知數
    final totalNotifications = upcomingEvents.length +
        ongoingEvents.length +
        todayEvents.length +
        tomorrowEvents.length +
        thisWeekEvents.length;

    if (totalNotifications == 0) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(kPaddingMedium),
      children: [
        // 正在進行的行程
        if (ongoingEvents.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.play_circle,
            title: '正在進行',
            color: colors.primary,
            count: ongoingEvents.length,
          ),
          ...ongoingEvents.map((e) => _buildNotificationCard(
                event: e,
                type: NotificationType.ongoing,
              )),
          const SizedBox(height: kPaddingMedium),
        ],

        // 即將開始的行程
        if (upcomingEvents.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.notifications_active,
            title: '即將開始（15分鐘內）',
            color: const Color(kWarningColorValue),
            count: upcomingEvents.length,
          ),
          ...upcomingEvents.map((e) => _buildNotificationCard(
                event: e,
                type: NotificationType.upcoming,
              )),
          const SizedBox(height: kPaddingMedium),
        ],

        // 今日剩餘行程
        if (todayEvents.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.today,
            title: '今日待辦',
            color: colors.primary,
            count: todayEvents.length,
          ),
          ...todayEvents.map((e) => _buildNotificationCard(
                event: e,
                type: NotificationType.today,
              )),
          const SizedBox(height: kPaddingMedium),
        ],

        // 明天的行程
        if (tomorrowEvents.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.event,
            title: '明天',
            color: Colors.blue,
            count: tomorrowEvents.length,
          ),
          ...tomorrowEvents.map((e) => _buildNotificationCard(
                event: e,
                type: NotificationType.tomorrow,
              )),
          const SizedBox(height: kPaddingMedium),
        ],

        // 本週剩餘行程
        if (thisWeekEvents.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.date_range,
            title: '本週',
            color: Colors.purple,
            count: thisWeekEvents.length,
          ),
          ...thisWeekEvents.map((e) => _buildNotificationCard(
                event: e,
                type: NotificationType.thisWeek,
              )),
        ],
      ],
    );
  }

  /// 建立區塊標題
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kPaddingSmall),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 建立通知卡片
  Widget _buildNotificationCard({
    required CalendarEvent event,
    required NotificationType type,
  }) {
    final colors = context.colors;
    // 根據通知類型決定顏色和圖示
    Color cardColor;
    IconData statusIcon;
    String timeText;

    switch (type) {
      case NotificationType.ongoing:
        cardColor = colors.primary;
        statusIcon = Icons.play_arrow;
        final remaining = event.endTime.difference(DateTime.now());
        timeText = '進行中，剩餘 ${remaining.inMinutes} 分鐘';
        break;
      case NotificationType.upcoming:
        cardColor = const Color(kWarningColorValue);
        statusIcon = Icons.access_time;
        final until = event.startTime.difference(DateTime.now());
        timeText = '${until.inMinutes} 分鐘後開始';
        break;
      case NotificationType.today:
        cardColor = colors.primary;
        statusIcon = Icons.schedule;
        timeText = DateFormat('HH:mm').format(event.startTime);
        break;
      case NotificationType.tomorrow:
        cardColor = Colors.blue;
        statusIcon = Icons.event;
        timeText = '明天 ${DateFormat('HH:mm').format(event.startTime)}';
        break;
      case NotificationType.thisWeek:
        cardColor = Colors.purple;
        statusIcon = Icons.date_range;
        timeText = DateFormat('EEEE HH:mm', 'zh_TW').format(event.startTime);
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: kPaddingSmall),
      child: InkWell(
        onTap: () => _navigateToEventDetail(event),
        borderRadius: BorderRadius.circular(kBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(kPaddingMedium),
          child: Row(
            children: [
              // 左側狀態指示器
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: cardColor, size: 20),
              ),

              const SizedBox(width: kPaddingMedium),

              // 中間內容
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        // 重複行程標記
                        if (event.isRecurring)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.repeat,
                              size: 14,
                              color: cardColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 時間
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: cardColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 13,
                            color: cardColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // 地點
                    if (event.location != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary,
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

              // 右側箭頭
              Icon(
                Icons.chevron_right,
                color: colors.iconTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 建立空狀態提示
  Widget _buildEmptyState() {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: colors.iconTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            '目前沒有通知',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '當有即將到來的行程時\n會在這裡顯示提醒',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  /// 導航到行程詳情
  void _navigateToEventDetail(CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允許佔滿螢幕
      backgroundColor: Colors.transparent,
      isDismissible: true, // 檢視模式可點擊外部關閉
      enableDrag: true, // 檢視模式可下滑關閉
      builder: (context) => EventDetailScreen(
        event: event,
        defaultDate: event.startTime,
        isViewMode: true, // 從通知點擊進入檢視模式
      ),
    );
  }
}

/// 通知類型
enum NotificationType {
  /// 正在進行
  ongoing,
  /// 即將開始（15分鐘內）
  upcoming,
  /// 今日待辦
  today,
  /// 明天
  tomorrow,
  /// 本週
  thisWeek,
}

