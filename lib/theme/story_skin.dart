/// 剧情域（沉浸式游戏画面）的**固定暗色皮肤**。
///
/// ## 为什么是固定色，不跟主题走
/// 剧情页是"游戏画面"的一部分：底图是场景素材、面板是贴片，跟随明暗切换会
/// 出现"浅底场景 + 深色面板"的割裂。因此这里的色值**写死**，不随主题变。
///
/// ## 色值不得擅自改动
/// 本文件的每个常量都是迁移前各页面里的原值，一一对应，没有重新配色。
/// 改这里 = 改游戏画面，必须是明确的产品决定。
library;

import 'package:flutter/material.dart';

/// 剧情域固定皮肤。
class StorySkin {
  StorySkin._();

  /// 页面底色（游戏画面背景）。
  static const Color backdrop = Color(0xFF10171F);

  /// 对话面板底色（gameTalk）。
  static const Color panel = Color(0xFF101418);

  /// 面板上的正文色。
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// 面板上的次要文字（70% 白）。
  static const Color textSecondary = Color(0xB3FFFFFF);

  /// 面板上的弱提示文字（54% 白）。
  static const Color textMuted = Color(0x8AFFFFFF);

  /// 极弱提示文字（38% 白）。
  static const Color textGhost = Color(0x61FFFFFF);

  /// 分隔线 / 描边（12% 白）。
  static const Color line = Color(0x1FFFFFFF);

  /// 卡片浮层（14% 白）。
  static const Color fillFaint = Color(0x0DFFFFFF);

  /// 卡片浮层（14% 白，另一种描边用法）。
  static const Color fill = Color(0x24FFFFFF);

  /// 遮罩（55% 黑）。
  static const Color scrim = Color(0x8C000000);

  /// 遮罩（45% 黑）。
  static const Color scrimLight = Color(0x73000000);

  /// 遮罩（38% 黑）。
  static const Color scrimSoft = Color(0x61000000);

  /// 强调色：积分 / 排名 / 高亮项（amber.shade300）。
  static const Color accent = Color(0xFFFFD54F);

  /// 琥珀原色（Colors.amber）。
  static const Color accentBase = Color(0xFFFFC107);

  /// 强调色中档（amber.shade400）：描边 / 高亮提示。
  static const Color accentMid = Color(0xFFFFCA28);

  /// 强调色深档（amber.shade600）：强调按钮底。
  static const Color accentStrong = Color(0xFFFFB300);

  /// 强调色最深档（amber.shade800）：提示图标。
  static const Color accentDeep = Color(0xFFFF8F00);

  /// 强调按钮上的前景色（黑）。
  static const Color onAccent = Color(0xFF000000);

  /// 高亮提示条的底色（米黄 FFF3C0）。
  static const Color hintSurface = Color(0xFFFFF3C0);

  /// 高亮提示条的浅底色（amber.shade50）。
  static const Color hintSurfaceSoft = Color(0xFFFFF8E1);

  /// 高亮提示条的描边色（amber.shade200）。
  static const Color hintSurfaceBorder = Color(0xFFFFE082);

  /// 高亮提示条上的前景色（黑 87%）。
  static const Color onHintSurface = Color(0xDE000000);

  /// 棕色系前景（brown.shade700）。
  static const Color brown = Color(0xFF5D4037);

  /// 已通过 / 正确状态（green.shade300）。
  static const Color success = Color(0xFF81C784);

  /// 通过项的弱底色（18% 绿）。
  static const Color successSoft = Color(0x2E81C784);

  /// 未通过 / 禁用项（grey.shade400）。
  static const Color muted = Color(0xFFBDBDBD);

  /// 中性灰（Colors.grey 原值）。
  static const Color grey = Color(0xFF9E9E9E);

  /// 未通过项的弱底色（18% 灰）。
  static const Color mutedSoft = Color(0x2E9E9E9E);

  /// 地图未解锁区域（blueGrey.shade900）。
  static const Color mapLocked = Color(0xFF263238);

  /// 地图主按钮底色（米黄 F5F5DC）。
  static const Color mapAction = Color(0xFFF5F5DC);

  /// 地图主按钮按下态（50% 米黄）。
  static const Color mapActionPressed = Color(0x80F5F5DC);

  /// 地图按钮前景（黑）。
  static const Color onMapAction = Color(0xFF000000);

  /// 地图禁用描边（黑 26%）。
  static const Color mapLine = Color(0x42000000);

  /// 地图禁用底色（黑 12%）。
  static const Color mapFill = Color(0x1F000000);

  /// 地图次要标记（blue.shade700 80%）。
  static const Color mapMarker = Color(0xCC1976D2);

  /// 画面渐变头（深青）。
  static const Color gradientHead = Color(0xFF134E5A);

  /// 画面渐变中（墨绿）。
  static const Color gradientMid = Color(0xFF3A7D44);

  /// 画面渐变尾（深墨绿）。
  static const Color gradientFoot = Color(0xFF1B2A20);

  /// 画面面板浮层（黑 82%）。
  static const Color panelOverlay = Color(0xD116171A);
}
