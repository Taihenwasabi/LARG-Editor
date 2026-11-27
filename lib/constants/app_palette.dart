/// 全局**语义色 Token**（ThemeExtension）——黑夜模式可复用架构的地基。
///
/// 目标：把散落在各页的硬编码 `Colors.black` / `Colors.white`「内容色」收敛成
/// 一组**随明暗自动切换**的语义角色，页面只写 `context.palette.textPrimary`
/// 之类，不再关心当前是白天还是黑夜。这样新增页面沿用同一套 token 即可天然适配
/// 黑夜模式，满足「架构兼容性 + 可复用性优先」。
///
/// 用法：在 [MaterialApp] 的 `theme` / `darkTheme` 里用 [AppPalette.fromScheme]
/// 生成对应明暗的实例并塞进 `ThemeData.extensions`，业务层通过
/// `context.palette` 读取。
///
/// 关系：
/// - **系统 UI 域**走本扩展（随主题明暗）。
/// - **剧情域**走 [StorySkin]、**编辑器画布域**走 [CanvasSkin]（固定暗色皮肤）。
/// - **状态信号色**（危险/成功/信息/禁用）走 [AppStateColors]。
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/theme/state_colors.dart';

/// 语义色集合。所有字段都应是「随 brightness 变化」的中性色，
/// 不含品牌主色（主色走 `Theme.of(context).colorScheme.primary`）。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// 主要正文 / 图标色（浅底深字、深底浅字自动成立）。
  final Color textPrimary;

  /// 次要文字（说明、副标题）。
  final Color textSecondary;

  /// 更弱的提示文字（占位、禁用）。
  final Color textMuted;

  /// 卡片 / 列表项背景。
  final Color cardBg;

  /// 卡片 / 分隔描边。
  final Color cardBorder;

  /// 次级控件（胶囊按钮、chip）背景。
  final Color controlBg;

  /// 次级控件前景（文字/图标）。
  final Color controlText;

  /// 空态 / 灰色提示。
  final Color placeholder;

  /// 半透明遮罩（弹窗 barrier 等，明暗一致）。
  final Color scrim;

  /// 危险 / 破坏性操作色（删除、退出）。
  final Color danger;

  /// 更醒目的危险信号（校验失败、录制中）。
  final Color dangerStrong;

  /// 成功 / 已完成色。
  final Color success;

  /// 中性信息色（录制、预览）。
  final Color info;

  /// 不可用 / 未解锁色。
  final Color locked;

  /// 中性占位色（头像兜底）。
  final Color neutral;

  /// 危险底上的前景色。
  final Color onDanger;

  const AppPalette({
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.cardBg,
    required this.cardBorder,
    required this.controlBg,
    required this.controlText,
    required this.placeholder,
    required this.scrim,
    required this.danger,
    required this.dangerStrong,
    required this.success,
    required this.info,
    required this.locked,
    required this.neutral,
    required this.onDanger,
  });

  /// 由 Material 3 [ColorScheme] 派生——明暗各调用一次即自动适配。
  factory AppPalette.fromScheme(ColorScheme s) {
    return AppPalette(
      textPrimary: s.onSurface,
      textSecondary: s.onSurfaceVariant,
      textMuted: s.onSurfaceVariant.withValues(alpha: 0.62),
      cardBg: s.surfaceContainerHigh,
      cardBorder: s.outlineVariant,
      controlBg: s.surfaceContainerHighest,
      controlText: s.onSurface,
      placeholder: s.onSurfaceVariant.withValues(alpha: 0.5),
      scrim: const Color(0x8A000000),
      danger: AppStateColors.danger,
      dangerStrong: AppStateColors.dangerStrong,
      success: AppStateColors.success,
      info: AppStateColors.info,
      locked: AppStateColors.locked,
      neutral: AppStateColors.neutral,
      onDanger: AppStateColors.onDanger,
    );
  }

  /// 兜底浅色盘（未注册扩展时用，避免崩溃）。
  static final AppPalette fallback = AppPalette.fromScheme(
    ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
  );

  @override
  AppPalette copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? cardBg,
    Color? cardBorder,
    Color? controlBg,
    Color? controlText,
    Color? placeholder,
    Color? scrim,
    Color? danger,
    Color? dangerStrong,
    Color? success,
    Color? info,
    Color? locked,
    Color? neutral,
    Color? onDanger,
  }) {
    return AppPalette(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      controlBg: controlBg ?? this.controlBg,
      controlText: controlText ?? this.controlText,
      placeholder: placeholder ?? this.placeholder,
      scrim: scrim ?? this.scrim,
      danger: danger ?? this.danger,
      dangerStrong: dangerStrong ?? this.dangerStrong,
      success: success ?? this.success,
      info: info ?? this.info,
      locked: locked ?? this.locked,
      neutral: neutral ?? this.neutral,
      onDanger: onDanger ?? this.onDanger,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      textPrimary: m(textPrimary, other.textPrimary),
      textSecondary: m(textSecondary, other.textSecondary),
      textMuted: m(textMuted, other.textMuted),
      cardBg: m(cardBg, other.cardBg),
      cardBorder: m(cardBorder, other.cardBorder),
      controlBg: m(controlBg, other.controlBg),
      controlText: m(controlText, other.controlText),
      placeholder: m(placeholder, other.placeholder),
      scrim: m(scrim, other.scrim),
      danger: m(danger, other.danger),
      dangerStrong: m(dangerStrong, other.dangerStrong),
      success: m(success, other.success),
      info: m(info, other.info),
      locked: m(locked, other.locked),
      neutral: m(neutral, other.neutral),
      onDanger: m(onDanger, other.onDanger),
    );
  }
}

/// `context.palette` 便捷读取；未注册时回退到 [AppPalette.fallback]。
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.fallback;
}
