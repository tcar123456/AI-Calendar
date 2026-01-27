import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 重複設定的 UI 狀態資料類別
class RepeatSettings {
  /// 是否啟用重複
  final bool isRepeat;

  /// 重複類型：'daily' | 'weekly' | 'monthly' | 'yearly'
  final String? repeatType;

  /// 重複間隔（每 N 天/週/月/年）
  final int repeatInterval;

  /// 週重複時選擇的星期幾（1=週一, 7=週日）
  final Set<int> repeatWeekdays;

  /// 月重複時指定的日期（1-31）
  final int? repeatMonthDay;

  /// 重複結束日期（null 表示永不結束）
  final DateTime? repeatEndDate;

  const RepeatSettings({
    this.isRepeat = false,
    this.repeatType,
    this.repeatInterval = 1,
    this.repeatWeekdays = const {},
    this.repeatMonthDay,
    this.repeatEndDate,
  });

  /// 建立預設設定（不重複）
  factory RepeatSettings.none() => const RepeatSettings();

  /// 複製並修改部分欄位
  RepeatSettings copyWith({
    bool? isRepeat,
    String? repeatType,
    int? repeatInterval,
    Set<int>? repeatWeekdays,
    int? repeatMonthDay,
    DateTime? repeatEndDate,
    bool clearEndDate = false,
  }) {
    return RepeatSettings(
      isRepeat: isRepeat ?? this.isRepeat,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      repeatMonthDay: repeatMonthDay ?? this.repeatMonthDay,
      repeatEndDate: clearEndDate ? null : (repeatEndDate ?? this.repeatEndDate),
    );
  }

  /// 取得顯示文字
  String getDisplayText() {
    if (!isRepeat || repeatType == null) {
      return '無重複';
    }

    final typeText = {
      'daily': '天',
      'weekly': '週',
      'monthly': '月',
      'yearly': '年',
    }[repeatType] ?? '';

    // 顯示間隔
    if (repeatInterval == 1) {
      final simpleText = {
        'daily': '每天',
        'weekly': '每週',
        'monthly': '每月',
        'yearly': '每年',
      }[repeatType] ?? '';

      // 週重複：顯示選擇的星期幾
      if (repeatType == 'weekly' && repeatWeekdays.isNotEmpty) {
        final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
        final sortedDays = repeatWeekdays.toList()..sort();
        final daysText = sortedDays.map((d) => '週${weekdayNames[d - 1]}').join('、');
        return '$simpleText ($daysText)';
      }

      // 月重複：顯示選擇的日期
      if (repeatType == 'monthly' && repeatMonthDay != null) {
        return '$simpleText ($repeatMonthDay日)';
      }

      return simpleText;
    } else {
      String result = '每 $repeatInterval $typeText';

      // 週重複：顯示選擇的星期幾
      if (repeatType == 'weekly' && repeatWeekdays.isNotEmpty) {
        final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
        final sortedDays = repeatWeekdays.toList()..sort();
        final daysText = sortedDays.map((d) => '週${weekdayNames[d - 1]}').join('、');
        result += ' ($daysText)';
      }

      // 月重複：顯示選擇的日期
      if (repeatType == 'monthly' && repeatMonthDay != null) {
        result += ' ($repeatMonthDay日)';
      }

      return result;
    }
  }

  /// 重設為不重複
  RepeatSettings reset() {
    return const RepeatSettings(
      isRepeat: false,
      repeatType: null,
      repeatInterval: 1,
      repeatWeekdays: {},
      repeatMonthDay: null,
      repeatEndDate: null,
    );
  }
}

/// 重複設定頁面
///
/// 用於在 EventDetailScreen 中設定行程的重複規則
class RepeatSettingsPage extends StatefulWidget {
  /// 初始設定值
  final RepeatSettings initialSettings;

  /// 預設開始日期（用於初始化星期和月日）
  final DateTime defaultStartDate;

  /// 設定變更回調
  final ValueChanged<RepeatSettings> onSettingsChanged;

  /// 返回按鈕回調
  final VoidCallback onBack;

  const RepeatSettingsPage({
    super.key,
    required this.initialSettings,
    required this.defaultStartDate,
    required this.onSettingsChanged,
    required this.onBack,
  });

