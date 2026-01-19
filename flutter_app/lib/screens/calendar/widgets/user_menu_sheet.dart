import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/calendar_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/constants.dart';
import '../profile_edit_screen.dart';

/// 用戶選單底部面板
/// 
/// 顯示用戶資訊和操作選項：
/// - 用戶頭像、名稱、Email
/// - 行事曆切換區塊（類似 TimeTree）
/// - 設定（開發中）
/// - 登出
class UserMenuSheet extends ConsumerStatefulWidget {
  /// 點擊設定的回調
  final VoidCallback onSettings;
  
  /// 點擊登出的回調
  final VoidCallback onSignOut;

  const UserMenuSheet({
    super.key,
    required this.onSettings,
    required this.onSignOut,
  });

  /// 顯示用戶選單的靜態方法
  static void show({
    required BuildContext context,
    required VoidCallback onSettings,
    required VoidCallback onSignOut,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserMenuSheet(
        onSettings: onSettings,
        onSignOut: onSignOut,
      ),
    );
  }

  @override
  ConsumerState<UserMenuSheet> createState() => _UserMenuSheetState();
}

class _UserMenuSheetState extends ConsumerState<UserMenuSheet> {
  @override
  void initState() {
    super.initState();
    // 確保用戶有預設行事曆
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarControllerProvider.notifier).ensureDefaultCalendar();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 監聽行事曆列表
    final calendarsAsync = ref.watch(calendarsProvider);
    final selectedCalendar = ref.watch(selectedCalendarProvider);

    // 計算最大高度：螢幕高度減去狀態列和 AppBar 高度，確保底部面板在狀態列下方
    final maxSheetHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxSheetHeight,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 頂部拖曳指示器
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 用戶資訊
              _buildUserInfo(),

              const Divider(height: 24),
              
