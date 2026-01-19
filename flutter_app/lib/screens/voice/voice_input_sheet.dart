import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/voice_provider.dart';
import '../../utils/constants.dart';

/// 語音輸入底部面板
///
/// 以底部面板的形式顯示語音輸入功能
class VoiceInputSheet extends ConsumerStatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet>
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
    // 監聽語音狀態
    final voiceState = ref.watch(voiceControllerProvider);

    // 計算高度：螢幕高度減去狀態列和 AppBar 高度
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight;
    final bottomSheetHeight = screenHeight - statusBarHeight - appBarHeight;

    // 監聽狀態變化並顯示訊息
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.black,
          ),
        );
        ref.read(voiceControllerProvider.notifier).clearMessages();

        // 成功後關閉面板
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
            backgroundColor: const Color(0xFF333333),
          ),
        );
        ref.read(voiceControllerProvider.notifier).clearMessages();
      }
    });

    return Container(
      height: bottomSheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: PopScope(
          canPop: !voiceState.isRecording && !voiceState.isProcessing,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleBack(context, voiceState);
          },
          child: Scaffold(
            primary: false,
            appBar: AppBar(
              title: const Text('語音建立行程'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _handleBack(context, voiceState),
              ),
            ),
            body: Column(
              children: [
                // 分隔線
                const Divider(height: 1),

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
                        if (voiceState.isProcessing) _buildProcessingIndicator(),
                      ],
                    ),
                  ),
                ),

                // 使用說明
                _buildInstructions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 建立狀態提示文字
  Widget _buildStatusText(VoiceState voiceState) {
    String text;
    Color color;

    if (voiceState.isProcessing) {
      // 使用階段訊息
      text = voiceState.stageMessage;
      color = Colors.black;
    } else if (voiceState.isRecording) {
      text = '正在錄音...';
      color = Colors.black;
    } else {
      text = '點擊麥克風開始錄音';
      color = Colors.grey[700]!;
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
    final isRecording = voiceState.isRecording;
    final isProcessing = voiceState.isProcessing;

    // 如果正在處理，禁用按鈕
    if (isProcessing) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.mic,
          size: 60,
          color: Colors.grey,
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
                    color: Colors.black.withOpacity(
                      0.2 * (1 - _pulseController.value),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ],

              // 主按鈕（浮凸立體效果）
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isRecording
                        ? [
                            const Color(0xFFF5F5F5),
                            const Color(0xFFE0E0E0),
                          ]
                        : [
                            const Color(0xFFFFFFFF),
                            const Color(0xFFF0F0F0),
                          ],
                  ),
                  border: Border.all(
                    color: isRecording
                        ? const Color(0xFF333333)
                        : Colors.black,
                    width: 3,
                  ),
                  boxShadow: [
                    // 底部深色陰影（立體感）
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    // 頂部高光（浮凸效果）
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      blurRadius: 6,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  size: 60,
                  color: isRecording
                      ? const Color(0xFF333333)
                      : Colors.black,
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
    final duration = voiceState.recordingDuration;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;

    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  /// 建立處理進度指示器
  Widget _buildProcessingIndicator() {
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
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
            if (progress > 0)
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '這可能需要幾秒鐘...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            ref.read(voiceControllerProvider.notifier).cancelProcessing();
          },
          child: const Text(
            '取消',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 建立使用說明
  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(kPaddingLarge),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '使用提示：',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.black,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
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
  Future<void> _handleBack(BuildContext context, VoiceState voiceState) async {
    if (voiceState.isRecording || voiceState.isProcessing) {
      // 如果正在錄音或處理，顯示確認對話框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('確定要離開嗎？'),
          content: Text(
            voiceState.isRecording
                ? '錄音將被取消'
                : 'AI 正在處理中，離開將取消此次操作',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('繼續'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('離開', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        if (voiceState.isRecording) {
          ref.read(voiceControllerProvider.notifier).cancelRecording();
        }
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }
}
