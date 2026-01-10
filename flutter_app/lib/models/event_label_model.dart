import 'package:flutter/material.dart';

/// 行程標籤模型
/// 
/// 用於定義行程的分類標籤，每個標籤包含：
/// - 唯一識別碼
/// - 顏色
/// - 自訂名稱
class EventLabel {
  /// 標籤唯一識別碼
  final String id;
  
  /// 標籤顏色的值 (Color.value)
  final int colorValue;
  
  /// 標籤名稱（可自訂）
  final String name;

  const EventLabel({
    required this.id,
    required this.colorValue,
    required this.name,
  });

  /// 取得 Color 物件
  Color get color => Color(colorValue);

  /// 從 JSON 建立物件
  factory EventLabel.fromJson(Map<String, dynamic> json) {
    return EventLabel(
      id: json['id'] as String,
      colorValue: json['colorValue'] as int,
      name: json['name'] as String,
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'colorValue': colorValue,
      'name': name,
    };
  }

  /// 複製物件並允許修改部分欄位
  EventLabel copyWith({
    String? id,
    int? colorValue,
    String? name,
  }) {
    return EventLabel(
      id: id ?? this.id,
      colorValue: colorValue ?? this.colorValue,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventLabel &&
        other.id == id &&
        other.colorValue == colorValue &&
        other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ colorValue.hashCode ^ name.hashCode;
}

/// 預設的 12 種行程標籤
/// 
/// 提供預設的顏色和名稱，用戶可以自行修改名稱
class DefaultEventLabels {
  /// 預設標籤列表
  static const List<EventLabel> labels = [
    EventLabel(id: 'label_1', colorValue: 0xFFE91E63, name: '工作'),      // 粉紅色
    EventLabel(id: 'label_2', colorValue: 0xFFF44336, name: '重要'),      // 紅色
    EventLabel(id: 'label_3', colorValue: 0xFF9C27B0, name: '個人'),      // 紫色
    EventLabel(id: 'label_4', colorValue: 0xFF673AB7, name: '家庭'),      // 深紫色
    EventLabel(id: 'label_5', colorValue: 0xFF3F51B5, name: '學習'),      // 靛藍色
    EventLabel(id: 'label_6', colorValue: 0xFF2196F3, name: '會議'),      // 藍色
    EventLabel(id: 'label_7', colorValue: 0xFF00BCD4, name: '社交'),      // 青色
    EventLabel(id: 'label_8', colorValue: 0xFF009688, name: '運動'),      // 藍綠色
    EventLabel(id: 'label_9', colorValue: 0xFF4CAF50, name: '休閒'),      // 綠色
    EventLabel(id: 'label_10', colorValue: 0xFFFF9800, name: '約會'),     // 橙色
    EventLabel(id: 'label_11', colorValue: 0xFF795548, name: '旅行'),     // 棕色
    EventLabel(id: 'label_12', colorValue: 0xFF607D8B, name: '其他'),     // 灰藍色
  ];

  /// 根據 ID 取得預設標籤
  static EventLabel? getById(String id) {
    try {
      return labels.firstWhere((label) => label.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 取得預設的第一個標籤
  static EventLabel get defaultLabel => labels[0];
}

