import 'event_label_model.dart';

/// 行事曆專屬設定模型
///
/// 每個行事曆擁有獨立的設定，包括：
/// - 標籤自訂名稱
/// - 節日顯示設定
/// - 農曆顯示設定
/// - 預設視圖設定
class CalendarSettings {
  /// 標籤自訂名稱（Map<標籤ID, 自訂名稱>）
  ///
  /// 例如：{'label_1': '專案會議', 'label_2': '緊急'}
  /// 未自訂的標籤使用 DefaultEventLabels 的預設名稱
  final Map<String, String> labelNames;

  /// 是否顯示節日（預設 true）
  final bool showHolidays;

  /// 節日地區列表（預設 ['taiwan']）
  final List<String> holidayRegions;

  /// 是否顯示農曆（預設 false）
  final bool showLunar;

  /// 預設視圖 ('month', 'twoWeeks', 'week')
  final String defaultView;

  const CalendarSettings({
    this.labelNames = const {},
    this.showHolidays = true,
    this.holidayRegions = const ['taiwan'],
    this.showLunar = false,
    this.defaultView = 'month',
  });

  /// 從 JSON 建立物件
  ///
  /// 若 json 為 null，回傳預設設定（向下相容舊資料）
  factory CalendarSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CalendarSettings();

    return CalendarSettings(
      labelNames: Map<String, String>.from(json['labelNames'] ?? {}),
      showHolidays: json['showHolidays'] as bool? ?? true,
      holidayRegions: List<String>.from(json['holidayRegions'] ?? ['taiwan']),
      showLunar: json['showLunar'] as bool? ?? false,
      defaultView: json['defaultView'] as String? ?? 'month',
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'labelNames': labelNames,
      'showHolidays': showHolidays,
      'holidayRegions': holidayRegions,
      'showLunar': showLunar,
      'defaultView': defaultView,
    };
  }

  /// 複製物件並允許修改部分欄位
  CalendarSettings copyWith({
    Map<String, String>? labelNames,
    bool? showHolidays,
    List<String>? holidayRegions,
    bool? showLunar,
    String? defaultView,
  }) {
    return CalendarSettings(
      labelNames: labelNames ?? this.labelNames,
      showHolidays: showHolidays ?? this.showHolidays,
      holidayRegions: holidayRegions ?? this.holidayRegions,
      showLunar: showLunar ?? this.showLunar,
      defaultView: defaultView ?? this.defaultView,
    );
  }

  /// 取得指定標籤的名稱
  ///
  /// 優先使用自訂名稱，若無則使用預設名稱
  String getLabelName(String labelId) {
    return labelNames[labelId] ??
        DefaultEventLabels.getById(labelId)?.name ??
        '未命名';
  }

  /// 取得所有標籤列表（結合預設顏色和自訂名稱）
  List<EventLabel> getLabels() {
    return DefaultEventLabels.labels.map((defaultLabel) {
      final customName = labelNames[defaultLabel.id];
      if (customName != null) {
        return defaultLabel.copyWith(name: customName);
      }
      return defaultLabel;
    }).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CalendarSettings) return false;

    return _mapEquals(labelNames, other.labelNames) &&
        showHolidays == other.showHolidays &&
        _listEquals(holidayRegions, other.holidayRegions) &&
        showLunar == other.showLunar &&
        defaultView == other.defaultView;
  }

  @override
  int get hashCode {
    return labelNames.hashCode ^
        showHolidays.hashCode ^
        holidayRegions.hashCode ^
        showLunar.hashCode ^
        defaultView.hashCode;
  }
}

/// 比較兩個 Map 是否相等
bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}

/// 比較兩個 List 是否相等
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
