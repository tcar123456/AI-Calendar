import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import '../models/voice_processing_model.dart';
import '../utils/constants.dart';
import 'dart:typed_data';

/// Firebase 服務類別
/// 統一管理所有 Firebase 相關操作
class FirebaseService {
  // ==================== 單例模式 ====================
  
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // ==================== Firebase 實例 ====================
  
  /// Firebase Auth 實例
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  
  /// Firestore 實例
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Storage 實例
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== 認證相關 ====================

  /// 取得當前用戶
  auth.User? get currentUser => _auth.currentUser;

  /// 取得當前用戶 ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// 監聽認證狀態變化
  Stream<auth.User?> get authStateChanges => _auth.authStateChanges();

  /// Email 登入
  /// 
  /// [email] 電子郵件地址
  /// [password] 密碼
  /// 
  /// 回傳：登入後的用戶物件
  Future<auth.User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Email 註冊
  /// 
  /// [email] 電子郵件地址
  /// [password] 密碼
  /// [displayName] 顯示名稱（可選）
  /// 
  /// 回傳：註冊後的用戶物件
  Future<auth.User?> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      // 建立帳號
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // 更新顯示名稱
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }

        // 在 Firestore 中建立用戶資料
        await createUserDocument(user, displayName: displayName);
      }

      return user;
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 登出
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 發送密碼重設郵件
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 處理 Firebase Auth 錯誤
  String _handleAuthException(auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '找不到此帳號';
      case 'wrong-password':
        return '密碼錯誤';
      case 'email-already-in-use':
        return '此電子郵件已被使用';
      case 'invalid-email':
        return '電子郵件格式不正確';
      case 'weak-password':
        return '密碼強度不足（至少6個字元）';
      case 'user-disabled':
        return '此帳號已被停用';
      default:
        return '認證失敗：${e.message}';
    }
  }

  // ==================== 用戶資料相關 ====================

  /// 建立用戶文檔
  Future<void> createUserDocument(
    auth.User user, {
    String? displayName,
  }) async {
    final userModel = UserModel(
      id: user.uid,
      email: user.email!,
      displayName: displayName ?? user.displayName,
      photoURL: user.photoURL,
      createdAt: DateTime.now(),
      settings: UserSettings(),
    );

    await _firestore
        .collection(kUsersCollection)
        .doc(user.uid)
        .set(userModel.toFirestore());
  }

  /// 取得用戶資料
  Future<UserModel?> getUserData(String userId) async {
    final doc = await _firestore.collection(kUsersCollection).doc(userId).get();
    
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// 監聽用戶資料變化
  Stream<UserModel?> watchUserData(String userId) {
    return _firestore
        .collection(kUsersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  /// 更新用戶資料
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    await _firestore.collection(kUsersCollection).doc(userId).update(data);
  }

  /// 更新 FCM Token
  Future<void> updateFCMToken(String userId, String token) async {
    await updateUserData(userId, {'fcmToken': token});
  }

  // ==================== 行程相關 ====================

  /// 建立行程
  /// 
  /// [event] 行程物件
  /// 
  /// 回傳：建立的行程 ID
  Future<String> createEvent(CalendarEvent event) async {
    final docRef = await _firestore
        .collection(kEventsCollection)
        .add(event.toFirestore());
    return docRef.id;
  }

  /// 更新行程
  Future<void> updateEvent(String eventId, CalendarEvent event) async {
    await _firestore
        .collection(kEventsCollection)
        .doc(eventId)
        .update(event.toFirestore());
  }

  /// 刪除行程
  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection(kEventsCollection).doc(eventId).delete();
  }

  /// 取得單一行程
  Future<CalendarEvent?> getEvent(String eventId) async {
    final doc = await _firestore.collection(kEventsCollection).doc(eventId).get();
    
    if (!doc.exists) return null;
    return CalendarEvent.fromFirestore(doc);
  }

  /// 取得用戶的所有行程
  Stream<List<CalendarEvent>> watchUserEvents(String userId) {
    return _firestore
        .collection(kEventsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEvent.fromFirestore(doc))
            .toList());
  }

  /// 取得指定日期範圍的行程
  Stream<List<CalendarEvent>> watchEventsInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return _firestore
        .collection(kEventsCollection)
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEvent.fromFirestore(doc))
            .toList());
  }

  /// 取得指定日期的行程
  Future<List<CalendarEvent>> getEventsForDate(String userId, DateTime date) async {
    // 設定當天的開始和結束時間
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection(kEventsCollection)
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('startTime')
        .get();

    return snapshot.docs
        .map((doc) => CalendarEvent.fromFirestore(doc))
        .toList();
  }

  // ==================== 語音處理相關 ====================

  /// 上傳語音檔案到 Storage（移動平台）
  /// 
  /// [file] 語音檔案（dynamic 類型以支援跨平台編譯）
  /// [userId] 用戶 ID
  /// 
  /// 回傳：檔案的下載 URL
  Future<String> uploadVoiceFile(dynamic file, String userId) async {
    // 此方法只應在非 Web 平台調用
    if (kIsWeb) {
      throw Exception('Web 平台請使用 uploadVoiceFileFromBytes 方法');
    }
    
    try {
      // 產生唯一檔案名稱（使用時間戳記）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp.m4a';
      final path = '$kVoiceStoragePath/$userId/$fileName';

      // 上傳檔案
      final ref = _storage.ref().child(path);
      // 使用 dynamic 類型，在運行時檢查
      final uploadTask = await ref.putFile(file);

      // 取得下載 URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('上傳語音檔案失敗：$e');
    }
  }

  /// 上傳語音檔案到 Storage（Web 平台）
  /// 
  /// [data] 語音檔案數據（Uint8List）
  /// [userId] 用戶 ID
  /// 
  /// 回傳：檔案的下載 URL
  Future<String> uploadVoiceFileFromBytes(Uint8List data, String userId) async {
    return uploadVoiceFileFromBytesWithFormat(data, userId, 'audio/wav', 'wav');
  }

  /// 上傳語音檔案到 Storage（通用方法，支援自定義格式）
  /// 
  /// [data] 語音檔案數據（Uint8List）
  /// [userId] 用戶 ID
  /// [contentType] 檔案的 MIME 類型（例如：'audio/wav', 'audio/aac'）
  /// [extension] 檔案擴展名（例如：'wav', 'm4a'）
  /// 
  /// 回傳：檔案的下載 URL
  Future<String> uploadVoiceFileFromBytesWithFormat(
    Uint8List data,
    String userId,
    String contentType,
    String extension,
  ) async {
    try {
      // 產生唯一檔案名稱（使用時間戳記）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp.$extension';
      final path = '$kVoiceStoragePath/$userId/$fileName';

      if (kDebugMode) {
        print('📤 上傳到 Firebase Storage: $path (${data.length} bytes)');
      }

      // 上傳檔案
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(
        data,
        SettableMetadata(contentType: contentType),
      );

      // 取得下載 URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      if (kDebugMode) {
        print('✅ Firebase Storage 上傳成功: $downloadUrl');
      }
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Storage 上傳失敗: $e');
      }
      throw Exception('上傳語音檔案失敗：$e');
    }
  }

  /// 建立語音處理記錄
  /// 
  /// [userId] 用戶 ID
  /// [audioUrl] 語音檔案 URL
  /// 
  /// 回傳：處理記錄 ID
  Future<String> createVoiceProcessingRecord(
    String userId,
    String audioUrl,
  ) async {
    final record = VoiceProcessingRecord(
      id: '', // 會由 Firestore 自動產生
      userId: userId,
      audioUrl: audioUrl,
      status: VoiceProcessingStatus.processing,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection(kVoiceProcessingCollection)
        .add(record.toFirestore());

    return docRef.id;
  }

  /// 監聽語音處理記錄
  Stream<VoiceProcessingRecord?> watchVoiceProcessingRecord(String recordId) {
    return _firestore
        .collection(kVoiceProcessingCollection)
        .doc(recordId)
        .snapshots()
        .map((doc) => doc.exists ? VoiceProcessingRecord.fromFirestore(doc) : null);
  }

  /// 取得用戶的語音處理記錄列表
  Stream<List<VoiceProcessingRecord>> watchUserVoiceRecords(String userId) {
    return _firestore
        .collection(kVoiceProcessingCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20) // 只顯示最近 20 筆
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VoiceProcessingRecord.fromFirestore(doc))
            .toList());
  }

  /// 刪除語音處理記錄
  Future<void> deleteVoiceProcessingRecord(String recordId) async {
    await _firestore
        .collection(kVoiceProcessingCollection)
        .doc(recordId)
        .delete();
  }

  // ==================== 工具方法 ====================

  /// 批次寫入（用於效能優化）
  WriteBatch get batch => _firestore.batch();

  /// 執行交易
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler,
  ) {
    return _firestore.runTransaction(transactionHandler);
  }
}

