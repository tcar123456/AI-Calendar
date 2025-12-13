# 語音處理優化指南

## 📊 當前流程時間分析

```
用戶錄音結束
   ↓ (~2-5秒)
上傳到 Firebase Storage (116KB)
   ↓ (~1-2秒)
建立 Firestore 記錄
   ↓ (~1-3秒 - Cloud Function 冷啟動)
Cloud Function 觸發
   ↓ (~15-30秒 - 主要瓶頸)
Zeabur API 處理
  ├─ Whisper 語音轉文字 (~10-20秒)
  └─ GPT 解析行程資訊 (~5-10秒)
   ↓ (~1秒)
更新 Firestore & 建立行程
   ↓ (即時)
Flutter 監聽到更新
```

**當前總時間：約 20-45 秒**

---

## 🚀 優化建議（按優先級排序）

### 優先級 1：架構優化 ⭐⭐⭐⭐⭐

#### 方案 A：直接調用 Zeabur API（推薦）
**效果：減少 2-5 秒（省去 Cloud Function 冷啟動和 Firestore 往返）**

**當前架構（異步）：**
```
Flutter → Storage → Firestore → Cloud Function → Zeabur API
         (等待)      (監聽)
```

**優化後（直接調用）：**
```
Flutter → Storage → Zeabur API（直接）→ Firestore
         (等待)                        (儲存結果)
```

**實施方式：**

修改 `flutter_app/lib/services/voice_service.dart`：

```dart
/// 直接上傳並處理語音（優化版本）
Future<String> uploadAndProcessVoiceDirectly(
  String? filePath,
  String userId, {
  Uint8List? audioBytes,
}) async {
  try {
    // 1. 上傳到 Firebase Storage（保持不變）
    String audioUrl;
    
    if (kIsWeb) {
      if (audioBytes == null) {
        throw Exception('Web 平台需要提供音檔數據');
      }
      audioUrl = await _firebaseService.uploadVoiceFileFromBytes(audioBytes, userId);
    } else {
      if (filePath == null) {
        throw Exception('移動平台需要提供檔案路徑');
      }
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      audioUrl = await _firebaseService.uploadVoiceFileFromBytesWithFormat(
        fileBytes, 
        userId,
        'audio/aac',
        'm4a',
      );
      
      // 刪除本地暫存檔案
      await file.delete();
    }
    
    if (kDebugMode) {
      print('✅ 語音檔案已上傳：$audioUrl');
    }
    
    // 2. 直接調用 Zeabur API（新增）
    final response = await http.post(
      Uri.parse('$kZeaburApiBaseUrl$kVoiceParseEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'audioUrl': audioUrl,
        'userId': userId,
      }),
    ).timeout(Duration(seconds: 60));
    
    if (response.statusCode != 200) {
      throw Exception('API 請求失敗：${response.statusCode}');
    }
    
    final result = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    
    if (kDebugMode) {
      print('✅ 語音解析成功：${result['title']}');
    }
    
    // 3. 立即建立行程（不用等 Cloud Function）
    final eventId = await _firebaseService.createEventFromVoiceResult(
      userId,
      result,
      audioUrl,
    );
    
    if (kDebugMode) {
      print('✅ 行程建立成功：$eventId');
    }
    
    return eventId;
  } catch (e) {
    if (kDebugMode) {
      print('❌ 語音處理失敗：$e');
    }
    rethrow;
  }
}
```

**優點：**
- 省去 Cloud Function 冷啟動時間（1-3秒）
- 減少一次 Firestore 往返（1-2秒）
- 實時進度回饋
- 更簡單的錯誤處理

**缺點：**
- Flutter 需要等待整個過程完成
- 需要在 Firebase Service 中添加 `createEventFromVoiceResult` 方法

---

### 優先級 2：音檔優化 ⭐⭐⭐⭐

#### 降低音檔大小和採樣率
**效果：減少 2-3 秒上傳時間，減少 3-5 秒 Whisper 處理時間**

**當前設定（flutter_app/lib/services/voice_service.dart）：**
```dart
// 移動平台
await _recorder.start(
  const RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 128000,    // 128 kbps（高音質）
    sampleRate: 44100,  // 44.1 kHz（CD 音質）
  ),
  path: _currentRecordingPath!,
);
```

**優化建議：**
```dart
// 語音辨識不需要高音質
await _recorder.start(
  const RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,     // 64 kbps（減少一半）
    sampleRate: 16000,  // 16 kHz（Whisper 官方推薦）
    numChannels: 1,     // 單聲道（確保設定）
  ),
  path: _currentRecordingPath!,
);
```