              // 行事曆區塊標題
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kPaddingMedium),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '我的行事曆',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 行事曆卡片列表（垂直排列）
              // 若超過 4 張卡片（包含新增按鈕）則可滾動顯示
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kPaddingMedium),
                child: calendarsAsync.when(
                  data: (calendars) => _buildCalendarCardsList(
                    calendars,
                    selectedCalendar,
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('載入失敗: $error'),
                    ),
                  ),
                ),
              ),
              
              const Divider(height: 24),
              
              // 設定選項
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('設定'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _showAppSettingsSheet();
                },
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 建立用戶資訊區域
  ///
  /// 顯示用戶頭像、名稱、Email，右側有鉛筆編輯圖示
  /// 點擊可進入個人資料編輯頁面
  /// 內部監聽 currentUserDataProvider 以確保資料即時更新
  Widget _buildUserInfo() {
    // 監聽用戶資料（在 Widget 內部監聽以確保即時更新）
    final userDataAsync = ref.watch(currentUserDataProvider);

    return userDataAsync.when(
      // 資料載入中
      loading: () => const ListTile(
        leading: CircularProgressIndicator(color: Colors.black),
        title: Text('載入中...'),
      ),
      // 載入失敗
      error: (error, _) => const ListTile(
        leading: Icon(Icons.error),
        title: Text('載入失敗'),
      ),
      // 資料載入成功
      data: (user) => _buildUserInfoContent(user),
    );
  }

  /// 建立用戶資訊內容
  Widget _buildUserInfoContent(UserModel? user) {
    // 點擊區域可進入個人資料編輯頁面
    return InkWell(
      onTap: () {
        // 保存必要的數據和 Navigator（在 pop 之前）
        final navigator = Navigator.of(context);
        final onSettings = widget.onSettings;
        final onSignOut = widget.onSignOut;

        // 關閉底部選單
        Navigator.pop(context);

        // 導航至個人資料編輯頁面，並在返回後重新打開用戶選單
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ProfileEditScreen(user: user),
          ),
        ).then((_) {
          // 檢查用戶是否仍然登入（避免登出後仍彈出面板）
          final firebaseService = FirebaseService();
          if (firebaseService.currentUser == null) {
            return; // 用戶已登出，不重新打開選單
          }

          // 返回時重新打開用戶選單
          UserMenuSheet.show(
            context: navigator.context,
            onSettings: onSettings,
            onSignOut: onSignOut,
          );
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 用戶頭像
            CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.1),
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? const Icon(
                      Icons.person,
                      color: Colors.black,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // 用戶名稱和 Email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.getDisplayName() ?? '用戶',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // 鉛筆編輯圖示（位於帳號右邊）
            const Icon(
              Icons.edit,
              color: Colors.black,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 建立行事曆卡片垂直列表
  /// 
  /// 若行事曆數量超過 4 張（包含新增按鈕），則限制高度並可滾動顯示
  /// 單張卡片高度約 72px（12 上邊距 + 48 內容 + 8 底部間距 + 4 額外）
  Widget _buildCalendarCardsList(
    List<CalendarModel> calendars,
    CalendarModel? selectedCalendar,
  ) {
    // 計算總項目數（行事曆數量 + 新增按鈕）
    final totalItems = calendars.length + 1;
    
    // 單張卡片高度（含間距）
    const double cardHeight = 72.0;
    
    // 最大顯示 4 張卡片的高度
    const double maxVisibleHeight = cardHeight * 4;
    
    // 建立行事曆列表 Widget
    Widget listContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 現有行事曆卡片
        ...calendars.map((calendar) {
          final isSelected = selectedCalendar?.id == calendar.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildCalendarCard(calendar, isSelected),
          );
        }),
        
        // 新增行事曆按鈕
        _buildAddCalendarCard(),
      ],
    );
    
    // 若超過 4 張卡片，則限制高度並可滾動
    if (totalItems > 4) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: maxVisibleHeight,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: listContent,
        ),
      );
    }
    
    // 4 張或以下，直接顯示不滾動
    return listContent;
  }

  /// 建立行事曆卡片（全寬橫向）
  Widget _buildCalendarCard(CalendarModel calendar, bool isSelected) {
    return GestureDetector(
      onTap: () {
        // 選擇此行事曆
        ref.read(calendarControllerProvider.notifier).selectCalendar(calendar.id);
        Navigator.pop(context);
      },
      onLongPress: () {
        // 長按顯示編輯選單
        _showCalendarOptionsMenu(calendar);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          // 選中狀態只顯示邊框
          border: Border.all(
            color: isSelected ? calendar.color : Colors.grey[300]!,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // 行事曆顏色指示器
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: calendar.color,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today,
                color: Colors.white,
                size: 20,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 行事曆名稱
            Expanded(
              child: Text(
                calendar.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 右側箭頭
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// 建立新增行事曆卡片（虛線樣式）
  Widget _buildAddCalendarCard() {
    return GestureDetector(
      onTap: () => _showCreateCalendarDialog(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[400]!,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            // 加號圖示
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[400]!,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(
                Icons.add,
                color: Colors.grey[600],
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 文字
            Text(
              '新增行事曆',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顯示行事曆選項選單
  void _showCalendarOptionsMenu(CalendarModel calendar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
                    // 空白區域（保持對稱）
                    const SizedBox(width: 48),

                    // 標題（行事曆名稱）
                    Text(
                      calendar.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // 關閉按鈕
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 編輯
              ListTile(
                title: const Text('編輯行事曆'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pop(context);
                  _showEditCalendarDialog(calendar);
                },
              ),

              // 刪除行事曆
              ListTile(
                title: const Text(
                  '刪除行事曆',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteCalendarConfirm(calendar);
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 顯示新增行事曆對話框
  void _showCreateCalendarDialog() {
    final nameController = TextEditingController();
    Color selectedColor = CalendarModel.defaultColors[0];
    bool isCreating = false;

    showDialog(
      context: context,
      barrierDismissible: false, // 防止點擊外部關閉
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('新增行事曆'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 名稱輸入
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '行事曆名稱',
                  hintText: '例如：工作、家庭',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                enabled: !isCreating,
              ),
              
              const SizedBox(height: 16),
              
              // 顏色選擇
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '選擇顏色',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              IgnorePointer(
                ignoring: isCreating,
                child: Opacity(
                  opacity: isCreating ? 0.5 : 1.0,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CalendarModel.defaultColors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.clearSnackBars();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('請輸入行事曆名稱')),
                        );
                        return;
                      }

                      // 設定載入狀態
                      setDialogState(() {
                        isCreating = true;
                      });
                      
                      // 建立行事曆
                      final calendarId = await ref
                          .read(calendarControllerProvider.notifier)
                          .createCalendar(
                            name: name,
                            color: selectedColor,
                          );
                      
                      // 關閉對話框
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      
                      // 顯示結果
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.clearSnackBars();
                        if (calendarId != null) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('行事曆建立成功')),
                          );
                        } else {
                          // 顯示錯誤訊息
                          final errorMessage = ref.read(calendarControllerProvider).errorMessage;
                          messenger.showSnackBar(
                            SnackBar(content: Text(errorMessage ?? '建立失敗，請重試')),
                          );
                        }
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('建立'),
            ),
          ],
        ),
      ),
    );
  }

  /// 顯示編輯行事曆對話框
  void _showEditCalendarDialog(CalendarModel calendar) {
    final nameController = TextEditingController(text: calendar.name);
    Color selectedColor = calendar.color;
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('編輯行事曆'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 名稱輸入
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '行事曆名稱',
                  border: OutlineInputBorder(),
                ),
                enabled: !isUpdating,
              ),
              
              const SizedBox(height: 16),
              
              // 顏色選擇
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '選擇顏色',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              IgnorePointer(
                ignoring: isUpdating,
                child: Opacity(
                  opacity: isUpdating ? 0.5 : 1.0,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CalendarModel.defaultColors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: isUpdating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.clearSnackBars();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('請輸入行事曆名稱')),
                        );
                        return;
                      }

                      setDialogState(() {
                        isUpdating = true;
                      });

                      final success = await ref
                          .read(calendarControllerProvider.notifier)
                          .updateCalendar(
                            calendarId: calendar.id,
                            name: name,
                            color: selectedColor,
                          );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.clearSnackBars();
                        if (success) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('行事曆更新成功')),
                          );
                        } else {
                          final errorMessage = ref.read(calendarControllerProvider).errorMessage;
                          messenger.showSnackBar(
                            SnackBar(content: Text(errorMessage ?? '更新失敗，請重試')),
                          );
                        }
                      }
                    },
              child: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 顯示刪除行事曆確認對話框
  void _showDeleteCalendarConfirm(CalendarModel calendar) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除行事曆'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('確定要刪除「${calendar.name}」嗎？'),
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
            onPressed: () async {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
              
              final success = await ref
                  .read(calendarControllerProvider.notifier)
                  .deleteCalendar(calendar.id);
              
              if (success && mounted) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  const SnackBar(content: Text('行事曆已刪除')),
                );
              }
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  /// 顯示 APP 設定面板
  void _showAppSettingsSheet() {
    // 保存必要的數據（在關閉 UserMenuSheet 之前）
    final navigator = Navigator.of(context);
    final onSettings = widget.onSettings;
    final onSignOut = widget.onSignOut;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // 修復：不再傳遞 parentContext，改用 widget 自身的 context 來顯示 SnackBar
      builder: (sheetContext) => _AppSettingsSheet(
        navigator: navigator,
        onSettings: onSettings,
        onSignOut: onSignOut,
      ),
    );
  }
}

