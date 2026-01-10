import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_label_model.dart';

/// SharedPreferences 的 Key
const String _labelsStorageKey = 'event_labels';

/// 行程標籤列表 Provider
/// 
/// 管理用戶自訂的行程標籤，提供：
/// - 讀取標籤列表
/// - 更新標籤名稱
/// - 重設為預設標籤
class EventLabelNotifier extends StateNotifier<List<EventLabel>> {
  EventLabelNotifier() : super(DefaultEventLabels.labels.toList()) {
    // 初始化時載入已儲存的標籤
    _loadLabels();
  }

  /// 從本地儲存載入標籤
  Future<void> _loadLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_labelsStorageKey);
      
      if (jsonString != null) {
        // 解析已儲存的標籤
        final List<dynamic> jsonList = json.decode(jsonString);
        final loadedLabels = jsonList
            .map((item) => EventLabel.fromJson(item as Map<String, dynamic>))
            .toList();
        
        // 確保標籤數量正確（應該有 12 個）
        if (loadedLabels.length == 12) {
          state = loadedLabels;
        }
      }
    } catch (e) {
      // 載入失敗時使用預設標籤
      state = DefaultEventLabels.labels.toList();
    }
  }

  /// 儲存標籤到本地
  Future<void> _saveLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(state.map((label) => label.toJson()).toList());
      await prefs.setString(_labelsStorageKey, jsonString);
    } catch (e) {
      // 儲存失敗時不做處理
    }
  }

  /// 更新指定標籤的名稱
  /// 
  /// [labelId] 標籤 ID
  /// [newName] 新的標籤名稱
  Future<void> updateLabelName(String labelId, String newName) async {
    // 找到要更新的標籤索引
    final index = state.indexWhere((label) => label.id == labelId);
    
    if (index != -1) {
      // 建立新的標籤列表
      final newLabels = List<EventLabel>.from(state);
      newLabels[index] = state[index].copyWith(name: newName);
      
      // 更新狀態
      state = newLabels;
      
      // 儲存到本地
      await _saveLabels();
    }
  }

  /// 重設所有標籤為預設值
  Future<void> resetToDefault() async {
    state = DefaultEventLabels.labels.toList();
    await _saveLabels();
  }

  /// 根據 ID 取得標籤
  EventLabel? getLabelById(String? labelId) {
    if (labelId == null) return null;
    
    try {
      return state.firstWhere((label) => label.id == labelId);
    } catch (_) {
      return null;
    }
  }
}

/// 行程標籤列表 Provider
final eventLabelsProvider = StateNotifierProvider<EventLabelNotifier, List<EventLabel>>((ref) {
  return EventLabelNotifier();
});

/// 根據 ID 取得單一標籤的 Provider
final eventLabelByIdProvider = Provider.family<EventLabel?, String?>((ref, labelId) {
  if (labelId == null) return null;
  
  final labels = ref.watch(eventLabelsProvider);
  try {
    return labels.firstWhere((label) => label.id == labelId);
  } catch (_) {
    return null;
  }
});

