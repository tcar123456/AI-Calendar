import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/event_model.dart';
import '../../../providers/event_provider.dart';
import '../../../providers/event_label_provider.dart';
import '../../../utils/constants.dart';
import '../event_detail_screen.dart';

/// 行程搜尋面板
/// 
/// 提供搜尋功能，可搜尋目前行事曆中的行程：
/// - 支援標題、地點、描述的關鍵字搜尋
/// - 顯示搜尋結果列表
/// - 點擊結果可導航到行程詳情
class EventSearchSheet extends ConsumerStatefulWidget {
  const EventSearchSheet({super.key});

  /// 顯示搜尋面板的靜態方法
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const EventSearchSheet(),
    );
  }

  @override
  ConsumerState<EventSearchSheet> createState() => _EventSearchSheetState();
}

class _EventSearchSheetState extends ConsumerState<EventSearchSheet> {
  /// 搜尋文字控制器
  final TextEditingController _searchController = TextEditingController();
  
  /// 搜尋關鍵字
  String _searchQuery = '';
  
  /// 搜尋結果
  List<CalendarEvent> _searchResults = [];
  
  /// 是否正在搜尋
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 執行搜尋
  void _performSearch(String query, List<CalendarEvent> allEvents) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
      _isSearching = true;
    });

    // 過濾符合條件的行程
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final results = allEvents.where((event) {
      // 搜尋標題
      if (event.title.toLowerCase().contains(_searchQuery)) {
        return true;
      }
      // 搜尋地點
      if (event.location?.toLowerCase().contains(_searchQuery) ?? false) {
        return true;
      }
      // 搜尋描述
      if (event.description?.toLowerCase().contains(_searchQuery) ?? false) {
        return true;
      }
      return false;
    }).toList();

    // 依照開始時間排序（最近的優先）
    results.sort((a, b) => b.startTime.compareTo(a.startTime));

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  /// 導航到行程詳情頁面
  void _navigateToEventDetail(CalendarEvent event) {
    // 關閉搜尋面板
    Navigator.pop(context);

    // 導航到行程詳情（使用 BottomSheet 方式）
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允許佔滿螢幕
      backgroundColor: Colors.transparent,
      isDismissible: true, // 檢視模式可點擊外部關閉
      enableDrag: true, // 檢視模式可下滑關閉
      builder: (context) => EventDetailScreen(
        event: event,
        isViewMode: true, // 從搜尋結果點擊進入檢視模式
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 監聯所有行程
    final eventsAsync = ref.watch(allEventsProvider);
    
    return SafeArea(
      // 使用 GestureDetector 包裹，點擊空白處可收起鍵盤
      child: GestureDetector(
        onTap: () {
          // 點擊空白處時收起鍵盤
          FocusScope.of(context).unfocus();
        },
        // 確保透明區域也能響應點擊
        behavior: HitTestBehavior.opaque,
        child: Container(
          // 計算高度：螢幕高度減去狀態列和 AppBar 高度，確保底部面板在狀態列下方
          height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // 標題列
              _buildHeader(),
              
              const Divider(height: 1),
              
              // 搜尋輸入框
              _buildSearchField(eventsAsync),
              
              // 搜尋結果
              Expanded(
                child: _buildSearchResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 建立標題列
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(kPaddingMedium),
      child: Row(
        children: [
          // 返回按鈕
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          // 搜尋圖示
          const Icon(
            Icons.search,
            color: Color(kPrimaryColorValue),
          ),
          const SizedBox(width: 12),
          // 標題
          const Text(
            '搜尋行程',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 建立搜尋輸入框
  Widget _buildSearchField(AsyncValue<List<CalendarEvent>> eventsAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kPaddingMedium,
        vertical: kPaddingSmall,
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '輸入關鍵字搜尋...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _searchResults = [];
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(kPrimaryColorValue),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          // 當輸入變更時執行搜尋
          eventsAsync.when(
            data: (events) => _performSearch(value, events),
            loading: () {},
            error: (_, __) {},
          );
        },
      ),
    );
  }

  /// 建立搜尋結果區域
  Widget _buildSearchResults() {
    // 尚未輸入搜尋關鍵字
    if (_searchQuery.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        message: '輸入關鍵字搜尋行程',
        subtitle: '可搜尋標題、地點、描述',
      );
    }

    // 搜尋中
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 無搜尋結果
    if (_searchResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        message: '找不到符合的行程',
        subtitle: '請嘗試其他關鍵字',
      );
    }

    // 顯示搜尋結果
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: kPaddingSmall),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = _searchResults[index];
        return _buildEventItem(event);
      },
    );
  }

  /// 建立空狀態提示
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 建立行程項目
  Widget _buildEventItem(CalendarEvent event) {
    // 取得標籤顏色
    final labels = ref.watch(eventLabelsProvider);
    final label = labels.firstWhere(
      (l) => l.id == event.labelId,
      orElse: () => labels.first,
    );
    
    // 格式化時間
    final dateFormat = DateFormat('yyyy/MM/dd');
    final timeFormat = DateFormat('HH:mm');
    
    String timeText;
    if (event.isAllDay) {
      timeText = '${dateFormat.format(event.startTime)} 全天';
    } else if (event.isMultiDay()) {
      timeText = '${dateFormat.format(event.startTime)} - ${dateFormat.format(event.endTime)}';
    } else {
      timeText = '${dateFormat.format(event.startTime)} ${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kPaddingMedium,
        vertical: kPaddingSmall,
      ),
      leading: Container(
        width: 4,
        height: 48,
        decoration: BoxDecoration(
          color: label.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Text(
        event.title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // 時間
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          // 地點（如果有）
          if (event.location != null && event.location!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: () => _navigateToEventDetail(event),
    );
  }
}
