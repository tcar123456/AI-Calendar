import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart'; // 日期格式本地化
import 'package:flutter_localizations/flutter_localizations.dart'; // Material 本地化支援
import 'screens/auth/login_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart'; // Firebase 設定檔

/// 應用程式主入口
void main() async {
  // 確保 Flutter 綁定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日期格式本地化（支援中文）
  await initializeDateFormatting('zh_TW', null);

  // 初始化 Firebase
  // 使用 firebase_options.dart 中的平台專屬設定
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 設定背景訊息處理器
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 執行應用程式
  runApp(
    // ProviderScope 是 Riverpod 的根節點
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// 應用程式主元件
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 監聽認證狀態
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'AI 語音行事曆',
      debugShowCheckedModeBanner: false,
      
      // 本地化設定（必須用於 DatePicker/TimePicker 等 Material 元件的中文支援）
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,  // Material 元件本地化
        GlobalWidgetsLocalizations.delegate,   // Widget 本地化
        GlobalCupertinoLocalizations.delegate, // Cupertino 元件本地化
      ],
      supportedLocales: const [
        Locale('zh', 'TW'), // 繁體中文（台灣）
        Locale('zh', 'CN'), // 簡體中文
        Locale('en', 'US'), // 英文
      ],
      locale: const Locale('zh', 'TW'), // 預設使用繁體中文
      
      // 主題設定（黑白簡約風格）
      theme: ThemeData(
        // 使用 Material 3 設計
        useMaterial3: true,

        // 黑白主色調
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Color(0xFF666666),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
          error: Color(0xFF333333),
          onError: Colors.white,
        ),

        // 字體設定（使用 Noto Sans TC 中文字體）
        textTheme: GoogleFonts.notoSansTextTheme(
          Theme.of(context).textTheme,
        ),

        // AppBar 主題（黑白風格）
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          titleTextStyle: GoogleFonts.notoSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),

        // 卡片主題
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
        ),

        // 按鈕主題（黑底白字）
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // 次要按鈕主題（白底黑邊）
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // 輸入框主題（白底細黑邊）
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF333333), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),

        // Divider 主題
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE5E5E5),
          thickness: 1,
        ),

        // Switch 主題
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black.withOpacity(0.5);
            }
            return Colors.grey.withOpacity(0.3);
          }),
        ),

        // Checkbox 主題
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
          side: const BorderSide(color: Color(0xFF666666), width: 1.5),
        ),
      ),
      
      // 根據認證狀態決定顯示的畫面
      home: authState.when(
        // 載入中
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        
        // 發生錯誤
        error: (error, stack) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('載入失敗：$error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // 重新載入
                    ref.invalidate(authStateProvider);
                  },
                  child: const Text('重試'),
                ),
              ],
            ),
          ),
        ),
        
        // 載入完成
        data: (user) {
          if (user != null) {
            // 已登入，初始化推播服務
            _initializeNotifications(ref);
            
            // 顯示行事曆主畫面
            return const CalendarScreen();
          } else {
            // 未登入，顯示登入畫面
            return const LoginScreen();
          }
        },
      ),
    );
  }

  /// 初始化推播通知服務
  void _initializeNotifications(WidgetRef ref) {
    // 延遲執行，避免在 build 過程中執行非同步操作
    Future.microtask(() async {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.handleTerminatedMessage();
    });
  }
}

