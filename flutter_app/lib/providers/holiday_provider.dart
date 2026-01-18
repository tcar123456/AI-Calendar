import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/holiday_model.dart';
import '../services/holiday_service.dart';

/// HolidayService Provider（單例）
final holidayServiceProvider = Provider<HolidayService>((ref) {
  return HolidayService();
});

/// 年度節日 Provider
///
/// 根據年份取得該年所有節日
/// 使用 FutureProvider.family 支援不同年份的快取
final yearHolidaysProvider = FutureProvider.family<List<Holiday>, int>((ref, year) async {
  final service = ref.read(holidayServiceProvider);
  return service.getHolidaysForYear(year);
});

/// 節日快取狀態
class HolidayCacheState {
  /// 已載入的年份
  final Set<int> loadedYears;

  /// 是否正在載入
  final bool isLoading;

  /// 錯誤訊息
  final String? error;

  const HolidayCacheState({
    this.loadedYears = const {},
    this.isLoading = false,
    this.error,
  });

  HolidayCacheState copyWith({
    Set<int>? loadedYears,
    bool? isLoading,
    String? error,
  }) {
    return HolidayCacheState(
      loadedYears: loadedYears ?? this.loadedYears,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 節日快取 Controller
///
/// 負責管理節日資料的預載入和快取狀態
class HolidayCacheController extends StateNotifier<HolidayCacheState> {
  final HolidayService _service;
  final Ref _ref;

  HolidayCacheController(this._service, this._ref) : super(const HolidayCacheState());

  /// 預載入指定年份
  Future<void> preloadYear(int year) async {
    if (state.loadedYears.contains(year)) {
      return; // 已載入，跳過
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.getHolidaysForYear(year);
      state = state.copyWith(
        loadedYears: {...state.loadedYears, year},
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 預載入當年和下一年
  Future<void> preloadCurrentAndNextYear() async {
    final currentYear = DateTime.now().year;
    await preloadYear(currentYear);
    await preloadYear(currentYear + 1);
  }

  /// 預載入指定年份前後各一年
  Future<void> preloadAroundYear(int year) async {
    await preloadYear(year - 1);
    await preloadYear(year);
    await preloadYear(year + 1);
  }

  /// 清除快取並重新載入
  Future<void> refreshCache() async {
    await _service.clearCache();
    state = const HolidayCacheState();
    await preloadCurrentAndNextYear();
  }
}

/// 節日快取 Provider
final holidayCacheProvider = StateNotifierProvider<HolidayCacheController, HolidayCacheState>((ref) {
  final service = ref.read(holidayServiceProvider);
  return HolidayCacheController(service, ref);
});

/// 根據日期取得節日的輔助方法
///
/// 這是一個同步方法，用於 UI 渲染時快速查詢
/// 如果該年份尚未載入，會返回靜態資料
List<Holiday> getHolidaysForDateSync(
  DateTime date,
  List<String> regionIds,
  HolidayService service,
) {
  // 嘗試從記憶體快取取得（同步）
  // 如果沒有快取，使用靜態資料
  return HolidayManager.getHolidaysForDate(date, regionIds);
}
