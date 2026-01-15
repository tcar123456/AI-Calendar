import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_model.dart';
import '../models/calendar_settings_model.dart';
import '../models/event_label_model.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// SharedPreferences key 常數
const String _kSelectedCalendarIdKey = 'selected_calendar_id';

/// 用戶所有行事曆列表 Provider
/// 
/// 監聯當前用戶的所有行事曆
final calendarsProvider = StreamProvider<List<CalendarModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return Stream.value([]);
  }
  
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchUserCalendars(userId);
});

/// 當前選擇的行事曆 ID Provider
/// 
/// 儲存用戶當前選擇檢視的行事曆 ID
/// 如果為 null，表示尚未選擇（會自動選擇第一個行事曆）
/// 
/// 此 Provider 會自動從 SharedPreferences 載入上次選擇的行事曆 ID，
/// 並在選擇變更時自動儲存
final selectedCalendarIdProvider = StateNotifierProvider<SelectedCalendarIdNotifier, String?>((ref) {
  return SelectedCalendarIdNotifier();
});

/// 選擇的行事曆 ID 狀態管理器
/// 
/// 負責：
/// - 從 SharedPreferences 載入上次選擇的行事曆 ID
/// - 在選擇變更時自動儲存到 SharedPreferences
class SelectedCalendarIdNotifier extends StateNotifier<String?> {
  SelectedCalendarIdNotifier() : super(null) {
    // 初始化時從 SharedPreferences 載入
    _loadSavedCalendarId();
  }

  /// 從 SharedPreferences 載入儲存的行事曆 ID
  Future<void> _loadSavedCalendarId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kSelectedCalendarIdKey);
      if (savedId != null && savedId.isNotEmpty) {
        state = savedId;
      }
    } catch (e) {
      // 載入失敗時保持 null，讓系統自動選擇第一個行事曆
      debugPrint('載入儲存的行事曆 ID 失敗: $e');
    }
  }

  /// 設定選擇的行事曆 ID
  /// 
  /// 會自動儲存到 SharedPreferences
  Future<void> setCalendarId(String? calendarId) async {
    state = calendarId;
    
    // 儲存到 SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      if (calendarId != null && calendarId.isNotEmpty) {
        await prefs.setString(_kSelectedCalendarIdKey, calendarId);
      } else {
        await prefs.remove(_kSelectedCalendarIdKey);
      }
    } catch (e) {
      debugPrint('儲存行事曆 ID 失敗: $e');
    }
  }

  /// 清除選擇的行事曆 ID
  Future<void> clear() async {
    await setCalendarId(null);
  }
}

