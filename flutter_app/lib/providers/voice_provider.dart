import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/voice_processing_model.dart';
import '../services/voice_service.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';
import 'calendar_provider.dart';

/// 處理階段枚舉
enum ProcessingStage {
  uploading,      // 上傳中
  transcribing,   // 轉錄中
  analyzing,      // 分析中
  creating,       // 建立行程中
  completed,      // 完成
}

/// 語音服務 Provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService();
});

/// 錄音狀態 Provider
/// 
/// 監聽當前是否正在錄音
final isRecordingProvider = StreamProvider<bool>((ref) async* {
  final voiceService = ref.watch(voiceServiceProvider);
  
  // 每 100ms 檢查一次錄音狀態
  while (true) {
    await Future.delayed(const Duration(milliseconds: 100));
    yield voiceService.isRecording;
  }
});

/// 錄音振幅 Provider
/// 
/// 用於顯示錄音波形動畫
final recordingAmplitudeProvider = StreamProvider<double>((ref) async* {
  final voiceService = ref.watch(voiceServiceProvider);
  
  while (true) {
    await Future.delayed(const Duration(milliseconds: 50));
    if (voiceService.isRecording) {
      final amplitude = await voiceService.getAmplitude();
      yield amplitude;
    } else {
      yield 0.0;
    }
  }
});

/// 語音處理記錄 Provider
/// 
/// 監聽指定的語音處理記錄
final voiceProcessingRecordProvider = StreamProvider.family<VoiceProcessingRecord?, String>(
  (ref, recordId) {
    final firebaseService = ref.watch(firebaseServiceProvider);
    return firebaseService.watchVoiceProcessingRecord(recordId);
  },
);

/// 用戶的語音處理記錄列表 Provider
final userVoiceRecordsProvider = StreamProvider<List<VoiceProcessingRecord>>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return Stream.value([]);
  }

  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchUserVoiceRecords(userId);
});

/// 語音建立行程的目標行事曆 ID Provider
///
/// 用於在語音輸入面板中選擇要建立行程的行事曆
/// 預設為 null，會使用當前選擇的行事曆
final voiceTargetCalendarIdProvider = StateProvider<String?>((ref) => null);

/// 語音控制器 State
class VoiceState {
  /// 是否正在錄音
  final bool isRecording;

  /// 是否正在處理
  final bool isProcessing;

  /// 錯誤訊息
  final String? errorMessage;

  /// 成功訊息
  final String? successMessage;

  /// 當前處理的語音記錄 ID
  final String? currentRecordId;

  /// 錄音時長（秒）
  final int recordingDuration;

  /// 當前處理階段
  final ProcessingStage? currentStage;

  /// 處理進度（0.0 - 1.0）
  final double progress;

  const VoiceState({
    this.isRecording = false,
    this.isProcessing = false,
    this.errorMessage,
    this.successMessage,
    this.currentRecordId,
    this.recordingDuration = 0,
    this.currentStage,
    this.progress = 0.0,
  });

  /// 取得當前階段的訊息
  String get stageMessage {
    switch (currentStage) {
      case ProcessingStage.uploading:
        return '正在上傳語音檔案...';
      case ProcessingStage.transcribing:
        return '正在轉錄語音內容...';
      case ProcessingStage.analyzing:
        return '正在分析行程資訊...';
      case ProcessingStage.creating:
        return '正在建立行程...';
      case ProcessingStage.completed:
        return '處理完成！';
      default:
        return '處理中...';
    }
  }

  /// 複製並修改部分屬性
  VoiceState copyWith({
    bool? isRecording,
    bool? isProcessing,
    String? errorMessage,
    String? successMessage,
    String? currentRecordId,
    int? recordingDuration,
    ProcessingStage? currentStage,
    double? progress,
    bool clearMessages = false,
    bool clearStage = false,
  }) {
    return VoiceState(
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      currentRecordId: currentRecordId ?? this.currentRecordId,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      currentStage: clearStage ? null : (currentStage ?? this.currentStage),
      progress: progress ?? this.progress,
    );
  }
}

/// 語音控制器
///
/// 處理語音錄製、上傳、AI 解析等操作
class VoiceController extends StateNotifier<VoiceState> {
  final VoiceService _voiceService;
  final FirebaseService _firebaseService;
  final Ref _ref;
  Timer? _recordingTimer;
  StreamSubscription? _processingSubscription;

  /// 是否已被用戶取消（用於忽略取消後的錯誤回報）
  bool _isCancelled = false;

