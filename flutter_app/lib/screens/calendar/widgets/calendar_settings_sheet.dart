import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/event_label_model.dart';
import '../../../models/holiday_model.dart';
import '../../../providers/calendar_provider.dart';
import '../../../utils/constants.dart';
import 'event_search_sheet.dart';

/// 行事曆設定選單
/// 
/// 針對行事曆主體的設定（與整個 APP 的設定不同）
/// 可設定項目：
/// - 行程標籤（顏色和名稱自訂）
/// - 預設視圖（月/週/日）
/// - 顯示農曆
/// - 顯示節日
/// - 刪除行事曆
class CalendarSettingsSheet extends ConsumerWidget {
  const CalendarSettingsSheet({super.key});

  /// 顯示設定面板的靜態方法
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CalendarSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 取得當前行事曆的設定
    final calendarSettings = ref.watch(selectedCalendarSettingsProvider);
    final showHolidays = calendarSettings.showHolidays;
    final holidayRegions = calendarSettings.holidayRegions;
    final showLunar = calendarSettings.showLunar;
    
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 標題區域
          Padding(
            padding: const EdgeInsets.all(kPaddingMedium),
            child: Row(
              children: const [
                Icon(
                  Icons.space_dashboard,
                  color: Color(kPrimaryColorValue),
                ),
                SizedBox(width: 12),
                Text(
                  '行事曆設定',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // 搜尋行程
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('搜尋行程'),
            subtitle: const Text('搜尋標題、地點、描述'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              EventSearchSheet.show(context);
            },
          ),
          
          // 行程標籤設定
          ListTile(
            leading: const Icon(Icons.label),
            title: const Text('行程標籤'),
            subtitle: const Text('自訂標籤顏色和名稱'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              _showLabelSettingsSheet(context);
            },
          ),
          
          
          
          // 顯示農曆
          ListTile(
            leading: const Icon(Icons.event_note),
            title: const Text('顯示農曆'),
            subtitle: Text(showLunar ? '已開啟' : '已關閉'),
            trailing: Transform.scale(
              scale: 0.7,
              child: Switch(
                value: showLunar,
                activeColor: const Color(kPrimaryColorValue),
                onChanged: (value) => _updateShowLunar(context, ref, value),
              ),
            ),
            onTap: () => _updateShowLunar(context, ref, !showLunar),
          ),

          // 顯示節日
          ListTile(
            leading: const Icon(Icons.celebration),
            title: const Text('顯示節日'),
            subtitle: Text(showHolidays ? '已開啟' : '已關閉'),
            trailing: Transform.scale(
              scale: 0.7,
              child: Switch(
                value: showHolidays,
                activeColor: const Color(kPrimaryColorValue),
                onChanged: (value) => _updateShowHolidays(context, ref, value),
              ),
            ),
            onTap: () => _updateShowHolidays(context, ref, !showHolidays),
          ),

          // 節日地區選擇（只在顯示節日開啟時顯示，帶動畫過渡）
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.only(left: 32),
              child: _buildHolidayRegionsListTile(context, ref, holidayRegions),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: showHolidays
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),

          const Divider(height: 16),
          
          // 刪除行事曆
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              '刪除行事曆',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _showDeleteCalendarConfirm(context, ref),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  /// 建立節日地區選擇 ListTile
  /// 
  /// 點擊後顯示彈窗選擇地區（類似提醒選擇）
  Widget _buildHolidayRegionsListTile(
    BuildContext context,
    WidgetRef ref,
    List<String> currentRegions,
  ) {
    // 取得所有可用地區
    final availableRegions = HolidayManager.getAvailableRegions();
    
    // 取得當前選擇的地區名稱
    final selectedRegionNames = currentRegions
        .map((id) {
          final region = availableRegions.firstWhere(
            (r) => r.id == id,
            orElse: () => (id: id, name: id, isImplemented: false),
          );
          return region.name;
        })
        .join('、');
    
    return ListTile(
      leading: const Icon(Icons.public),
      title: const Text('節日地區'),
      subtitle: Text(selectedRegionNames.isEmpty ? '未選擇' : selectedRegionNames),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showRegionPickerDialog(context, ref, currentRegions),
    );
  }
  
  /// 顯示地區選擇底部面板
  /// 
  /// 類似建立行程中提醒的 CheckboxListTile 底部面板樣式
  void _showRegionPickerDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> currentRegions,
  ) {
    showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RegionPickerBottomSheet(
        selectedRegions: currentRegions,
        onConfirm: (newRegions) {
          _saveRegionSelection(context, ref, newRegions);
        },
      ),
    );
  }
  
