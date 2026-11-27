/// 全局主题构建 —— FDL 视觉体系的主题执行层。
///
/// ## 用户裁定
/// - **颜色维持原样**（2026-11-26）：品牌色仍是 [kSeedColor] 生成的原色板，
///   不换 FDL v2 的酒红米色。构造时传自己的 [ColorScheme]，颜色一个不变。
/// - **启用 Manrope**（2026-11-27）：字族采用 FDL 规范的 Manrope。
///
/// ## Manrope 怎么用（零网络）
/// 五个静态字重在 `pubspec.yaml` 的 `fonts:` 里声明、随包分发，
/// 配 [FontSource.asset] 由 Flutter 引擎在构建期内置。因此：
/// - 不走 google_fonts 的运行时下载，**不联网**；
/// - 不存在"每次都要加载"，字体随 APK 一起装上，运行时直接可用。
///
/// 中文不在 Manrope 内，由 [kFontFamilyFallback] 的系统字体补齐。
library;

import 'package:fifty_theme/fifty_theme.dart';
import 'package:fifty_tokens/fifty_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:larg_editor/constants/app_palette.dart';

/// 品牌种子色。用户裁定颜色维持原样，**不要改这个值**。
const Color kSeedColor = Color(0xFF6750A4);

/// 正文字族（FDL 规范字体，随包内置）。
const String kFontFamily = 'Manrope';

/// 中文回退链。Manrope 只覆盖拉丁/数字/符号，汉字落到系统字体，
/// 顺序按平台惯例：Android 优先 Noto Sans CJK，iOS/macOS 优先苹方。
const List<String> kFontFamilyFallback = <String>[
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'PingFang SC',
  'Microsoft YaHei',
  'sans-serif',
];

bool _fiftyReady = false;

/// 关掉 google_fonts 的运行时下载。
///
/// 安全：`FiftyComponentThemes` 内部经 [FiftyFontResolver] 取字体，一旦
/// 字体源是 `googleFonts` 就会去 fonts.gstatic.com 拉；失败还会 rethrow。
/// 这里把源固定为 `asset`，并关掉下载开关做双保险——
/// 有代码误用 `GoogleFonts.getFont()` 会立刻抛错，而不是把用户 IP 发出去。
void initFiftyTheme() {
  if (_fiftyReady) return;
  _fiftyReady = true;
  GoogleFonts.config.allowRuntimeFetching = false;
  FiftyTokens.configure(
    typography: FiftyTokens.active.typography.copyWith(
      fontFamily: kFontFamily,
      fontSource: FontSource.asset,
    ),
  );
}

/// 构建指定明暗的全局主题。
ThemeData buildAppTheme(Brightness brightness) {
  initFiftyTheme();
  final scheme = ColorScheme.fromSeed(
    seedColor: kSeedColor,
    brightness: brightness,
  );
  final base = brightness == Brightness.dark
      ? FiftyTheme.dark(colorScheme: scheme, fontSource: FontSource.asset)
      : FiftyTheme.light(colorScheme: scheme, fontSource: FontSource.asset);
  return base.copyWith(
    // 中文回退：FiftyTheme 只设了 fontFamily，汉字需要显式给出回退链。
    textTheme: base.textTheme.apply(fontFamilyFallback: kFontFamilyFallback),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamilyFallback: kFontFamilyFallback,
    ),
    // 只注册 AppPalette：FiftyThemeExtension 带的是 FDL 的酒红/墨绿/粉橘，
    // 与「颜色维持原样」冲突，因此不引入。
    extensions: <ThemeExtension<dynamic>>[AppPalette.fromScheme(scheme)],
  );
}