**Web 平台同樣優化：**
```dart
await _recorder.start(
  const RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,  // 降低採樣率
    numChannels: 1,     // 單聲道
  ),
  path: '',
);
```

**效果：**
- 檔案大小減少 50-60%（116KB → 50-60KB）
- 上傳速度提升 50%
- Whisper 處理速度提升 20-30%
- **總節省時間：5-8 秒**

**注意事項：**
- 16kHz 是語音辨識的最佳平衡點
- 音質對人耳可能稍降低，但對 AI 辨識無影響
- Whisper 模型針對 16kHz 優化

---

### 優先級 3：UI/UX 優化 ⭐⭐⭐⭐

#### 添加處理進度提示
**效果：改善用戶體驗，減少等待焦慮（不減少實際時間但大幅提升感知速度）**

**實施步驟：**

**1. 修改 `flutter_app/lib/providers/voice_provider.dart`：**

```dart
/// 處理階段枚舉
enum ProcessingStage {
  uploading,      // 上傳中 (0-20%)
  transcribing,   // 轉錄中 (20-70%)
  analyzing,      // 分析中 (70-90%)
  creating,       // 建立行程中 (90-100%)
  completed,      // 完成
}

/// 語音控制器 State
class VoiceState {
  final bool isRecording;
  final bool isProcessing;
  final String? errorMessage;
  final String? successMessage;
  final String? currentRecordId;
  final int recordingDuration;
  
  // 新增處理階段相關欄位
  final ProcessingStage? currentStage;
  final double progress; // 0.0 - 1.0
  
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
  
  /// 取得預估剩餘時間（秒）
  int get estimatedRemainingSeconds {
    if (currentStage == null) return 0;
    
    // 根據階段預估剩餘時間
    switch (currentStage!) {
      case ProcessingStage.uploading:
        return 20; // 還需要約 20 秒
      case ProcessingStage.transcribing:
        return 15; // 還需要約 15 秒
      case ProcessingStage.analyzing:
        return 5;  // 還需要約 5 秒
      case ProcessingStage.creating:
        return 2;  // 還需要約 2 秒
      case ProcessingStage.completed:
        return 0;
    }
  }
  
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
  }) {
    return VoiceState(
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      currentRecordId: currentRecordId ?? this.currentRecordId,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      currentStage: currentStage ?? this.currentStage,
      progress: progress ?? this.progress,
    );
  }
}
```

**2. 在處理過程中更新階段：**

```dart
Future<void> _processVoiceData({String? filePath, Uint8List? audioBytes}) async {
  // ... 前面代碼保持不變 ...
  
  state = state.copyWith(
    isProcessing: true,
    currentStage: ProcessingStage.uploading,
    progress: 0.1,
  );

  try {
    // 上傳語音檔案
    final recordId = await _voiceService.uploadAndProcessVoice(
      filePath,
      userId,
      audioBytes: audioBytes,
    );
    
    // 更新為轉錄階段
    state = state.copyWith(
      currentStage: ProcessingStage.transcribing,
      progress: 0.3,
      currentRecordId: recordId,
    );

    // 監聽處理結果（添加模擬進度）
    Timer.periodic(Duration(seconds: 2), (timer) {
      if (state.currentStage == ProcessingStage.transcribing && state.progress < 0.7) {
        state = state.copyWith(progress: state.progress + 0.1);
      } else if (state.currentStage == ProcessingStage.analyzing && state.progress < 0.9) {
        state = state.copyWith(progress: state.progress + 0.05);
      }
      
      if (!state.isProcessing) {
        timer.cancel();
      }
    });
    
    // ... 後續處理 ...
  } catch (e) {
    // 錯誤處理
  }
}
```

**3. 在 UI 中顯示進度（voice_input_screen.dart）：**

```dart
// 處理中狀態的 UI
if (voiceState.isProcessing) {
  return Container(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 圓形進度指示器
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: voiceState.progress,
                strokeWidth: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(kPrimaryColorValue),
                ),
              ),
            ),
            Text(
              '${(voiceState.progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 24),
        
        // 階段訊息
        Text(
          voiceState.stageMessage,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        SizedBox(height: 8),
        
        // 預估剩餘時間
        if (voiceState.estimatedRemainingSeconds > 0)
          Text(
            '預計還需 ${voiceState.estimatedRemainingSeconds} 秒',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        
        SizedBox(height: 24),
        
        // 可選：取消按鈕
        TextButton(
          onPressed: () {
            // 取消處理邏輯
            Navigator.pop(context);
          },
          child: Text('返回日曆'),
        ),
      ],
    ),
  );
}
```

