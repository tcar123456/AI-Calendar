import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/voice_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_colors.dart';
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

    // 初始化語音目標行事曆為當前選擇的行事曆
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedCalendar = ref.read(selectedCalendarProvider);
      if (selectedCalendar != null) {
        ref.read(voiceTargetCalendarIdProvider.notifier).state = selectedCalendar.id;
      }
    });
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

    // 計算高度：螢幕高度減去狀態列和 AppBar 高度
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight;
    final bottomSheetHeight = screenHeight - statusBarHeight - appBarHeight;

    // 監聯狀態變化並顯示訊息
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: colors.primary,
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
            backgroundColor: colors.error,
          ),
        );
        ref.read(voiceControllerProvider.notifier).clearMessages();
      }
    });

    return Container(
      height: bottomSheetHeight,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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

                // 行事曆選擇
                _buildCalendarSelector(),

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

  /// 建立行事曆選擇器
  Widget _buildCalendarSelector() {
    final colors = context.colors;
    final calendars = ref.watch(calendarsProvider);
    final selectedCalendarId = ref.watch(voiceTargetCalendarIdProvider);

    return calendars.when(
      data: (calendarList) {
        if (calendarList.isEmpty) {
          return const SizedBox.shrink();
        }

        // 確保選中的行事曆存在於列表中
        final validSelectedId = calendarList.any((c) => c.id == selectedCalendarId)
            ? selectedCalendarId
            : calendarList.first.id;

        // 如果 selectedCalendarId 無效，更新為第一個行事曆
        if (selectedCalendarId != validSelectedId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(voiceTargetCalendarIdProvider.notifier).state = validSelectedId;
          });
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '選擇行事曆',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: validSelectedId,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: colors.icon),
                      dropdownColor: colors.surface,
                      items: calendarList.map((calendar) {
                        return DropdownMenuItem<String>(
                          value: calendar.id,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: calendar.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  calendar.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          ref.read(voiceTargetCalendarIdProvider.notifier).state = newValue;
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
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
                            colors.surfaceContainer,
                            colors.surfaceContainerHigh,
                          ]
                        : [
                            colors.surface,
                            colors.surfaceContainer,
                          ],
                  ),
                  border: Border.all(
                    color: colors.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    // 底部深色陰影（立體感）
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, 6),
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
