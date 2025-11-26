import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// 推播通知服務類別
/// 處理 Firebase Cloud Messaging 相關功能
class NotificationService {
  // ==================== 單例模式 ====================
  
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ==================== 實例變數 ====================
  
  /// Firebase Messaging 實例
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  /// Firebase 服務
  final FirebaseService _firebaseService = FirebaseService();
  
  /// 是否已初始化
  bool _isInitialized = false;

  // ==================== 初始化 ====================

  /// 初始化推播通知服務
  /// 
  /// 回傳：FCM Token
  Future<String?> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️ 推播服務已初始化');
      }
      return null;
    }

    try {
      // 1. 請求通知權限
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('✅ 通知權限已授予');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ 通知權限被拒絕');
        }
        return null;
      }

      // 2. 取得 FCM Token
      final token = await _messaging.getToken();
      
      if (token != null) {
        if (kDebugMode) {
          print('✅ FCM Token: $token');
        }

        // 3. 儲存 Token 到 Firestore
        final userId = _firebaseService.currentUserId;
        if (userId != null) {
          await _firebaseService.updateFCMToken(userId, token);
        }
      }

      // 4. 監聽 Token 更新
      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('🔄 FCM Token 已更新: $newToken');
        }
        
        final userId = _firebaseService.currentUserId;
        if (userId != null) {
          _firebaseService.updateFCMToken(userId, newToken);
        }
      });

      // 5. 設定前景訊息處理
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 6. 設定背景訊息處理
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      _isInitialized = true;
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 初始化推播服務失敗：$e');
      }
      return null;
    }
  }

  // ==================== 訊息處理 ====================

  /// 處理前景訊息（APP 在前台時收到的通知）
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('📨 收到前景訊息：${message.notification?.title}');
      print('   內容：${message.notification?.body}');
      print('   資料：${message.data}');
    }

    // TODO: 顯示本地通知或更新 UI
    // 可以使用 flutter_local_notifications 套件
  }

  /// 處理背景訊息（點擊通知打開 APP 時）
  void _handleBackgroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('📨 處理背景訊息：${message.notification?.title}');
      print('   資料：${message.data}');
    }

    // TODO: 根據訊息內容導航到相應頁面
    // 例如：導航到行程詳情頁
  }

  /// 處理終止狀態訊息（APP 完全關閉時點擊通知）
  Future<void> handleTerminatedMessage() async {
    final message = await _messaging.getInitialMessage();
    
    if (message != null) {
      if (kDebugMode) {
        print('📨 處理終止狀態訊息：${message.notification?.title}');
      }
      
      // TODO: 導航到相應頁面
    }
  }

  // ==================== 訂閱主題 ====================

  /// 訂閱特定主題（用於群發通知）
  /// 
  /// [topic] 主題名稱
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      
      if (kDebugMode) {
        print('✅ 已訂閱主題：$topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 訂閱主題失敗：$e');
      }
    }
  }

  /// 取消訂閱主題
  /// 
  /// [topic] 主題名稱
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      
      if (kDebugMode) {
        print('✅ 已取消訂閱主題：$topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 取消訂閱主題失敗：$e');
      }
    }
  }

  // ==================== 工具方法 ====================

  /// 取得當前 FCM Token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// 刪除 FCM Token
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    
    if (kDebugMode) {
      print('✅ 已刪除 FCM Token');
    }
  }
}

/// 背景訊息處理器（需要是頂層函數）
/// 
/// 當 APP 在背景或終止狀態時收到訊息會呼叫此函數
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('📨 背景訊息處理器：${message.notification?.title}');
  }
  
  // 這裡可以執行背景任務，但不能更新 UI
}

