import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/event_label_model.dart';
import '../../providers/event_provider.dart';
import '../../providers/event_label_provider.dart';
import '../../utils/constants.dart';

/// 行程詳情畫面
/// 
/// 用於檢視、新增或編輯行程
class EventDetailScreen extends ConsumerStatefulWidget {
  /// 要編輯的行程（null 表示新增）
  final CalendarEvent? event;
  
  /// 預設日期（用於新增行程時）
  final DateTime? defaultDate;

  const EventDetailScreen({
    super.key,
    this.event,
    this.defaultDate,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // 表單控制器
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  
  // 日期時間
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  
  // 其他設定
  late bool _isAllDay;
  /// 提醒時間選項（複選，可選擇多個）
  late Set<int> _selectedReminders;
  
  // 行程標籤
  String? _selectedLabelId;

  /// 是否為編輯模式
  bool get isEditMode => widget.event != null;

  @override
  void initState() {
    super.initState();
    
    if (isEditMode) {
      // 編輯模式：載入現有資料
      final event = widget.event!;
      _titleController = TextEditingController(text: event.title);
      _locationController = TextEditingController(text: event.location ?? '');
      _descriptionController = TextEditingController(text: event.description ?? '');
      
      _startDate = event.startTime;
      _startTime = TimeOfDay.fromDateTime(event.startTime);
      _endDate = event.endTime;
      _endTime = TimeOfDay.fromDateTime(event.endTime);
      
      _isAllDay = event.isAllDay;
      // 將單一提醒時間轉換為 Set（向後相容）
      _selectedReminders = event.reminderMinutes > 0 ? {event.reminderMinutes} : {};
      _selectedLabelId = event.labelId;
    } else {
      // 新增模式：使用預設值
      _titleController = TextEditingController();
      _locationController = TextEditingController();
      _descriptionController = TextEditingController();
      
      final defaultDate = widget.defaultDate ?? DateTime.now();
      _startDate = defaultDate;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endDate = defaultDate;
      _endTime = const TimeOfDay(hour: 10, minute: 0);
      
      _isAllDay = false;
      _selectedReminders = {kDefaultReminderMinutes}; // 預設 15 分鐘前提醒
      _selectedLabelId = DefaultEventLabels.defaultLabel.id; // 預設使用第一個標籤（工作）
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventState = ref.watch(eventControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? '編輯行程' : '新增行程'),
        actions: [
          // 刪除按鈕（僅編輯模式）
          if (isEditMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _handleDelete(),
            ),
        ],
      ),
      
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(kPaddingMedium),
          children: [
            // 標題
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '行程標題 *',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '請輸入行程標題';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 全天行程開關
            SwitchListTile(
              title: const Text('全天行程'),
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 16),
            
            // 開始時間
            _buildDateTimeField(
              label: '開始',
              date: _startDate,
              time: _startTime,
              onDateTap: () => _selectDate(context, true),
              onTimeTap: () => _selectTime(context, true),
            ),
            
            const SizedBox(height: 16),
            
            // 結束時間
            _buildDateTimeField(
              label: '結束',
              date: _endDate,
              time: _endTime,
              onDateTap: () => _selectDate(context, false),
              onTimeTap: () => _selectTime(context, false),
            ),
            
            const SizedBox(height: 16),
            
            // 地點
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '地點',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 備註
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '備註',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // 行程標籤
            _buildLabelField(),
            
            const SizedBox(height: 16),
            
            // 提醒時間
            _buildReminderField(),
            
            const SizedBox(height: 32),
            
            // 儲存按鈕
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: eventState.isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(kPrimaryColorValue),
                  foregroundColor: Colors.white,
                ),
                child: eventState.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(isEditMode ? '更新行程' : '建立行程'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建立日期時間選擇欄位（標籤放在左邊）
  Widget _buildDateTimeField({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Row(
      children: [
        // 左側標籤
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.black,
            ),
          ),
        ),
        
        // 日期選擇
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: onDateTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy/MM/dd').format(date),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // 時間選擇（全天行程時隱藏）
        if (!_isAllDay) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: onTimeTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        time.format(context),
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 建立行程標籤選擇欄位（下拉式選單）
  Widget _buildLabelField() {
    // 監聽標籤列表
    final labels = ref.watch(eventLabelsProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '行程標籤',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        
        // 使用下拉式選單選擇標籤
        DropdownButtonFormField<String>(
          value: _selectedLabelId,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: labels.map((label) {
            return DropdownMenuItem<String>(
              value: label.id,
              child: Row(
                children: [
                  // 色塊
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: label.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 標籤名稱
                  Text(
                    label.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedLabelId = value;
              });
            }
          },
          // 自訂下拉選單樣式
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 提醒選項對照表
  static const Map<int, String> _reminderOptions = {
    5: '5 分鐘前',
    15: '15 分鐘前',
    30: '30 分鐘前',
    60: '1 小時前',
    120: '2 小時前',
    1440: '1 天前',
  };

  /// 取得選中提醒的顯示文字
  String _getSelectedRemindersText() {
    if (_selectedReminders.isEmpty) {
      return '不提醒';
    }
    // 按時間排序後用「、」連接
    final sortedReminders = _selectedReminders.toList()..sort();
    return sortedReminders
        .map((minutes) => _reminderOptions[minutes] ?? '')
        .where((text) => text.isNotEmpty)
        .join('、');
  }

  /// 建立提醒時間選擇欄位（複選）
  Widget _buildReminderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '提醒時間',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        // 點擊後顯示複選對話框
        InkWell(
          onTap: () => _showReminderPicker(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getSelectedRemindersText(),
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedReminders.isEmpty ? Colors.grey[500] : Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 顯示提醒時間複選對話框
  Future<void> _showReminderPicker() async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReminderPickerBottomSheet(
        selectedReminders: _selectedReminders,
        options: _reminderOptions,
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedReminders = result;
      });
    }
  }

  /// 選擇日期
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'TW'),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
          // 自動調整結束時間（如果開始時間超過結束時間）
          _autoAdjustEndTime();
        } else {
          _endDate = pickedDate;
          // 如果結束日期早於開始日期，自動調整開始日期
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  /// 選擇時間（使用滾動選取器）
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final initialTime = isStart ? _startTime : _endTime;
    
    // 使用自訂的滾動時間選擇器
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _TimePickerBottomSheet(
        initialTime: initialTime,
        onTimeSelected: (time) {
          setState(() {
            if (isStart) {
              _startTime = time;
              // 自動調整結束時間：如果開始時間超過結束時間，結束時間設為開始時間+1小時
              _autoAdjustEndTime();
            } else {
              _endTime = time;
            }
          });
        },
      ),
    );
  }

  /// 自動調整結束時間
  /// 
  /// 當開始時間超過結束時間時，將結束時間設為開始時間+1小時
  void _autoAdjustEndTime() {
    // 組合完整的開始和結束 DateTime
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    
    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    
    // 如果開始時間超過或等於結束時間，自動將結束時間設為開始時間+1小時
    if (!startDateTime.isBefore(endDateTime)) {
      final newEndDateTime = startDateTime.add(const Duration(hours: 1));
      _endDate = DateTime(newEndDateTime.year, newEndDateTime.month, newEndDateTime.day);
      _endTime = TimeOfDay(hour: newEndDateTime.hour, minute: newEndDateTime.minute);
    }
  }

  /// 處理儲存
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 組合日期和時間
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _isAllDay ? 23 : _endTime.hour,
      _isAllDay ? 59 : _endTime.minute,
    );

    // 驗證時間邏輯
    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('結束時間不能早於開始時間'),
          backgroundColor: Color(kErrorColorValue),
        ),
      );
      return;
    }

    final eventController = ref.read(eventControllerProvider.notifier);

    // 取得提醒時間（使用最早的提醒，或 0 表示不提醒）
    final reminderMinutes = _selectedReminders.isEmpty 
        ? 0 
        : (_selectedReminders.toList()..sort()).first;

    bool success;
    if (isEditMode) {
      // 更新現有行程
      final updatedEvent = widget.event!.copyWith(
        title: _titleController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        reminderMinutes: reminderMinutes,
        isAllDay: _isAllDay,
        labelId: _selectedLabelId,
        updatedAt: DateTime.now(),
      );

      success = await eventController.updateEvent(widget.event!.id, updatedEvent);
    } else {
      // 建立新行程
      final eventId = await eventController.createManualEvent(
        title: _titleController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        reminderMinutes: reminderMinutes,
        isAllDay: _isAllDay,
        labelId: _selectedLabelId,
      );

      success = eventId != null;
    }

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 處理刪除
  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除行程'),
        content: const Text('確定要刪除這個行程嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final eventController = ref.read(eventControllerProvider.notifier);
      final success = await eventController.deleteEvent(widget.event!.id);

      if (success && mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

/// 滾動式時間選擇器底部面板
/// 
/// 使用兩個滾動選取器分別選擇小時和分鐘
class _TimePickerBottomSheet extends StatefulWidget {
  /// 初始時間
  final TimeOfDay initialTime;
  
  /// 選擇完成的回調
  final ValueChanged<TimeOfDay> onTimeSelected;

  const _TimePickerBottomSheet({
    required this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<_TimePickerBottomSheet> createState() => _TimePickerBottomSheetState();
}

class _TimePickerBottomSheetState extends State<_TimePickerBottomSheet> {
  /// 當前選擇的小時
  late int _selectedHour;
  
  /// 當前選擇的分鐘索引（0-5，對應 0, 10, 20, 30, 40, 50 分鐘）
  late int _selectedMinuteIndex;
  
  /// 分鐘選項列表（每 10 分鐘為間隔）
  static const List<int> _minuteOptions = [0, 10, 20, 30, 40, 50];
  
  /// 小時滾動控制器
  late FixedExtentScrollController _hourController;
  
  /// 分鐘滾動控制器
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    
    // 將初始分鐘四捨五入到最近的 10 分鐘，並轉換為索引
    final initialMinute = widget.initialTime.minute;
    _selectedMinuteIndex = ((initialMinute + 5) ~/ 10).clamp(0, 5);
    // 如果四捨五入後是 60，則設為 50（索引 5）
    if (_selectedMinuteIndex > 5) _selectedMinuteIndex = 5;
    
    // 初始化滾動控制器，定位到初始值
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinuteIndex);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 頂部拖動指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 標題和按鈕列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    '選擇時間',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  // 確認按鈕
                  TextButton(
                    onPressed: () {
                      // 將索引轉換回實際分鐘數
                      final selectedMinute = _minuteOptions[_selectedMinuteIndex];
                      widget.onTimeSelected(
                        TimeOfDay(hour: _selectedHour, minute: selectedMinute),
                      );
                      Navigator.of(context).pop();
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
            
            // 時間選擇器
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  // 小時選擇器
                  Expanded(
                    child: _buildWheelPicker(
                      controller: _hourController,
                      itemCount: 24,
                      selectedValue: _selectedHour,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedHour = index);
                      },
                      labelBuilder: (index) => index.toString().padLeft(2, '0'),
                      suffix: '時',
                    ),
                  ),
                  
                  // 分隔符
                  const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  
                  // 分鐘選擇器（每 10 分鐘為間隔）
                  Expanded(
                    child: _buildWheelPicker(
                      controller: _minuteController,
                      itemCount: _minuteOptions.length,
                      selectedValue: _selectedMinuteIndex,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedMinuteIndex = index);
                      },
                      labelBuilder: (index) => _minuteOptions[index].toString().padLeft(2, '0'),
                      suffix: '分',
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 建立滾動選擇器
  Widget _buildWheelPicker({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedValue,
    required ValueChanged<int> onSelectedItemChanged,
    required String Function(int) labelBuilder,
    required String suffix,
  }) {
    return Stack(
      children: [
        // 選中項目的背景高亮
        Center(
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        
        // 滾動選擇器
        CupertinoPicker(
          scrollController: controller,
          itemExtent: 44,
          diameterRatio: 1.5,
          squeeze: 1.0,
          selectionOverlay: null, // 移除預設的選中覆蓋層
          onSelectedItemChanged: onSelectedItemChanged,
          children: List.generate(itemCount, (index) {
            final isSelected = index == selectedValue;
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labelBuilder(index),
                    style: TextStyle(
                      fontSize: isSelected ? 22 : 18,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    suffix,
                    style: TextStyle(
                      fontSize: isSelected ? 14 : 12,
                      color: isSelected ? Colors.black54 : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// 提醒時間複選底部面板
/// 
/// 允許用戶選擇多個提醒時間
class _ReminderPickerBottomSheet extends StatefulWidget {
  /// 當前已選中的提醒時間
  final Set<int> selectedReminders;
  
  /// 提醒選項
  final Map<int, String> options;

  const _ReminderPickerBottomSheet({
    required this.selectedReminders,
    required this.options,
  });

  @override
  State<_ReminderPickerBottomSheet> createState() => _ReminderPickerBottomSheetState();
}

class _ReminderPickerBottomSheetState extends State<_ReminderPickerBottomSheet> {
  /// 當前選中的提醒時間（本地副本）
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedReminders);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 頂部拖動指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 標題和按鈕列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    '選擇提醒時間',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  // 確認按鈕
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
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
            
            // 提醒選項列表
            ...widget.options.entries.map((entry) {
              final isChecked = _selected.contains(entry.key);
              return CheckboxListTile(
                title: Text(entry.value),
                value: isChecked,
                activeColor: const Color(kPrimaryColorValue),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(entry.key);
                    } else {
                      _selected.remove(entry.key);
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
