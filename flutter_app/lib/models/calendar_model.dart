import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 行事曆模型
/// 
/// 代表一個獨立的行事曆，用戶可以擁有多個行事曆
/// 類似 TimeTree 的多行事曆功能
class CalendarModel {
  /// 行事曆唯一識別碼
  final String id;
  
  /// 行事曆擁有者的用戶 ID
  final String ownerId;
  
  /// 行事曆名稱（例如：「我的行事曆」、「工作」、「家庭」）
  final String name;
  
  /// 行事曆顏色（用於識別不同行事曆）
  final Color color;
  
  /// 行事曆描述（可選）
  final String? description;
  
  /// 是否為預設行事曆
  final bool isDefault;
  
  /// 行事曆建立時間
  final DateTime createdAt;
  
  /// 行事曆最後更新時間
  final DateTime updatedAt;
  
  /// 行事曆圖示（可選，使用 Material Icons 名稱）
  final String? iconName;

  CalendarModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.color,
    this.description,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.iconName,
  });

  /// 從 Firestore 文檔建立物件
  factory CalendarModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CalendarModel(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      name: data['name'] as String,
      color: Color(data['colorValue'] as int),
      description: data['description'] as String?,
      isDefault: data['isDefault'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      iconName: data['iconName'] as String?,
    );
  }

  /// 從 JSON 建立物件
  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      color: Color(json['colorValue'] as int),
      description: json['description'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      iconName: json['iconName'] as String?,
    );
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'colorValue': color.value,
      'description': description,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'iconName': iconName,
    };
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'colorValue': color.value,
      'description': description,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'iconName': iconName,
    };
  }

  /// 複製物件並允許修改部分欄位
  CalendarModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    Color? color,
    String? description,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? iconName,
  }) {
    return CalendarModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      color: color ?? this.color,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      iconName: iconName ?? this.iconName,
    );
  }

  /// 預設行事曆顏色列表
  static const List<Color> defaultColors = [
    Color(0xFF6366F1), // Indigo（主題色）
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFF84CC16), // Lime
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Teal
  ];

  /// 建立預設行事曆
  static CalendarModel createDefault({
    required String ownerId,
    String name = '我的行事曆',
  }) {
    final now = DateTime.now();
    return CalendarModel(
      id: '', // 會由 Firestore 自動產生
      ownerId: ownerId,
      name: name,
      color: defaultColors[0], // 使用主題色
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );
  }
}