  @override
  State<RepeatSettingsPage> createState() => _RepeatSettingsPageState();
}

class _RepeatSettingsPageState extends State<RepeatSettingsPage> {
  late bool _isRepeat;
  late String? _repeatType;
  late int _repeatInterval;
  late Set<int> _repeatWeekdays;
  late int? _repeatMonthDay;
  late DateTime? _repeatEndDate;

  @override
  void initState() {
    super.initState();
    _initFromSettings(widget.initialSettings);
  }

  void _initFromSettings(RepeatSettings settings) {
    _isRepeat = settings.isRepeat;
    _repeatType = settings.repeatType ?? 'daily';
    _repeatInterval = settings.repeatInterval;
    _repeatWeekdays = Set.from(settings.repeatWeekdays);
    _repeatMonthDay = settings.repeatMonthDay;
    _repeatEndDate = settings.repeatEndDate;

    // 初始化預設值
    if (_repeatWeekdays.isEmpty) {
      _repeatWeekdays = {widget.defaultStartDate.weekday};
    }
    _repeatMonthDay ??= widget.defaultStartDate.day;
  }

  RepeatSettings _buildSettings() {
    return RepeatSettings(
      isRepeat: _isRepeat,
      repeatType: _repeatType,
      repeatInterval: _repeatInterval,
      repeatWeekdays: _repeatWeekdays,
      repeatMonthDay: _repeatMonthDay,
      repeatEndDate: _repeatEndDate,
    );
  }

  void _handleComplete() {
    widget.onSettingsChanged(_buildSettings());
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('repeat'),
      color: Colors.white,
      child: Column(
        children: [
          // 重複設定標題列
          _buildHeader(),
          // 分隔線
          Container(
            height: 0.5,
            color: Colors.grey[200],
          ),
          // 內容區域
          Expanded(
            child: GestureDetector(
              // 支援向右滑動返回
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                  _handleComplete();
                }
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // 重複頻率區塊
                  _buildSectionHeader('頻率'),

                  // 不重複選項
                  _buildListItem(
                    title: '不重複',
                    isSelected: !_isRepeat,
                    onTap: () {
                      setState(() {
                        _isRepeat = false;
                      });
                    },
                  ),

                  // 每天
                  _buildListItem(
                    title: '每天',
                    isSelected: _isRepeat && _repeatType == 'daily',
                    onTap: () {
                      setState(() {
                        _isRepeat = true;
                        _repeatType = 'daily';
                        _repeatInterval = 1;
                      });
                    },
                  ),

                  // 每週
                  _buildListItem(
                    title: '每週',
                    subtitle: _isRepeat && _repeatType == 'weekly' && _repeatWeekdays.isNotEmpty
                        ? _getWeekdaysDisplayText()
                        : null,
                    isSelected: _isRepeat && _repeatType == 'weekly',
                    onTap: () {
                      setState(() {
                        _isRepeat = true;
                        _repeatType = 'weekly';
                        _repeatInterval = 1;
                      });
                    },
                  ),

                  // 每月
                  _buildListItem(
                    title: '每月',
                    subtitle: _isRepeat && _repeatType == 'monthly' && _repeatMonthDay != null
                        ? '每月 $_repeatMonthDay 日'
                        : null,
                    isSelected: _isRepeat && _repeatType == 'monthly',
                    onTap: () {
                      setState(() {
                        _isRepeat = true;
                        _repeatType = 'monthly';
                        _repeatInterval = 1;
                      });
                    },
                  ),

                  // 每年
                  _buildListItem(
                    title: '每年',
                    isSelected: _isRepeat && _repeatType == 'yearly',
                    onTap: () {
                      setState(() {
                        _isRepeat = true;
                        _repeatType = 'yearly';
                        _repeatInterval = 1;
                      });
                    },
                    showDivider: false,
                  ),

                  // 自訂設定區域（僅當有選擇重複時顯示）
                  if (_isRepeat) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('自訂'),
                    _buildIntervalRow(),

                    // 週重複：選擇星期幾
                    if (_repeatType == 'weekly') ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '重複日',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildWeekdaySelector(),
                          ],
                        ),
                      ),
                    ],

