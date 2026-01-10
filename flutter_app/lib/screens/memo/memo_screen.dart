import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/memo_model.dart';
import '../../providers/memo_provider.dart';
import '../../utils/constants.dart';

/// 備忘錄主畫面
/// 
/// 顯示用戶的所有備忘錄，支援新增、編輯、刪除、完成等操作
class MemoScreen extends ConsumerStatefulWidget {
  const MemoScreen({super.key});

  @override
  ConsumerState<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends ConsumerState<MemoScreen> with SingleTickerProviderStateMixin {
  /// Tab 控制器（未完成 / 已完成）
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('備忘錄'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '待辦事項'),
            Tab(text: '已完成'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 未完成的備忘錄
          _buildPendingMemoList(),
          // 已完成的備忘錄
          _buildCompletedMemoList(),
        ],
      ),
      // 新增備忘錄按鈕
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMemoEditor(context, null),
        backgroundColor: const Color(kPrimaryColorValue),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 建立未完成的備忘錄列表
  Widget _buildPendingMemoList() {
    final pendingMemosAsync = ref.watch(pendingMemosProvider);

    return pendingMemosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('載入失敗：$error'),
          ],
        ),
      ),
      data: (memos) {
        if (memos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            message: '沒有待辦事項\n點擊右下角按鈕新增備忘錄',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(kPaddingMedium),
          itemCount: memos.length,
          itemBuilder: (context, index) {
            return _buildMemoCard(memos[index]);
          },
        );
      },
    );
  }

  /// 建立已完成的備忘錄列表
  Widget _buildCompletedMemoList() {
    final completedMemosAsync = ref.watch(completedMemosProvider);

    return completedMemosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('載入失敗：$error'),
          ],
        ),
      ),
      data: (memos) {
        if (memos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            message: '沒有已完成的備忘錄',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(kPaddingMedium),
          itemCount: memos.length,
          itemBuilder: (context, index) {
            return _buildMemoCard(memos[index], isCompleted: true);
          },
        );
      },
    );
  }

  /// 建立空狀態提示
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 建立備忘錄卡片
  Widget _buildMemoCard(Memo memo, {bool isCompleted = false}) {
    // 優先級顏色
    Color priorityColor;
    switch (memo.priority) {
      case 2:
        priorityColor = const Color(kErrorColorValue);
        break;
      case 1:
        priorityColor = const Color(kWarningColorValue);
        break;
      default:
        priorityColor = const Color(kSuccessColorValue);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: kPaddingMedium),
      child: InkWell(
        onTap: () => _showMemoEditor(context, memo),
        borderRadius: BorderRadius.circular(kBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(kPaddingMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 完成勾選框
              GestureDetector(
                onTap: () => _toggleComplete(memo),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? const Color(kSuccessColorValue) : Colors.grey,
                      width: 2,
                    ),
                    color: isCompleted ? const Color(kSuccessColorValue) : Colors.transparent,
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              
              const SizedBox(width: kPaddingMedium),
              
              // 備忘錄內容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題列（含釘選圖示）
                    Row(
                      children: [
                        if (memo.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.push_pin,
                              size: 16,
                              color: const Color(kPrimaryColorValue),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            memo.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted 
                                  ? TextDecoration.lineThrough 
                                  : null,
                              color: isCompleted ? Colors.grey : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // 內容預覽
                    if (memo.content != null && memo.content!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        memo.content!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          decoration: isCompleted 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    
                    // 底部資訊列
                    Row(
                      children: [
                        // 優先級標籤
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            memo.getPriorityText(),
                            style: TextStyle(
                              fontSize: 12,
                              color: priorityColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // 提醒時間
                        if (memo.reminderTime != null) ...[
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: memo.isReminderPast() 
                                ? Colors.red 
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MM/dd HH:mm').format(memo.reminderTime!),
                            style: TextStyle(
                              fontSize: 12,
                              color: memo.isReminderPast() 
                                  ? Colors.red 
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                        
                        const Spacer(),
                        
                        // 更多選項
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(
                                    memo.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(memo.isPinned ? '取消釘選' : '釘選'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('刪除', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'pin') {
                              _togglePin(memo);
                            } else if (value == 'delete') {
                              _confirmDelete(memo);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切換完成狀態
  Future<void> _toggleComplete(Memo memo) async {
    await ref.read(memoControllerProvider.notifier).toggleComplete(memo);
  }

  /// 切換釘選狀態
  Future<void> _togglePin(Memo memo) async {
    await ref.read(memoControllerProvider.notifier).togglePin(memo);
  }

  /// 確認刪除
  void _confirmDelete(Memo memo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${memo.title}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(memoControllerProvider.notifier).deleteMemo(memo.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('備忘錄已刪除')),
                );
              }
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 顯示備忘錄編輯器
  void _showMemoEditor(BuildContext context, Memo? memo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemoEditorSheet(memo: memo),
    );
  }
}

/// 備忘錄編輯器底部面板
class MemoEditorSheet extends ConsumerStatefulWidget {
  /// 要編輯的備忘錄（null 表示新增）
  final Memo? memo;

  const MemoEditorSheet({super.key, this.memo});

  @override
  ConsumerState<MemoEditorSheet> createState() => _MemoEditorSheetState();
}

class _MemoEditorSheetState extends ConsumerState<MemoEditorSheet> {
  /// 標題控制器
  late TextEditingController _titleController;
  
  /// 內容控制器
  late TextEditingController _contentController;
  
  /// 優先級
  late int _priority;
  
  /// 提醒時間
  DateTime? _reminderTime;
  
  /// 是否正在儲存
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo?.title ?? '');
    _contentController = TextEditingController(text: widget.memo?.content ?? '');
    _priority = widget.memo?.priority ?? 0;
    _reminderTime = widget.memo?.reminderTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.memo != null;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kPaddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題列
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add_task,
                    color: const Color(kPrimaryColorValue),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? '編輯備忘錄' : '新增備忘錄',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const Divider(),
              const SizedBox(height: kPaddingMedium),
              
              // 標題輸入
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '標題',
                  hintText: '輸入備忘錄標題',                 
                ),
                textInputAction: TextInputAction.next,
              ),
              
              const SizedBox(height: kPaddingMedium),
              
              // 內容輸入
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '內容（選填）',
                  hintText: '輸入備忘錄內容',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: kPaddingMedium),
              
              // 優先級選擇
              Row(
                children: [
                  const Icon(Icons.flag, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Text('優先級：'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('普通')),
                        ButtonSegment(value: 1, label: Text('重要')),
                        ButtonSegment(value: 2, label: Text('緊急')),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _priority = selected.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: kPaddingMedium),
              
              // 提醒時間
              InkWell(
                onTap: _pickReminderTime,
                borderRadius: BorderRadius.circular(kBorderRadius),
                child: Container(
                  padding: const EdgeInsets.all(kPaddingMedium),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(kBorderRadius),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: _reminderTime != null 
                            ? const Color(kPrimaryColorValue)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _reminderTime != null
                              ? '提醒時間：${DateFormat('yyyy/MM/dd HH:mm').format(_reminderTime!)}'
                              : '設定提醒時間（選填）',
                          style: TextStyle(
                            color: _reminderTime != null 
                                ? Colors.black87 
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      if (_reminderTime != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              _reminderTime = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: kPaddingLarge),
              
              // 儲存按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(kPrimaryColorValue),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(isEditing ? '儲存變更' : '新增備忘錄'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 選擇提醒時間
  Future<void> _pickReminderTime() async {
    // 選擇日期
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date == null || !mounted) return;
    
    // 選擇時間
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime != null
          ? TimeOfDay.fromDateTime(_reminderTime!)
          : TimeOfDay.now(),
    );
    
    if (time == null || !mounted) return;
    
    setState(() {
      _reminderTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  /// 儲存備忘錄
  Future<void> _save() async {
    // 驗證標題
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入備忘錄標題')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final controller = ref.read(memoControllerProvider.notifier);
      
      if (widget.memo != null) {
        // 更新現有備忘錄
        final updatedMemo = widget.memo!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text.trim().isEmpty 
              ? null 
              : _contentController.text.trim(),
          priority: _priority,
          reminderTime: _reminderTime,
          updatedAt: DateTime.now(),
        );
        await controller.updateMemo(widget.memo!.id, updatedMemo);
      } else {
        // 建立新備忘錄
        await controller.createMemo(
          title: _titleController.text.trim(),
          content: _contentController.text.trim().isEmpty 
              ? null 
              : _contentController.text.trim(),
          priority: _priority,
          reminderTime: _reminderTime,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.memo != null ? '備忘錄已更新' : '備忘錄已新增'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

