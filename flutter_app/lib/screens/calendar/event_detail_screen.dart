import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/event_label_model.dart';
import '../../models/recurrence_rule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/event_label_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/recurrence_service.dart';
import '../../utils/constants.dart';
import 'widgets/repeat_settings_page.dart';

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

  /// 選擇的行事曆 ID（總覽模式下使用）
  String? _selectedCalendarId;

  /// 是否顯示備註欄位
  bool _showDescription = false;

  /// 重複設定
  RepeatSettings _repeatSettings = const RepeatSettings();

  /// 當前是否為檢視模式
  late bool _isCurrentlyViewMode;

  /// 是否為編輯模式
  bool get isEditMode => widget.event != null;

  /// 動畫方向：true = 向左滑入（進入編輯模式），false = 向右滑入（返回檢視模式）
  bool _isTransitioningToEdit = true;

  /// 是否顯示重複設定頁面（在同一面板內向左推入）
  bool _showRepeatPage = false;

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
  late String? _originalCalendarId;

  /// 滾動控制器（用於追蹤 ListView 滾動位置）
  final ScrollController _scrollController = ScrollController();

  /// 累積的 overscroll 距離（用於判斷是否應該關閉面板）
  double _overscrollAccumulator = 0;

  /// 更多選單按鈕的 GlobalKey（用於計算重複行程選單彈出位置）
  final GlobalKey _moreButtonKey = GlobalKey();

  /// 備註區域的 GlobalKey（用於自動滾動）
  final GlobalKey _descriptionKey = GlobalKey();

  /// 地點輸入框的 GlobalKey（用於自動滾動）
  final GlobalKey _locationKey = GlobalKey();

  /// 地點輸入框的 FocusNode
  final FocusNode _locationFocusNode = FocusNode();

  /// 備註輸入框的 FocusNode
  final FocusNode _descriptionFocusNode = FocusNode();

  /// 額外的底部空間（當地點或備註輸入框獲得焦點時）
  double _extraBottomPadding = 0;

  /// 當前展開的選擇器類型（null, 'startDate', 'startTime', 'endDate', 'endTime'）
  String? _expandedPicker;

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
      _selectedCalendarId = event.calendarId;
      // 如果有備註，預設展開備註欄位
      _showDescription = event.description?.isNotEmpty ?? false;
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
      _selectedCalendarId = null; // 會在 build 後透過 WidgetsBinding 初始化
    }

    // 儲存原始資料
    _saveOriginalData();

    // 新增模式：在 build 後取得預設行事曆 ID
    if (!isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initDefaultCalendarId();
      });
    }

    // 監聽輸入變化
    _titleController.addListener(_checkForChanges);
    _locationController.addListener(_checkForChanges);
    _descriptionController.addListener(_checkForChanges);

    // 監聽焦點變化，當獲得焦點時自動滾動到可見位置
    _locationFocusNode.addListener(_onLocationFocusChange);
    _descriptionFocusNode.addListener(_onDescriptionFocusChange);
  }

  /// 地點輸入框焦點變更（不做延展或滾動，但失去焦點時檢查是否收起 padding）
  void _onLocationFocusChange() {
    if (_locationFocusNode.hasFocus) {
      // 地點獲得焦點：不延展也不滾動
    } else {
      // 地點失去焦點：延遲檢查，避免切換時先收再開
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && !_descriptionFocusNode.hasFocus && !_locationFocusNode.hasFocus) {
          setState(() => _extraBottomPadding = 0);
        }
      });
    }
  }

  /// 備註輸入框獲得焦點時滾動到可見位置並延展底部空間
  void _onDescriptionFocusChange() {
    if (_descriptionFocusNode.hasFocus) {
      // 備註獲得焦點：直接設為 250
      setState(() => _extraBottomPadding = 250);
      _scrollToWidget(_descriptionKey);
    } else {
      // 備註失去焦點：延遲檢查，避免切換時先收再開
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && !_locationFocusNode.hasFocus && !_descriptionFocusNode.hasFocus) {
          setState(() => _extraBottomPadding = 0);
        }
      });
    }
  }

  /// 滾動到指定 widget 可見位置
  void _scrollToWidget(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        // 當需要額外底部空間時（鍵盤彈出），滾動到更靠近頂部的位置
        final alignment = _extraBottomPadding > 0 ? 0.1 : 0.3;
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: alignment,
        );
      }
    });
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
    _originalCalendarId = _selectedCalendarId;
  }

  /// 初始化預設行事曆 ID（新增模式）
  void _initDefaultCalendarId() {
    final isOverviewMode = ref.read(isOverviewModeProvider);
    if (isOverviewMode && _selectedCalendarId == null) {
      // 總覽模式：取得預設行事曆或第一個行事曆
      final calendarsAsync = ref.read(calendarsProvider);
      calendarsAsync.whenData((calendars) {
        if (calendars.isNotEmpty) {
          // 優先選擇預設行事曆，否則選第一個
          final defaultCalendar = calendars.firstWhere(
            (c) => c.isDefault,
            orElse: () => calendars.first,
          );
          setState(() {
            _selectedCalendarId = defaultCalendar.id;
            _originalCalendarId = defaultCalendar.id;
          });
        }
      });
    } else if (!isOverviewMode) {
      // 非總覽模式：使用當前選擇的行事曆
      final selectedCalendar = ref.read(selectedCalendarProvider);
      if (selectedCalendar != null && _selectedCalendarId == null) {
        setState(() {
          _selectedCalendarId = selectedCalendar.id;
          _originalCalendarId = selectedCalendar.id;
        });
      }
    }
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
        _selectedLabelId != _originalLabelId ||
        _selectedCalendarId != _originalCalendarId;

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
    _locationFocusNode.removeListener(_onLocationFocusChange);
    _descriptionFocusNode.removeListener(_onDescriptionFocusChange);
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    _locationFocusNode.dispose();
    _descriptionFocusNode.dispose();
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

                // 內容區域（支援整個面板下滑關閉）
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      // 計算當前頁面的 key
                      final currentPageKey = _showRepeatPage
                          ? 'repeat'
                          : (_isCurrentlyViewMode ? 'view' : 'edit');
                      final isEntering = child.key == ValueKey(currentPageKey);

                      Offset beginOffset;
                      if (isEntering) {
                        // 進入的 widget - 從右邊滑入
                        beginOffset = _isTransitioningToEdit
                            ? const Offset(1.0, 0.0)
                            : const Offset(-1.0, 0.0);
                      } else {
                        // 離開的 widget - 向左滑出
                        beginOffset = _isTransitioningToEdit
                            ? const Offset(-1.0, 0.0)
                            : const Offset(1.0, 0.0);
                      }

                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: beginOffset,
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        )),
                        child: child,
                      );
                    },
                    layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: _showRepeatPage
                        ? RepeatSettingsPage(
                            key: const ValueKey('repeat'),
                            initialSettings: _repeatSettings,
                            defaultStartDate: _startDate,
                            onSettingsChanged: (settings) {
                              setState(() => _repeatSettings = settings);
                            },
                            onBack: _hideRepeatPicker,
                          )
                        : NotificationListener<ScrollNotification>(
                      key: ValueKey(_isCurrentlyViewMode ? 'view' : 'edit'),
                      onNotification: (notification) {
                        // 當處於編輯/新增模式時，禁用下滑關閉功能
                        // 避免用戶在編輯時意外下滑導致資料遺失
                        if (!_isCurrentlyViewMode) {
                          return false; // 不處理 overscroll，禁用下滑關閉
                        }

                        // 處理 overscroll 事件：當在頂部繼續向下拖動時關閉面板
                        if (notification is OverscrollNotification) {
                          // 只處理向下的 overscroll（負值表示向下拉）
                          if (notification.overscroll < 0) {
                            _overscrollAccumulator += notification.overscroll.abs();
                            // 當累積的 overscroll 超過閾值時，關閉面板
                            if (_overscrollAccumulator > 150) {
                              _overscrollAccumulator = 0;
                              _handleBackNavigation();
                            }
                          }
                        } else if (notification is ScrollUpdateNotification) {
                          // 重置累積器（用戶開始正常滾動時）
                          if (notification.scrollDelta != null && notification.scrollDelta! > 0) {
                            _overscrollAccumulator = 0;
                          }
                        }
                        return false; // 不攔截通知，讓其繼續傳遞
                      },
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: kPaddingMedium,
                          right: kPaddingMedium,
                          // 當地點或備註輸入框獲得焦點時，增加底部空間以避免被鍵盤遮蔽
                          bottom: MediaQuery.of(context).viewInsets.bottom +
                                  (_extraBottomPadding > 0 ? _extraBottomPadding : 32),
                        ),
                        children: [
                      // 標題
                      if (_isCurrentlyViewMode)
                        _buildViewTitleSection()
                      else ...[
                        const SizedBox(height: 2),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: '行程標題 *',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '請輸入行程標題';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 全天行程開關（僅編輯模式顯示）
                      if (!_isCurrentlyViewMode)
                        ListTile(
                          title: const Text('全天行程'),
                          trailing: Transform.scale(
                            scale: 0.7,
                            child: Switch(
                              value: _isAllDay,
                              onChanged: (value) {
                                FocusScope.of(context).unfocus(); // 收起鍵盤
                                setState(() {
                                  _isAllDay = value;
                                  // 當切換為全天行程時，收合時間選擇器
                                  if (value && (_expandedPicker == 'startTime' || _expandedPicker == 'endTime')) {
                                    _expandedPicker = null;
                                  }
                                });
                                _checkForChanges();
                              },
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),

                      if (!_isCurrentlyViewMode)
                        const SizedBox(height: 16),

                      // 時間
                      if (_isCurrentlyViewMode)
                        _buildViewTimeCard()
                      else ...[
                        _buildDateTimeField(
                          label: '開始',
                          date: _startDate,
                          time: _startTime,
                          isStart: true,
                        ),
                        const SizedBox(height: 16),
                        _buildDateTimeField(
                          label: '結束',
                          date: _endDate,
                          time: _endTime,
                          isStart: false,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 所屬行事曆（總覽模式時顯示）
                      _buildCalendarField(),

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
    // 重複設定頁面有自己的標題列，這裡只顯示拖動指示器
    if (_showRepeatPage) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

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
                  key: _moreButtonKey,
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
                          Expanded(
                            child: Text(
                              '複製到',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'move',
                      child: Row(
                        children: [

                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '移動到',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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
                      _showCalendarSubMenu(isCopy: true);
                    } else if (value == 'move') {
                      _showCalendarSubMenu(isCopy: false);
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
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          '儲存',
                          style: TextStyle(
                            color: Colors.black,
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

  /// 建立地點欄位（直接輸入框 + X 重置按鈕）
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

    // 編輯/新增模式：直接顯示輸入框（無邊框樣式）
    return Row(
      key: _locationKey,
      children: [
        // 地點圖示
        Icon(
          Icons.location_on_outlined,
          color: Colors.grey[600],
          size: 24,
        ),
        const SizedBox(width: 12),
        // 地點輸入框（無邊框）
        Expanded(
          child: TextFormField(
            controller: _locationController,
            focusNode: _locationFocusNode,
            decoration: InputDecoration(
              hintText: '無地點',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        // X 重置按鈕（只在有內容時顯示）
        if (_locationController.text.isNotEmpty) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus(); // 收起鍵盤
              setState(() {
                _locationController.clear();
              });
              _checkForChanges();
            },
            child: Icon(
              Icons.close,
              size: 18,
              color: Colors.grey[500],
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
      key: _descriptionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 備註開關
        ListTile(
          leading: const Icon(Icons.notes),
          title: const Text('備註'),
          trailing: Transform.scale(
            scale: 0.7,
            child: Switch(
              value: _showDescription,
              onChanged: (value) {
                FocusScope.of(context).unfocus(); // 收起鍵盤
                setState(() {
                  _showDescription = value;
                });
                // 當打開備註開關時，自動滾動到備註區域可見位置
                if (value) {
                  _scrollToWidget(_descriptionKey);
                }
              },
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),

        // 備註輸入框（展開時顯示）
        if (_showDescription) ...[
          const SizedBox(height: 4),
          TextFormField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
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

  /// 建立重複行程欄位（點擊開啟底部面板）
  Widget _buildRepeatField() {
    // 檢視模式：如果有重複設定則顯示
    if (_isCurrentlyViewMode) {
      if (!_repeatSettings.isRepeat || _repeatSettings.repeatType == null) {
        return const SizedBox.shrink();
      }
      return _buildViewField(
        label: '重複',
        value: _repeatSettings.getDisplayText(),
        icon: Icons.repeat,
      );
    }

    // 編輯模式：不顯示重複設定（只能在新增時設定）
    if (isEditMode) {
      return const SizedBox.shrink();
    }

    // 新增模式：點擊開啟重複設定面板（無邊框樣式，不可輸入）
    return Row(
      children: [
        // 重複圖示
        Icon(
          Icons.repeat,
          color: Colors.grey[600],
          size: 24,
        ),
        const SizedBox(width: 12),
        // 重複設定顯示區域（點擊開啟面板，不可直接輸入）
        Expanded(
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus(); // 收起鍵盤
              _showRepeatPicker();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
              child: Text(
                _repeatSettings.getDisplayText(),
                style: TextStyle(
                  fontSize: 15,
                  color: _repeatSettings.isRepeat ? Colors.black87 : Colors.grey[400],
                ),
              ),
            ),
          ),
        ),
        // X 重置按鈕（只在有設定時顯示）
        if (_repeatSettings.isRepeat) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus(); // 收起鍵盤
              setState(() {
                _repeatSettings = _repeatSettings.reset();
              });
              _checkForChanges();
            },
            child: Icon(
              Icons.close,
              size: 18,
              color: Colors.grey[500],
            ),
          ),
        ],
      ],
    );
  }

  /// 顯示重複設定頁面（在同一面板內向左推入）
  void _showRepeatPicker() {
    setState(() {
      _isTransitioningToEdit = true; // 向左滑入
      _showRepeatPage = true;
    });
  }

  /// 從重複設定頁面返回
  void _hideRepeatPicker() {
    setState(() {
      _isTransitioningToEdit = false; // 向右滑出
      _showRepeatPage = false;
    });
    _checkForChanges();
  }

  /// 判斷是否可以直接關閉頁面
  bool _canPop() {
    // 如果在重複設定頁面，不能直接關閉（要先返回編輯頁面）
    if (_showRepeatPage) return false;

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
    // 如果在重複設定頁面，返回編輯頁面
    if (_showRepeatPage) {
      _hideRepeatPicker();
      return;
    }

    // 如果在編輯模式且原本是從檢視模式進來的，返回檢視模式（向右推入動畫）
    if (!_isCurrentlyViewMode && isEditMode && widget.isViewMode) {
      // 如果有未儲存的變更，詢問是否捨棄
      if (_hasUnsavedChanges) {
        final shouldDiscard = await _showDiscardChangesDialog();
        if (shouldDiscard != true) return;

        // 恢復原始資料
        _restoreOriginalData();
      }

      setState(() {
        _isTransitioningToEdit = false; // 設定動畫方向：向右滑入（返回檢視模式）
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
    _selectedCalendarId = _originalCalendarId;
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

  /// 建立日期時間選擇欄位（標籤放在左邊，支援 inline 展開選擇器）
  Widget _buildDateTimeField({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required bool isStart,
  }) {
    final datePickerKey = isStart ? 'startDate' : 'endDate';
    final timePickerKey = isStart ? 'startTime' : 'endTime';
    final isDateExpanded = _expandedPicker == datePickerKey;
    final isTimeExpanded = _expandedPicker == timePickerKey;

    return Column(
      children: [
        // 日期時間欄位行
        Row(
          children: [
            // 左側標籤
            SizedBox(
              width: 40,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
            ),

            // 日期選擇按鈕
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  FocusScope.of(context).unfocus(); // 收起鍵盤
                  setState(() {
                    // 點擊日期欄位：切換展開狀態
                    if (_expandedPicker == datePickerKey) {
                      _expandedPicker = null;
                    } else {
                      _expandedPicker = datePickerKey;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDateExpanded ? Colors.grey[200] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: isDateExpanded
                        ? Border.all(color: Colors.black54, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: isDateExpanded ? Colors.black87 : Colors.black54,
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('yyyy/MM/dd').format(date),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDateExpanded ? Colors.black87 : Colors.black87,
                          fontWeight: isDateExpanded ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 時間選擇按鈕（全天行程時隱藏）
            if (!_isAllDay) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    FocusScope.of(context).unfocus(); // 收起鍵盤
                    setState(() {
                      // 點擊時間欄位：切換展開狀態
                      if (_expandedPicker == timePickerKey) {
                        _expandedPicker = null;
                      } else {
                        _expandedPicker = timePickerKey;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: isTimeExpanded ? Colors.grey[200] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: isTimeExpanded
                          ? Border.all(color: Colors.black54, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: isTimeExpanded ? Colors.black87 : Colors.black54,
                        ),
                        const Spacer(),
                        Text(
                          time.format(context),
                          style: TextStyle(
                            fontSize: 14,
                            color: isTimeExpanded ? Colors.black87 : Colors.black87,
                            fontWeight: isTimeExpanded ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

        // Inline 日期選擇器（展開時顯示）
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildInlineDatePicker(
            date: date,
            isStart: isStart,
          ),
          crossFadeState: isDateExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
        ),

        // Inline 時間選擇器（展開時顯示，全天行程時不顯示）
        if (!_isAllDay)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildInlineTimePicker(
              time: time,
              isStart: isStart,
            ),
            crossFadeState: isTimeExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
      ],
    );
  }

  /// 建立 inline 日期選擇器
  Widget _buildInlineDatePicker({
    required DateTime date,
    required bool isStart,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: CalendarDatePicker(
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        onDateChanged: (selectedDate) {
          setState(() {
            if (isStart) {
              _startDate = selectedDate;
              // 自動調整結束時間（如果開始時間超過結束時間）
              _autoAdjustEndTime();
            } else {
              _endDate = selectedDate;
              // 如果結束日期早於開始日期，自動調整開始日期
              if (_endDate.isBefore(_startDate)) {
                _startDate = _endDate;
              }
            }
            // 選擇後收合選擇器
            _expandedPicker = null;
          });
          _checkForChanges();
        },
      ),
    );
  }

  /// 建立 inline 時間選擇器
  Widget _buildInlineTimePicker({
    required TimeOfDay time,
    required bool isStart,
  }) {
    // 分鐘選項列表（每 10 分鐘為間隔）
    const minuteOptions = [0, 10, 20, 30, 40, 50];

    // 將初始分鐘四捨五入到最近的 10 分鐘，並轉換為索引
    final initialMinuteIndex = ((time.minute + 5) ~/ 10).clamp(0, 5);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SizedBox(
        height: 180,
        child: Row(
          children: [
            // 小時選擇器
            Expanded(
              child: _InlineWheelPicker(
                itemCount: 24,
                initialItem: time.hour,
                onSelectedItemChanged: (hour) {
                  setState(() {
                    if (isStart) {
                      // 保持當前分鐘值（四捨五入到最近的 10 分鐘）
                      final currentMinuteIndex = ((_startTime.minute + 5) ~/ 10).clamp(0, 5);
                      _startTime = TimeOfDay(hour: hour, minute: minuteOptions[currentMinuteIndex]);
                      _autoAdjustEndTime();
                    } else {
                      final currentMinuteIndex = ((_endTime.minute + 5) ~/ 10).clamp(0, 5);
                      _endTime = TimeOfDay(hour: hour, minute: minuteOptions[currentMinuteIndex]);
                    }
                  });
                  _checkForChanges();
                },
                labelBuilder: (index) => index.toString().padLeft(2, '0'),
                suffix: '時',
              ),
            ),

            // 分隔符
            const Text(
              ':',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),

            // 分鐘選擇器（每 10 分鐘為間隔）
            Expanded(
              child: _InlineWheelPicker(
                itemCount: minuteOptions.length,
                initialItem: initialMinuteIndex,
                onSelectedItemChanged: (index) {
                  setState(() {
                    final selectedMinute = minuteOptions[index];
                    if (isStart) {
                      _startTime = TimeOfDay(hour: _startTime.hour, minute: selectedMinute);
                      _autoAdjustEndTime();
                    } else {
                      _endTime = TimeOfDay(hour: _endTime.hour, minute: selectedMinute);
                    }
                  });
                  _checkForChanges();
                },
                labelBuilder: (index) => minuteOptions[index].toString().padLeft(2, '0'),
                suffix: '分',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建立行事曆選擇欄位
  /// - 總覽模式 + 新增行程：顯示下拉選單
  /// - 總覽模式 + 檢視/編輯現有行程：顯示唯讀資訊
  /// - 非總覽模式：不顯示
  Widget _buildCalendarField() {
    final isOverviewMode = ref.watch(isOverviewModeProvider);

    // 非總覽模式時不顯示
    if (!isOverviewMode) return const SizedBox.shrink();

    final calendarsAsync = ref.watch(calendarsProvider);

    return calendarsAsync.when(
      data: (calendars) {
        if (calendars.isEmpty) return const SizedBox.shrink();

        // 確保 _selectedCalendarId 有效
        String? effectiveCalendarId = _selectedCalendarId;
        if (effectiveCalendarId == null || !calendars.any((c) => c.id == effectiveCalendarId)) {
          effectiveCalendarId = calendars.first.id;
        }

        // 取得當前行事曆
        final currentCalendar = calendars.firstWhere(
          (cal) => cal.id == effectiveCalendarId,
          orElse: () => calendars.first,
        );

        // 檢視現有行程：使用共用的 _buildColoredItemViewField
        if (isEditMode && _isCurrentlyViewMode) {
          return _buildColoredItemViewField(
            label: '行事曆',
            name: currentCalendar.name,
            color: currentCalendar.color,
            addBottomSpacing: true,
          );
        }

        // 編輯現有行程（非檢視模式）：不顯示
        if (isEditMode) return const SizedBox.shrink();

        // 新增模式：下拉選單
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '行事曆',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: effectiveCalendarId,
              decoration: _dropdownDecoration,
              items: calendars.map((cal) {
                return DropdownMenuItem<String>(
                  value: cal.id,
                  child: Row(
                    children: [
                      _buildColorDot(cal.color),
                      const SizedBox(width: 12),
                      Text(
                        cal.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onTap: () => FocusScope.of(context).unfocus(), // 收起鍵盤
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCalendarId = value;
                  });
                  _checkForChanges();
                }
              },
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// 建立行程標籤選擇欄位（下拉式選單）
  Widget _buildLabelField() {
    // 監聽標籤列表
    final labels = ref.watch(eventLabelsProvider);

    // 檢視模式：使用共用的 _buildColoredItemViewField
    if (_isCurrentlyViewMode) {
      final currentLabel = labels.firstWhere(
        (label) => label.id == _selectedLabelId,
        orElse: () => labels.first,
      );

      return _buildColoredItemViewField(
        label: '行程標籤',
        name: currentLabel.name,
        color: currentLabel.color,
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
          decoration: _dropdownDecoration,
          items: labels.map((label) {
            return DropdownMenuItem<String>(
              value: label.id,
              child: Row(
                children: [
                  _buildColorDot(label.color),
                  const SizedBox(width: 12),
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
          onTap: () => FocusScope.of(context).unfocus(), // 收起鍵盤
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

  /// 下拉選單共用裝飾
  InputDecoration get _dropdownDecoration => InputDecoration(
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
  );

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
    // 檢視模式：使用共用的 _buildViewField
    if (_isCurrentlyViewMode) {
      return _buildViewField(
        label: '提醒時間',
        value: _getSelectedRemindersText(),
        icon: Icons.notifications_outlined,
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
          onTap: () {
            FocusScope.of(context).unfocus(); // 收起鍵盤
            _showReminderPicker();
          },
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
          backgroundColor: const Color(0xFF333333),
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
      // 編輯模式
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
        calendarId: _selectedCalendarId,
        updatedAt: DateTime.now(),
      );

      // 檢查是否為重複行程
      if (widget.event!.isRecurring) {
        // 顯示重複行程編輯選項對話框
        final choice = await _showRecurrenceEditDialog();
        if (choice == null) {
          // 用戶取消
          return;
        }
        success = await eventController.editRecurringEvent(
          widget.event!.id,
          updatedEvent,
          choice,
        );
      } else {
        // 普通行程：直接更新
        success = await eventController.updateEvent(widget.event!.id, updatedEvent);
      }
    } else {
      // 新增模式
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用戶未登入')),
        );
        return;
      }

      // 檢查是否有重複設定
      if (_repeatSettings.isRepeat && _repeatSettings.repeatType != null) {
        // 建立重複規則
        final recurrenceService = RecurrenceService();
        final rule = recurrenceService.createRuleFromUI(
          type: _repeatSettings.repeatType,
          interval: _repeatSettings.repeatInterval,
          weekdays: _repeatSettings.repeatWeekdays,
          monthDay: _repeatSettings.repeatMonthDay,
          endDate: _repeatSettings.repeatEndDate,
        );

        if (rule != null) {
          // 建立主行程物件
          final masterEvent = CalendarEvent(
            id: '',
            userId: userId,
            calendarId: _selectedCalendarId,
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
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: EventMetadata(createdBy: 'manual'),
            isMasterEvent: true,
            recurrenceRule: rule,
          );

          // 建立重複行程
          final masterId = await eventController.createRecurringEvent(masterEvent, rule);
          success = masterId != null;
        } else {
          success = false;
        }
      } else {
        // 普通行程：使用原有方法建立
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
          calendarId: _selectedCalendarId,
        );

        success = eventId != null;
      }
    }

    if (success && mounted) {
      // 儲存成功
      // 如果是從檢視模式進入編輯模式的，用向右推入動畫回到檢視模式
      if (isEditMode && widget.isViewMode) {
        // 更新原始資料（反映最新儲存的值）
        _saveOriginalData();
        setState(() {
          _isTransitioningToEdit = false; // 設定動畫方向：向右滑入（返回檢視模式）
          _isCurrentlyViewMode = true;
          _hasUnsavedChanges = false;
        });
      } else {
        // 新增模式或直接進入編輯模式：關閉整個面板
        setState(() {
          _hasUnsavedChanges = false;
        });
        Navigator.of(context).pop();
      }
    }
  }

  /// 處理刪除
  Future<void> _handleDelete() async {
    final eventController = ref.read(eventControllerProvider.notifier);
    bool success;

    // 檢查是否為重複行程
    if (widget.event!.isRecurring) {
      // 顯示重複行程刪除選項對話框
      final choice = await _showRecurrenceDeleteDialog();
      if (choice == null) {
        // 用戶取消
        return;
      }
      success = await eventController.deleteRecurringEvent(widget.event!, choice);
    } else {
      // 普通行程：顯示確認對話框
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

      if (confirmed != true) {
        return;
      }

      success = await eventController.deleteEvent(widget.event!.id);
    }

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
      } else {
        // 顯示錯誤訊息
        final errorMessage = ref.read(eventControllerProvider).errorMessage;
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  /// 計算選單彈出位置（基於「...」按鈕位置）
  RelativeRect _getMenuPosition() {
    final RenderBox? renderBox =
        _moreButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // 如果找不到按鈕，使用預設位置（右上角）
      return RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        100,
        16,
        0,
      );
    }
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    return RelativeRect.fromLTRB(
      offset.dx - 100, // 選單左邊界
      offset.dy + size.height, // 選單頂部（按鈕下方）
      offset.dx + size.width, // 選單右邊界
      0,
    );
  }

  /// 顯示重複行程編輯選項選單
  Future<RecurrenceEditChoice?> _showRecurrenceEditDialog() async {
    return showMenu<RecurrenceEditChoice>(
      context: context,
      position: _getMenuPosition(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: [
        const PopupMenuItem(
          value: RecurrenceEditChoice.thisOnly,
          child: Text(
            '僅此行程',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        const PopupMenuItem(
          value: RecurrenceEditChoice.thisAndFollowing,
          child: Text(
            '此行程及之後',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        const PopupMenuItem(
          value: RecurrenceEditChoice.all,
          child: Text(
            '所有行程',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// 顯示重複行程刪除選項選單
  Future<RecurrenceDeleteChoice?> _showRecurrenceDeleteDialog() async {
    return showMenu<RecurrenceDeleteChoice>(
      context: context,
      position: _getMenuPosition(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: [
        const PopupMenuItem(
          value: RecurrenceDeleteChoice.thisOnly,
          child: Text(
            '僅此行程',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
        ),
        const PopupMenuItem(
          value: RecurrenceDeleteChoice.thisAndFollowing,
          child: Text(
            '此行程及之後',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
        ),
        const PopupMenuItem(
          value: RecurrenceDeleteChoice.all,
          child: Text(
            '所有行程',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  /// 切換到編輯模式（向左推入動畫）
  void _switchToEditMode() {
    setState(() {
      _isTransitioningToEdit = true; // 設定動畫方向：向左滑入
      _isCurrentlyViewMode = false;
    });
  }

  /// 顯示行事曆子選單（用於複製或移動行程）
  ///
  /// [isCopy] 為 true 時執行複製，false 時執行移動
  Future<void> _showCalendarSubMenu({required bool isCopy}) async {
    final calendarsAsync = ref.read(calendarsProvider);
    final calendars = calendarsAsync.valueOrNull ?? [];

    if (calendars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有可用的行事曆')),
      );
      return;
    }

    final selectedCalendarId = await showMenu<String>(
      context: context,
      position: _getMenuPosition(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: calendars.map((calendar) {
        return PopupMenuItem<String>(
          value: calendar.id,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: calendar.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  calendar.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // 標示當前行事曆
              if (calendar.id == _selectedCalendarId)
                Icon(Icons.check, size: 18, color: Colors.grey[600]),
            ],
          ),
        );
      }).toList(),
    );

    if (selectedCalendarId != null && mounted) {
      if (isCopy) {
        await _handleDuplicateToCalendar(selectedCalendarId);
      } else {
        await _handleMoveToCalendar(selectedCalendarId);
      }
    }
  }

  /// 處理複製行程到指定行事曆
  Future<void> _handleDuplicateToCalendar(String targetCalendarId) async {
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

    // 取得目標行事曆名稱（用於提示訊息）
    final calendarsAsync = ref.read(calendarsProvider);
    final calendars = calendarsAsync.valueOrNull ?? [];
    final targetCalendar = calendars.firstWhere(
      (c) => c.id == targetCalendarId,
      orElse: () => calendars.first,
    );

    // 建立複製的行程（複製到不同行事曆時不加「副本」，同行事曆才加）
    final isSameCalendar = targetCalendarId == _selectedCalendarId;
    final newTitle = isSameCalendar
        ? '${_titleController.text.trim()}（副本）'
        : _titleController.text.trim();

    final eventId = await eventController.createManualEvent(
      title: newTitle,
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
      calendarId: targetCalendarId,
    );

    if (eventId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('行程已複製到「${targetCalendar.name}」')),
      );
      Navigator.of(context).pop();
    }
  }

  /// 處理移動行程到指定行事曆
  Future<void> _handleMoveToCalendar(String targetCalendarId) async {
    if (!isEditMode || widget.event == null) return;

    // 如果目標行事曆與當前相同，不做任何操作
    if (targetCalendarId == _selectedCalendarId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('行程已在此行事曆中')),
      );
      return;
    }

    // 取得目標行事曆名稱（用於提示訊息）
    final calendarsAsync = ref.read(calendarsProvider);
    final calendars = calendarsAsync.valueOrNull ?? [];
    final targetCalendar = calendars.firstWhere(
      (c) => c.id == targetCalendarId,
      orElse: () => calendars.first,
    );

    final eventController = ref.read(eventControllerProvider.notifier);

    // 更新行程的 calendarId
    final updatedEvent = widget.event!.copyWith(
      calendarId: targetCalendarId,
      updatedAt: DateTime.now(),
    );

    final success = await eventController.updateEvent(widget.event!.id, updatedEvent);

    if (success && mounted) {
      // 更新本地狀態
      setState(() {
        _selectedCalendarId = targetCalendarId;
        _originalCalendarId = targetCalendarId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('行程已移動到「${targetCalendar.name}」')),
      );
      Navigator.of(context).pop();
    }
  }

  /// 建立檢視模式的標題區塊
  Widget _buildViewTitleSection() {
    // 監聽標籤列表，取得當前標籤顏色
    final labels = ref.watch(eventLabelsProvider);
    final currentLabel = labels.firstWhere(
      (label) => label.id == _selectedLabelId,
      orElse: () => labels.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 標籤顏色條
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: currentLabel.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        // 行程標題
        Text(
          _titleController.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// 建立檢視模式的時間顯示
  Widget _buildViewTimeCard() {
    // 判斷是否跨日
    final isSameDay = _startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day;

    return Column(
      children: [
        // 日期行
        _buildViewInfoRow(
          icon: Icons.calendar_today_outlined,
          content: _buildDateText(isSameDay),
        ),
        const SizedBox(height: 12),
        // 時間行
        _buildViewInfoRow(
          icon: Icons.access_time_outlined,
          content: _buildTimeText(isSameDay),
        ),
      ],
    );
  }

  /// 建立日期文字
  String _buildDateText(bool isSameDay) {
    final startStr = DateFormat('M月d日').format(_startDate);
    final startWeekday = _getWeekdayName(_startDate.weekday);

    if (isSameDay) {
      return '$startStr $startWeekday';
    } else {
      final endStr = DateFormat('M月d日').format(_endDate);
      final endWeekday = _getWeekdayName(_endDate.weekday);
      return '$startStr $startWeekday - $endStr $endWeekday';
    }
  }

  /// 建立時間文字
  String _buildTimeText(bool isSameDay) {
    if (_isAllDay) {
      return '全天';
    }
    final startTimeStr = _startTime.format(context);
    final endTimeStr = _endTime.format(context);
    return '$startTimeStr - $endTimeStr';
  }

  /// 建立檢視模式的資訊行
  Widget _buildViewInfoRow({
    required IconData icon,
    required String content,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[500],
        ),
        const SizedBox(width: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  /// 取得星期幾的中文名稱
  String _getWeekdayName(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '週${weekdays[weekday - 1]}';
  }

  /// 建立圓形色塊（用於行事曆、標籤等顯示）
  Widget _buildColorDot(Color color, {double size = 16}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// 建立帶有色塊的檢視模式欄位（用於行事曆、標籤選擇）
  Widget _buildColoredItemViewField({
    required String label,
    required String name,
    required Color color,
    bool addBottomSpacing = false,
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
            children: [
              _buildColorDot(color, size: 20),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (addBottomSpacing) const SizedBox(height: 16),
      ],
    );
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
                        color: Colors.black,
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
                activeColor: Colors.black,
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

/// Inline 滾動選擇器（用於日期時間 inline 選擇）
///
/// 無需確認按鈕，選擇即時生效
class _InlineWheelPicker extends StatefulWidget {
  /// 選項數量
  final int itemCount;

  /// 初始選中項目
  final int initialItem;

  /// 選中項目變更回調
  final ValueChanged<int> onSelectedItemChanged;

  /// 標籤建立器
  final String Function(int) labelBuilder;

  /// 後綴文字（如「時」、「分」）
  final String suffix;

  const _InlineWheelPicker({
    required this.itemCount,
    required this.initialItem,
    required this.onSelectedItemChanged,
    required this.labelBuilder,
    required this.suffix,
  });

  @override
  State<_InlineWheelPicker> createState() => _InlineWheelPickerState();
}

class _InlineWheelPickerState extends State<_InlineWheelPicker> {
  /// 當前選中的項目索引
  late int _selectedIndex;

  /// 滾動控制器
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialItem;
    _controller = FixedExtentScrollController(initialItem: widget.initialItem);
  }

  @override
  void didUpdateWidget(_InlineWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當外部時間變更時，更新滾動位置
    if (oldWidget.initialItem != widget.initialItem) {
      _selectedIndex = widget.initialItem;
      // 使用 jumpToItem 來避免動畫造成的延遲
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.jumpToItem(widget.initialItem);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 選中項目的背景高亮
        Center(
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // 滾動選擇器 - 使用 ListWheelScrollView 實現更平滑的滾動
        ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: 40,
          perspective: 0.003,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          onSelectedItemChanged: (index) {
            setState(() => _selectedIndex = index);
            widget.onSelectedItemChanged(index);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.itemCount,
            builder: (context, index) {
              final isSelected = index == _selectedIndex;
              return Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.labelBuilder(index),
                      style: TextStyle(
                        fontSize: isSelected ? 20 : 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.black : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.suffix,
                      style: TextStyle(
                        fontSize: isSelected ? 14 : 12,
                        color: isSelected ? Colors.black54 : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
