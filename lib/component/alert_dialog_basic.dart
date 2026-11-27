import 'package:flutter/material.dart';
import 'package:larg_editor/i18n/i18n.dart';

/// 弹出基础对话框
///
/// [title]      - 标题文字
/// [content]     - 内容区域（完全自定义）
/// [cancelText]  - 取消按钮文字
/// [confirmText] - 确定按钮文字
/// [onCancel]    - 取消回调（自动关闭）
/// [onConfirm]   - 确定回调（不自动关闭，需手动 pop）
Future<void> showAlertDialog({
  required BuildContext context,
  required String title,
  required Widget content,
  String? cancelText,
  String? confirmText,
  VoidCallback? onCancel,
  VoidCallback? onConfirm,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 5),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          Text(title, style: const TextStyle(fontSize: 18)),
          IconButton(
            onPressed: () {
              onCancel?.call();
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: content,
      actions: [
        TextButton(
          onPressed: () {
            onCancel?.call();
            Navigator.pop(ctx);
          },
          child: Text(cancelText ?? t('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx); // 先关弹窗
            onConfirm?.call(); // 再执行回调
          },
          child: Text(confirmText ?? t('common.confirm')),
        ),
      ],
    ),
  );
}
