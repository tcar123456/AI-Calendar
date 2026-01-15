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

  /// 是否為檢視模式（預設 false，即編輯模式）
  final bool isViewMode;

  const EventDetailScreen({
    super.key,
    this.event,
    this.defaultDate,
    this.isViewMode = false,
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

  /// 是否顯示備註欄位
  bool _showDescription = false;

  /// 是否顯示地點欄位
  bool _showLocation = false;

  /// 是否為重複行程
  bool _isRepeat = false;

  /// 重複類型（daily/weekly/monthly）
  String? _repeatType;

  /// 當前是否為檢視模式
  late bool _isCurrentlyViewMode;

  /// 是否為編輯模式
  bool get isEditMode => widget.event != null;

  /// 是否有未儲存的變更
  bool _hasUnsavedChanges = false;

  /// 原始資料（用於判斷是否有變更）
  late String _originalTitle;
  late String _originalLocation;
  late String _originalDescription;
  late DateTime _originalStartDate;
  late TimeOfDay _originalStartTime;
  late DateTime _originalEndDate;
  late TimeOfDay _originalEndTime;
  late bool _originalIsAllDay;
  late Set<int> _originalReminders;
  late String? _originalLabelId;

  @override
  void initState() {
    super.initState();

    // 初始化檢視模式狀態
    _isCurrentlyViewMode = widget.isViewMode;

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
      // 如果有備註，預設展開備註欄位
      _showDescription = event.description?.isNotEmpty ?? false;
      // 如果有地點，預設展開地點欄位
      _showLocation = event.location?.isNotEmpty ?? false;
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

    // 儲存原始資料
    _saveOriginalData();

    // 監聽輸入變化
    _titleController.addListener(_checkForChanges);
    _locationController.addListener(_checkForChanges);
    _descriptionController.addListener(_checkForChanges);
  }

  /// 儲存原始資料
  void _saveOriginalData() {
    _originalTitle = _titleController.text;
    _originalLocation = _locationController.text;
    _originalDescription = _descriptionController.text;
    _originalStartDate = _startDate;
    _originalStartTime = _startTime;
    _originalEndDate = _endDate;
    _originalEndTime = _endTime;
    _originalIsAllDay = _isAllDay;
    _originalReminders = Set.from(_selectedReminders);
    _originalLabelId = _selectedLabelId;
  }

  /// 檢查是否有變更
  void _checkForChanges() {
    final hasChanges = _titleController.text != _originalTitle ||
        _locationController.text != _originalLocation ||
        _descriptionController.text != _originalDescription ||
        _startDate != _originalStartDate ||
        _startTime != _originalStartTime ||
        _endDate != _originalEndDate ||
        _endTime != _originalEndTime ||
        _isAllDay != _originalIsAllDay ||
        !_selectedReminders.containsAll(_originalReminders) ||
        !_originalReminders.containsAll(_selectedReminders) ||
        _selectedLabelId != _originalLabelId;

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_checkForChanges);
    _locationController.removeListener(_checkForChanges);
    _descriptionController.removeListener(_checkForChanges);
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventState = ref.watch(eventControllerProvider);

    // 計算高度：螢幕高度減去狀態列高度和 AppBar 高度，確保底部面板在狀態列下方
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight; // AppBar 標準高度 (56px)
    final bottomSheetHeight = screenHeight - statusBarHeight - appBarHeight;

    return PopScope(
      canPop: _canPop(),
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Container(
        height: bottomSheetHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 頂部拖動指示器和按鈕區域
                _buildHeader(eventState),

                // 內容區域
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: kPaddingMedium),
                    children: [
                      // 標題
                      if (_isCurrentlyViewMode)
                        _buildViewField(
                          label: '行程標題',
                          value: _titleController.text,
                          icon: Icons.title,
                        )
                      else
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
                      if (_isCurrentlyViewMode)
                        _buildViewField(
                          label: '行程類型',
                          value: _isAllDay ? '全天行程' : '一般行程',
                          icon: _isAllDay ? Icons.event_available : Icons.access_time,
                        )
                      else
                        SwitchListTile(
                          title: const Text('全天行程'),
                          value: _isAllDay,
                          onChanged: (value) {
                            setState(() {
                              _isAllDay = value;
                            });
                            _checkForChanges();
                          },
                          contentPadding: EdgeInsets.zero,
                        ),

                      const SizedBox(height: 16),

                      // 開始時間
                      if (_isCurrentlyViewMode)
                        _buildViewField(
                          label: '開始時間',
                          value: _isAllDay
                              ? DateFormat('yyyy/MM/dd').format(_startDate)
                              : '${DateFormat('yyyy/MM/dd').format(_startDate)} ${_startTime.format(context)}',
                          icon: Icons.calendar_today,
                        )
                      else
                        _buildDateTimeField(
                          label: '開始',
                          date: _startDate,
                          time: _startTime,
                          onDateTap: () => _selectDate(context, true),
                          onTimeTap: () => _selectTime(context, true),
                        ),

                      const SizedBox(height: 16),

                      // 結束時間
                      if (_isCurrentlyViewMode)
                        _buildViewField(
                          label: '結束時間',
                          value: _isAllDay
                              ? DateFormat('yyyy/MM/dd').format(_endDate)
                              : '${DateFormat('yyyy/MM/dd').format(_endDate)} ${_endTime.format(context)}',
                          icon: Icons.event,
                        )
                      else
                        _buildDateTimeField(
                          label: '結束',
                          date: _endDate,
                          time: _endTime,
                          onDateTap: () => _selectDate(context, false),
                          onTimeTap: () => _selectTime(context, false),
                        ),

                      const SizedBox(height: 16),

                      // 行程標籤
                      _buildLabelField(),

                      const SizedBox(height: 16),

                      // 提醒時間
                      _buildReminderField(),

                      const SizedBox(height: 16),

                      // 地點（開關控制）
                      _buildLocationField(),

                      const SizedBox(height: 4),

                      // 重複行程（僅在編輯/新增模式顯示開關）
                      _buildRepeatField(),

                      const SizedBox(height: 4),

                      // 備註（開關控制）
                      _buildDescriptionField(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 建立頂部區域（拖動指示器和按鈕）
  Widget _buildHeader(EventState eventState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // 拖動指示器
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 按鈕列
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左側：返回按鈕
              IconButton(
                onPressed: () => _handleBackNavigation(),
                icon: const Icon(Icons.arrow_back),
                color: Colors.grey[600],
              ),

              // 右側：操作按鈕
              if (_isCurrentlyViewMode)
                // 檢視模式：顯示「...」選單
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  popUpAnimationStyle: AnimationStyle(
                    duration: const Duration(milliseconds: 100),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                         
                          SizedBox(width: 12),
                          Text(
                            '編輯',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          
                          SizedBox(width: 12),
                          Text(
                            '複製',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                         
                          SizedBox(width: 12),
                          Text(
                            '刪除',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _switchToEditMode();
                    } else if (value == 'duplicate') {
                      _handleDuplicate();
                    } else if (value == 'delete') {
                      _handleDelete();
                    }
                  },
                )
              else
                // 編輯/新增模式：顯示儲存按鈕
                TextButton(
                  onPressed: eventState.isLoading ? null : _handleSave,
                  child: eventState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(kPrimaryColorValue),
                          ),
                        )
                      : const Text(
                          '儲存',
                          style: TextStyle(
                            color: Color(kPrimaryColorValue),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 建立地點欄位（帶開關控制）
  Widget _buildLocationField() {
    // 檢視模式：顯示地點內容（如果有的話）
    if (_isCurrentlyViewMode) {
      if (_locationController.text.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildViewField(
        label: '地點',
        value: _locationController.text,
        icon: Icons.location_on,
      );
    }

    // 編輯/新增模式：顯示開關
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 地點開關
        SwitchListTile(
          title: const Text('地點'),
          value: _showLocation,
          onChanged: (value) {
            setState(() {
              _showLocation = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.location_on),
        ),

        // 地點輸入框（展開時顯示）
        if (_showLocation) ...[
          const SizedBox(height: 4),
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: '輸入地點...',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 建立備註欄位（帶開關控制）
  Widget _buildDescriptionField() {
    // 檢視模式：顯示備註內容（如果有的話）
    if (_isCurrentlyViewMode) {
      if (_descriptionController.text.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildViewField(
        label: '備註',
        value: _descriptionController.text,
        icon: Icons.notes,
        maxLines: 3,
      );
    }

    // 編輯/新增模式：顯示開關
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 備註開關
        SwitchListTile(
          title: const Text('備註'),
          value: _showDescription,
          onChanged: (value) {
            setState(() {
              _showDescription = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notes),
        ),

        // 備註輸入框（展開時顯示）
        if (_showDescription) ...[
          const SizedBox(height: 4),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: '輸入備註內容...',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            maxLines: 3,
          ),
        ],
      ],
    );
  }

  /// 建立重複行程欄位
  Widget _buildRepeatField() {
    // 檢視模式：如果有重複設定則顯示
    if (_isCurrentlyViewMode) {
      if (!_isRepeat || _repeatType == null) {
        return const SizedBox.shrink();
      }
      final repeatText = {
        'daily': '每日',
        'weekly': '每週',
        'monthly': '每月',
      }[_repeatType] ?? '';
      return _buildViewField(
        label: '重複',
        value: repeatText,
        icon: Icons.repeat,
      );
    }

    // 編輯/新增模式：顯示開關和選項
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 重複開關
        SwitchListTile(
          title: const Text('重複'),
          value: _isRepeat,
          onChanged: (value) {
            setState(() {
              _isRepeat = value;
              if (!value) {
                _repeatType = null;
              } else if (_repeatType == null) {
                _repeatType = 'daily'; // 預設每日
              }
            });
            _checkForChanges();
          },
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.repeat),
        ),

        // 重複選項（展開時顯示）
        if (_isRepeat) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              _buildRepeatOption('daily', '每日'),
              const SizedBox(width: 12),
              _buildRepeatOption('weekly', '每週'),
              const SizedBox(width: 12),
              _buildRepeatOption('monthly', '每月'),
            ],
          ),
        ],
      ],
    );
  }

  /// 建立重複選項按鈕
  Widget _buildRepeatOption(String value, String label) {
    final isSelected = _repeatType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _repeatType = value;
          });
          _checkForChanges();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(kPrimaryColorValue) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 判斷是否可以直接關閉頁面
  bool _canPop() {
    // 檢視模式：可以直接關閉
    if (_isCurrentlyViewMode) return true;

    // 編輯模式：如果是從檢視模式進入的，不能直接關閉（要回到檢視模式）
    if (!_isCurrentlyViewMode && isEditMode && widget.isViewMode) {
      return false;
    }

    // 編輯/新增模式但沒有變更：可以直接關閉
    if (!_hasUnsavedChanges) return true;

    // 有未儲存的變更：不能直接關閉
    return false;
  }

  /// 處理返回導航
  Future<void> _handleBackNavigation() async {
    // 如果在編輯模式且原本是從檢視模式進來的，返回檢視模式
    if (!_isCurrentlyViewMode && isEditMode && widget.isViewMode) {
      // 如果有未儲存的變更，詢問是否捨棄
      if (_hasUnsavedChanges) {
        final shouldDiscard = await _showDiscardChangesDialog();
        if (shouldDiscard != true) return;

        // 恢復原始資料
        _restoreOriginalData();
      }

      setState(() {
        _isCurrentlyViewMode = true;
        _hasUnsavedChanges = false;
      });
      return;
    }

    // 如果有未儲存的變更，顯示確認對話框
    if (_hasUnsavedChanges) {
      final shouldDiscard = await _showDiscardChangesDialog();
      if (shouldDiscard == true && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // 其他情況直接返回
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 恢復原始資料
  void _restoreOriginalData() {
    _titleController.text = _originalTitle;
    _locationController.text = _originalLocation;
    _descriptionController.text = _originalDescription;
    _startDate = _originalStartDate;
    _startTime = _originalStartTime;
    _endDate = _originalEndDate;
    _endTime = _originalEndTime;
    _isAllDay = _originalIsAllDay;
    _selectedReminders = Set.from(_originalReminders);
    _selectedLabelId = _originalLabelId;
  }

  /// 顯示捨棄變更確認對話框
  Future<bool?> _showDiscardChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('捨棄變更？'),
        content: const Text('您有未儲存的變更，確定要捨棄嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('捨棄'),
          ),
        ],
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

    // 檢視模式：顯示當前標籤
    if (_isCurrentlyViewMode) {
      final currentLabel = labels.firstWhere(
        (label) => label.id == _selectedLabelId,
        orElse: () => labels.first,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '行程標籤',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: currentLabel.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  currentLabel.name,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 編輯模式：顯示下拉選單
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
              _checkForChanges();
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
    // 檢視模式：顯示當前提醒時間
    if (_isCurrentlyViewMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '提醒時間',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getSelectedRemindersText(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 編輯模式：顯示可選擇的欄位
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
      _checkForChanges();
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
      _checkForChanges();
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
          _checkForChanges();
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
      // 儲存成功，重置變更標記
      setState(() {
        _hasUnsavedChanges = false;
      });
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

  /// 切換到編輯模式
  void _switchToEditMode() {
    setState(() {
      _isCurrentlyViewMode = false;
    });
  }

  /// 處理複製行程
  Future<void> _handleDuplicate() async {
    if (!isEditMode) return;

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

    final eventController = ref.read(eventControllerProvider.notifier);

    // 取得提醒時間（使用最早的提醒，或 0 表示不提醒）
    final reminderMinutes = _selectedReminders.isEmpty
        ? 0
        : (_selectedReminders.toList()..sort()).first;

    // 建立複製的行程（標題加上「副本」）
    final eventId = await eventController.createManualEvent(
      title: '${_titleController.text.trim()}（副本）',
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

    if (eventId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('行程已複製')),
      );
      Navigator.of(context).pop();
    }
  }

  /// 建立檢視模式的只讀欄位
  Widget _buildViewField({
    required String label,
    required String value,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  maxLines: maxLines,
                  overflow: maxLines > 1 ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
