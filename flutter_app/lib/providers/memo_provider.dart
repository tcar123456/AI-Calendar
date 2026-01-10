import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/memo_model.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// 備忘錄列表 Provider
/// 
/// 監聽當前用戶的所有備忘錄
final memosProvider = StreamProvider<List<Memo>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return Stream.value([]);
  }
  
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchUserMemos(userId);
});

/// 未完成的備忘錄 Provider
/// 
/// 只取得未完成的備忘錄，並按照釘選狀態和優先級排序
final pendingMemosProvider = Provider<AsyncValue<List<Memo>>>((ref) {
  final memosAsync = ref.watch(memosProvider);
  
  return memosAsync.whenData((memos) {
    // 過濾未完成的備忘錄
    final pendingMemos = memos.where((m) => !m.isCompleted).toList();
    
    // 排序：釘選的在前，然後按優先級排序，最後按建立時間
    pendingMemos.sort((a, b) {
      // 釘選狀態
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // 優先級（高到低）
      if (a.priority != b.priority) {
        return b.priority.compareTo(a.priority);
      }
      // 建立時間（新到舊）
      return b.createdAt.compareTo(a.createdAt);
    });
    
    return pendingMemos;
  });
});

/// 已完成的備忘錄 Provider
/// 
/// 只取得已完成的備忘錄
final completedMemosProvider = Provider<AsyncValue<List<Memo>>>((ref) {
  final memosAsync = ref.watch(memosProvider);
  
  return memosAsync.whenData((memos) {
    // 過濾已完成的備忘錄，按更新時間排序（最近完成的在前）
    final completedMemos = memos.where((m) => m.isCompleted).toList();
    completedMemos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return completedMemos;
  });
});

/// 備忘錄控制器 State
class MemoState {
  /// 是否正在載入
  final bool isLoading;
  
  /// 錯誤訊息
  final String? errorMessage;
  
  /// 成功訊息
  final String? successMessage;

  const MemoState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  /// 複製並修改部分屬性
  MemoState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return MemoState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// 備忘錄控制器
/// 
/// 處理備忘錄的建立、更新、刪除等操作
class MemoController extends StateNotifier<MemoState> {
  final FirebaseService _firebaseService;
  final Ref _ref;

  MemoController(this._firebaseService, this._ref) : super(const MemoState());

  /// 建立備忘錄
  Future<String?> createMemo({
    required String title,
    String? content,
    DateTime? reminderTime,
    List<String> tags = const [],
    int priority = 0,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(errorMessage: '用戶未登入');
      return null;
    }

    state = state.copyWith(isLoading: true, clearMessages: true);
    
    try {
      final memo = Memo(
        id: '', // 會由 Firestore 自動產生
        userId: userId,
        title: title,
        content: content,
        isCompleted: false,
        isPinned: false,
        reminderTime: reminderTime,
        tags: tags,
        priority: priority,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final memoId = await _firebaseService.createMemo(memo);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '備忘錄建立成功',
      );
      
      return memoId;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '建立備忘錄失敗：$e',
      );
      return null;
    }
  }

  /// 更新備忘錄
  Future<bool> updateMemo(String memoId, Memo memo) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    
    try {
      await _firebaseService.updateMemo(memoId, memo);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '備忘錄更新成功',
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '更新備忘錄失敗：$e',
      );
      return false;
    }
  }

  /// 切換完成狀態
  Future<bool> toggleComplete(Memo memo) async {
    try {
      final updatedMemo = memo.copyWith(
        isCompleted: !memo.isCompleted,
        updatedAt: DateTime.now(),
      );
      
      await _firebaseService.updateMemo(memo.id, updatedMemo);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: '更新狀態失敗：$e',
      );
      return false;
    }
  }

  /// 切換釘選狀態
  Future<bool> togglePin(Memo memo) async {
    try {
      final updatedMemo = memo.copyWith(
        isPinned: !memo.isPinned,
        updatedAt: DateTime.now(),
      );
      
      await _firebaseService.updateMemo(memo.id, updatedMemo);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: '更新狀態失敗：$e',
      );
      return false;
    }
  }

  /// 刪除備忘錄
  Future<bool> deleteMemo(String memoId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    
    try {
      await _firebaseService.deleteMemo(memoId);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: '備忘錄刪除成功',
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '刪除備忘錄失敗：$e',
      );
      return false;
    }
  }

  /// 清除訊息
  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }
}

/// 備忘錄控制器 Provider
final memoControllerProvider = StateNotifierProvider<MemoController, MemoState>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return MemoController(firebaseService, ref);
});