  VoiceController(this._voiceService, this._firebaseService, this._ref)
    : super(const VoiceState());

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _processingSubscription?.cancel();
    super.dispose();
  }

  /// 開始錄音
  Future<void> startRecording() async {
    state = state.copyWith(clearMessages: true);
    
    try {
      final success = await _voiceService.startRecording();
      
      if (success) {
        state = state.copyWith(isRecording: true, recordingDuration: 0);
        
        // 啟動計時器
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          state = state.copyWith(recordingDuration: state.recordingDuration + 1);
          
          // 達到最大錄音時長自動停止
          if (state.recordingDuration >= 120) { // 2 分鐘
            stopAndProcessRecording();
          }
        });
      } else {
        state = state.copyWith(errorMessage: '開始錄音失敗');
      }
    } catch (e) {
      state = state.copyWith(errorMessage: '錄音錯誤：$e');
    }
  }

  /// 停止錄音並處理
  Future<void> stopAndProcessRecording() async {
    _recordingTimer?.cancel();
    
    try {
      if (kIsWeb) {
        // Web 平台：取得錄音數據
        final audioBytes = await _voiceService.stopRecordingAndGetBytes();
        
        state = state.copyWith(isRecording: false);
        
        if (audioBytes == null) {
          state = state.copyWith(errorMessage: '錄音數據無效');
          return;
        }

        // 上傳並處理語音
        await _processVoiceData(audioBytes: audioBytes);
      } else {
        // 移動平台：取得檔案路徑
        final filePath = await _voiceService.stopRecording();
        
        state = state.copyWith(isRecording: false);
        
        if (filePath == null) {
          state = state.copyWith(errorMessage: '錄音檔案無效');
          return;
        }

        // 上傳並處理語音
        await _processVoiceData(filePath: filePath);
      }
    } catch (e) {
      state = state.copyWith(
        isRecording: false,
        errorMessage: '停止錄音失敗：$e',
      );
    }
  }

  /// 取消錄音
  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    
    try {
      await _voiceService.cancelRecording();
      state = const VoiceState();
    } catch (e) {
      state = state.copyWith(
        isRecording: false,
        errorMessage: '取消錄音失敗：$e',
      );
    }
  }

  /// 處理語音數據或檔案
  ///
  /// [filePath] 移動平台的檔案路徑
  /// [audioBytes] Web 平台的音檔數據
  Future<void> _processVoiceData({String? filePath, Uint8List? audioBytes}) async {
    // 重置取消標記
    _isCancelled = false;

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(errorMessage: '用戶未登入');
      return;
    }

    // 取得語音建立的目標行事曆（優先使用語音面板中選擇的行事曆，否則使用當前選擇的行事曆）
    final voiceTargetCalendarId = _ref.read(voiceTargetCalendarIdProvider);
    final selectedCalendar = _ref.read(selectedCalendarProvider);
    final calendarId = voiceTargetCalendarId ?? selectedCalendar?.id;

    // 取得當前行事曆的標籤列表（用於 AI 自動選擇標籤）
    final labels = _ref.read(calendarLabelsProvider);
    final List<Map<String, String>> labelsList = labels.map((label) => <String, String>{
      'id': label.id,
      'name': label.name,
    }).toList();

    if (kDebugMode) {
      print('📅 語音處理 - 目標行事曆: ${selectedCalendar?.name ?? "未選擇"} ($calendarId)');
      print('🏷️ 語音處理 - 標籤數量: ${labelsList.length}');
      for (final label in labelsList) {
        print('  - ${label['id']}: ${label['name']}');
      }
    }

    // 開始處理 - 上傳階段
    state = state.copyWith(
      isProcessing: true,
      currentStage: ProcessingStage.uploading,
      progress: 0.1,
    );

    try {
      // 上傳語音檔案並建立處理記錄（傳遞行事曆 ID 和標籤列表）
      final recordId = await _voiceService.uploadAndProcessVoice(
        filePath,
        userId,
        audioBytes: audioBytes,
        calendarId: calendarId,
        labels: labelsList,
      );

      // 上傳完成，進入轉錄階段
      state = state.copyWith(
        currentRecordId: recordId,
        currentStage: ProcessingStage.transcribing,
        progress: 0.3,
      );

      // 監聽處理結果
      _processingSubscription = _firebaseService
          .watchVoiceProcessingRecord(recordId)
          .listen((record) async {
        if (record == null) return;

        // 根據 record 狀態更新進度
        if (record.transcription != null && state.currentStage == ProcessingStage.transcribing) {
          // 有轉錄結果了，進入分析階段
          state = state.copyWith(
            currentStage: ProcessingStage.analyzing,
            progress: 0.7,
          );
        }

        if (record.isCompleted() && record.result != null) {
          // 處理成功，Cloud Function 已建立行程，這裡只需更新狀態
          _onVoiceProcessingCompleted(record);
        } else if (record.isFailed()) {
          // 如果已被用戶取消，忽略錯誤
          if (_isCancelled) return;

          // 處理失敗
          state = state.copyWith(
            isProcessing: false,
            errorMessage: record.errorMessage ?? '語音處理失敗',
            currentRecordId: null,
            clearStage: true,
            progress: 0.0,
          );
          _processingSubscription?.cancel();
        }
      });
    } catch (e) {
      // 如果已被用戶取消，忽略錯誤
      if (_isCancelled) return;

      state = state.copyWith(
        isProcessing: false,
        errorMessage: '上傳語音失敗：$e',
        clearStage: true,
        progress: 0.0,
      );
    }
  }

  /// 語音處理完成時的處理
  ///
  /// 注意：行程已由 Cloud Function 建立，這裡只需更新 UI 狀態
  void _onVoiceProcessingCompleted(VoiceProcessingRecord record) {
    if (record.result == null) return;

    final result = record.result!;

    // 更新狀態為完成
    state = state.copyWith(
      isProcessing: false,
      currentStage: ProcessingStage.completed,
      progress: 1.0,
      successMessage: '行程「${result.title}」建立成功！',
      currentRecordId: null,
    );

    _processingSubscription?.cancel();
  }

  /// 取消解析處理
  void cancelProcessing() {
    // 設定取消標記，忽略後續的錯誤回報
    _isCancelled = true;

    _processingSubscription?.cancel();
    _processingSubscription = null;
    // 重置所有狀態，包括階段和進度
    state = const VoiceState();
  }

  /// 清除訊息
  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }
}

/// 語音控制器 Provider
final voiceControllerProvider = StateNotifierProvider<VoiceController, VoiceState>((ref) {
  final voiceService = ref.watch(voiceServiceProvider);
  final firebaseService = ref.watch(firebaseServiceProvider);
  return VoiceController(voiceService, firebaseService, ref);
});

