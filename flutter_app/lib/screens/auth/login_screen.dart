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
    with TickerProviderStateMixin {
  // ==================== 表單相關 ====================

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  /// 是否顯示 Email 登入表單
  bool _showEmailForm = false;

  /// 是否為註冊模式（false 為登入模式）
  bool _isSignUpMode = false;

  /// 是否顯示密碼
  bool _obscurePassword = true;

  /// 淡入動畫控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  /// 頁面切換動畫控制器
  late AnimationController _slideController;
  late Animation<Offset> _loginButtonsSlideAnimation;
  late Animation<Offset> _emailFormSlideAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化淡入動畫
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kAnimationDurationMedium),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // 初始化頁面切換動畫
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 登入按鈕區域：從中間向左滑出
    _loginButtonsSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    // Email 表單區域：從右側滑入中間
    _emailFormSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// 切換到 Email 表單（向左推入）
  void _showEmailLoginForm() {
    setState(() {
      _showEmailForm = true;
    });
    _slideController.forward();
  }

  /// 返回登入按鈕（向右推出）
  void _hideEmailLoginForm() {
    _slideController.reverse().then((_) {
      setState(() {
        _showEmailForm = false;
        _isSignUpMode = false;
        _emailController.clear();
        _passwordController.clear();
        _nameController.clear();
      });
    });
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
        child: Stack(
          children: [
            // 主要內容
            FadeTransition(
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

                      // 使用 ClipRect 防止動畫溢出
                      ClipRect(
                        child: Stack(
                          children: [
                            // 登入按鈕區域（向左滑出）
                            SlideTransition(
                              position: _loginButtonsSlideAnimation,
                              child: _buildLoginButtons(authState),
                            ),
                            // Email 表單區域（從右滑入）
                            if (_showEmailForm)
                              SlideTransition(
                                position: _emailFormSlideAnimation,
                                child: _buildEmailLoginSection(authState),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 左上角返回按鈕（僅在 Email 表單顯示時出現）
            if (_showEmailForm)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: _hideEmailLoginForm,
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.grey[600],
                  tooltip: '返回',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 建立標題區域
  Widget _buildHeader() {
    return Column(
      children: [
        // Logo 圖示（黑白簡約風格）
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
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
                color: Colors.black,
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

  /// 建立登入按鈕區域（初始畫面）
  Widget _buildLoginButtons(AuthState authState) {
    return Column(
      children: [
        // Email 登入按鈕
        _buildLoginButton(
          icon: Icons.email_outlined,
          iconColor: Colors.grey[700]!,
          label: '使用 Email 登入',
          onPressed: authState.isLoading ? null : _showEmailLoginForm,
        ),

        const SizedBox(height: 16),

        // Google 登入按鈕
        _buildLoginButton(
          icon: Icons.g_mobiledata,
          iconColor: Colors.red,
          label: '使用 Google 登入',
          onPressed: authState.isLoading ? null : _handleGoogleSignIn,
        ),

        const SizedBox(height: 16),

        // Facebook 登入按鈕（禁用）
        _buildLoginButton(
          icon: Icons.facebook,
          iconColor: Colors.blue,
          label: '使用 Facebook 登入',
          onPressed: null,
          isDisabled: true,
        ),

        const SizedBox(height: 12),

        // Loading 指示器
        if (authState.isLoading) ...[
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ],
    );
  }

  /// 建立登入按鈕（統一樣式）
  Widget _buildLoginButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback? onPressed,
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          side: BorderSide(
            color: isDisabled ? Colors.grey[300]! : Colors.grey[400]!,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDisabled ? Colors.grey[400] : iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: isDisabled ? Colors.grey[400] : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建立 Email 登入區域
  Widget _buildEmailLoginSection(AuthState authState) {
    return Column(
      children: [
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
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
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
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
        style: const TextStyle(color: Colors.black),
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

  /// 處理 Google 登入
  Future<void> _handleGoogleSignIn() async {
    final authController = ref.read(authControllerProvider.notifier);
    await authController.signInWithGoogle();
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
