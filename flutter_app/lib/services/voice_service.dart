import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_io/io.dart'; // 跨平台 IO 支援
import '../utils/constants.dart';
import 'firebase_service.dart';
import 'package:path_provider/path_provider.dart';

/// 語音服務類別
/// 處理語音錄製、上傳和 AI 解析
class VoiceService {
  // ==================== 單例模式 ====================
  
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  // ==================== 實例變數 ====================
  
  /// 錄音器實例
  final AudioRecorder _recorder = AudioRecorder();
  
  /// Firebase 服務
  final FirebaseService _firebaseService = FirebaseService();
  
  /// 是否正在錄音
  bool _isRecording = false;
  
  /// 當前錄音檔案路徑（移動平台）
  String? _currentRecordingPath;
  
  /// 當前錄音數據（Web 平台）
  Uint8List? _currentRecordingBytes;

  // ==================== Getter ====================
  
  /// 取得錄音狀態
  bool get isRecording => _isRecording;
  
  /// 取得錄音數據（Web 平台）
  Uint8List? get recordingBytes => _currentRecordingBytes;

  // ==================== 權限檢查 ====================

  /// 檢查麥克風權限
  /// 
  /// 回傳：是否已授予權限
  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// 請求麥克風權限
  /// 
  /// 回傳：是否授予權限
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// 確保擁有麥克風權限（如果沒有則請求）
  /// 
  /// 回傳：是否成功取得權限
  Future<bool> ensureMicrophonePermission() async {
    // 先檢查是否已有權限
    if (await checkMicrophonePermission()) {
      return true;
    }

    // 請求權限
    final granted = await requestMicrophonePermission();
    
    if (!granted) {
      throw Exception(kPermissionErrorMessage);
    }

    return granted;
  }

  // ==================== 錄音功能 ====================

