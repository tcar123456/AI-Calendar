import 'package:flutter/material.dart';

/// 語意化顏色系統
/// 使用 ThemeExtension 提供深淺色主題的統一顏色存取
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    // 背景
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    // 文字
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textOnPrimary,
    // 邊框
    required this.border,
    required this.borderSubtle,
    required this.borderFocused,
    // 互動
    required this.primary,
    required this.onPrimary,
    required this.icon,
    required this.iconSecondary,
    required this.iconTertiary,
    // 狀態
    required this.error,
    required this.success,
    required this.warning,
    // 特殊
    required this.divider,
    required this.dragHandle,
    required this.overlay,
    required this.shadow,
    required this.holiday,
    required this.currentTime,
  });

  // 背景
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;

  // 文字
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textOnPrimary;

  // 邊框
  final Color border;
  final Color borderSubtle;
  final Color borderFocused;

  // 互動
  final Color primary;
  final Color onPrimary;
  final Color icon;
  final Color iconSecondary;
  final Color iconTertiary;

  // 狀態
  final Color error;
  final Color success;
  final Color warning;

  // 特殊
  final Color divider;
  final Color dragHandle;
  final Color overlay;
  final Color shadow;
  final Color holiday;
  final Color currentTime;

  /// 淺色主題顏色
  static const light = AppColors(
    // 背景
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF5F5F5),
    surfaceContainerHigh: Color(0xFFEEEEEE),
    // 文字
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF666666),
    textDisabled: Color(0xFF999999),
    textOnPrimary: Color(0xFFFFFFFF),
    // 邊框
    border: Color(0xFFE5E5E5),
    borderSubtle: Color(0xFFF0F0F0),
    borderFocused: Color(0xFF000000),
    // 互動
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    icon: Color(0xFF000000),
    iconSecondary: Color(0xFF666666),
    iconTertiary: Color(0xFFBDBDBD),
    // 狀態
    error: Color(0xFFDC3545),
    success: Color(0xFF28A745),
    warning: Color(0xFFFFC107),
    // 特殊
    divider: Color(0xFFE5E5E5),
    dragHandle: Color(0xFFDDDDDD),
    overlay: Color(0x33000000),
    shadow: Color(0x1A000000),
    holiday: Color(0xFFE53935),
    currentTime: Color(0xFFE53935),
  );

  /// 深色主題顏色
  static const dark = AppColors(
    // 背景
    background: Color(0xFF121212),
    surface: Color(0xFF1A1A1A),
    surfaceContainer: Color(0xFF2A2A2A),
    surfaceContainerHigh: Color(0xFF333333),
    // 文字
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFAAAAAA),
    textDisabled: Color(0xFF666666),
    textOnPrimary: Color(0xFF000000),
    // 邊框
    border: Color(0xFF333333),
    borderSubtle: Color(0xFF2A2A2A),
    borderFocused: Color(0xFFFFFFFF),
    // 互動
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    icon: Color(0xFFFFFFFF),
    iconSecondary: Color(0xFFAAAAAA),
    iconTertiary: Color(0xFF616161),
    // 狀態
    error: Color(0xFFFF6B6B),
    success: Color(0xFF51CF66),
    warning: Color(0xFFFFD43B),
    // 特殊
    divider: Color(0xFF333333),
    dragHandle: Color(0xFF555555),
    overlay: Color(0x66000000),
    shadow: Color(0x33000000),
    holiday: Color(0xFFEF5350),
    currentTime: Color(0xFFEF5350),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? textOnPrimary,
    Color? border,
    Color? borderSubtle,
    Color? borderFocused,
    Color? primary,
    Color? onPrimary,
    Color? icon,
    Color? iconSecondary,
    Color? iconTertiary,
    Color? error,
    Color? success,
    Color? warning,
    Color? divider,
    Color? dragHandle,
    Color? overlay,
    Color? shadow,
    Color? holiday,
    Color? currentTime,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderFocused: borderFocused ?? this.borderFocused,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      icon: icon ?? this.icon,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      iconTertiary: iconTertiary ?? this.iconTertiary,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      divider: divider ?? this.divider,
      dragHandle: dragHandle ?? this.dragHandle,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
      holiday: holiday ?? this.holiday,
      currentTime: currentTime ?? this.currentTime,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh: Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderFocused: Color.lerp(borderFocused, other.borderFocused, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      iconTertiary: Color.lerp(iconTertiary, other.iconTertiary, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dragHandle: Color.lerp(dragHandle, other.dragHandle, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      holiday: Color.lerp(holiday, other.holiday, t)!,
      currentTime: Color.lerp(currentTime, other.currentTime, t)!,
    );
  }
}

/// 便捷存取 AppColors 的擴展方法
extension AppColorsExtension on BuildContext {
  /// 取得當前主題的 AppColors
  /// 使用方式：context.colors.surface
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
