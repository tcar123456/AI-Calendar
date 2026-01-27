import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../models/recurrence_rule.dart';
import '../services/firebase_service.dart';
import '../services/recurrence_service.dart';
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
/// - 總覽模式 → 顯示所有行事曆的行程
/// - 選中行事曆 A → 只顯示 calendarId == A 的行程
/// - 選中行事曆 B → 只顯示 calendarId == B 的行程
/// - 舊行程（無 calendarId）→ 顯示在第一個行事曆中
/// - 隱藏標籤過濾：根據 hiddenLabelIds 過濾掉對應標籤的行程
final eventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final allEvents = ref.watch(allEventsProvider);
  final selectedCalendar = ref.watch(selectedCalendarProvider);
  final calendars = ref.watch(calendarsProvider);
  final hiddenLabelIds = ref.watch(hiddenLabelIdsProvider);
  final isOverviewMode = ref.watch(isOverviewModeProvider);

  return allEvents.when(
    data: (events) {
      // 總覽模式：顯示所有行程（不依行事曆過濾）
      if (isOverviewMode) {
        // 標籤過濾：根據 hiddenLabelIds 過濾掉對應標籤的行程
        final filteredByLabel = events.where((event) {
          if (event.labelId == null) return true;
          return !hiddenLabelIds.contains(event.labelId);
        }).toList();
        return AsyncValue.data(filteredByLabel);
      }

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

  // ==================== 重複行程相關方法 ====================

  /// 建立重複行程（主行程 + 實例）
  ///
  /// [event] 行程資料（會被設為主行程）
  /// [rule] 重複規則
  ///
  /// 回傳：主行程的 ID（失敗時回傳 null）
  Future<String?> createRecurringEvent(
    CalendarEvent event,
    RecurrenceRule rule,
  ) async {
    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      // 建立主行程
      final masterEvent = event.copyWith(
        isMasterEvent: true,
        recurrenceRule: rule,
        isException: false,
      );

      // 使用 RecurrenceService 展開實例
      final recurrenceService = RecurrenceService();
      final instances = recurrenceService.expandInstances(masterEvent);

      // 批次建立到 Firestore
      final masterId = await _firebaseService.createRecurringEvents(
        masterEvent,
        instances,
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: '重複行程建立成功（共 ${instances.length + 1} 個）',
      );

      return masterId;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '建立重複行程失敗：$e',
      );
      return null;
    }
  }

  /// 編輯重複行程
  ///
  /// [eventId] 要編輯的行程 ID
  /// [updatedEvent] 更新後的行程資料
  /// [choice] 編輯選項（僅此行程/此行程及之後/所有行程）
  ///
  /// 回傳：是否成功
  Future<bool> editRecurringEvent(
    String eventId,
    CalendarEvent updatedEvent,
    RecurrenceEditChoice choice,
  ) async {
    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      switch (choice) {
        case RecurrenceEditChoice.thisOnly:
          // 僅此行程：標記為例外，更新內容
          final exceptionEvent = updatedEvent.copyWith(
            isException: true,
            updatedAt: DateTime.now(),
          );
          await _firebaseService.updateEvent(eventId, exceptionEvent);
          break;

        case RecurrenceEditChoice.thisAndFollowing:
          // 此行程及之後：較複雜，需要分割系列
          // 1. 取得原主行程
          final originalMasterId = updatedEvent.masterEventId;
          if (originalMasterId == null) {
            throw Exception('找不到主行程');
          }

          final originalMaster = await _firebaseService.getMasterEvent(originalMasterId);
          if (originalMaster == null) {
            throw Exception('主行程不存在');
          }

          // 2. 更新原主行程的結束日期為此行程的前一天
          final newEndDate = updatedEvent.originalDate?.subtract(const Duration(days: 1)) ??
              updatedEvent.startTime.subtract(const Duration(days: 1));

          if (originalMaster.recurrenceRule != null) {
            final updatedRule = originalMaster.recurrenceRule!.copyWith(
              endDate: newEndDate,
            );
            final updatedMaster = originalMaster.copyWith(
              recurrenceRule: updatedRule,
              updatedAt: DateTime.now(),
            );
            await _firebaseService.updateEvent(originalMasterId, updatedMaster);
          }

          // 3. 刪除此日期及之後的實例
          final fromDate = updatedEvent.originalDate ?? updatedEvent.startTime;
          await _firebaseService.deleteInstancesFromDate(originalMasterId, fromDate);

          // 4. 建立新的主行程和實例（如果還有重複規則）
          if (originalMaster.recurrenceRule != null) {
            final newMaster = updatedEvent.copyWith(
              id: '',
              isMasterEvent: true,
              recurrenceRule: originalMaster.recurrenceRule,
              masterEventId: null,
              originalDate: null,
              isException: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final recurrenceService = RecurrenceService();
            final newInstances = recurrenceService.expandInstances(newMaster);
            await _firebaseService.createRecurringEvents(newMaster, newInstances);
          }
          break;

        case RecurrenceEditChoice.all:
          // 所有行程：更新主行程，同步更新所有非例外實例
          final masterId = updatedEvent.isMasterEvent
              ? updatedEvent.id
              : updatedEvent.masterEventId;

          if (masterId == null) {
            throw Exception('找不到主行程');
          }

          // 準備要更新的欄位（DateTime 轉換為 Timestamp）
          final updates = {
            'title': updatedEvent.title,
            'location': updatedEvent.location,
            'description': updatedEvent.description,
            'reminderMinutes': updatedEvent.reminderMinutes,
            'isAllDay': updatedEvent.isAllDay,
            'labelId': updatedEvent.labelId,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          };

          await _firebaseService.updateRecurrenceSeries(masterId, updates);
          break;
      }

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

  /// 刪除重複行程
  ///
  /// [event] 要刪除的行程
  /// [choice] 刪除選項（僅此行程/此行程及之後/所有行程）
  ///
  /// 回傳：是否成功
  Future<bool> deleteRecurringEvent(
    CalendarEvent event,
    RecurrenceDeleteChoice choice,
  ) async {
    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      switch (choice) {
        case RecurrenceDeleteChoice.thisOnly:
          // 僅此行程：直接刪除此實例
          await _firebaseService.deleteEvent(event.id);
          break;

        case RecurrenceDeleteChoice.thisAndFollowing:
          // 此行程及之後：更新主行程結束日期，刪除之後的實例
          final masterId = event.isMasterEvent ? event.id : event.masterEventId;
          if (masterId == null) {
            throw Exception('找不到主行程');
          }

          // 取得主行程
          final master = await _firebaseService.getMasterEvent(masterId);
          if (master == null) {
            throw Exception('主行程不存在');
          }

          // 計算要刪除的起始日期（只取日期部分）
          final eventDate = event.originalDate ?? event.startTime;
          final fromDate = DateTime(eventDate.year, eventDate.month, eventDate.day);

          // 計算新的結束日期（此行程的前一天）
          final newEndDate = fromDate.subtract(const Duration(days: 1));

          // 取主行程開始日期（只取日期部分）用於比較
          final masterStartDate = DateTime(
            master.startTime.year,
            master.startTime.month,
            master.startTime.day,
          );

          // 如果新結束日期早於主行程開始日期，則刪除整個系列
          if (newEndDate.isBefore(masterStartDate)) {
            await _firebaseService.deleteRecurrenceSeries(masterId);
          } else {
            // 更新主行程的重複規則結束日期
            if (master.recurrenceRule != null) {
              final updatedRule = master.recurrenceRule!.copyWith(
                endDate: newEndDate,
              );
              final updatedMaster = master.copyWith(
                recurrenceRule: updatedRule,
                updatedAt: DateTime.now(),
              );
              await _firebaseService.updateEvent(masterId, updatedMaster);
            }

            // 刪除此日期及之後的實例
            await _firebaseService.deleteInstancesFromDate(masterId, fromDate);
          }
          break;

        case RecurrenceDeleteChoice.all:
          // 所有行程：刪除主行程和所有實例
          final masterId = event.isMasterEvent ? event.id : event.masterEventId;
          if (masterId == null) {
            throw Exception('找不到主行程');
          }

          await _firebaseService.deleteRecurrenceSeries(masterId);
          break;
      }

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

