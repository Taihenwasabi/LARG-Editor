
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_media.dart';
import 'package:larg_editor/page/editor/editor_models.dart';

class ScriptTextPage extends StatefulWidget {
  final EditablePack pack;
  const ScriptTextPage({super.key, required this.pack});

  @override
  State<ScriptTextPage> createState() => _ScriptTextPageState();
}

class _ScriptTextPageState extends State<ScriptTextPage> {
  static const double _bodySize = 15.5;

  EditablePack get pack => widget.pack;

  @override
  void initState() {
    super.initState();
    pack.addListener(_onPack);
  }

  @override
  void dispose() {
    pack.removeListener(_onPack);
    super.dispose();
  }

  void _onPack() {
    if (mounted) setState(() {});
  }

  bool get _empty =>
      pack.stages.every((s) => s.lines.isEmpty && s.checkpoints.isEmpty);

  String _nextLabel(String next) {
    if (next.trim().isEmpty) return t('editor.cp.next.end');
    for (final s in pack.stages) {
      if (s.id == next) return s.displayLabel;
    }
    return next;
  }

  String _itemName(String id) {
    for (final i in pack.items) {
      if (i.id == id) return i.name;
    }
    return id;
  }

  String _stageTitle(int index, EditableStage stage) {
    final title = t('editor.stage.number', args: {'n': index + 1});
    final label = stage.displayLabel.trim();
    return label.isEmpty ? title : '$title · $label';
  }

  List<_MediaEntry> _mediaEntries(EditableLine line) {
    final image = line.image.trim();
    final audio = line.audio.trim();
    final video = line.video.trim();
    return [
      if (image.isNotEmpty && isImagePath(image))
        _MediaEntry(t('editor.line.image'), image, Icons.image_outlined),
      if (audio.isNotEmpty && isAudioPath(audio))
        _MediaEntry(t('editor.line.audio'), audio, Icons.audiotrack),
      if (video.isNotEmpty && isVideoPath(video))
        _MediaEntry(t('editor.line.video'), video, Icons.videocam),
    ];
  }

  String? _mediaTag(EditableLine line) {
    final entries = _mediaEntries(line);
    if (entries.isEmpty) return null;
    return entries.map((e) => '  [${e.label}] ${e.path}').join('\n');
  }

  List<String> _grants(EditableCheckpoint cp) => [
    for (final e in cp.grant.entries)
      if (e.value != 0) '${_itemName(e.key)}×${e.value}',
  ];

  String _checkpointLabel(EditableCheckpoint cp, int index) {
    final text = cp.text.trim();
    if (text.isNotEmpty) return text;
    final next = cp.next.trim();
    if (next.isNotEmpty) return next;
    return '#${index + 1}';
  }

  String _buildText() {
    final buf = StringBuffer();
    var hasContent = false;
    for (var i = 0; i < pack.stages.length; i++) {
      final stage = pack.stages[i];
      if (i > 0) buf.writeln();
      buf.writeln(_stageTitle(i, stage));
      for (final line in stage.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        hasContent = true;
        final speaker = line.speaker.trim();
        buf.writeln(speaker.isEmpty ? text : '$speaker：$text');
        final tag = _mediaTag(line);
        if (tag != null) buf.writeln(tag);
      }
      if (stage.checkpoints.isNotEmpty) {
        hasContent = true;
        buf.writeln(t('editor.stage.checkpoints'));
        for (var k = 0; k < stage.checkpoints.length; k++) {
          final cp = stage.checkpoints[k];
          buf.writeln('· ${_checkpointLabel(cp, k)}');
          final condition = cp.condition.trim();
          if (condition.isNotEmpty) {
            buf.writeln('  ${t('editor.cp.condition')}：$condition');
          }
          final grants = _grants(cp);
          if (grants.isNotEmpty) {
            buf.writeln('  ${t('editor.cp.grant')}：${grants.join('、')}');
          }
          buf.writeln('  ${t('editor.cp.next')}：${_nextLabel(cp.next)}');
        }
      }
    }
    if (!hasContent) return '';
    return buf.toString().trimRight();
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _buildText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('editor.script.copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(t('editor.script.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: t('editor.script.copy'),
            onPressed: () => _copy(context),
          ),
        ],
      ),
      body: _empty
          ? Center(
              child: Text(
                t('editor.script.empty'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final horizontal = width < 600
                    ? 16.0
                    : width < 1100
                        ? 32.0
                        : 48.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 48),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < pack.stages.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == pack.stages.length - 1 ? 0 : 32,
                              ),
                              child: _stageView(context, i, pack.stages[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _stageView(BuildContext context, int index, EditableStage stage) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _stageTitle(index, stage),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 8, bottom: 10),
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        for (final line in stage.lines)
          _ScriptLineRow(
            key: ObjectKey(line),
            line: line,
            media: _mediaEntries(line),
            onChanged: pack.notify,
          ),
        if (stage.checkpoints.isNotEmpty) _checkpointView(context, stage),
      ],
    );
  }

  Widget _checkpointView(BuildContext context, EditableStage stage) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('editor.stage.checkpoints'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: secondary,
            ),
          ),
          for (var k = 0; k < stage.checkpoints.length; k++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(Icons.alt_route, size: 14, color: secondary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ScriptOptionField(
                          key: ObjectKey(stage.checkpoints[k]),
                          cp: stage.checkpoints[k],
                          fallback: _checkpointLabel(
                            stage.checkpoints[k],
                            k,
                          ),
                          onChanged: pack.notify,
                        ),
                      ),
                    ],
                  ),
                  ..._checkpointRows(context, stage.checkpoints[k]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _checkpointRows(BuildContext context, EditableCheckpoint cp) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final rows = <Widget>[];
    void add(IconData icon, String label, String value) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 2),
          child: Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '$label：$value',
                  style: TextStyle(fontSize: 12.5, color: color),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final condition = cp.condition.trim();
    if (condition.isNotEmpty) {
      add(Icons.rule_outlined, t('editor.cp.condition'), condition);
    }
    final grants = _grants(cp);
    if (grants.isNotEmpty) {
      add(Icons.inventory_2_outlined, t('editor.cp.grant'), grants.join('、'));
    }
    add(
      Icons.subdirectory_arrow_right,
      t('editor.cp.next'),
      _nextLabel(cp.next),
    );
    return rows;
  }
}