                    // 月重複：選擇日期
                    if (_repeatType == 'monthly') ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '重複日期',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildMonthDaySelector(),
                          ],
                        ),
                      ),
                    ],

                    // 結束重複
                    const SizedBox(height: 24),
                    _buildSectionHeader('結束'),
                    _buildEndDateSelector(),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 建立標題列
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          // 返回按鈕
          IconButton(
            onPressed: _handleComplete,
            icon: const Icon(Icons.arrow_back, size: 22),
            color: Colors.black87,
          ),
          // 標題（置中）
          const Expanded(
            child: Text(
              '重複',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 完成按鈕
          TextButton(
            onPressed: _handleComplete,
            child: const Text(
              '完成',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 取得星期選擇的顯示文字
  String _getWeekdaysDisplayText() {
    if (_repeatWeekdays.isEmpty) return '';
    const weekdayNames = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    final sortedDays = _repeatWeekdays.toList()..sort();
    return sortedDays.map((d) => weekdayNames[d - 1]).join('、');
  }

  /// 建立區塊標題
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 建立列表項目
  Widget _buildListItem({
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            margin: const EdgeInsets.only(left: 16),
            height: 0.5,
            color: Colors.grey[200],
          ),
      ],
    );
  }

  /// 建立間隔設定行
  Widget _buildIntervalRow() {
    final typeText = {
      'daily': '天',
      'weekly': '週',
      'monthly': '月',
      'yearly': '年',
    }[_repeatType] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '每',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 16),
          // 間隔數字選擇器
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 減少按鈕
                InkWell(
                  onTap: _repeatInterval > 1
                      ? () {
                          setState(() {
                            _repeatInterval--;
                          });
                        }
                      : null,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.remove,
                      size: 18,
                      color: _repeatInterval > 1 ? Colors.black87 : Colors.grey[300],
                    ),
                  ),
                ),
                // 分隔線
                Container(
                  width: 0.5,
                  height: 24,
                  color: Colors.grey[300],
                ),
                // 數字顯示
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '$_repeatInterval',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // 分隔線
                Container(
                  width: 0.5,
                  height: 24,
                  color: Colors.grey[300],
                ),
                // 增加按鈕
                InkWell(
                  onTap: _repeatInterval < 99
                      ? () {
                          setState(() {
                            _repeatInterval++;
                          });
                        }
                      : null,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.add,
                      size: 18,
                      color: _repeatInterval < 99 ? Colors.black87 : Colors.grey[300],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            typeText,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  /// 建立星期選擇器
  Widget _buildWeekdaySelector() {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final weekday = index + 1;
        final isSelected = _repeatWeekdays.contains(weekday);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                if (_repeatWeekdays.length > 1) {
                  _repeatWeekdays.remove(weekday);
                }
              } else {
                _repeatWeekdays.add(weekday);
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.transparent,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                weekdays[index],
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 建立月日選擇器
  Widget _buildMonthDaySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(31, (index) {
        final day = index + 1;
        final isSelected = _repeatMonthDay == day;

        return GestureDetector(
          onTap: () {
            setState(() {
              _repeatMonthDay = day;
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.transparent,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 建立結束日期選擇器
  Widget _buildEndDateSelector() {
    return Column(
      children: [
        // 永不結束選項
        _buildListItem(
          title: '永不',
          isSelected: _repeatEndDate == null,
          onTap: () {
            setState(() {
              _repeatEndDate = null;
            });
          },
        ),
        // 選擇日期選項
        InkWell(
          onTap: () => _selectEndDate(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '結束日期',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      if (_repeatEndDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('yyyy/MM/dd').format(_repeatEndDate!),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_repeatEndDate != null)
                  const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 選擇結束日期
  Future<void> _selectEndDate() async {
    final DateTime initialDate = _repeatEndDate ?? widget.defaultStartDate.add(const Duration(days: 30));
    final DateTime firstDate = widget.defaultStartDate;
    final DateTime lastDate = widget.defaultStartDate.add(const Duration(days: 365 * 10)); // 最多 10 年

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _repeatEndDate = picked;
      });
    }
  }
}
