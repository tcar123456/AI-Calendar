import 'package:cloud_firestore/cloud_firestore.dart';

/// 語音處理狀態枚舉
enum VoiceProcessingStatus {
  /// 正在上傳語音檔案
  uploading,
  
  /// 正在處理（AI 辨識中）
  processing,
  
  /// 處理完成
  completed,
  
  /// 處理失敗
  failed,
}

/// 語音處理結果模型
/// 儲存 AI 解析後的行程資訊
class VoiceProcessingResult {
  /// 行程標題
  final String title;
  
  /// 開始時間（ISO 8601 格式）
  final String startTime;
  
  /// 結束時間（ISO 8601 格式）
  final String endTime;
  
  /// 地點
  final String? location;
  
  /// 描述/備註
  final String? description;
  
  /// 是否為全天行程
  final bool isAllDay;
  
  /// 參與者列表
  final List<String> participants;

  VoiceProcessingResult({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    this.isAllDay = false,
    this.participants = const [],
  });

  /// 從 JSON 建立物件
  factory VoiceProcessingResult.fromJson(Map<String, dynamic> json) {
    return VoiceProcessingResult(
      title: json['title'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      location: json['location'] as String?,
      description: json['description'] as String?,
      isAllDay: json['isAllDay'] as bool? ?? false,
      participants: List<String>.from(json['participants'] ?? []),
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'description': description,
      'isAllDay': isAllDay,
      'participants': participants,
    };
  }
}

/// 語音處理記錄模型
/// 記錄語音辨識的處理過程和結果
class VoiceProcessingRecord {
  /// 處理記錄唯一識別碼
  final String id;
  
  /// 用戶 ID
  final String userId;
  
  /// 語音檔案 URL
  final String audioUrl;
  
  /// 處理狀態
  final VoiceProcessingStatus status;
  
  /// 處理結果（僅在成功時有值）
  final VoiceProcessingResult? result;
  
  /// 錯誤訊息（僅在失敗時有值）
  final String? errorMessage;
  
  /// 原始語音轉換的文字
  final String? transcription;
  
  /// 建立時間
  final DateTime createdAt;
  
  /// 最後更新時間
  final DateTime? updatedAt;

  VoiceProcessingRecord({
    required this.id,
    required this.userId,
    required this.audioUrl,
    required this.status,
    this.result,
    this.errorMessage,
    this.transcription,
    required this.createdAt,
    this.updatedAt,
  });

  /// 從 Firestore 文檔建立物件
  factory VoiceProcessingRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 解析狀態字串為枚舉
    VoiceProcessingStatus status;
    switch (data['status'] as String) {
      case 'uploading':
        status = VoiceProcessingStatus.uploading;
        break;
      case 'processing':
        status = VoiceProcessingStatus.processing;
        break;
      case 'completed':
        status = VoiceProcessingStatus.completed;
        break;
      case 'failed':
        status = VoiceProcessingStatus.failed;
        break;
      default:
        status = VoiceProcessingStatus.processing;
    }
    
    return VoiceProcessingRecord(
      id: doc.id,
      userId: data['userId'] as String,
      audioUrl: data['audioUrl'] as String,
      status: status,
      result: data['result'] != null 
        ? VoiceProcessingResult.fromJson(data['result'] as Map<String, dynamic>)
        : null,
      errorMessage: data['errorMessage'] as String?,
      transcription: data['transcription'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
        ? (data['updatedAt'] as Timestamp).toDate()
        : null,
    );
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    // 將枚舉轉換為字串
    String statusString;
    switch (status) {
      case VoiceProcessingStatus.uploading:
        statusString = 'uploading';
        break;
      case VoiceProcessingStatus.processing:
        statusString = 'processing';
        break;
      case VoiceProcessingStatus.completed:
        statusString = 'completed';
        break;
      case VoiceProcessingStatus.failed:
        statusString = 'failed';
        break;
    }
    
    return {
      'userId': userId,
      'audioUrl': audioUrl,
      'status': statusString,
      'result': result?.toJson(),
      'errorMessage': errorMessage,
      'transcription': transcription,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// 複製物件並允許修改部分欄位
  VoiceProcessingRecord copyWith({
    String? id,
    String? userId,
    String? audioUrl,
    VoiceProcessingStatus? status,
    VoiceProcessingResult? result,
    String? errorMessage,
    String? transcription,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoiceProcessingRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      audioUrl: audioUrl ?? this.audioUrl,
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      transcription: transcription ?? this.transcription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 檢查是否處理完成
  bool isCompleted() => status == VoiceProcessingStatus.completed;

  /// 檢查是否處理失敗
  bool isFailed() => status == VoiceProcessingStatus.failed;

  /// 檢查是否正在處理中
  bool isProcessing() => 
    status == VoiceProcessingStatus.uploading || 
    status == VoiceProcessingStatus.processing;
}

