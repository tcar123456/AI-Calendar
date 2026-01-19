import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/holiday_model.dart';
import '../utils/constants.dart';

/// 節日 API 回應模型
class HolidaysApiResponse {
  final int year;
  final String region;
  final List<HolidayData> holidays;
  final String generatedAt;

  HolidaysApiResponse({
    required this.year,
    required this.region,
    required this.holidays,
    required this.generatedAt,
  });

  factory HolidaysApiResponse.fromJson(Map<String, dynamic> json) {
    return HolidaysApiResponse(
      year: json['year'] as int,
      region: json['region'] as String,
      holidays: (json['holidays'] as List)
          .map((h) => HolidayData.fromJson(h as Map<String, dynamic>))
          .toList(),
      generatedAt: json['generated_at'] as String,
    );
  }
}

/// 單一節日資料（來自 API）
class HolidayData {
  final String name;
  final String date; // YYYY-MM-DD
  final String type;
  final bool isOffDay;
  final String? lunarDate;

  HolidayData({
    required this.name,
    required this.date,
    required this.type,
    required this.isOffDay,
    this.lunarDate,
  });

  factory HolidayData.fromJson(Map<String, dynamic> json) {
    return HolidayData(
      name: json['name'] as String,
      date: json['date'] as String,
      type: json['type'] as String,
      isOffDay: json['is_off_day'] as bool,
      lunarDate: json['lunar_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'date': date,
      'type': type,
      'is_off_day': isOffDay,
      'lunar_date': lunarDate,
    };
  }

  /// 轉換為 Holiday 模型
  Holiday toHoliday() {
    final parts = date.split('-');
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    HolidayType holidayType;
    switch (type) {
      case 'national':
        holidayType = HolidayType.national;
        break;
      case 'traditional':
        holidayType = HolidayType.traditional;
        break;
      case 'memorial':
        holidayType = HolidayType.memorial;
        break;
      case 'international':
        holidayType = HolidayType.international;
        break;
      default:
        holidayType = HolidayType.memorial;
    }

    return Holiday(
      name: name,
      month: month,
      day: day,
      type: holidayType,
      isOffDay: isOffDay,
      region: HolidayRegion.taiwan,
    );
  }
}

/// 節日服務類別
///
/// 提供三層快取：
/// 1. 記憶體快取（最快）
/// 2. SharedPreferences（7天有效）
/// 3. API 請求
/// 4. 靜態資料回退
class HolidayService {
  // 單例模式
  static final HolidayService _instance = HolidayService._internal();
  factory HolidayService() => _instance;
  HolidayService._internal();

  // 記憶體快取
  final Map<int, List<Holiday>> _memoryCache = {};

  // 快取有效期（7 天）
  static const int _cacheValidityDays = 7;

  // SharedPreferences 快取 key 前綴
  static const String _cacheKeyPrefix = 'holidays_cache_';
  static const String _cacheTimestampPrefix = 'holidays_timestamp_';

  /// 是否啟用 API 呼叫
  ///
  /// 設為 false 時直接使用靜態資料，適合 API 尚未部署時使用
  static const bool _enableApiCall = true; // API 已部署，啟用動態節日計算

  /// 取得指定年份的節日列表
  ///
  /// 快取優先順序：
  /// 1. 記憶體快取
  /// 2. SharedPreferences
  /// 3. API 請求（若啟用）
  /// 4. 靜態資料回退
  Future<List<Holiday>> getHolidaysForYear(int year, {String region = 'taiwan'}) async {
    // 1. 檢查記憶體快取
    if (_memoryCache.containsKey(year)) {
      return _memoryCache[year]!;
    }

    // 2. 檢查 SharedPreferences 快取
    final cachedHolidays = await _loadFromLocalCache(year);
    if (cachedHolidays != null) {
      debugPrint('從本地快取取得 $year 年節日資料 (${cachedHolidays.length} 個)');
      _memoryCache[year] = cachedHolidays;
      return cachedHolidays;
    }

    // 3. 從 API 取得（若啟用）
    if (_enableApiCall) {
      try {
        debugPrint('從 API 取得 $year 年節日資料...');
        final holidays = await _fetchFromApi(year, region);
        debugPrint('成功取得 ${holidays.length} 個節日');
        _memoryCache[year] = holidays;
        await _saveToLocalCache(year, holidays);
        return holidays;
      } catch (e) {
        debugPrint('取得節日資料失敗: $e');
      }
    }

    // 4. 回退到靜態資料
    debugPrint('使用靜態節日資料 ($year 年)');
    return _getStaticHolidays(year);
  }

  /// 從 API 取得節日資料
  Future<List<Holiday>> _fetchFromApi(int year, String region) async {
    final url = Uri.parse('$kZeaburApiBaseUrl$kHolidaysEndpoint/$year?region=$region');

    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('API 請求超時');
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final apiResponse = HolidaysApiResponse.fromJson(json);
      return apiResponse.holidays.map((h) => h.toHoliday()).toList();
    } else {
      throw Exception('API 回應錯誤: ${response.statusCode}');
    }
  }

  /// 從本地快取載入
  Future<List<Holiday>?> _loadFromLocalCache(int year) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$year';
      final timestampKey = '$_cacheTimestampPrefix$year';

      final cachedData = prefs.getString(cacheKey);
      final timestampStr = prefs.getString(timestampKey);

      if (cachedData == null || timestampStr == null) {
        return null;
      }

      // 檢查快取是否過期
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      if (now.difference(timestamp).inDays > _cacheValidityDays) {
        // 快取過期，清除
        await prefs.remove(cacheKey);
        await prefs.remove(timestampKey);
        return null;
      }

      // 解析快取資料
      final List<dynamic> jsonList = jsonDecode(cachedData);
      return jsonList
          .map((json) => HolidayData.fromJson(json as Map<String, dynamic>).toHoliday())
          .toList();
    } catch (e) {
      debugPrint('載入本地快取失敗: $e');
      return null;
    }
  }

  /// 儲存到本地快取
  Future<void> _saveToLocalCache(int year, List<Holiday> holidays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$year';
      final timestampKey = '$_cacheTimestampPrefix$year';

      // 將 Holiday 轉換為可序列化的格式
      final jsonList = holidays.map((h) => {
        'name': h.name,
        'date': '$year-${h.month.toString().padLeft(2, '0')}-${h.day.toString().padLeft(2, '0')}',
        'type': h.type.name,
        'is_off_day': h.isOffDay,
        'lunar_date': null,
      }).toList();

      await prefs.setString(cacheKey, jsonEncode(jsonList));
      await prefs.setString(timestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('儲存本地快取失敗: $e');
    }
  }

  /// 取得靜態節日資料（回退用）
  List<Holiday> _getStaticHolidays(int year) {
    // 使用現有的靜態資料
    return TaiwanHolidays.fixedHolidays.toList();
  }

  /// 預載入指定年份的節日資料
  ///
  /// 適合在應用啟動時呼叫
  Future<void> preloadYear(int year) async {
    await getHolidaysForYear(year);
  }

  /// 預載入多年節日資料
  ///
  /// 適合預載入當年和下一年的資料
  Future<void> preloadYears(List<int> years) async {
    for (final year in years) {
      await getHolidaysForYear(year);
    }
  }

  /// 清除所有快取
  Future<void> clearCache() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) || key.startsWith(_cacheTimestampPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// 清除指定年份的快取
  Future<void> clearCacheForYear(int year) async {
    _memoryCache.remove(year);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cacheKeyPrefix$year');
    await prefs.remove('$_cacheTimestampPrefix$year');
  }
}
