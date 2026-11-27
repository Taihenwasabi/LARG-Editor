/// 试玩时的「作答」面板：提交文字 / 选素材 → 本地或 AI 判定 → 显示结果。
///
/// 判定口径与 quq1 一致：先本地能判的就地判，配置了 AI 且要点非空的走 AI。
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/engine/model/check.dart';
import 'package:larg_editor/model/check_ai_config.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/service/ai_judge.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

/// 提交结果。
class SubmitOutcome {
  final bool passed;
  final String message;
  final List<String> reasons;

  const SubmitOutcome({
    required this.passed,
    required this.message,
    this.reasons = const [],
  });
}

class SubmitPanel extends StatefulWidget {
  final EditablePack pack;
  final EditableCheck check;
  final String question;
  final bool needText;

  const SubmitPanel({
    super.key,
    required this.pack,
    required this.check,
    required this.question,
    required this.needText,
  });

  @override
  State<SubmitPanel> createState() => _SubmitPanelState();
}

class _SubmitPanelState extends State<SubmitPanel> {
  final _textCtrl = TextEditingController();
  final Set<String> _pickedMedia = {};
  bool _busy = false;
  SubmitOutcome? _outcome;

  Check get _engineCheck => Check(
    id: widget.check.id,
    type: widget.check.type,
    verify: widget.check.verify,
    params: widget.check.params,
  );

  bool get _aiMode => widget.check.verify == 'ai' && _engineCheck.aiEnabled;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _outcome = null;
    });
    try {
      final answer = _textCtrl.text.trim();
      if (widget.needText && answer.isEmpty) {
        setState(() {
          _busy = false;
          _outcome = const SubmitOutcome(
            passed: false,
            message: '先写点什么再提交',
          );
        });
        return;
      }
      if (_aiMode) {
        final verdict = await AiJudge.judge(
          check: _engineCheck,
          question: widget.question,
          answer: answer,
          evidence: [
            for (final path in _pickedMedia)
              AiEvidence(path.split('/').last, '已提交的素材'),
          ],
        );
        setState(() {
          _outcome = SubmitOutcome(
            passed: verdict.passed,
            message: verdict.passed
                ? '通过'
                : (_engineCheck.failText.isEmpty
                      ? '这次没有通过'
                      : _engineCheck.failText),
            reasons: verdict.reasons,
          );
        });
      } else {
        setState(() => _outcome = _localJudge(answer));
      }
    } catch (e) {
      setState(() {
        _outcome = SubmitOutcome(passed: false, message: '判定出错：$e');
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  SubmitOutcome _localJudge(String answer) {
    final spec = _engineCheck.submitRequirement;
    if (spec.need > 0 && _pickedMedia.length < spec.need) {
      return SubmitOutcome(
        passed: false,
        message: '需要提交 ${spec.need} 个素材，当前已选 ${_pickedMedia.length} 个',
      );
    }
    if (widget.check.type == 'text_answer') {
      final expected = (widget.check.params['answer'] ?? '').toString().trim();
      if (expected.isNotEmpty) {
        final ok = answer.toLowerCase() == expected.toLowerCase();
        return SubmitOutcome(
          passed: ok,
          message: ok
              ? '通过'
              : (_engineCheck.failText.isEmpty ? '答案不对，再想想' : _engineCheck.failText),
        );
      }
    }
    return const SubmitOutcome(passed: true, message: '通过');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CanvasSkin.panel,
              borderRadius: FiftyRadii.xlRadius,
              border: Border.all(
                color: CanvasSkin.white.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note, size: 18, color: _accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.question,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: CanvasSkin.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: CanvasSkin.white54,
                          ),
                        ),
                      ],
                    ),
                    if (widget.needText) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _textCtrl,
                        maxLines: 5,
                        minLines: 3,
                        style: const TextStyle(color: CanvasSkin.white),
                        decoration: InputDecoration(
                          hintText: '写下你的答案…',
                          hintStyle: const TextStyle(color: CanvasSkin.white38),
                          filled: true,
                          fillColor: CanvasSkin.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: FiftyRadii.mdRadius,
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                    if (_mediaChoices().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        '可选素材（点选后才算提交）',
                        style: TextStyle(fontSize: 11, color: CanvasSkin.white54),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final path in _mediaChoices())
                            FilterChip(
                              label: Text(
                                path.split('/').last,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: _pickedMedia.contains(path),
                              onSelected: (on) => setState(() {
                                if (on) {
                                  _pickedMedia.add(path);
                                } else {
                                  _pickedMedia.remove(path);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (_outcome != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _outcome!.passed
                              ? Colors.green.withValues(alpha: 0.14)
                              : Colors.red.withValues(alpha: 0.14),
                          borderRadius: FiftyRadii.mdRadius,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _outcome!.passed ? '✓ ${_outcome!.message}' : '✗ ${_outcome!.message}',
                              style: TextStyle(
                                color: _outcome!.passed
                                    ? Colors.green.shade300
                                    : Colors.red.shade300,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            for (final r in _outcome!.reasons) ...[
                              const SizedBox(height: 4),
                              Text(
                                '· $r',
                                style: const TextStyle(
                                  color: CanvasSkin.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        if (_outcome?.passed == true)
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('继续'),
                          )
                        else
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_aiMode ? '让 AI 判定' : '提交'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  List<String> _mediaChoices() {
    final out = <String>[];
    for (final p in widget.pack.mediaPaths) {
      final lower = p.toLowerCase();
      if (lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.wav') ||
          lower.endsWith('.mp3') ||
          lower.endsWith('.mp4')) {
        out.add(p);
      }
    }
    return out;
  }
}

const Color _accent = CanvasSkin.accent;
