import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/constants.dart';

/// 個人資料編輯頁面
/// 
/// 讓用戶編輯自己的個人資訊：
/// - 顯示名稱
/// - （未來可擴展：頭像、其他設定）
class ProfileEditScreen extends ConsumerStatefulWidget {
  /// 用戶資料
  final UserModel? user;

  const ProfileEditScreen({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  /// 顯示名稱輸入控制器
  late TextEditingController _displayNameController;
  
  /// 是否正在儲存
  bool _isSaving = false;
  
  /// 是否有變更
  bool _hasChanges = false;
  
  /// 原始顯示名稱（用於判斷是否有變更）
  late String _originalDisplayName;

  @override
  void initState() {
    super.initState();
    // 初始化原始值
    _originalDisplayName = widget.user?.displayName ?? '';
    
    // 初始化輸入框
    _displayNameController = TextEditingController(
      text: _originalDisplayName,
    );
    
    // 監聽輸入變化
    _displayNameController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_onInputChanged);
    _displayNameController.dispose();
    super.dispose();
  }

  /// 輸入變化時的回調
  void _onInputChanged() {
    final currentName = _displayNameController.text.trim();
    
    setState(() {
      _hasChanges = currentName != _originalDisplayName;
    });
  }

  /// 儲存變更
  Future<void> _saveChanges() async {
    final newDisplayName = _displayNameController.text.trim();
    
    // 檢查是否有輸入名稱
    if (newDisplayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入顯示名稱')),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // 取得 Firebase Service 並更新用戶資料
      final userId = widget.user?.id;
      if (userId == null) {
        throw Exception('用戶 ID 不存在');
      }
      
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.updateUserData(userId, {
        'displayName': newDisplayName,
      });
      
      if (mounted) {
        // 更新原始值，這樣儲存按鈕會變成不可點選狀態
        setState(() {
          _originalDisplayName = newDisplayName;
          _hasChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('個人資料已更新')),
        );
        // 不再自動返回，保留在當前頁面
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗：$e')),
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
  
  /// 顯示登出確認對話框
  Future<void> _showSignOutConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('登出'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      // 執行登出
      ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 取得當前選擇的行事曆顏色作為主題色
    final selectedCalendar = ref.watch(selectedCalendarProvider);
    final themeColor = selectedCalendar?.color ?? const Color(kPrimaryColorValue);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯個人資料'),
        centerTitle: true,
        // AppBar 背景色使用選擇的行事曆顏色
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        actions: [
          // 儲存按鈕（常駐顯示，無變更時不可點選）
          TextButton(
            // 只有在有變更且不在儲存中時才可點選
            onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '儲存',
                    style: TextStyle(
                      // 有變更時顯示白色，無變更時顯示半透明白色
                      color: _hasChanges 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kPaddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 用戶頭像區域
            _buildAvatarSection(themeColor),
            
            const SizedBox(height: 32),
            
            // 用戶資訊表單
            _buildUserInfoForm(themeColor),
            
            const SizedBox(height: 24),
            
            // 帳號資訊（唯讀）
            _buildAccountInfo(themeColor),
            
            const SizedBox(height: 48),
            
            // 登出按鈕
            _buildSignOutButton(),
            
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 建立頭像區域
  Widget _buildAvatarSection(Color themeColor) {
    return Center(
      child: Column(
        children: [
          // 頭像
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: themeColor.withOpacity(0.1),
                backgroundImage: widget.user?.photoURL != null
                    ? NetworkImage(widget.user!.photoURL!)
                    : null,
                child: widget.user?.photoURL == null
                    ? Icon(
                        Icons.person,
                        size: 50,
                        color: themeColor,
                      )
                    : null,
              ),
              // 編輯頭像按鈕（未來功能）
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 提示文字
          Text(
            '點擊更換頭像（開發中）',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 建立用戶資訊表單
  Widget _buildUserInfoForm(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題
        Text(
          '基本資訊',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeColor,
          ),
        ),
        const SizedBox(height: 16),
        
        // 顯示名稱輸入
        TextField(
          controller: _displayNameController,
          decoration: InputDecoration(
            labelText: '顯示名稱',
            hintText: '請輸入您的顯示名稱',
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: themeColor, width: 2),
            ),
            labelStyle: TextStyle(color: themeColor),
            prefixIcon: Icon(Icons.person_outline, color: themeColor),
          ),
          cursorColor: themeColor,
          enabled: !_isSaving,
        ),
      ],
    );
  }

  /// 建立帳號資訊區域（唯讀）
  Widget _buildAccountInfo(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題
        Text(
          '帳號資訊',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeColor,
          ),
        ),
        const SizedBox(height: 16),
        
        // Email（唯讀）
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.email_outlined, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '電子郵件',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user?.email ?? '未設定',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // 鎖定圖示表示不可編輯
              Icon(Icons.lock_outline, color: Colors.grey[400], size: 18),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // 提示文字
        Text(
          '電子郵件無法修改',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 帳號建立時間
        _buildInfoRow(
          icon: Icons.calendar_today_outlined,
          label: '帳號建立時間',
          value: _formatDate(widget.user?.createdAt),
        ),
      ],
    );
  }

  /// 建立資訊列
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime? date) {
    if (date == null) return '未知';
    return '${date.year}年${date.month}月${date.day}日';
  }
  
  /// 建立登出按鈕區域
  Widget _buildSignOutButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _showSignOutConfirmDialog,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text(
            '登出',
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

