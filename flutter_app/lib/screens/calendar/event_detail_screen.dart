import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
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
  late int _reminderMinutes;

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
      _reminderMinutes = event.reminderMinutes;
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
      _reminderMinutes = kDefaultReminderMinutes;
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
                prefixIcon: Icon(Icons.title),
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
              label: '開始時間',
              date: _startDate,
              time: _startTime,
              onDateTap: () => _selectDate(context, true),
              onTimeTap: () => _selectTime(context, true),
            ),
            
            const SizedBox(height: 16),
            
            // 結束時間
            _buildDateTimeField(
              label: '結束時間',
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

  /// 建立日期時間選擇欄位
  Widget _buildDateTimeField({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // 日期選擇
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: onDateTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Text(DateFormat('yyyy/MM/dd').format(date)),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 時間選擇（全天行程時隱藏）
            if (!_isAllDay)
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: onTimeTap,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 20),
                        const SizedBox(width: 8),
                        Text(time.format(context)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 建立提醒時間選擇欄位
  Widget _buildReminderField() {
    final reminderOptions = {
      0: '不提醒',
      5: '5 分鐘前',
      15: '15 分鐘前',
      30: '30 分鐘前',
      60: '1 小時前',
      1440: '1 天前',
    };

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
        DropdownButtonFormField<int>(
          value: _reminderMinutes,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.notifications),
            filled: true,
            fillColor: Colors.grey[100],
          ),
          items: reminderOptions.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _reminderMinutes = value;
              });
            }
          },
        ),
      ],
    );
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
          // 如果開始日期晚於結束日期，自動調整結束日期
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
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

  /// 選擇時間
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final initialTime = isStart ? _startTime : _endTime;
    
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      setState(() {
        if (isStart) {
          _startTime = pickedTime;
        } else {
          _endTime = pickedTime;
        }
      });
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
        reminderMinutes: _reminderMinutes,
        isAllDay: _isAllDay,
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
        reminderMinutes: _reminderMinutes,
        isAllDay: _isAllDay,
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

