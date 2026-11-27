/// 自持控制器的标签输入框。
///
/// 桌面检查器里大量"值↔模型"小输入框。若每次 build 新建
/// [TextEditingController]，任何外层重建都会把光标弹回末尾（打字中断游标）。
/// 本组件自己管理控制器生命周期：外部值变了才同步，用户输入过程中不打扰。
library;

import 'package:flutter/material.dart';

class LabeledField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final TextInputType? keyboardType;

  const LabeledField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines,
    this.keyboardType,
  });

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant LabeledField old) {
    super.didUpdateWidget(old);
    // 外部值变了且与当前输入不一致才覆盖（避免打字过程中被重建重置）
    if (widget.value != old.value && widget.value != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _ctrl,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(labelText: widget.label, isDense: true),
        onChanged: widget.onChanged,
      ),
    );
  }
}
