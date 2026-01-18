import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';
import 'calendar_provider.dart';

/// 所有行程列表 Provider
/// 
/// 監聯當前用戶的所有行程（不過濾行事曆）
final allEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return Stream.value([]);
  }
  
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchUserEvents(userId);
});

/// 行程列表 Provider
///
/// 監聽當前選擇行事曆的行程
/// 會根據 selectedCalendarProvider 過濾行程
///
/// 過濾邏輯：
/// - 選中行事曆 A → 只顯示 calendarId == A 的行程
/// - 選中行事曆 B → 只顯示 calendarId == B 的行程
/// - 舊行程（無 calendarId）→ 顯示在第一個行事曆中
/// - 隱藏標籤過濾：根據 hiddenLabelIds 過濾掉對應標籤的行程
final eventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final allEvents = ref.watch(allEventsProvider);
  final selectedCalendar = ref.watch(selectedCalendarProvider);
  final calendars = ref.watch(calendarsProvider);
  final hiddenLabelIds = ref.watch(hiddenLabelIdsProvider);

  return allEvents.when(
    data: (events) {
      // 如果沒有選擇的行事曆，返回空列表
      if (selectedCalendar == null) {
        return const AsyncValue.data([]);
      }

      // 取得第一個行事曆的 ID（用於處理舊行程）
      final firstCalendarId = calendars.when(
        data: (list) => list.isNotEmpty ? list.first.id : null,
        loading: () => null,
        error: (_, __) => null,
      );

      // 過濾出屬於當前選擇行事曆的行程
      final filteredByCalendar = events.where((event) {
        // 情況 1：行程有 calendarId，必須完全匹配
        if (event.calendarId != null) {
          return event.calendarId == selectedCalendar.id;
        }

        // 情況 2：舊行程（無 calendarId），顯示在第一個行事曆中
        return selectedCalendar.id == firstCalendarId;
      }).toList();

      // 標籤過濾：根據 hiddenLabelIds 過濾掉對應標籤的行程
      final filteredByLabel = filteredByCalendar.where((event) {
        // 無標籤行程永遠顯示
        if (event.labelId == null) return true;
        // 檢查標籤是否在隱藏列表中
        return !hiddenLabelIds.contains(event.labelId);
      }).toList();

      return AsyncValue.data(filteredByLabel);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// 指定日期的行程 Provider
/// 
/// 取得特定日期的所有行程
final eventsForDateProvider = FutureProvider.family<List<CalendarEvent>, DateTime>(
  (ref, date) async {
    final userId = ref.watch(currentUserIdProvider);
    
    if (userId == null) {
      return [];
    }
    
    final firebaseService = ref.watch(firebaseServiceProvider);
    return await firebaseService.getEventsForDate(userId, date);
  },
);

/// 選中的日期 Provider
/// 
/// 用於行事曆 UI 顯示選中的日期
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// 行程控制器 State
class EventState {
  /// 是否正在載入
  final bool isLoading;
  
  /// 錯誤訊息
  final String? errorMessage;
  
  /// 成功訊息
  final String? successMessage;

  const EventState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  /// 複製並修改部分屬性
  EventState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return EventState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// 行程控制器
/// 
/// 處理行程的建立、更新、刪除等操作
class EventController extends StateNotifier<EventState> {
  final FirebaseService _firebaseService;
  final Ref _ref;

  EventController(this._firebaseService, this._ref) : super(const EventState());

  /// 建立行程
  Future<String?> createEvent(CalendarEvent event) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    
    try {
      final eventId = await _firebaseService.createEvent(event);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '行程建立成功',
      );
      
      return eventId;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '建立行程失敗：$e',
      );
      return null;
    }
  }

  /// 更新行程
  Future<bool> updateEvent(String eventId, CalendarEvent event) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    
    try {
      await _firebaseService.updateEvent(eventId, event);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '行程更新成功',
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '更新行程失敗：$e',
      );
      return false;
    }
  }

  /// 刪除行程
  Future<bool> deleteEvent(String eventId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    
    try {
      await _firebaseService.deleteEvent(eventId);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '行程刪除成功',
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '刪除行程失敗：$e',
      );
      return false;
    }
  }

  /// 快速建立手動行程
  /// 
  /// 提供便捷的方法建立手動輸入的行程
  /// 如果未指定 calendarId，會自動使用當前選擇的行事曆
  Future<String?> createManualEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    String? description,
    List<String> participants = const [],
    int reminderMinutes = 15,
    bool isAllDay = false,
    String? labelId,
    String? calendarId,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(errorMessage: '用戶未登入');
      return null;
    }

    // 如果未指定 calendarId，使用當前選擇的行事曆
    final effectiveCalendarId = calendarId ?? 
        _ref.read(selectedCalendarProvider)?.id;

    final event = CalendarEvent(
      id: '', // 會由 Firestore 自動產生
      userId: userId,
      calendarId: effectiveCalendarId,
      title: title,
      startTime: startTime,
      endTime: endTime,
      location: location,
      description: description,
      participants: participants,
      reminderMinutes: reminderMinutes,
      isAllDay: isAllDay,
      labelId: labelId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: EventMetadata(createdBy: 'manual'),
    );

    return await createEvent(event);
  }

  /// 清除訊息
  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }
}

/// 行程控制器 Provider
final eventControllerProvider = StateNotifierProvider<EventController, EventState>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return EventController(firebaseService, ref);
});

// ============================================
// 通知紅點相關 Providers
// ============================================

/// 最後查看通知的時間 Provider
///
/// 記錄用戶最後一次打開通知頁面的時間
final notificationLastViewedProvider = StateProvider<DateTime?>((ref) => null);

/// 是否有未讀通知 Provider
///
/// 計算邏輯：
/// - 有「即將開始」（15 分鐘內）的行程
/// - 有「正在進行」的行程，且行程開始時間在上次查看之後
///
/// 點擊通知頁面後，更新 lastViewed 時間，紅點消失
final hasUnreadNotificationProvider = Provider<bool>((ref) {
  final eventsAsync = ref.watch(allEventsProvider);
  final lastViewed = ref.watch(notificationLastViewedProvider);

  return eventsAsync.when(
    data: (events) {
      // 檢查是否有即將開始的行程（15 分鐘內）
      final hasUpcoming = events.any((e) => e.isUpcoming());
      if (hasUpcoming) return true;

      // 檢查是否有正在進行的行程，且開始時間在上次查看之後
      final hasNewOngoing = events.any((e) {
        if (!e.isOngoing()) return false;
        // 如果從未查看過通知，顯示紅點
        if (lastViewed == null) return true;
        // 如果行程開始時間在上次查看之後，顯示紅點
        return e.startTime.isAfter(lastViewed);
      });

      return hasNewOngoing;
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