/// 當前選擇的行事曆 Provider
/// 
/// 根據 selectedCalendarIdProvider 取得對應的行事曆物件
final selectedCalendarProvider = Provider<CalendarModel?>((ref) {
  final calendars = ref.watch(calendarsProvider);
  final selectedId = ref.watch(selectedCalendarIdProvider);
  
  return calendars.when(
    data: (calendarList) {
      if (calendarList.isEmpty) return null;
      
      // 如果有選擇的行事曆 ID，找出對應的行事曆
      if (selectedId != null) {
        final selected = calendarList.where((c) => c.id == selectedId);
        if (selected.isNotEmpty) return selected.first;
      }
      
      // 否則返回第一個行事曆
      return calendarList.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// 行事曆控制器 State
class CalendarControllerState {
  /// 是否正在載入
  final bool isLoading;
  
  /// 錯誤訊息
  final String? errorMessage;
  
  /// 成功訊息
  final String? successMessage;

  const CalendarControllerState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  /// 複製並修改部分屬性
  CalendarControllerState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return CalendarControllerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// 行事曆控制器
/// 
/// 處理行事曆的建立、更新、刪除等操作
class CalendarController extends StateNotifier<CalendarControllerState> {
  final FirebaseService _firebaseService;
  final Ref _ref;

  CalendarController(this._firebaseService, this._ref) 
      : super(const CalendarControllerState());

  /// 建立新行事曆
  Future<String?> createCalendar({
    required String name,
    Color? color,
    String? description,
    String? iconName,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '用戶未登入',
      );
      return null;
    }

    try {
      final now = DateTime.now();
      final calendar = CalendarModel(
        id: '', // 會由 Firestore 自動產生
        ownerId: userId,
        name: name,
        color: color ?? CalendarModel.defaultColors[0],
        description: description,
        isDefault: false,
        createdAt: now,
        updatedAt: now,
        iconName: iconName,
      );

      final calendarId = await _firebaseService.createCalendar(calendar);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '行事曆建立成功',
      );
      
      return calendarId;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '建立行事曆失敗：$e',
      );
      return null;
    }
  }

  /// 更新行事曆
  Future<bool> updateCalendar({
    required String calendarId,
    String? name,
    Color? color,
    String? description,
    String? iconName,
    CalendarSettings? settings,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      // 先取得現有行事曆
      final existingCalendar = await _firebaseService.getCalendar(calendarId);
      if (existingCalendar == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '找不到行事曆',
        );
        return false;
      }

      // 更新行事曆
      final updatedCalendar = existingCalendar.copyWith(
        name: name,
        color: color,
        description: description,
        iconName: iconName,
        settings: settings,
        updatedAt: DateTime.now(),
      );

      await _firebaseService.updateCalendar(calendarId, updatedCalendar);

      state = state.copyWith(
        isLoading: false,
        successMessage: '行事曆更新成功',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '更新行事曆失敗：$e',
      );
      return false;
    }
  }

  /// 更新行事曆設定
  ///
  /// 只更新 settings 欄位，保留其他欄位不變
  Future<bool> updateCalendarSettings(
    String calendarId,
    CalendarSettings settings,
  ) async {
    return updateCalendar(
      calendarId: calendarId,
      settings: settings,
    );
  }

  /// 更新單一標籤名稱
  ///
  /// [calendarId] 行事曆 ID
  /// [labelId] 標籤 ID (label_1 ~ label_12)
  /// [newName] 新的標籤名稱
  Future<bool> updateLabelName(
    String calendarId,
    String labelId,
    String newName,
  ) async {
    try {
      final calendar = await _firebaseService.getCalendar(calendarId);
      if (calendar == null) return false;

      final newLabelNames = Map<String, String>.from(calendar.settings.labelNames);
      newLabelNames[labelId] = newName;

      final newSettings = calendar.settings.copyWith(labelNames: newLabelNames);
      return updateCalendarSettings(calendarId, newSettings);
    } catch (e) {
      state = state.copyWith(
        errorMessage: '更新標籤失敗：$e',
      );
      return false;
    }
  }

  /// 刪除行事曆
  /// 
  /// 刪除行事曆會一併刪除其中所有行程
  Future<bool> deleteCalendar(String calendarId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      // 檢查行事曆是否存在
      final calendar = await _firebaseService.getCalendar(calendarId);
      if (calendar == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '找不到行事曆',
        );
        return false;
      }

      await _firebaseService.deleteCalendar(calendarId);
      
      // 如果刪除的是當前選擇的行事曆，重設選擇
      final selectedId = _ref.read(selectedCalendarIdProvider);
      if (selectedId == calendarId) {
        await _ref.read(selectedCalendarIdProvider.notifier).clear();
      }
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '行事曆刪除成功',
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '刪除行事曆失敗：$e',
      );
      return false;
    }
  }

  /// 設定預設行事曆
  Future<bool> setDefaultCalendar(String calendarId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '用戶未登入',
      );
      return false;
    }

    try {
      await _firebaseService.setDefaultCalendar(userId, calendarId);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '已設為預設行事曆',
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '設定預設行事曆失敗：$e',
      );
      return false;
    }
  }

  /// 確保用戶有預設行事曆
  Future<String?> ensureDefaultCalendar() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return null;

    try {
      return await _firebaseService.ensureDefaultCalendar(userId);
    } catch (e) {
      state = state.copyWith(
        errorMessage: '建立預設行事曆失敗：$e',
      );
      return null;
    }
  }

  /// 選擇行事曆
  /// 
  /// 會自動儲存選擇到 SharedPreferences
  Future<void> selectCalendar(String calendarId) async {
    await _ref.read(selectedCalendarIdProvider.notifier).setCalendarId(calendarId);
  }

  /// 清除訊息
  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }
}

/// 行事曆控制器 Provider
final calendarControllerProvider =
    StateNotifierProvider<CalendarController, CalendarControllerState>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return CalendarController(firebaseService, ref);
});

/// 當前選擇行事曆的設定 Provider
///
/// 便於 UI 直接存取當前行事曆的設定
/// 如果沒有選擇的行事曆，回傳預設設定
final selectedCalendarSettingsProvider = Provider<CalendarSettings>((ref) {
  final calendar = ref.watch(selectedCalendarProvider);
  return calendar?.settings ?? const CalendarSettings();
});

/// 當前行事曆的標籤列表 Provider
///
/// 結合預設標籤顏色和自訂標籤名稱
/// 如果沒有選擇的行事曆，回傳預設標籤列表
final calendarLabelsProvider = Provider<List<EventLabel>>((ref) {
  final settings = ref.watch(selectedCalendarSettingsProvider);
  return settings.getLabels();
});

