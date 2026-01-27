import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/calendar_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../utils/constants.dart';

/// 行事曆成員管理面板
///
/// 顯示行事曆的成員列表，支援邀請新成員和移除成員
class CalendarMembersSheet extends ConsumerStatefulWidget {
  /// 滾動控制器（用於 DraggableScrollableSheet）
  final ScrollController? scrollController;

  const CalendarMembersSheet({
    super.key,
    this.scrollController,
  });

  /// 顯示成員面板的靜態方法
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => CalendarMembersSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  ConsumerState<CalendarMembersSheet> createState() =>
      _CalendarMembersSheetState();
}

class _CalendarMembersSheetState extends ConsumerState<CalendarMembersSheet> {
  /// 邀請用的 Email 輸入控制器
  final TextEditingController _emailController = TextEditingController();

  /// 是否正在邀請中
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// 邀請成員
  Future<void> _inviteMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('請輸入 Email');
      return;
    }

    // 驗證 Email 格式
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Email 格式不正確');
      return;
    }

    final calendar = ref.read(selectedCalendarProvider);
    if (calendar == null) return;

    setState(() => _isInviting = true);

    try {
      final success = await ref
          .read(calendarControllerProvider.notifier)
          .inviteMemberByEmail(calendar.id, email);

      if (success) {
        _emailController.clear();
        _showMessage('已成功邀請成員');
      } else {
        final errorMessage =
            ref.read(calendarControllerProvider).errorMessage ?? '邀請失敗';
        _showMessage(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  /// 移除成員
  Future<void> _removeMember(String memberId) async {
    final calendar = ref.read(selectedCalendarProvider);
    if (calendar == null) return;

    // 確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成員'),
        content: const Text('確定要移除此成員嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref
        .read(calendarControllerProvider.notifier)
        .removeMember(calendar.id, memberId);

    if (success) {
      _showMessage('成員已移除');
    } else {
      final errorMessage =
          ref.read(calendarControllerProvider).errorMessage ?? '移除失敗';
      _showMessage(errorMessage);
    }
  }

  /// 顯示訊息
  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(selectedCalendarProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final membersAsync = ref.watch(calendarMembersProvider);

    if (calendar == null) {
      return const SizedBox.shrink();
    }

    final isOwner = calendar.ownerId == currentUserId;

    return Column(
      children: [
        // 拖曳指示器
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // 標題區域
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kPaddingMedium,
            vertical: kPaddingSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 關閉按鈕
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '關閉',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),

              // 標題（顯示行事曆名稱）
              Flexible(
                child: Column(
                  children: [
                    const Text(
                      '成員',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      calendar.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 佔位
              const SizedBox(width: 60),
            ],
          ),
        ),

        const Divider(height: 1),

        // 邀請成員區域（創建者和成員都可邀請）
        Padding(
          padding: const EdgeInsets.all(kPaddingMedium),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: '輸入 Email 邀請成員',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _inviteMember(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isInviting ? null : _inviteMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: _isInviting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('邀請'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 成員列表
        Expanded(
          child: membersAsync.when(
            data: (members) => _buildMembersList(
              members,
              calendar,
              currentUserId,
              isOwner,
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('載入失敗：$error'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 建立成員列表
  Widget _buildMembersList(
    List<UserModel> members,
    CalendarModel calendar,
    String? currentUserId,
    bool isOwner,
  ) {
    if (members.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '目前沒有其他成員',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // 將擁有者排在最前面
    final sortedMembers = List<UserModel>.from(members);
    sortedMembers.sort((a, b) {
      if (a.id == calendar.ownerId) return -1;
      if (b.id == calendar.ownerId) return 1;
      return a.getDisplayName().compareTo(b.getDisplayName());
    });

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: kPaddingMedium),
      itemCount: sortedMembers.length,
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        final isSelf = member.id == currentUserId;
        final isMemberOwner = member.id == calendar.ownerId;

        return _MemberListItem(
          member: member,
          calendar: calendar,
          isSelf: isSelf,
          isOwnerRole: isMemberOwner,
          showRemoveButton: isOwner && !isMemberOwner && !isSelf,
          onRemove: () => _removeMember(member.id),
          onEditNickname: isSelf ? () => _showEditNicknameDialog(member) : null,
        );
      },
    );
  }

  /// 顯示編輯暱稱對話框
  Future<void> _showEditNicknameDialog(UserModel member) async {
    final calendar = ref.read(selectedCalendarProvider);
    if (calendar == null) return;

    // 取得目前的暱稱
    final currentNickname = calendar.memberNicknames[member.id] ?? '';
    final controller = TextEditingController(text: currentNickname);

    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編輯暱稱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '設定你在「${calendar.name}」中的暱稱',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: member.getDisplayName(),
                labelText: '暱稱',
                border: const OutlineInputBorder(),
                helperText: '留空則使用原始名稱',
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (newNickname == null) return;

    final success = await ref
        .read(calendarControllerProvider.notifier)
        .updateMemberNickname(calendar.id, member.id, newNickname);

    if (success) {
      _showMessage(newNickname.trim().isEmpty ? '已移除暱稱' : '暱稱已更新');
    } else {
      final errorMessage =
          ref.read(calendarControllerProvider).errorMessage ?? '更新失敗';
      _showMessage(errorMessage);
    }
  }
}

/// 成員列表項目元件
class _MemberListItem extends StatelessWidget {
  /// 成員資料
  final UserModel member;

  /// 行事曆資料（用於取得暱稱）
  final CalendarModel calendar;

  /// 是否為自己
  final bool isSelf;

  /// 是否為擁有者角色
  final bool isOwnerRole;

  /// 是否顯示移除按鈕
  final bool showRemoveButton;

  /// 移除回調
  final VoidCallback onRemove;

  /// 編輯暱稱回調（僅自己可編輯）
  final VoidCallback? onEditNickname;

  const _MemberListItem({
    required this.member,
    required this.calendar,
    required this.isSelf,
    required this.isOwnerRole,
    required this.showRemoveButton,
    required this.onRemove,
    this.onEditNickname,
  });

  @override
  Widget build(BuildContext context) {
    // 取得顯示名稱（優先使用暱稱）
    final nickname = calendar.memberNicknames[member.id];
    final displayName = nickname ?? member.getDisplayName();
    final hasNickname = nickname != null && nickname.isNotEmpty;

    // 頭像使用個人資料的名稱（不是暱稱）
    final originalName = member.getDisplayName();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        backgroundImage:
            member.photoURL != null ? NetworkImage(member.photoURL!) : null,
        child: member.photoURL == null
            ? Text(
                originalName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 擁有者標籤
          if (isOwnerRole) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '擁有者',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 如果有暱稱，顯示原始名稱
          if (hasNickname)
            Text(
              member.getDisplayName(),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          Text(
            member.email,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: _buildTrailing(),
    );
  }

  /// 建立右側按鈕
  Widget? _buildTrailing() {
    // 自己可以編輯暱稱
    if (isSelf && onEditNickname != null) {
      return IconButton(
        icon: Icon(
          Icons.edit,
          size: 20,
          color: Colors.grey[500],
        ),
        onPressed: onEditNickname,
      );
    }

    // 擁有者可以移除成員
    if (showRemoveButton) {
      return IconButton(
        icon: const Icon(Icons.close, size: 20),
        color: Colors.red[400],
        onPressed: onRemove,
      );
    }

    return null;
  }
}