class _ScriptLineRow extends StatefulWidget {
  final EditableLine line;
  final List<_MediaEntry> media;
  final VoidCallback onChanged;

  const _ScriptLineRow({
    super.key,
    required this.line,
    required this.media,
    required this.onChanged,
  });

  @override
  State<_ScriptLineRow> createState() => _ScriptLineRowState();
}

class _ScriptLineRowState extends State<_ScriptLineRow> {
  late final TextEditingController _speaker = TextEditingController(
    text: widget.line.speaker,
  );
  late final TextEditingController _text = TextEditingController(
    text: widget.line.text,
  );
  final FocusNode _speakerFocus = FocusNode();
  final FocusNode _textFocus = FocusNode();

  @override
  void didUpdateWidget(covariant _ScriptLineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_speakerFocus.hasFocus && _speaker.text != widget.line.speaker) {
      _speaker.text = widget.line.speaker;
    }
    if (!_textFocus.hasFocus && _text.text != widget.line.text) {
      _text.text = widget.line.text;
    }
  }

  @override
  void dispose() {
    _speaker.dispose();
    _text.dispose();
    _speakerFocus.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _speaker,
                  focusNode: _speakerFocus,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.86,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 3),
                    hintText: t('editor.line.narration'),
                    hintStyle: TextStyle(
                      fontSize: 14.5,
                      height: 1.86,
                      fontWeight: FontWeight.w400,
                      color: scheme.outline,
                    ),
                  ),
                  onChanged: (v) {
                    widget.line.speaker = v;
                    widget.line.type =
                        v.trim().isEmpty ? 'narration' : 'dialogue';
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _textFocus,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: TextStyle(
                    fontSize: _ScriptTextPageState._bodySize,
                    height: 1.75,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 3),
                    hintText: t('editor.line.text'),
                    hintStyle: TextStyle(
                      fontSize: _ScriptTextPageState._bodySize,
                      height: 1.75,
                      color: scheme.outline,
                    ),
                  ),
                  onChanged: (v) {
                    widget.line.text = v;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          if (widget.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in widget.media)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          Icon(
                            entry.icon,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              entry.path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScriptOptionField extends StatefulWidget {
  final EditableCheckpoint cp;
  final String fallback;
  final VoidCallback onChanged;

  const _ScriptOptionField({
    super.key,
    required this.cp,
    required this.fallback,
    required this.onChanged,
  });

  @override
  State<_ScriptOptionField> createState() => _ScriptOptionFieldState();
}

class _ScriptOptionFieldState extends State<_ScriptOptionField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.cp.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _ScriptOptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _c.text != widget.cp.text) {
      _c.text = widget.cp.text;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _c,
      focusNode: _focus,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 3),
        hintText: widget.fallback,
        hintStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
      onChanged: (v) {
        widget.cp.text = v;
        widget.onChanged();
      },
    );
  }
}

class _MediaEntry {
  final String label;
  final String path;
  final IconData icon;
  const _MediaEntry(this.label, this.path, this.icon);
}
