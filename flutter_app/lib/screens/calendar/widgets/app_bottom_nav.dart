import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/event_provider.dart';
import '../../../utils/constants.dart';

/// 底部導航欄元件
/// 
/// 5 個區塊的底部導航：
/// 1. 行事曆（當前頁面）
/// 2. 通知
/// 3. 麥克風（語音輸入）
/// 4. 備忘錄
/// 5. 我的帳號
class AppBottomNav extends ConsumerWidget {
  /// 當前選中的頁面索引
  final int currentIndex;

  /// 點擊導航項目的回調
  /// 參數：項目索引 (0-4)
  final ValueChanged<int> onItemTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 監聽是否有未讀通知
    final hasUnreadNotification = ref.watch(hasUnreadNotificationProvider);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              // 第一個位置：行事曆
              Expanded(
                child: _buildNavItem(
                  icon: Icons.calendar_today,
                  label: '行事曆',
                  index: 0,
                ),
              ),
              // 第二個位置：通知功能
              Expanded(
                child: _buildNavItem(
                  icon: Icons.notifications_outlined,
                  label: '通知',
                  index: 1,
                  showBadge: hasUnreadNotification,
                ),
              ),
              // 第三個位置：麥克風按鈕（中央）
              Expanded(
                child: _buildMicButton(),
              ),
              // 第四個位置：備忘錄功能
              Expanded(
                child: _buildNavItem(
                  icon: Icons.note_alt_outlined,
                  label: '備忘錄',
                  index: 3,
                ),
              ),
              // 第五個位置：個人資料
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline,
                  label: '我的帳號',
                  index: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 建立導航項目
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    bool showBadge = false,
  }) {
    final isActive = currentIndex == index;
    final color = isActive ? Colors.black : Colors.grey[500]!;

    return InkWell(
      onTap: () => onItemTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 使用 Stack 在圖示上疊加紅點
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
                // 紅點提示
                if (showBadge)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建立麥克風按鈕（浮凸立體效果）
  Widget _buildMicButton() {
    return InkWell(
      onTap: () => onItemTap(2),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF0F0F0),
            ],
          ),
          border: Border.all(
            color: Colors.black,
            width: 2,
          ),
          boxShadow: [
            // 底部深色陰影（立體感）
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            // 頂部高光（浮凸效果）
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.black,
          size: 32,
        ),
      ),
    );
  }
}

