/// 系统 UI 域的**语义状态色**。
///
/// ## 色值维持原样（用户 2026-11-27 裁定，勿改）
/// 本文件的每个值都是迁移前页面里写死的原值，一一对应：
/// - [AppStateColors.danger] = `Colors.redAccent`（退出登录、删除素材）
/// - [AppStateColors.dangerStrong] = `Colors.red`（表单校验失败、录制中）
/// - [AppStateColors.info] = `Colors.blue`（可玩标记、录制待机）
/// - [AppStateColors.locked] = `Colors.grey`（锁定标记）
/// - [AppStateColors.neutral] = `Colors.blueGrey`（头像占位）
/// - [AppStateColors.success] = `Colors.green`
///
/// 这些色**不随明暗切换**（原先就是固定色），换主题时保持一致。
///
/// 语义角色（不要按颜色取用）：
/// - [AppStateColors.danger]：破坏性操作（删除、退出登录）
/// - [AppStateColors.dangerStrong]：需要更醒目的危险信号（校验失败、录制中）
/// - [AppStateColors.success]：完成 / 通过
/// - [AppStateColors.info]：中性信息（录制、预览）
/// - [AppStateColors.locked]：不可用 / 未解锁
/// - [AppStateColors.neutral]：中性占位
library;

import 'package:flutter/material.dart';

/// 系统 UI 状态色（固定值，不随主题明暗变化）。
class AppStateColors {
  AppStateColors._();

  /// 危险 / 破坏性操作（`Colors.redAccent` 原值）。
  static const Color danger = Color(0xFFFF5252);

  /// 需要更醒目的危险信号（`Colors.red` 原值）。
  static const Color dangerStrong = Color(0xFFF44336);

  /// 成功 / 已完成（`Colors.green` 原值）。
  static const Color success = Color(0xFF4CAF50);

  /// 中性信息 / 进行中（`Colors.blue` 原值）。
  static const Color info = Color(0xFF2196F3);

  /// 不可用 / 未解锁（`Colors.grey` 原值）。
  static const Color locked = Color(0xFF9E9E9E);

  /// 中性占位（`Colors.blueGrey` 原值）。
  static const Color neutral = Color(0xFF607D8B);

  /// 危险底上的前景色。
  static const Color onDanger = Color(0xFFFFFFFF);
}
