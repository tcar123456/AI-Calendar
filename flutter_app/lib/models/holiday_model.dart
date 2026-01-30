import 'package:flutter/material.dart';

/// 節日類型
enum HolidayType {
  /// 國定假日（紅字）
  national,
  /// 傳統節日
  traditional,
  /// 國際節日
  international,
  /// 紀念日
  memorial,
}

/// 節日地區
/// 
/// 用於區分不同地區的節日
enum HolidayRegion {
  /// 台灣
  taiwan,
  /// 日本（未實作）
  japan,
  /// 美國（未實作）
  usa,
  /// 中國（未實作）
  china,
}

/// 節日地區的擴充方法
extension HolidayRegionExtension on HolidayRegion {
  /// 取得地區的中文名稱
  String get displayName {
    switch (this) {
      case HolidayRegion.taiwan:
        return '台灣';
      case HolidayRegion.japan:
        return '日本';
      case HolidayRegion.usa:
        return '美國';
      case HolidayRegion.china:
        return '中國';
    }
  }
  
  /// 取得地區的 ID（用於設定儲存）
  String get id {
    switch (this) {
      case HolidayRegion.taiwan:
        return 'taiwan';
      case HolidayRegion.japan:
        return 'japan';
      case HolidayRegion.usa:
        return 'usa';
      case HolidayRegion.china:
        return 'china';
    }
  }
  
  /// 從 ID 字串取得地區
  static HolidayRegion? fromId(String id) {
    switch (id) {
      case 'taiwan':
        return HolidayRegion.taiwan;
      case 'japan':
        return HolidayRegion.japan;
      case 'usa':
        return HolidayRegion.usa;
      case 'china':
        return HolidayRegion.china;
      default:
        return null;
    }
  }
  
  /// 是否已實作（目前只有台灣）
  bool get isImplemented {
    return this == HolidayRegion.taiwan;
  }
}

/// 節日模型
/// 
/// 儲存節日的基本資訊
class Holiday {
  /// 節日名稱
  final String name;
  
  /// 節日月份（1-12）
  final int month;
  
  /// 節日日期（1-31）
  final int day;
  
  /// 節日類型
  final HolidayType type;
  
  /// 是否為放假日
  final bool isOffDay;
  
  /// 節日所屬地區
  final HolidayRegion region;

  const Holiday({
    required this.name,
    required this.month,
    required this.day,
    required this.type,
    this.isOffDay = false,
    this.region = HolidayRegion.taiwan,
  });
  
  
  
  /// 取得節日的顏色
  Color get color {
    return Colors.red;
  }
  
  /// 取得節日的背景顏色
  Color get backgroundColor {
    return Colors.red;
  }
  
  /// 檢查日期是否為此節日
  bool isOnDate(DateTime date) {
    return date.month == month && date.day == day;
  }
}


/// 節日管理工具類別
///
/// 提供根據地區取得節日的統一介面
/// 節日資料在首次啟動時從 API 下載並永久快取
class HolidayManager {
  /// 動態節日快取（按年份儲存）
  ///
  /// 由 HolidayService 載入後更新此快取
  static final Map<int, List<Holiday>> _dynamicCache = {};

  /// 更新指定年份的動態快取
  ///
  /// 由 HolidayProvider 在載入節日資料後呼叫
  static void updateCache(int year, List<Holiday> holidays) {
    _dynamicCache[year] = holidays;
  }

  /// 清除所有動態快取
  static void clearCache() {
    _dynamicCache.clear();
  }

  /// 檢查指定年份是否已快取
  static bool isCached(int year) {
    return _dynamicCache.containsKey(year);
  }

  /// 根據地區 ID 列表取得指定日期的所有節日
  ///
  /// [date] 要查詢的日期
  /// [regionIds] 地區 ID 列表（例如：['taiwan', 'japan']）
  /// 返回該日期的所有節日列表（若該年份尚未下載則返回空列表）
  static List<Holiday> getHolidaysForDate(DateTime date, List<String> regionIds) {
    final holidays = <Holiday>[];

    for (final regionId in regionIds) {
      final region = HolidayRegionExtension.fromId(regionId);
      if (region == null || !region.isImplemented) continue;

      // 目前只有台灣實作
      if (region == HolidayRegion.taiwan) {
        final holiday = _getHolidayForDateFromCache(date);
        if (holiday != null) {
          holidays.add(holiday);
        }
      }
    }

    return holidays;
  }

  /// 從快取中取得指定日期的節日
  ///
  /// 從動態快取取得，若該年份尚未下載則返回 null
  static Holiday? _getHolidayForDateFromCache(DateTime date) {
    final year = date.year;

    // 從動態快取取得（首次啟動時會從 API 下載並永久快取）
    if (_dynamicCache.containsKey(year)) {
      final holidays = _dynamicCache[year]!;
      for (final holiday in holidays) {
        if (holiday.isOnDate(date)) {
          return holiday;
        }
      }
    }

    // 該年份尚未下載，返回 null
    return null;
  }

  /// 根據地區 ID 列表取得指定日期的第一個節日
  ///
  /// 相容舊有 API，返回單一節日或 null
  static Holiday? getHolidayForDate(DateTime date, List<String> regionIds) {
    final holidays = getHolidaysForDate(date, regionIds);
    return holidays.isNotEmpty ? holidays.first : null;
  }

  /// 取得指定年份的所有節日
  ///
  /// 從動態快取取得，若該年份尚未下載則返回空列表
  static List<Holiday> getHolidaysForYear(int year, List<String> regionIds) {
    final holidays = <Holiday>[];

    for (final regionId in regionIds) {
      final region = HolidayRegionExtension.fromId(regionId);
      if (region == null || !region.isImplemented) continue;

      if (region == HolidayRegion.taiwan) {
        // 從動態快取取得（首次啟動時會從 API 下載並永久快取）
        if (_dynamicCache.containsKey(year)) {
          holidays.addAll(_dynamicCache[year]!);
        }
        // 若該年份尚未下載，返回空列表（UI 會在資料載入後更新）
      }
    }

    return holidays;
  }

  /// 取得所有可用的地區選項
  ///
  /// 返回 (regionId, displayName, isImplemented) 的列表
  static List<({String id, String name, bool isImplemented})> getAvailableRegions() {
    return [
      (id: 'taiwan', name: '台灣', isImplemented: true),
      (id: 'japan', name: '日本', isImplemented: false),
      (id: 'usa', name: '美國', isImplemented: false),
      (id: 'china', name: '中國', isImplemented: false),
    ];
  }
}
