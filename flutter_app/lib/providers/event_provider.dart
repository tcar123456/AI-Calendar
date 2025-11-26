import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// 行程列表 Provider
/// 
/// 監聽當前用戶的所有行程
final eventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return Stream.value([]);
  }
  
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchUserEvents(userId);
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
  Future<String?> createManualEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    String? description,
    List<String> participants = const [],
    int reminderMinutes = 15,
    bool isAllDay = false,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(errorMessage: '用戶未登入');
      return null;
    }

    final event = CalendarEvent(
      id: '', // 會由 Firestore 自動產生
      userId: userId,
      title: title,
      startTime: startTime,
      endTime: endTime,
      location: location,
      description: description,
      participants: participants,
      reminderMinutes: reminderMinutes,
      isAllDay: isAllDay,
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