  /// 儲存地區選擇
  Future<void> _saveRegionSelection(
    BuildContext context,
    WidgetRef ref,
    List<String> newRegions,
  ) async {
    final selectedCalendar = ref.read(selectedCalendarProvider);
    if (selectedCalendar == null) return;

    // 確保至少選擇一個地區
    if (newRegions.isEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('至少需要選擇一個地區')),
      );
      return;
    }

    try {
      // 更新行事曆設定
      final newSettings = selectedCalendar.settings.copyWith(
        holidayRegions: newRegions,
      );
      await ref.read(calendarControllerProvider.notifier).updateCalendarSettings(
        selectedCalendar.id,
        newSettings,
      );
    } catch (e) {
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('更新設定失敗：$e')),
        );
      }
    }
  }

  /// 更新顯示節日設定
  Future<void> _updateShowHolidays(BuildContext context, WidgetRef ref, bool value) async {
    final selectedCalendar = ref.read(selectedCalendarProvider);
    if (selectedCalendar == null) return;

    try {
      // 更新行事曆設定
      final newSettings = selectedCalendar.settings.copyWith(showHolidays: value);
      await ref.read(calendarControllerProvider.notifier).updateCalendarSettings(
        selectedCalendar.id,
        newSettings,
      );

      // 顯示提示訊息
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(value ? '已開啟節日顯示' : '已關閉節日顯示'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('更新設定失敗：$e')),
        );
      }
    }
  }

  /// 更新顯示農曆設定
  Future<void> _updateShowLunar(BuildContext context, WidgetRef ref, bool value) async {
    final selectedCalendar = ref.read(selectedCalendarProvider);
    if (selectedCalendar == null) return;

    try {
      // 更新行事曆設定
      final newSettings = selectedCalendar.settings.copyWith(showLunar: value);
      await ref.read(calendarControllerProvider.notifier).updateCalendarSettings(
        selectedCalendar.id,
        newSettings,
      );

      // 顯示提示訊息
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(value ? '已開啟農曆顯示' : '已關閉農曆顯示'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('更新設定失敗：$e')),
        );
      }
    }
  }

  /// 顯示標籤設定面板
  void _showLabelSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _LabelSettingsSheet(),
    );
  }

  /// 顯示刪除行事曆確認對話框
  void _showDeleteCalendarConfirm(BuildContext context, WidgetRef ref) {
    final selectedCalendar = ref.read(selectedCalendarProvider);

    if (selectedCalendar == null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('沒有選擇的行事曆')),
      );
      return;
    }

    // 保存 sheet 的 Navigator，用於稍後關閉
    final sheetNavigator = Navigator.of(context);

    // 第一次確認
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除行事曆'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('確定要刪除「${selectedCalendar.name}」嗎？'),
            const SizedBox(height: 8),
            const Text(
              '⚠️ 此操作無法復原，該行事曆下的所有行程也會一併刪除。',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              // 第二次確認
              _showSecondDeleteConfirm(
                context,
                ref,
                selectedCalendar.name,
                selectedCalendar.id,
                sheetNavigator,
              );
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  /// 顯示第二次刪除確認對話框
  void _showSecondDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    String calendarName,
    String calendarId,
    NavigatorState sheetNavigator,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('再次確認'),
        content: Text(
          '您即將永久刪除「$calendarName」及其所有行程。\n\n確定要繼續嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // 先關閉確認對話框
              Navigator.pop(dialogContext);

              // 執行刪除
              final success = await ref
                  .read(calendarControllerProvider.notifier)
                  .deleteCalendar(calendarId);

              // 關閉設定 sheet
              if (sheetNavigator.mounted) {
                sheetNavigator.pop();
              }

              // 顯示結果訊息
              if (context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.clearSnackBars();
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('行事曆已刪除')),
                  );
                } else {
                  final errorMessage =
                      ref.read(calendarControllerProvider).errorMessage;
                  messenger.showSnackBar(
                    SnackBar(content: Text(errorMessage ?? '刪除失敗，請重試')),
                  );
                }
              }
            },
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
  }
}

/// 標籤設定面板
/// 
/// 顯示 12 種預設標籤的條列式清單，
/// 每個標籤顯示色塊和可編輯的名稱
class _LabelSettingsSheet extends ConsumerStatefulWidget {
  const _LabelSettingsSheet();

  @override
  ConsumerState<_LabelSettingsSheet> createState() => _LabelSettingsSheetState();
}

class _LabelSettingsSheetState extends ConsumerState<_LabelSettingsSheet> {
  /// 當前正在編輯的標籤 ID
  String? _editingLabelId;
  
  /// 文字編輯控制器
  late TextEditingController _editController;
  
  /// 焦點節點
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _focusNode = FocusNode();
    