  /// 開始錄音
  /// 
  /// 回傳：是否成功開始錄音
  Future<bool> startRecording() async {
    try {
      // 確保有權限（在 Web 上會自動處理瀏覽器的權限提示）
      if (!kIsWeb && !await ensureMicrophonePermission()) {
        return false;
      }

      // 如果已經在錄音，先停止
      if (_isRecording) {
        await stopRecording();
      }

      // 開始錄音（移動平台需要路徑，Web 平台會自動生成）
      if (kIsWeb) {
        // Web 平台：使用 WAV 格式，不需要檔案路徑
        // 優化：降低採樣率至 16kHz（Whisper 官方推薦）
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,  // 從 44100 降至 16000（Whisper 最佳）
            numChannels: 1,     // 單聲道
          ),
          path: '', // Web 平台傳空字串
        );
        _currentRecordingPath = null;
        
        if (kDebugMode) {
          print('✅ 開始錄音 (Web 平台)');
        }
      } else {
        // 移動平台：使用 AAC 格式，需要檔案路徑
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentRecordingPath = '${directory.path}/voice_$timestamp.m4a';

        // 優化：降低位元率和採樣率以加速上傳和 Whisper 處理
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,     // 從 128000 降至 64000（減少 50% 檔案大小）
            sampleRate: 16000,  // 從 44100 降至 16000（Whisper 官方推薦）
            numChannels: 1,     // 單聲道
          ),
          path: _currentRecordingPath!,
        );
        
        if (kDebugMode) {
          print('✅ 開始錄音 (移動平台)：$_currentRecordingPath');
        }
      }

      _isRecording = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 錄音失敗：$e');
      }
      _isRecording = false;
      return false;
    }
  }

  /// 停止錄音
  /// 
  /// 回傳：錄音檔案路徑（移動平台）或成功標記（Web 平台）
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        return null;
      }

      // 停止錄音
      final path = await _recorder.stop();
      _isRecording = false;

      if (kIsWeb) {
        // Web 平台：path 實際上是 base64 編碼的數據 URL 或 null
        // 我們需要將錄音數據保存起來，供上傳使用
        // 注意：record 套件在 Web 上會直接返回數據
        // 我們稍後會在上傳時從 recorder 獲取數據
        if (kDebugMode) {
          print('✅ 停止錄音 (Web 平台)');
        }
        return 'web_recording'; // 返回標記表示錄音成功
      } else {
        // 移動平台：返回檔案路徑
        if (kDebugMode) {
          print('✅ 停止錄音：$path');
        }
        return path;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 停止錄音失敗：$e');
      }
      _isRecording = false;
      _currentRecordingBytes = null;
      return null;
    }
  }
  
  /// 停止錄音並取得數據（Web 平台專用）
  /// 
  /// 回傳：錄音數據（Uint8List）
  Future<Uint8List?> stopRecordingAndGetBytes() async {
    try {
      if (!_isRecording) {
        return null;
      }

      // 停止錄音並取得數據
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null && kIsWeb) {
        // 在 Web 平台上，path 是一個 Blob URL
        // 我們需要使用 HTTP 請求來讀取 Blob 數據
        try {
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            _currentRecordingBytes = response.bodyBytes;
            
            if (kDebugMode) {
              print('✅ 停止錄音並取得數據 (Web)：${_currentRecordingBytes!.length / 1024} KB');
            }
            
            return _currentRecordingBytes;
          } else {
            throw Exception('無法讀取錄音數據：HTTP ${response.statusCode}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ 讀取 Web 錄音數據失敗：$e');
          }
          return null;
        }
      }

      return _currentRecordingBytes;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 停止錄音失敗：$e');
      }
      _isRecording = false;
      _currentRecordingBytes = null;
      return null;
    }
  }

  /// 取消錄音（停止並刪除檔案）
  Future<void> cancelRecording() async {
    final path = await stopRecording();
    
    // 在移動平台上刪除錄音檔案（Web 平台不需要）
    if (!kIsWeb && path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode) {
            print('✅ 已刪除錄音檔案：$path');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 刪除錄音檔案失敗：$e');
        }
      }
    }
  }

  /// 取得錄音振幅（用於顯示波形動畫）
  /// 
  /// 回傳：振幅值（-160.0 到 0.0 dB）
  Future<double> getAmplitude() async {
    if (!_isRecording) return 0.0;
    
    try {
      final amplitude = await _recorder.getAmplitude();
      return amplitude.current;
    } catch (e) {
      return 0.0;
    }
  }

  // ==================== 語音上傳與處理 ====================

  /// 上傳語音並觸發 AI 處理
  ///
  /// [filePath] 語音檔案路徑或數據（Web 平台可能為 null）
  /// [userId] 用戶 ID
  /// [audioBytes] Web 平台的音檔數據（可選）
  /// [calendarId] 目標行事曆 ID（語音建立的行程會放入此行事曆）
  /// [labels] 行事曆的標籤列表（用於 AI 自動選擇標籤）
  ///
  /// 回傳：語音處理記錄 ID
  Future<String> uploadAndProcessVoice(
    String? filePath,
    String userId, {
    Uint8List? audioBytes,
    String? calendarId,
    List<Map<String, String>>? labels,
  }) async {
    try {
      String audioUrl;

      if (kIsWeb) {
        // Web 平台：使用傳入的 audioBytes
        if (audioBytes == null) {
          throw Exception('Web 平台需要提供音檔數據');
        }

        // 檢查檔案大小
        if (audioBytes.length > kMaxVoiceFileSize) {
          throw Exception('語音檔案過大（最大 ${kMaxVoiceFileSize ~/ 1024 ~/ 1024} MB）');
        }

        if (kDebugMode) {
          print('📤 開始上傳語音檔案 (Web)：${audioBytes.length / 1024} KB');
        }

        // 上傳到 Firebase Storage
        audioUrl = await _firebaseService.uploadVoiceFileFromBytes(audioBytes, userId);
      } else {
        // 移動平台：讀取檔案為字節數據再上傳（避免 universal_io 與 Firebase 的相容性問題）
        if (filePath == null) {
          throw Exception('移動平台需要提供檔案路徑');
        }

        // 1. 檢查檔案是否存在
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('語音檔案不存在');
        }

        // 2. 讀取檔案為字節數據
        final fileBytes = await file.readAsBytes();
        
        // 3. 檢查檔案大小
        if (fileBytes.length > kMaxVoiceFileSize) {
          throw Exception('語音檔案過大（最大 ${kMaxVoiceFileSize ~/ 1024 ~/ 1024} MB）');
        }

        if (kDebugMode) {
          print('📤 開始上傳語音檔案 (移動平台)：${fileBytes.length / 1024} KB');
        }

        // 4. 使用字節數據上傳（統一使用 uploadVoiceFileFromBytes）
        audioUrl = await _firebaseService.uploadVoiceFileFromBytesWithFormat(
          fileBytes, 
          userId,
          'audio/aac', // Android 使用 AAC 格式
          'm4a',
        );

        // 5. 刪除本地暫存檔案
        try {
          await file.delete();
          if (kDebugMode) {
            print('✅ 已刪除本地暫存檔案');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ 刪除暫存檔案失敗：$e');
          }
        }
      }

      if (kDebugMode) {
        print('✅ 語音檔案已上傳：$audioUrl');
        if (calendarId != null) {
          print('📅 目標行事曆：$calendarId');
        }
        if (labels != null && labels.isNotEmpty) {
          print('🏷️ 標籤數量：${labels.length}');
        }
      }

      // 4. 建立語音處理記錄（會觸發 Cloud Function）
      final recordId = await _firebaseService.createVoiceProcessingRecord(
        userId,
        audioUrl,
        calendarId: calendarId,
        labels: labels,
      );

      if (kDebugMode) {
        print('✅ 已建立語音處理記錄：$recordId');
      }

      return recordId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 上傳語音失敗：$e');
      }
      rethrow;
    }
  }

  /// 直接呼叫 Zeabur API 進行語音解析（測試用）
  /// 
  /// [audioUrl] 語音檔案 URL
  /// [userId] 用戶 ID
  /// 
  /// 回傳：解析結果 JSON
  Future<Map<String, dynamic>> parseVoiceDirectly(
    String audioUrl,
    String userId,
  ) async {
    try {
      final url = Uri.parse('$kZeaburApiBaseUrl$kVoiceParseEndpoint');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'audioUrl': audioUrl,
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(utf8.decode(response.bodyBytes));
        
        if (kDebugMode) {
          print('✅ 語音解析成功：$result');
        }
        
        return result as Map<String, dynamic>;
      } else {
        throw Exception('API 請求失敗：${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 語音解析失敗：$e');
      }
      throw Exception('$kVoiceProcessingErrorMessage：$e');
    }
  }

  // ==================== 工具方法 ====================

  /// 釋放資源
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _recorder.dispose();
  }

  /// 檢查是否支援錄音功能
  Future<bool> isEncoderSupported(AudioEncoder encoder) async {
    return await _recorder.isEncoderSupported(encoder);
  }
}