**效果：**
- 用戶清楚了解當前進度
- 減少焦慮感
- 提供預估時間
- 允許中途返回

---

### 優先級 4：Zeabur API 優化 ⭐⭐⭐

#### 後端並行處理
**效果：減少 5-10 秒處理時間**

**當前流程（串行）：**
```python
# zeabur_api/app/routes/voice.py
async def parse_voice(request: VoiceParseRequest):
    # 1. 下載音檔 (2秒)
    audio_bytes = await download_audio(request.audioUrl)
    
    # 2. Whisper 轉錄 (15秒)
    transcription = await whisper_service.transcribe(audio_bytes)
    
    # 3. GPT 解析 (8秒)
    result = await gpt_service.parse(transcription)
    
    # 總計：25秒
    return result
```

**優化建議 1：預處理音檔（並行）**
```python
import asyncio

async def parse_voice_optimized(request: VoiceParseRequest):
    # 並行：下載 + 預處理
    download_task = asyncio.create_task(download_audio(request.audioUrl))
    
    # 等待下載完成
    audio_bytes = await download_task
    
    # 並行：音檔預處理 + Whisper 轉錄
    preprocess_task = asyncio.create_task(preprocess_audio(audio_bytes))
    transcribe_task = asyncio.create_task(whisper_service.transcribe(audio_bytes))
    
    # 等待轉錄完成
    transcription = await transcribe_task
    
    # GPT 解析（可以在轉錄時就開始部分解析）
    result = await gpt_service.parse(transcription)
    
    return result
```

**優化建議 2：串流處理（進階）**
```python
async def parse_voice_streaming(request: VoiceParseRequest):
    """
    串流模式：邊轉錄邊分析
    需要 Whisper API 支援串流輸出
    """
    audio_bytes = await download_audio(request.audioUrl)
    
    partial_transcription = ""
    partial_result = None
    
    # Whisper 串流轉錄
    async for chunk in whisper_service.transcribe_stream(audio_bytes):
        partial_transcription += chunk
        
        # 如果累積足夠文字，開始部分解析
        if len(partial_transcription) > 50:
            # 非阻塞式解析
            partial_result = await gpt_service.parse_partial(partial_transcription)
    
    # 最終修正和完善
    final_result = await gpt_service.finalize(partial_result, partial_transcription)
    
    return final_result
```

**實施注意事項：**
- 需要檢查 Whisper API 是否支援串流模式
- 需要處理部分結果的合併邏輯
- 可能需要調整 GPT prompt 以支援部分文字解析

---

### 優先級 5：音檔預處理 ⭐⭐

#### 添加音檔優化處理
**效果：提升 Whisper 辨識速度 10-20%，準確度提升**

**在 Zeabur API 端添加預處理：**

```python
# zeabur_api/app/services/audio_processor.py
import numpy as np
from pydub import AudioSegment
from pydub.effects import normalize
import io

class AudioProcessor:
    """音檔預處理服務"""
    
    @staticmethod
    def preprocess_for_whisper(audio_bytes: bytes) -> bytes:
        """
        優化音檔以提升 Whisper 辨識效果
        
        處理步驟：
        1. 轉換為 16kHz 單聲道
        2. 標準化音量
        3. 降噪（簡單）
        4. 裁剪頭尾靜音
        """
        # 1. 載入音檔
        audio = AudioSegment.from_file(io.BytesIO(audio_bytes))
        
        # 2. 轉換為 Whisper 最佳格式
        audio = audio.set_channels(1)  # 單聲道
        audio = audio.set_frame_rate(16000)  # 16kHz
        
        # 3. 標準化音量
        audio = normalize(audio)
        
        # 4. 裁剪頭尾靜音（超過 1 秒的靜音）
        audio = AudioProcessor._trim_silence(audio, silence_thresh=-40)
        
        # 5. 導出為 WAV（Whisper 最佳格式）
        buffer = io.BytesIO()
        audio.export(buffer, format='wav')
        
        return buffer.getvalue()
    
    @staticmethod
    def _trim_silence(audio: AudioSegment, silence_thresh: int = -40) -> AudioSegment:
        """裁剪頭尾靜音"""
        def detect_leading_silence(sound, silence_threshold=-50.0, chunk_size=10):
            trim_ms = 0
            assert chunk_size > 0
            while sound[trim_ms:trim_ms+chunk_size].dBFS < silence_threshold and trim_ms < len(sound):
                trim_ms += chunk_size
            return trim_ms
        
        start_trim = detect_leading_silence(audio, silence_thresh)
        end_trim = detect_leading_silence(audio.reverse(), silence_thresh)
        
        duration = len(audio)
        trimmed = audio[start_trim:duration-end_trim]
        
        return trimmed
```

