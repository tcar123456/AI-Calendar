import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/voice_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';

/// 語音輸入畫面
class VoiceInputScreen extends ConsumerStatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  ConsumerState<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends ConsumerState<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    // 初始化脈動動畫
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 監聽語音狀態
    final voiceState = ref.watch(voiceControllerProvider);

    // 監聽狀態變化並顯示訊息
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: colors.primary,
          ),
        );
        ref.read(voiceControllerProvider.notifier).clearMessages();

        // 成功後返回上一頁
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }

      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: colors.error,
          ),
        );
        ref.read(voiceControllerProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('語音建立行程'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleBack(context, voiceState),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 狀態提示文字
                    _buildStatusText(voiceState),
                    
                    const SizedBox(height: 48),
                    
                    // 錄音按鈕和波形動畫
                    _buildRecordButton(voiceState),
                    
                    const SizedBox(height: 48),
                    
                    // 錄音時長
                    if (voiceState.isRecording)
                      _buildRecordingDuration(voiceState),
                    
                    // 處理進度
                    if (voiceState.isProcessing)
                      _buildProcessingIndicator(),
                  ],
                ),
              ),
            ),
            
            // 使用說明
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  /// 建立狀態提示文字
  Widget _buildStatusText(VoiceState voiceState) {
    final colors = context.colors;
    String text;
    Color color;

    if (voiceState.isProcessing) {
      // 使用階段訊息
      text = voiceState.stageMessage;
      color = colors.textPrimary;
    } else if (voiceState.isRecording) {
      text = '正在錄音...';
      color = colors.textPrimary;
    } else {
      text = '點擊麥克風開始錄音';
      color = colors.textSecondary;
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// 建立錄音按鈕
  Widget _buildRecordButton(VoiceState voiceState) {
    final colors = context.colors;
    final isRecording = voiceState.isRecording;
    final isProcessing = voiceState.isProcessing;

    // 如果正在處理，禁用按鈕
    if (isProcessing) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic,
          size: 60,
          color: colors.textDisabled,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _handleRecordButtonTap(voiceState),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // 脈動圓環（僅錄音時顯示）
              if (isRecording) ...[
                Container(
                  width: 120 + (40 * _pulseController.value),
                  height: 120 + (40 * _pulseController.value),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(
                      0.3 * (1 - _pulseController.value),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ],

              // 主按鈕（白底黑框風格）
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  size: 60,
                  color: colors.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 建立錄音時長顯示
  Widget _buildRecordingDuration(VoiceState voiceState) {
    final colors = context.colors;
    final duration = voiceState.recordingDuration;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;

    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: colors.textPrimary,
      ),
    );
  }

  /// 建立處理進度指示器
  Widget _buildProcessingIndicator() {
    final colors = context.colors;
    final voiceState = ref.watch(voiceControllerProvider);
    final progress = voiceState.progress;
    final percentage = (progress * 100).toInt();

    return Column(
      children: [
        // 圓形進度指示器
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 6,
                backgroundColor: colors.surfaceContainer,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            if (progress > 0)
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '這可能需要幾秒鐘...',
          style: TextStyle(
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            ref.read(voiceControllerProvider.notifier).cancelProcessing();
          },
          child: Text(
            '取消',
            style: TextStyle(
              fontSize: 16,
              color: colors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 建立使用說明
  Widget _buildInstructions() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(kPaddingLarge),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '使用提示：',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            Icons.mic,
            '清楚說出行程時間、地點和事項',
          ),
          _buildInstructionItem(
            Icons.calendar_today,
            '例如：「明天下午兩點在公司開會」',
          ),
          _buildInstructionItem(
            Icons.info_outline,
            '可以加上備註：「記得帶筆電」',
          ),
        ],
      ),
    );
  }

  /// 建立說明項目
  Widget _buildInstructionItem(IconData icon, String text) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: colors.icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 處理錄音按鈕點擊
  Future<void> _handleRecordButtonTap(VoiceState voiceState) async {
    final voiceController = ref.read(voiceControllerProvider.notifier);
    
    if (voiceState.isRecording) {
      // 停止錄音並處理
      await voiceController.stopAndProcessRecording();
    } else {
      // 開始錄音
      await voiceController.startRecording();
    }
  }

  /// 處理返回
  void _handleBack(BuildContext context, VoiceState voiceState) {
    if (voiceState.isRecording || voiceState.isProcessing) {
      // 如果正在錄音或處理，顯示確認對話框
      showDialog(
        context: context,
        builder: (dialogContext) {
          final colors = dialogContext.colors;
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text(
              '確定要離開嗎？',
              style: TextStyle(color: colors.textPrimary),
            ),
            content: Text(
              voiceState.isRecording
                  ? '錄音將被取消'
                  : 'AI 正在處理中，離開將取消此次操作',
              style: TextStyle(color: colors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('繼續', style: TextStyle(color: colors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  if (voiceState.isRecording) {
                    ref.read(voiceControllerProvider.notifier).cancelRecording();
                  }
                  Navigator.of(dialogContext).pop(); // 關閉對話框
                  Navigator.of(context).pop(); // 返回上一頁
                },
                child: Text('離開', style: TextStyle(color: colors.error)),
              ),
            ],
          );
        },
      );
    } else {
      Navigator.of(context).pop();
    }
  }
}