    // 當焦點失去時，儲存編輯
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editingLabelId != null) {
        _saveEdit();
      }
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 開始編輯標籤
  void _startEditing(EventLabel label) {
    setState(() {
      _editingLabelId = label.id;
      _editController.text = label.name;
    });
    
    // 延遲一幀後聚焦，確保 TextField 已經建立
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// 儲存編輯
  void _saveEdit() {
    if (_editingLabelId != null && _editController.text.isNotEmpty) {
      final selectedCalendar = ref.read(selectedCalendarProvider);
      if (selectedCalendar != null) {
        // 使用 CalendarController 更新標籤名稱
        ref.read(calendarControllerProvider.notifier).updateLabelName(
          selectedCalendar.id,
          _editingLabelId!,
          _editController.text.trim(),
        );
      }
    }

    setState(() {
      _editingLabelId = null;
    });
  }

  /// 重設所有標籤為預設值
  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重設標籤'),
        content: const Text('確定要將所有標籤重設為預設值嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final selectedCalendar = ref.read(selectedCalendarProvider);
      if (selectedCalendar != null) {
        // 清空 labelNames，恢復使用預設名稱
        final newSettings = selectedCalendar.settings.copyWith(
          labelNames: {},
        );
        await ref.read(calendarControllerProvider.notifier).updateCalendarSettings(
          selectedCalendar.id,
          newSettings,
        );

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(content: Text('標籤已重設為預設值')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 監聽當前行事曆的標籤列表
    final labels = ref.watch(calendarLabelsProvider);
    
    return SafeArea(
      child: Container(
        // 設定最大高度為螢幕的 70%
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 標題區域
            Padding(
              padding: const EdgeInsets.all(kPaddingMedium),
              child: Row(
                children: [
                  // 返回按鈕
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.label,
                    color: Color(kPrimaryColorValue),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '行程標籤',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // 重設按鈕
                  TextButton(
                    onPressed: _resetToDefault,
                    child: const Text('重設'),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // 提示文字
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kPaddingMedium,
                vertical: kPaddingSmall,
              ),
              child: Text(
                '點擊標籤名稱可以直接編輯',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
            
            // 標籤列表
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: kPaddingMedium),
                itemCount: labels.length,
                itemBuilder: (context, index) {
                  final label = labels[index];
                  final isEditing = _editingLabelId == label.id;
                  
                  return _LabelListItem(
                    label: label,
                    isEditing: isEditing,
                    editController: _editController,
                    focusNode: _focusNode,
                    onTap: () => _startEditing(label),
                    onEditComplete: _saveEdit,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 標籤列表項目元件
/// 
/// 顯示單一標籤的色塊和名稱，
/// 支援點擊編輯名稱
class _LabelListItem extends StatelessWidget {
  /// 標籤資料
  final EventLabel label;
  
  /// 是否正在編輯
  final bool isEditing;
  
  /// 文字編輯控制器
  final TextEditingController editController;
  
  /// 焦點節點
  final FocusNode focusNode;
  
  /// 點擊回調
  final VoidCallback onTap;
  
  /// 編輯完成回調
  final VoidCallback onEditComplete;

  const _LabelListItem({
    required this.label,
    required this.isEditing,
    required this.editController,
    required this.focusNode,
    required this.onTap,
    required this.onEditComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kPaddingMedium,
        vertical: kPaddingSmall,
      ),
      child: Row(
        children: [
          // 圓形色塊
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: label.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: label.color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),
          
          // 標籤名稱（可編輯）
          Expanded(
            child: isEditing
                ? TextField(
                    controller: editController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 16),
                    onSubmitted: (_) => onEditComplete(),
                  )
                : GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 地區選擇底部面板
/// 
/// 類似提醒時間複選底部面板的樣式
/// 允許用戶選擇多個地區
class _RegionPickerBottomSheet extends StatefulWidget {
  /// 當前已選中的地區 ID 列表
  final List<String> selectedRegions;
  
  /// 確認選擇後的回調
  final void Function(List<String>) onConfirm;

  const _RegionPickerBottomSheet({
    required this.selectedRegions,
    required this.onConfirm,
  });

  @override
  State<_RegionPickerBottomSheet> createState() => _RegionPickerBottomSheetState();
}

class _RegionPickerBottomSheetState extends State<_RegionPickerBottomSheet> {
  /// 當前選中的地區（本地副本）
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedRegions);
  }

  @override
  Widget build(BuildContext context) {
    // 取得所有可用地區
    final availableRegions = HolidayManager.getAvailableRegions();
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 標題列
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kPaddingMedium,
                vertical: kPaddingSmall,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 取消按鈕
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                  // 標題
                  const Text(
                    '選擇地區',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  // 確認按鈕
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onConfirm(_selected);
                    },
                    child: const Text(
                      '確認',
                      style: TextStyle(
                        color: Color(kPrimaryColorValue),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // 地區選項列表
            ...availableRegions.map((region) {
              final isChecked = _selected.contains(region.id);
              
              return CheckboxListTile(
                title: Text(region.name),
                subtitle: region.isImplemented 
                    ? null 
                    : Text(
                        '即將推出',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                value: isChecked,
                activeColor: const Color(kPrimaryColorValue),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(region.id);
                    } else {
                      // 確保至少保留一個地區
                      if (_selected.length > 1) {
                        _selected.remove(region.id);
                      }
                    }
                  });
                },
              );
            }),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