**在 voice route 中使用：**

```python
# zeabur_api/app/routes/voice.py
from ..services.audio_processor import AudioProcessor

async def parse_voice(request: VoiceParseRequest):
    # 下載音檔
    audio_bytes = await download_audio(request.audioUrl)
    
    # 預處理音檔
    processed_audio = AudioProcessor.preprocess_for_whisper(audio_bytes)
    
    # Whisper 轉錄（使用處理後的音檔）
    transcription = await whisper_service.transcribe(processed_audio)
    
    # GPT 解析
    result = await gpt_service.parse(transcription)
    
    return result
```

**需要安裝的套件：**
```bash
# requirements.txt
pydub==0.25.1
numpy==1.24.3
```

---

## 📈 優化效果預估表

| 優化項目 | 時間節省 | 實施難度 | 優先級 | 預估工時 |
|---------|---------|---------|--------|---------|
| 直接調用 API | 2-5秒 | 中 | ⭐⭐⭐⭐⭐ | 1-2小時 |
| 降低採樣率/位元率 | 5-8秒 | 低 | ⭐⭐⭐⭐ | 5分鐘 |
| UI 進度提示 | 0秒（體驗提升） | 低 | ⭐⭐⭐⭐ | 30分鐘 |
| 後端並行處理 | 5-10秒 | 高 | ⭐⭐⭐ | 3-4小時 |
| 音檔預處理 | 2-4秒 | 中 | ⭐⭐ | 1-2小時 |

**累積優化效果：**
- **第一階段**（音質 + UI）：5-8秒 + 體驗大幅提升
- **第二階段**（直接調用）：再減少 2-5秒
- **第三階段**（後端優化）：再減少 7-14秒

**總計：從 25-40秒 → 8-15秒（減少約 60-70%）**

---

## 🎯 建議實施順序

### 第一階段（快速見效）⚡
**時間：40分鐘，立即見效**

1. **降低錄音音質設定**（5分鐘）
   - 修改 `voice_service.dart` 中的錄音配置
   - 測試音質是否可接受
   - 預期效果：減少 5-8秒

2. **添加 UI 進度提示**（30分鐘）
   - 修改 `VoiceState` 添加處理階段
   - 更新 UI 顯示進度
   - 預期效果：體驗大幅提升

3. **測試與調優**（5分鐘）
   - 完整流程測試
   - 記錄實際耗時

### 第二階段（中期優化）🚀
**時間：1-2小時，架構優化**

4. **直接調用 Zeabur API**（1-2小時）
   - 重構 `uploadAndProcessVoice` 方法
   - 添加 Firebase Service 輔助方法
   - 更新錯誤處理邏輯
   - 預期效果：減少 2-5秒

5. **完整測試**（30分鐘）
   - 各平台測試（Web、Android）
   - 錯誤場景測試
   - 性能對比測試

### 第三階段（深度優化）🔬
**時間：4-6小時，需要後端配合**

6. **後端並行處理**（2-3小時）
   - 重構 Zeabur API 路由
   - 實施非同步並行處理
   - 測試穩定性
   - 預期效果：減少 5-10秒

7. **音檔預處理**（2小時）
   - 添加音訊處理庫
   - 實施預處理邏輯
   - 測試辨識準確度
   - 預期效果：減少 2-4秒，提升準確度

8. **全面測試與優化**（1小時）
   - 端到端測試
   - 性能監控
   - 問題修復

---

## 💡 額外建議

### 1. 添加超時處理
```dart
// 在 voice_provider.dart 中添加
Future<void> _processVoiceData({String? filePath, Uint8List? audioBytes}) async {
  // ... 現有代碼 ...
  
  // 設定超時
  final timeoutDuration = Duration(seconds: 45);
  
  try {
    await Future.any([
      _actualProcessing(filePath, audioBytes),
      Future.delayed(timeoutDuration).then((_) => throw TimeoutException('處理超時')),
    ]);
  } on TimeoutException {
    state = state.copyWith(
      isProcessing: false,
      errorMessage: '處理時間過長，請稍後重試',
    );
  }
}
```

### 2. 添加背景處理模式
允許用戶在處理語音時返回日曆，處理完成後發送通知：

```dart
// 在 voice_input_screen.dart 中
if (voiceState.isProcessing) {
  // ... 顯示進度 UI ...
  
  // 添加「返回日曆」按鈕
  TextButton.icon(
    onPressed: () {
      // 顯示提示
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('繼續處理'),
          content: Text('語音處理將在背景繼續進行，完成後會通知您。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 關閉對話框
                Navigator.pop(context); // 返回日曆
              },
              child: Text('確定'),
            ),
          ],
        ),
      );
    },
    icon: Icon(Icons.arrow_back),
    label: Text('返回日曆'),
  ),
}
```

