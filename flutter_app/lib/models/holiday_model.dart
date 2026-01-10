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

/// 台灣節日資料
/// 
/// 包含國定假日、傳統節日、紀念日等
/// 註：僅收錄台灣特有的節日，不包含西洋節日
class TaiwanHolidays {
  /// 固定日期的節日列表
  static const List<Holiday> fixedHolidays = [
    // ========== 國定假日（放假） ==========
    Holiday(
      name: '元旦',
      month: 1,
      day: 1,
      type: HolidayType.national,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '和平紀念日',
      month: 2,
      day: 28,
      type: HolidayType.national,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '兒童節',
      month: 4,
      day: 4,
      type: HolidayType.national,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '國慶日',
      month: 10,
      day: 10,
      type: HolidayType.national,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '行憲紀念日',
      month: 12,
      day: 25,
      type: HolidayType.national,
      isOffDay: false, // 現已不放假
      region: HolidayRegion.taiwan,
    ),
    
    // ========== 傳統節日 ==========
    // 註：農曆節日的日期會隨年份變動，這裡使用 2026 年的日期作為示例
    Holiday(
      name: '除夕',
      month: 1,
      day: 29, // 2026 年農曆除夕
      type: HolidayType.traditional,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '春節',
      month: 1,
      day: 30, // 2026 年農曆初一
      type: HolidayType.traditional,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '元宵節',
      month: 2,
      day: 12, // 2026 年農曆正月十五
      type: HolidayType.traditional,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '清明節',
      month: 4,
      day: 5,
      type: HolidayType.traditional,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '端午節',
      month: 5,
      day: 31, // 2026 年農曆五月五日
      type: HolidayType.traditional,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '七夕',
      month: 8,
      day: 19, // 2026 年農曆七月七日
      type: HolidayType.traditional,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '中元節',
      month: 8,
      day: 27, // 2026 年農曆七月十五
      type: HolidayType.traditional,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '中秋節',
      month: 10,
      day: 3, // 2026 年農曆八月十五
      type: HolidayType.traditional,
      isOffDay: true,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '重陽節',
      month: 10,
      day: 18, // 2026 年農曆九月九日
      type: HolidayType.traditional,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '冬至',
      month: 12,
      day: 21, // 每年約在 12/21-22
      type: HolidayType.traditional,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    
    // ========== 台灣特有節日 ==========
    Holiday(
      name: '勞動節',
      month: 5,
      day: 1,
      type: HolidayType.national,
      isOffDay: true, // 勞工放假
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '母親節',
      month: 5,
      day: 11, // 2026 年 5 月第二個週日
      type: HolidayType.memorial,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '父親節',
      month: 8,
      day: 8,
      type: HolidayType.memorial,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    
    // ========== 紀念日 ==========
    Holiday(
      name: '婦女節',
      month: 3,
      day: 8,
      type: HolidayType.memorial,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '植樹節',
      month: 3,
      day: 12,
      type: HolidayType.memorial,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '青年節',
      month: 3,
      day: 29,
      type: HolidayType.memorial,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '教師節',
      month: 9,
      day: 28,
      type: HolidayType.memorial,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '光復節',
      month: 10,
      day: 25,
      type: HolidayType.memorial,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
    Holiday(
      name: '跨年夜',
      month: 12,
      day: 31,
      type: HolidayType.memorial,
      isOffDay: false,
      region: HolidayRegion.taiwan,
    ),
  ];
  
  /// 取得指定日期的節日
  /// 
  /// 如果該日期有節日則返回節日資料，否則返回 null
  static Holiday? getHolidayForDate(DateTime date) {
    for (final holiday in fixedHolidays) {
      if (holiday.isOnDate(date)) {
        return holiday;
      }
    }
    return null;
  }
  
  /// 取得指定月份的所有節日
  static List<Holiday> getHolidaysForMonth(int month) {
    return fixedHolidays.where((h) => h.month == month).toList();
  }
  
  /// 取得指定年份的所有節日（帶日期）
  /// 
  /// 返回 Map<DateTime, Holiday>，方便快速查詢
  static Map<DateTime, Holiday> getHolidaysForYear(int year) {
    final Map<DateTime, Holiday> holidays = {};
    
    for (final holiday in fixedHolidays) {
      final date = DateTime(year, holiday.month, holiday.day);
      holidays[date] = holiday;
    }
    
    return holidays;
  }
}

/// 節日管理工具類別
/// 
/// 提供根據地區取得節日的統一介面
class HolidayManager {
  /// 根據地區 ID 列表取得指定日期的所有節日
  /// 
  /// [date] 要查詢的日期
  /// [regionIds] 地區 ID 列表（例如：['taiwan', 'japan']）
  /// 返回該日期的所有節日列表
  static List<Holiday> getHolidaysForDate(DateTime date, List<String> regionIds) {
    final holidays = <Holiday>[];
    
    for (final regionId in regionIds) {
      final region = HolidayRegionExtension.fromId(regionId);
      if (region == null || !region.isImplemented) continue;
      
      // 目前只有台灣實作
      if (region == HolidayRegion.taiwan) {
        final holiday = TaiwanHolidays.getHolidayForDate(date);
        if (holiday != null) {
          holidays.add(holiday);
        }
      }
    }
    
    return holidays;
  }
  
  /// 根據地區 ID 列表取得指定日期的第一個節日
  /// 
  /// 相容舊有 API，返回單一節日或 null
  static Holiday? getHolidayForDate(DateTime date, List<String> regionIds) {
    final holidays = getHolidaysForDate(date, regionIds);
    return holidays.isNotEmpty ? holidays.first : null;
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
