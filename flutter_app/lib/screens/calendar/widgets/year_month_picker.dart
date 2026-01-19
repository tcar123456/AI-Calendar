import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

/// 年月選擇器對話框
/// 
/// 讓用戶可以快速跳轉到指定的年月
class YearMonthPicker extends StatefulWidget {
  /// 當前選中的日期
  final DateTime currentDate;
  
  /// 選擇年月後的回調
  final ValueChanged<DateTime> onDateSelected;
  
  /// 跳轉到今天的回調
  final VoidCallback onJumpToToday;

  const YearMonthPicker({
    super.key,
    required this.currentDate,
    required this.onDateSelected,
    required this.onJumpToToday,
  });

  /// 顯示年月選擇器的靜態方法
  static void show({
    required BuildContext context,
    required DateTime currentDate,
    required ValueChanged<DateTime> onDateSelected,
    required VoidCallback onJumpToToday,
  }) {
    showDialog(
      context: context,
      builder: (context) => YearMonthPicker(
        currentDate: currentDate,
        onDateSelected: onDateSelected,
        onJumpToToday: onJumpToToday,
      ),
    );
  }

  @override
  State<YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<YearMonthPicker> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.currentDate.year;
    selectedMonth = widget.currentDate.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('選擇年月'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 年份選擇器
            Row(
              children: [
                const Text('年份：', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    value: selectedYear,
                    isExpanded: true,
                    // 提供 2020-2030 年的選項
                    items: List.generate(11, (index) => 2020 + index)
                        .map((year) => DropdownMenuItem(
                              value: year,
                              child: Text('$year 年'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedYear = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 月份選擇器（使用網格佈局）
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('月份：', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = month == selectedMonth;
                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedMonth = month;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.black
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Colors.black
                            : Colors.grey[300]!,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$month月',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        // 取消按鈕
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        // 跳轉到今天按鈕
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onJumpToToday();
          },
          child: const Text('今天'),
        ),
        // 確認按鈕
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onDateSelected(DateTime(selectedYear, selectedMonth, 1));
          },
          child: const Text('確認'),
        ),
      ],
    );
  }
}