### 3. 添加處理成功的動畫反饋
```dart
// 處理完成時顯示慶祝動畫
if (voiceState.successMessage != null) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // 成功圖示（可使用 Lottie 動畫）
      Icon(
        Icons.check_circle,
        size: 80,
        color: Color(kSuccessColorValue),
      ),
      SizedBox(height: 16),
      Text(
        voiceState.successMessage!,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: () => Navigator.pop(context),
        child: Text('查看行程'),
      ),
    ],
  );
}
```

### 4. 添加效能監控
```dart
// 在 voice_service.dart 中添加計時
Future<String> uploadAndProcessVoice(...) async {
  final startTime = DateTime.now();
  
  try {
    // ... 處理邏輯 ...
    
    final duration = DateTime.now().difference(startTime);
    
    if (kDebugMode) {
      print('⏱️ 總處理時間：${duration.inSeconds} 秒');
    }
    
    // 可選：上傳到 Firebase Analytics
    // await FirebaseAnalytics.instance.logEvent(
    //   name: 'voice_processing_time',
    //   parameters: {'duration_seconds': duration.inSeconds},
    // );
    
    return recordId;
  } catch (e) {
    final duration = DateTime.now().difference(startTime);
    print('❌ 處理失敗，耗時：${duration.inSeconds} 秒');
    rethrow;
  }
}
```

---

## 🧪 測試檢查清單

優化後需要測試的項目：

### 功能測試
- [ ] 短語音（5秒內）處理正常
- [ ] 中等語音（10-30秒）處理正常
- [ ] 長語音（30-60秒）處理正常
- [ ] 音質可接受（人耳測試）
- [ ] 辨識準確度無下降

### 平台測試
- [ ] Android 平台正常運作
- [ ] iOS 平台正常運作（如有）
- [ ] Web 平台正常運作

### 錯誤場景測試
- [ ] 網路中斷時的錯誤處理
- [ ] API 超時時的錯誤處理
- [ ] 音檔上傳失敗的錯誤處理
- [ ] 辨識失敗的錯誤處理

### 性能測試
- [ ] 記錄優化前的平均處理時間
- [ ] 記錄優化後的平均處理時間
- [ ] 計算實際提升百分比
- [ ] 檢查記憶體使用情況

### UX 測試
- [ ] 進度顯示流暢
- [ ] 預估時間合理
- [ ] 錯誤訊息清晰
- [ ] 可以中途取消

---

## 📚 參考資源

### Whisper 最佳實踐
- [OpenAI Whisper 官方文檔](https://platform.openai.com/docs/guides/speech-to-text)
- 推薦音訊格式：16kHz, mono, WAV/M4A
- 最大檔案大小：25MB
- 最長時長：25分鐘

### Flutter 音訊處理
- [record 套件文檔](https://pub.dev/packages/record)
- [path_provider 套件](https://pub.dev/packages/path_provider)

### Firebase 最佳實踐
- [Cloud Functions 性能優化](https://firebase.google.com/docs/functions/tips)
- [Firestore 批次寫入](https://firebase.google.com/docs/firestore/manage-data/transactions)

---

## 📊 優化前後對比（預期）

| 指標 | 優化前 | 第一階段 | 第二階段 | 第三階段 |
|------|--------|---------|---------|---------|
| 平均處理時間 | 25-40秒 | 18-30秒 | 12-22秒 | 8-15秒 |
| 音檔大小 | 116KB | 50-60KB | 50-60KB | 40-50KB |
| 用戶滿意度 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 實施成本 | - | 低 | 中 | 高 |

---

## 🎯 結論

**建議實施策略：**

1. **立即實施**（今天完成）：
   - ✅ 降低錄音音質（5分鐘）
   - ✅ 添加 UI 進度提示（30分鐘）
   - 預期效果：體驗立即改善，時間減少 20-30%

2. **本週完成**：
   - ✅ 直接調用 Zeabur API（1-2小時）
   - 預期效果：總時間減少 50%

3. **後續優化**（時間充裕時）：
   - ⏰ 後端並行處理
   - ⏰ 音檔預處理
   - 預期效果：總時間減少 60-70%

**核心目標：** 將處理時間從 30秒 降低到 15秒以內，並提供清晰的進度反饋。

---

**文檔版本：** v1.0  
**建立日期：** 2025-12-13  
**作者：** AI Calendar Team  
**最後更新：** 2025-12-13

