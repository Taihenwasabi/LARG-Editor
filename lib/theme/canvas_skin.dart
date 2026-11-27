/// 编辑器画布域（预览页 / 素材预览）的**固定暗色皮肤**。
///
/// 与 [StorySkin] 同理：这是"作品画面"，跟随主题会割裂，色值写死。
/// 玫红强调色（FF385C）是编辑器视觉稿的主色，保留。
library;

import 'package:flutter/material.dart';

/// 编辑器画布固定皮肤。
class CanvasSkin {
  CanvasSkin._();

  /// 画布底色（最深的黑）。
  static const Color backdrop = Color(0xFF07080A);

  /// 面板底色（近黑）。
  static const Color panel = Color(0xFF0A0B0E);

  /// 面板浮层（黑 90%）。
  static const Color panelRaised = Color(0xE60A0B0E);

  /// 次级面板（黑 94%）。
  static const Color panelHigh = Color(0xF214161B);

  /// 面板浮层（黑 95%）。
  static const Color panelOverlay = Color(0xF014161A);

  /// 正文色（白）。
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// 次要文字（70% 白）。
  static const Color textSecondary = Color(0xB3FFFFFF);

  /// 弱提示（54% 白）。
  static const Color textMuted = Color(0x8AFFFFFF);

  /// 更弱的提示（36% 白）。
  static const Color textGhost = Color(0x5CFFFFFF);

  /// 描边（10% 白）。
  static const Color line = Color(0x1AFFFFFF);

  /// 浮层填充（6% 白）。
  static const Color fillFaint = Color(0x0F000000);

  /// 浮层填充（10% 白）。
  static const Color fill = Color(0x1AFFFFFF);

  /// 遮罩（52% 黑）。
  static const Color scrim = Color(0x85000000);

  /// 强调色：编辑器主色（玫红 FF385C）。
  static const Color accent = Color(0xFFFF385C);

  /// 强调色浅档（玫红 FF8FA5），用于文字与描边。
  static const Color accentSoft = Color(0xFFFF8FA5);

  /// 强调色更浅档（橘粉 FFA48F），用于提示。
  static const Color accentMuted = Color(0xFFFFA48F);

  /// 成功色（深绿 2E7D32）。
  static const Color success = Color(0xFF2E7D32);

  /// 极暗浮层（黑 90%）。
  static const Color deep90 = Color(0xE6000000);

  /// 黑色纯色（阴影 / 前景用）。
  static const Color black = Color(0xFF000000);

  /// 纯白。
  static const Color white = Color(0xFFFFFFFF);

  /// 白色 70%。
  static const Color white70 = Color(0xB3FFFFFF);

  /// 白色 54%。
  static const Color white54 = Color(0x8AFFFFFF);

  /// 白色 38%。
  static const Color white38 = Color(0x61FFFFFF);

  /// 白色 12%。
  static const Color white12 = Color(0x1FFFFFFF);

  /// 白色 24%。
  static const Color white24 = Color(0x3DFFFFFF);

  /// 黑 54%（浮层阴影 / 遮罩按钮底）。
  static const Color black54 = Color(0x8A000000);

  /// 黑 45%（遮罩按钮底）。
  static const Color black45 = Color(0x73000000);

  /// 黑 87%（重遮罩）。
  static const Color black87 = Color(0xDE000000);

  /// 浅灰（禁用 / 占位）。
  static const Color ddd = Color(0xFFDDDDDD);

  /// 近白（浅色面板）。
  static const Color f7f7f7 = Color(0xFFF7F7F7);

  /// 极浅灰（输入框底）。
  static const Color fafafa = Color(0xFFFAFAFA);

  /// 中灰（占位图标）。
  static const Color b0b0b0 = Color(0xFFB0B0B0);

  /// 中灰（禁用）。
  static const Color grey400 = Color(0xFF9E9E9E);

  /// 浅色预览窗的正文色（深墨）。
  static const Color lightInk = Color(0xFF222222);

  /// 浅色预览窗的次要文字（中灰）。
  static const Color lightMuted = Color(0xFF717171);

  /// 浅色预览窗的分隔线（浅灰）。
  static const Color lightLine = Color(0xFFEBEBEB);

  /// 画布渐变：蓝紫。
  static const Color gradientCool = Color(0xFF141C28);

  /// 画布渐变：紫。
  static const Color gradientViolet = Color(0xFF191428);

  /// 画布渐变：近黑。
  static const Color gradientDeep = Color(0xFF05060A);
}
