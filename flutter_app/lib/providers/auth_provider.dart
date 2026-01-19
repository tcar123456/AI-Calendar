import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

/// Firebase 服務 Provider
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

/// 認證狀態 Provider
/// 
/// 監聽 Firebase Auth 的認證狀態變化
/// 回傳當前登入的 User 物件（未登入時為 null）
final authStateProvider = StreamProvider<User?>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.authStateChanges;
});

/// 當前用戶 ID Provider
/// 
/// 從認證狀態中提取用戶 ID
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// 用戶資料 Provider
/// 
/// 根據用戶 ID 從 Firestore 取得完整的用戶資料
/// 自動監聽資料變化並即時更新
final userDataProvider = StreamProvider.family<UserModel?, String>((ref, userId) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchUserData(userId);
});

/// 當前登入用戶的完整資料 Provider
///
/// 結合 authStateProvider 和 firebaseService
/// 提供當前登入用戶的完整資料模型
final currentUserDataProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return Stream.value(null);
  }

  // 直接使用 firebaseService 監聽用戶資料
  // 避免通過 family provider 的 .stream 導致登出後再登入時訂閱問題
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchUserData(userId);
});

/// 認證控制器 State
class AuthState {
  /// 是否正在載入
  final bool isLoading;
  
  /// 錯誤訊息
  final String? errorMessage;
  
  /// 是否已登入
  final bool isAuthenticated;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  /// 複製並修改部分屬性
  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// 認證控制器
/// 
/// 處理登入、註冊、登出等認證相關操作
class AuthController extends StateNotifier<AuthState> {
  final FirebaseService _firebaseService;

  AuthController(this._firebaseService) : super(const AuthState());

  /// Email 登入
  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _firebaseService.signInWithEmail(email, password);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Google 登入
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _firebaseService.signInWithGoogle();

      if (user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
        );
      } else {
        // 用戶取消登入
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Email 註冊
  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      await _firebaseService.signUpWithEmail(
        email,
        password,
        displayName: displayName,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 登出
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _firebaseService.signOut();
      state = const AuthState(isAuthenticated: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 發送密碼重設郵件
  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      await _firebaseService.sendPasswordResetEmail(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 清除錯誤訊息
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// 認證控制器 Provider
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return AuthController(firebaseService);
});

