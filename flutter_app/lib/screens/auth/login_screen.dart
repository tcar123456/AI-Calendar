import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

/// 登入畫面
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> 
    with SingleTickerProviderStateMixin {
  // ==================== 表單相關 ====================
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  /// 是否為註冊模式（false 為登入模式）
  bool _isSignUpMode = false;
  
  /// 是否顯示密碼
  bool _obscurePassword = true;
  
  /// 動畫控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化動畫
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kAnimationDurationMedium),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 監聽認證狀態
    final authState = ref.watch(authControllerProvider);
    
    // 監聽錯誤訊息並顯示 SnackBar
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kPaddingLarge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo 和標題
                  _buildHeader(),
                  
                  const SizedBox(height: 48),
                  
                  // 登入/註冊表單
                  _buildForm(),
                  
                  const SizedBox(height: 24),
                  
                  // 提交按鈕
                  _buildSubmitButton(authState),
                  
                  const SizedBox(height: 16),
                  
                  // 切換登入/註冊模式
                  _buildToggleModeButton(),
                  
                  if (!_isSignUpMode) ...[
                    const SizedBox(height: 8),
                    _buildForgotPasswordButton(),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // 其他登入方式（未來可加入）
                  _buildOtherSignInOptions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 建立標題區域
  Widget _buildHeader() {
    return Column(
      children: [
        // Logo 圖示
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(kPrimaryColorValue),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(kPrimaryColorValue).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            size: 56,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 應用程式標題
        Text(
          'AI 語音行事曆',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(kPrimaryColorValue),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 副標題
        Text(
          '用聲音管理您的時間',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 建立登入/註冊表單
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // 名稱輸入框（僅註冊時顯示）
          if (_isSignUpMode) ...[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '顯示名稱',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _isSignUpMode
                  ? (value) {
                      if (value == null || value.isEmpty) {
                        return '請輸入顯示名稱';
                      }
                      return null;
                    }
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          
          // Email 輸入框
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '電子郵件',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '請輸入電子郵件';
              }
              if (!kEmailRegex.hasMatch(value)) {
                return '電子郵件格式不正確';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // 密碼輸入框
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '密碼',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '請輸入密碼';
              }
              if (_isSignUpMode && value.length < 6) {
                return '密碼至少需要 6 個字元';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// 建立提交按鈕
  Widget _buildSubmitButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: authState.isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(kPrimaryColorValue),
          foregroundColor: Colors.white,
        ),
        child: authState.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(_isSignUpMode ? '註冊' : '登入'),
      ),
    );
  }

  /// 建立切換模式按鈕
  Widget _buildToggleModeButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          _isSignUpMode = !_isSignUpMode;
        });
      },
      child: Text(
        _isSignUpMode ? '已有帳號？點此登入' : '沒有帳號？點此註冊',
        style: const TextStyle(color: Color(kPrimaryColorValue)),
      ),
    );
  }

  /// 建立忘記密碼按鈕
  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _handleForgotPassword,
      child: Text(
        '忘記密碼？',
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  /// 建立其他登入方式
  Widget _buildOtherSignInOptions() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '或使用以下方式登入',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Google 登入按鈕（未來實作）
        OutlinedButton.icon(
          onPressed: () {
            // TODO: 實作 Google 登入
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google 登入功能開發中')),
            );
          },
          icon: const Icon(Icons.g_mobiledata, size: 32),
          label: const Text('使用 Google 登入'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        ),
      ],
    );
  }

  /// 處理提交
  Future<void> _handleSubmit() async {
    // 驗證表單
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    final authController = ref.read(authControllerProvider.notifier);

    if (_isSignUpMode) {
      // 註冊
      await authController.signUpWithEmail(
        email,
        password,
        displayName: name.isNotEmpty ? name : null,
      );
    } else {
      // 登入
      await authController.signInWithEmail(email, password);
    }
  }

  /// 處理忘記密碼
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !kEmailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先輸入有效的電子郵件地址'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 顯示確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重設密碼'),
        content: Text('將發送密碼重設郵件至：\n$email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authController = ref.read(authControllerProvider.notifier);
      await authController.sendPasswordResetEmail(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('密碼重設郵件已發送，請檢查您的信箱'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

