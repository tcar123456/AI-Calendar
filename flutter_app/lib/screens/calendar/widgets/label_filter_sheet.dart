import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/event_label_model.dart';
import '../../../providers/calendar_provider.dart';
import '../../../utils/constants.dart';

/// 標籤篩選面板
///
/// 從右側滑出的面板，佔螢幕寬度一半
/// 用於篩選行事曆上顯示的行程標籤
class LabelFilterSheet extends ConsumerWidget {
  const LabelFilterSheet({super.key});

  /// 顯示標籤篩選面板
  ///
  /// 使用 showGeneralDialog 實現從右側滑入的效果
  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const LabelFilterSheet();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // 從右側滑入的動畫
        final slideAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final labels = ref.watch(calendarLabelsProvider);
    final hiddenLabelIds = ref.watch(hiddenLabelIdsProvider);
    final selectedCalendar = ref.watch(selectedCalendarProvider);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: screenWidth * 0.5,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 標題區域
                _buildHeader(context),

                const Divider(height: 1),

                // 標籤列表（平均分配行高）
                Expanded(
                  child: Column(
                    children: labels.map((label) {
                      final isVisible = !hiddenLabelIds.contains(label.id);

                      return Expanded(
                        child: _LabelFilterItem(
                          label: label,
                          isVisible: isVisible,
                          onToggle: (visible) {
                            if (selectedCalendar != null) {
                              ref
                                  .read(calendarControllerProvider.notifier)
                                  .toggleLabelVisibility(
                                    selectedCalendar.id,
                                    label.id,
                                    visible,
                                  );
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 1),

                // 底部按鈕區域
                _buildBottomActions(context, ref, hiddenLabelIds),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 建立標題區域
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kPaddingMedium),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list,
            color: Colors.black,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '篩選標籤',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 關閉按鈕
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// 建立底部按鈕區域
  Widget _buildBottomActions(
    BuildContext context,
    WidgetRef ref,
    List<String> hiddenLabelIds,
  ) {
    final selectedCalendar = ref.watch(selectedCalendarProvider);
    final allLabelIds = DefaultEventLabels.labels.map((l) => l.id).toList();
    final allHidden = hiddenLabelIds.length == allLabelIds.length;
    final allVisible = hiddenLabelIds.isEmpty;

    return Padding(
      padding: const EdgeInsets.all(kPaddingMedium),
      child: Row(
        children: [
          // 顯示全部按鈕
          Expanded(
            child: OutlinedButton(
              onPressed: allVisible || selectedCalendar == null
                  ? null
                  : () {
                      ref
                          .read(calendarControllerProvider.notifier)
                          .setAllLabelsVisibility(selectedCalendar.id, true);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: BorderSide(
                  color: allVisible
                      ? Colors.grey.shade300
                      : Colors.black,
                ),
              ),
              child: const Text('顯示全部'),
            ),
          ),
          const SizedBox(width: 8),
          // 隱藏全部按鈕
          Expanded(
            child: OutlinedButton(
              onPressed: allHidden || selectedCalendar == null
                  ? null
                  : () {
                      ref
                          .read(calendarControllerProvider.notifier)
                          .setAllLabelsVisibility(selectedCalendar.id, false);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(
                  color: allHidden ? Colors.grey.shade300 : Colors.grey.shade400,
                ),
              ),
              child: const Text('隱藏全部'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 標籤篩選項目元件
///
/// 顯示單一標籤的色塊、名稱和開關
class _LabelFilterItem extends StatelessWidget {
  /// 標籤資料
  final EventLabel label;

  /// 是否顯示（開關狀態）
  final bool isVisible;

  /// 切換回調
  final void Function(bool visible) onToggle;

  const _LabelFilterItem({
    required this.label,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(!isVisible),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kPaddingMedium),
        child: Row(
          children: [
            // 圓形色塊
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isVisible ? label.color : label.color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),

            const SizedBox(width: 12),

            // 標籤名稱
            Expanded(
              child: Text(
                label.name,
                style: TextStyle(
                  fontSize: 14,
                  color: isVisible ? Colors.black87 : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 顯示/隱藏圖示
            Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              size: 20,
              color: isVisible
                  ? Colors.black
                  : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
