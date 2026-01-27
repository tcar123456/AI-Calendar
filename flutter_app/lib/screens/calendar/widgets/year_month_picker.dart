import 'package:flutter/material.dart';

/// 年月選擇器對話框
///
/// 讓用戶可以快速跳轉到指定的年月
class YearMonthPicker extends StatefulWidget {
  /// 當前選中的日期
  final DateTime currentDate;

  /// 選擇年月後的回調
  final ValueChanged<DateTime> onDateSelected;

  const YearMonthPicker({
    super.key,
    required this.currentDate,
    required this.onDateSelected,
  });

  /// 顯示年月選擇器的靜態方法
  static void show({
    required BuildContext context,
    required DateTime currentDate,
    required ValueChanged<DateTime> onDateSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) => YearMonthPicker(
        currentDate: currentDate,
        onDateSelected: onDateSelected,
      ),
    );
  }

  @override
  State<YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<YearMonthPicker> {
  late int selectedYear;
  late int selectedMonth;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  // 年度範圍：當年度 +-30 年
  late int minYear;
  late int maxYear;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    minYear = currentYear - 30;
    maxYear = currentYear + 30;

    selectedYear = widget.currentDate.year;
    selectedMonth = widget.currentDate.month;

    // 計算年份在列表中的索引
    final yearIndex = selectedYear - minYear;
    _yearController = FixedExtentScrollController(initialItem: yearIndex);
    _monthController = FixedExtentScrollController(initialItem: selectedMonth - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 標題列：取消 - 選擇年月 - 確認
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // 取消按鈕（左邊，灰色）
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('取消'),
                  ),
                  // 標題（置中）
                  const Expanded(
                    child: Text(
                      '選擇年月',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // 確認按鈕（右邊，黑色）
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDateSelected(DateTime(selectedYear, selectedMonth, 1));
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('確認'),
                  ),
                ],
              ),
            ),
            // 滾輪選擇器區域
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // 左邊：年份滾輪
                  Expanded(
                    child: _buildWheelPicker(
                      controller: _yearController,
                      itemCount: maxYear - minYear + 1,
                      itemBuilder: (index) => '${minYear + index} 年',
                      onSelectedItemChanged: (index) {
                        setState(() {
                          selectedYear = minYear + index;
                        });
                      },
                      selectedIndex: selectedYear - minYear,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 右邊：月份滾輪
                  Expanded(
                    child: _buildWheelPicker(
                      controller: _monthController,
                      itemCount: 12,
                      itemBuilder: (index) => '${index + 1} 月',
                      onSelectedItemChanged: (index) {
                        setState(() {
                          selectedMonth = index + 1;
                        });
                      },
                      selectedIndex: selectedMonth - 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建立滾輪選擇器
  Widget _buildWheelPicker({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) itemBuilder,
    required ValueChanged<int> onSelectedItemChanged,
    required int selectedIndex,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // 選中項目的高亮背景
          Center(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),
          ),
          // 滾輪選擇器
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            diameterRatio: 1.5,
            perspective: 0.005,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onSelectedItemChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) {
                final isSelected = index == selectedIndex;
                return Center(
                  child: Text(
                    itemBuilder(index),
                    style: TextStyle(
                      fontSize: isSelected ? 18 : 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.grey[500],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