/// APP 設定面板內容
/// 
/// 包含通知設定、起始日設定、時區設定等
/// 
/// 修復：移除 parentContext 參數，改用 widget 自身的 context
/// 這樣可以避免在 builder 重建時訪問已 unmounted 的 context
class _AppSettingsSheet extends ConsumerStatefulWidget {
  /// Navigator 實例（用於返回時重開選單）
  final NavigatorState navigator;
  
  /// 設定回調
  final VoidCallback onSettings;
  
  /// 登出回調
  final VoidCallback onSignOut;

  const _AppSettingsSheet({
    required this.navigator,
    required this.onSettings,
    required this.onSignOut,
  });

  @override
  ConsumerState<_AppSettingsSheet> createState() => _AppSettingsSheetState();
}

class _AppSettingsSheetState extends ConsumerState<_AppSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    // 監聽用戶資料以取得設定
    final userDataAsync = ref.watch(currentUserDataProvider);

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
            // 標題區域
            _buildHeader(context),

            const Divider(height: 1),

            // 通知設定區塊
            _buildNotificationSection(userDataAsync),

            const Divider(height: 1),

            // 起始日設定（從用戶設定讀取當前值）
            userDataAsync.when(
              data: (user) {
                final weekStartDay = user?.settings.getWeekStartDayName() ?? '星期日';
                return ListTile(
                  title: const Text('起始日設定'),
                  subtitle: Text(weekStartDay),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showWeekStartDayPicker(user),
                );
              },
              loading: () => const ListTile(
                title: Text('起始日設定'),
                subtitle: Text('載入中...'),
              ),
              error: (_, __) => const ListTile(
                title: Text('起始日設定'),
                subtitle: Text('載入失敗'),
              ),
            ),

            // 時區設定（從用戶設定讀取當前值）
            userDataAsync.when(
              data: (user) {
                final timezone = user?.settings.getTimezoneDisplayName() ?? '台北 (GMT+8)';
                return ListTile(
                  title: const Text('時區設定'),
                  subtitle: Text(timezone),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTimezonePicker(user),
                );
              },
              loading: () => const ListTile(
                title: Text('時區設定'),
                subtitle: Text('載入中...'),
              ),
              error: (_, __) => const ListTile(
                title: Text('時區設定'),
                subtitle: Text('載入失敗'),
              ),
            ),

            // 語言設定（從用戶設定讀取當前值）
            userDataAsync.when(
              data: (user) {
                final language = user?.settings.getLanguageDisplayName() ?? '繁體中文（台灣）';
                return ListTile(
                  title: const Text('語言'),
                  subtitle: Text(language),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguagePicker(user),
                );
              },
              loading: () => const ListTile(
                title: Text('語言'),
                subtitle: Text('載入中...'),
              ),
              error: (_, __) => const ListTile(
                title: Text('語言'),
                subtitle: Text('載入失敗'),
              ),
            ),

            // 支援選項
            ListTile(
              title: const Text('支援'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSupportSheet(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 建立標題區域
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kPaddingMedium,
        vertical: kPaddingSmall,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按鈕（返回用戶選單）
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
              // 使用 Navigator 的 context 重新打開用戶選單
              UserMenuSheet.show(
                context: widget.navigator.context,
                onSettings: widget.onSettings,
                onSignOut: widget.onSignOut,
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          // 居中標題
          const Text(
            '設定',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          // 關閉按鈕
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// 建立通知設定區塊
  Widget _buildNotificationSection(AsyncValue<UserModel?> userDataAsync) {
    return userDataAsync.when(
      data: (user) {
        // 取得通知設定值
        final notificationsEnabled = user?.settings.notificationsEnabled ?? true;
        final notificationTime = user?.settings.getFormattedNotificationTime() ?? '08:00';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 區塊標題
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kPaddingMedium,
                kPaddingMedium,
                kPaddingMedium,
                kPaddingSmall,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications,
                    color: Colors.black,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '通知',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            // APP 通知開關
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('APP 通知'),
              subtitle: Text(notificationsEnabled ? '已開啟' : '已關閉'),
              trailing: Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: notificationsEnabled,
                  activeColor: Colors.black,
                  onChanged: (value) => _updateNotificationEnabled(value, user),
                ),
              ),
            ),
            
            // 通知時間設定
            ListTile(
              title: const Text('通知時間'),
              subtitle: Text(notificationTime),
              trailing: const Icon(Icons.chevron_right),
              enabled: notificationsEnabled,
              onTap: notificationsEnabled
                  ? () => _showTimePicker(user)
                  : null,
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(kPaddingMedium),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(kPaddingMedium),
        child: Center(
          child: Text('載入設定失敗: $error'),
        ),
      ),
    );
  }

  /// 顯示支援面板
  void _showSupportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
                    // 空白區域（保持對稱）
                    const SizedBox(width: 48),

                    // 標題
                    const Text(
                      '支援',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // 關閉按鈕
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 公告
              ListTile(
                title: const Text('公告'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 導航至公告頁面
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('公告功能開發中'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // 關於
              ListTile(
                title: const Text('關於'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 導航至關於頁面
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('關於功能開發中'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // 條款
              ListTile(
                title: const Text('條款'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 導航至條款頁面
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('條款功能開發中'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // 隱私權政策
              ListTile(
                title: const Text('隱私權政策'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 導航至隱私權政策頁面
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('隱私權政策功能開發中'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 版本號
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '版本 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 更新通知開關狀態
  Future<void> _updateNotificationEnabled(bool value, UserModel? user) async {
    if (user == null) return;
    
    try {
      // 更新 Firestore 中的設定
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.updateUserData(user.id, {
        'settings.notificationsEnabled': value,
      });
      
      // 顯示提示訊息
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(value ? '已開啟 APP 通知' : '已關閉 APP 通知'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('更新設定失敗：$e')),
        );
      }
    }
  }

  /// 顯示時間選擇器（使用 CupertinoPicker，分鐘間隔 10 分鐘）
  Future<void> _showTimePicker(UserModel? user) async {
    if (user == null) return;
    
    // 取得當前設定的時間
    final initialHour = user.settings.notificationHour;
    // 將分鐘對齊到最近的 10 分鐘間隔
    final initialMinuteIndex = (user.settings.notificationMinute / 10).round().clamp(0, 5);
    
    // 用於追蹤選擇的小時和分鐘
    int selectedHour = initialHour;
    int selectedMinuteIndex = initialMinuteIndex;
    
    // 分鐘選項列表（10 分鐘間隔：0, 10, 20, 30, 40, 50）
    final minuteOptions = [0, 10, 20, 30, 40, 50];
    
    // 使用底部面板顯示 CupertinoPicker
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: 340,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 標題列
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 取消按鈕
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // 標題
                    const Text(
                      '選擇通知時間',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // 確定按鈕
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text(
                        '確定',
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
              
              // CupertinoPicker 區域
              Expanded(
                child: Row(
                  children: [
                    // 小時選擇器
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedHour,
                        ),
                        itemExtent: 40,
                        magnification: 1.2,
                        squeeze: 1.0,
                        useMagnifier: true,
                        onSelectedItemChanged: (index) {
                          selectedHour = index;
                        },
                        children: List.generate(24, (index) {
                          return Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    
                    // 分隔符號
                    const Center(
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    // 分鐘選擇器（10 分鐘間隔）
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedMinuteIndex,
                        ),
                        itemExtent: 40,
                        magnification: 1.2,
                        squeeze: 1.0,
                        useMagnifier: true,
                        onSelectedItemChanged: (index) {
                          selectedMinuteIndex = index;
                        },
                        children: minuteOptions.map((minute) {
                          return Center(
                            child: Text(
                              minute.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // 如果使用者取消或未確認則返回
    if (confirmed != true) return;
    
    // 計算選擇的分鐘值
    final selectedMinute = minuteOptions[selectedMinuteIndex];
    
    try {
      // 更新 Firestore 中的設定
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.updateUserData(user.id, {
        'settings.notificationHour': selectedHour,
        'settings.notificationMinute': selectedMinute,
      });
      
      // 顯示提示訊息
      if (mounted) {
        final timeStr = '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('通知時間已設定為 $timeStr'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('更新設定失敗：$e')),
        );
      }
    }
  }

  /// 顯示週起始日選擇器（底部面板樣式，單選）
  Future<void> _showWeekStartDayPicker(UserModel? user) async {
    if (user == null) return;
    
    // 週起始日選項列表
    final options = [
      {'value': 0, 'name': '星期日'},
      {'value': 1, 'name': '星期一'},
      {'value': 6, 'name': '星期六'},
    ];
    
    // 取得當前設定的週起始日
    final currentValue = user.settings.weekStartDay;
    
    // 使用底部面板顯示選擇器
    final selectedValue = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
                    // 空白區域（保持對稱）
                    const SizedBox(width: 48),
                    
                    // 標題
                    const Text(
                      '選擇週起始日',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    // 關閉按鈕
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // 選項列表
              ...options.map((option) {
                final value = option['value'] as int;
                final name = option['name'] as String;
                final isSelected = value == currentValue;
                
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected 
                        ? Colors.black 
                        : Colors.grey[400],
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected 
                          ? Colors.black 
                          : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: Colors.black.withOpacity(0.1),
                  onTap: () => Navigator.of(sheetContext).pop(value),
                );
              }),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    
    // 若選擇相同值或取消，則不更新
    if (selectedValue == null || selectedValue == currentValue) return;
    
    try {
      // 更新 Firestore 中的設定
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.updateUserData(user.id, {
        'settings.weekStartDay': selectedValue,
      });
      
      // 取得選擇的週起始日名稱
      final selectedName = options.firstWhere(
        (o) => o['value'] == selectedValue,
      )['name'] as String;
      
      // 顯示提示訊息
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('週起始日已設定為 $selectedName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('更新設定失敗：$e')),
        );
      }
    }
  }

  /// 顯示時區選擇器
  Future<void> _showTimezonePicker(UserModel? user) async {
    if (user == null) return;

    // 常見時區列表（按地區分組）
    final timezones = [
      // 亞洲
      {'value': 'Asia/Taipei', 'name': '台北', 'offset': 'GMT+8'},
      {'value': 'Asia/Tokyo', 'name': '東京', 'offset': 'GMT+9'},
      {'value': 'Asia/Shanghai', 'name': '上海', 'offset': 'GMT+8'},
      {'value': 'Asia/Hong_Kong', 'name': '香港', 'offset': 'GMT+8'},
      {'value': 'Asia/Singapore', 'name': '新加坡', 'offset': 'GMT+8'},
      {'value': 'Asia/Seoul', 'name': '首爾', 'offset': 'GMT+9'},
      // 美洲
      {'value': 'America/New_York', 'name': '紐約', 'offset': 'GMT-5/-4'},
      {'value': 'America/Los_Angeles', 'name': '洛杉磯', 'offset': 'GMT-8/-7'},
      {'value': 'America/Chicago', 'name': '芝加哥', 'offset': 'GMT-6/-5'},
      // 歐洲
      {'value': 'Europe/London', 'name': '倫敦', 'offset': 'GMT+0/+1'},
      {'value': 'Europe/Paris', 'name': '巴黎', 'offset': 'GMT+1/+2'},
      {'value': 'Europe/Berlin', 'name': '柏林', 'offset': 'GMT+1/+2'},
      // 大洋洲
      {'value': 'Australia/Sydney', 'name': '雪梨', 'offset': 'GMT+10/+11'},
      {'value': 'Pacific/Auckland', 'name': '奧克蘭', 'offset': 'GMT+12/+13'},
      // 通用
      {'value': 'UTC', 'name': 'UTC', 'offset': 'GMT+0'},
    ];

    // 取得當前設定的時區
    final currentValue = user.settings.timezone;

    // 顯示選擇對話框
    final selectedValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
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
                    // 空白區域（保持對稱）
                    const SizedBox(width: 48),

                    // 標題
                    const Text(
                      '選擇時區',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // 關閉按鈕
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 時區列表
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: timezones.length,
                  itemBuilder: (context, index) {
                    final tz = timezones[index];
                    final value = tz['value'] as String;
                    final name = tz['name'] as String;
                    final offset = tz['offset'] as String;
                    final isSelected = value == currentValue;

                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? Colors.black
                            : Colors.grey[400],
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Colors.black
                              : Colors.black87,
                        ),
                      ),
                      subtitle: Text(offset),
                      selected: isSelected,
                      selectedTileColor: Colors.black.withOpacity(0.1),
                      onTap: () => Navigator.of(sheetContext).pop(value),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    
    if (selectedValue == null || selectedValue == currentValue) return;
    
    try {
      // 更新 Firestore 中的設定
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.updateUserData(user.id, {
        'settings.timezone': selectedValue,
      });
      
      // 取得選擇的時區名稱
      final selectedTz = timezones.firstWhere(
        (tz) => tz['value'] == selectedValue,
      );
      final selectedName = '${selectedTz['name']} (${selectedTz['offset']})';
      
      // 顯示提示訊息
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('時區已設定為 $selectedName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('更新設定失敗：$e')),
        );
      }
    }
  }

  /// 顯示語言選擇器
  Future<void> _showLanguagePicker(UserModel? user) async {
    if (user == null) return;

    // 語言選項列表
    // 除繁體中文（台灣）外，其他語言待開發
    final languages = [
      {'value': 'zh-TW', 'name': '繁體中文（台灣）', 'available': true},
      {'value': 'en', 'name': 'English', 'available': true},
      {'value': 'ja', 'name': '日本語', 'available': true},
      {'value': 'ko', 'name': '한국어', 'available': true},
      {'value': 'zh-CN', 'name': '简体中文', 'available': true},
    ];

    // 取得當前設定的語言
    final currentValue = user.settings.language;

    // 顯示選擇對話框
    final selectedValue = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
                    // 空白區域（保持對稱）
                    const SizedBox(width: 48),

                    // 標題
                    const Text(
                      '選擇語言',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // 關閉按鈕
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 選項列表
              ...languages.map((lang) {
                final value = lang['value'] as String;
                final name = lang['name'] as String;
                final available = lang['available'] as bool;
                final isSelected = value == currentValue;

                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? Colors.black
                        : Colors.grey[400],
                  ),
                  title: Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: available
                              ? (isSelected
                                  ? Colors.black
                                  : Colors.black87)
                              : Colors.grey[500],
                        ),
                      ),
                      if (!available) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '待開發',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  selectedTileColor: Colors.black.withOpacity(0.1),
                  onTap: available
                      ? () => Navigator.of(sheetContext).pop(value)
                      : () {
                          // 顯示待開發提示
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.clearSnackBars();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('$name 功能開發中，敬請期待！'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                );
              }),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    // 若選擇相同值或取消，則不更新
    if (selectedValue == null || selectedValue == currentValue) return;

    try {
      // 更新 Firestore 中的設定
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.updateUserData(user.id, {
        'settings.language': selectedValue,
      });

      // 取得選擇的語言名稱
      final selectedLang = languages.firstWhere(
        (lang) => lang['value'] == selectedValue,
      );
      final selectedName = selectedLang['name'] as String;

      // 顯示提示訊息
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('語言已設定為 $selectedName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('更新設定失敗：$e')),
        );
      }
    }
  }
}
