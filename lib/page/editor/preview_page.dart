import 'package:flutter/material.dart';
import 'package:larg_editor/component/media_preview_dialog.dart';
import 'package:larg_editor/engine/model/scene.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_media.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

const Color _accent = CanvasSkin.accent;

class EditorPreviewPage extends StatefulWidget {
  final EditablePack pack;

  const EditorPreviewPage({super.key, required this.pack});

  @override
  State<EditorPreviewPage> createState() => _EditorPreviewPageState();
}

class _EditorPreviewPageState extends State<EditorPreviewPage> {
  int _stageIndex = 0;
  int _lineIndex = 0;
  bool _ended = false;
  bool _debug = false;
  bool _editing = false;
  late Map<String, int> _values;

  EditablePack get _pack => widget.pack;

  EditableStage? get _stage =>
      _stageIndex >= 0 && _stageIndex < _pack.stages.length
      ? _pack.stages[_stageIndex]
      : null;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _values = {for (final item in _pack.items) item.id: item.initial};
    _stageIndex = 0;
    _lineIndex = 0;
    _ended = false;
  }

  bool get _atChoices {
    final stage = _stage;
    if (stage == null || _ended) return false;
    return _lineIndex >= stage.lines.length;
  }

  void _advance() {
    final stage = _stage;
    if (stage == null || _atChoices) return;
    if (_lineIndex < stage.lines.length - 1) {
      setState(() => _lineIndex++);
      return;
    }
    if (stage.checkpoints.isEmpty) {
      setState(() => _ended = true);
      return;
    }
    setState(() => _lineIndex = stage.lines.length);
  }

  void _choose(EditableCheckpoint cp) {
    for (final entry in cp.grant.entries) {
      _values[entry.key] = (_values[entry.key] ?? 0) + entry.value;
    }
    final nextId = cp.next.trim();
    if (nextId.isEmpty) {
      setState(() => _ended = true);
      return;
    }
    final index = _pack.stages.indexWhere((s) => s.id == nextId);
    if (index < 0) {
      setState(() => _ended = true);
      return;
    }
    setState(() {
      _stageIndex = index;
      _lineIndex = 0;
    });
  }

  bool _met(String condition) {
    final rows = EditableConditionRow.parse(condition);
    for (final row in rows) {
      if (row.isRaw) return false;
      final value = _values[row.item] ?? 0;
      final ok = switch (row.op) {
        '>=' => value >= row.value,
        '<=' => value <= row.value,
        '==' => value == row.value,
        '!=' => value != row.value,
        '>' => value > row.value,
        '<' => value < row.value,
        _ => false,
      };
      if (!ok) return false;
    }
    return true;
  }

  void _openMedia(String rel) {
    final kind = isImagePath(rel)
        ? MediaKind.image
        : isAudioPath(rel)
        ? MediaKind.audio
        : MediaKind.video;
    openMediaPreview(
      context,
      kind: kind,
      assetKey: _pack.assetKeyFor(rel) ?? rel,
      bytes: _pack.importedMedia[rel],
      title: rel.split('/').last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    final lines = stage?.lines ?? const <EditableLine>[];
    final line = _lineIndex < lines.length ? lines[_lineIndex] : null;
    final scene = _sceneAt(line == null ? lines.length : _lineIndex);
    final reading = !_atChoices && !_ended && line != null;
    final dark = Theme.of(context).copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: Brightness.dark,
      ),
    );
    return Theme(
      data: dark,
      child: Scaffold(
        backgroundColor: CanvasSkin.backdrop,
        appBar: _appBar(stage, lines),
        body: _pack.stages.isEmpty
            ? Center(
                child: Text(
                  t('editor.preview.empty'),
                  style: const TextStyle(color: CanvasSkin.white70),
                ),
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _editing || _atChoices || _ended ? null : _advance,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _sceneLayer(scene),
                    const Positioned.fill(child: _BottomScrim()),
                    if (stage != null) _progressBar(lines),
                    if (reading) _lineImageLayer(line),
                    if (reading) _topMediaChips(line),
                    if (reading) _bottomOverlay(line, lines.length),
                    if (_atChoices) _choices(stage!.checkpoints),
                    if (_ended) _endLayer(),
                    if (_debug) _debugPanel(stage),
                  ],
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _appBar(EditableStage? stage, List<EditableLine> lines) {
    return AppBar(
      backgroundColor: CanvasSkin.panelRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: CanvasSkin.white,
      centerTitle: false,
      titleSpacing: 18,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('editor.preview.title'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: CanvasSkin.white,
            ),
          ),
          if (stage != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                _stageSubtitle(stage, lines),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: CanvasSkin.white54,
                ),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _editing
              ? t('editor.preview.editDone')
              : t('editor.preview.edit'),
          onPressed: () => setState(() => _editing = !_editing),
          icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
        ),
        IconButton(
          tooltip: t('editor.preview.debug'),
          onPressed: () => setState(() => _debug = !_debug),
          icon: Icon(_debug ? Icons.bug_report : Icons.bug_report_outlined),
        ),
        IconButton(
          tooltip: t('editor.preview.restart'),
          onPressed: () => setState(_reset),
          icon: const Icon(Icons.restart_alt),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  String _stageSubtitle(EditableStage stage, List<EditableLine> lines) {
    final parts = <String>[
      t('editor.stage.number', args: {'n': _stageIndex + 1}),
    ];
    final name = stage.id.isEmpty ? stage.fileName : stage.id;
    if (name.isNotEmpty) parts.add(name);
    if (lines.isNotEmpty) {
      final current = _lineIndex >= lines.length
          ? lines.length
          : _lineIndex + 1;
      parts.add(
        t(
          'editor.preview.debug.progress',
          args: {'n': current, 'total': lines.length},
        ),
      );
    }
    final total = _pack.stages.length;
    if (total > 1) parts.add('${_stageIndex + 1}/$total');
    return parts.join(' · ');
  }

  _Scene _sceneAt(int lineIndex) {
    final stage = _stage;
    var background = '';
    var sprites = const <EditableSprite>[];
    final lines = stage?.lines ?? const <EditableLine>[];
    final last = lineIndex.clamp(0, lines.isEmpty ? 0 : lines.length - 1);
    for (var i = 0; i < lines.length && i <= last; i++) {
      final l = lines[i];
      if (l.background.isNotEmpty) background = l.background;
      if (l.declaresSprites) sprites = l.sprites;
    }
    return _Scene(background: background, sprites: sprites);
  }

  Widget _sceneLayer(_Scene scene) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (scene.background.isNotEmpty)
            editorAssetImage(
              context,
              _pack,
              scene.background,
              fit: BoxFit.cover,
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CanvasSkin.gradientCool,
                    CanvasSkin.gradientViolet,
                    CanvasSkin.gradientDeep,
                  ],
                ),
              ),
            ),
          if (scene.sprites.isNotEmpty)
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final sprite in scene.sprites)
                    if (sprite.asset.isNotEmpty)
                      Align(
                        alignment: Alignment(spriteAlignX(sprite.position), 0.35),
                        child: FractionallySizedBox(
                          heightFactor: 0.62,
                          child: editorAssetImage(
                            context,
                            _pack,
                            sprite.asset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _progressBar(List<EditableLine> lines) {
    final total = lines.length;
    final value = total == 0
        ? 0.0
        : (_lineIndex >= total ? 1.0 : (_lineIndex + 1) / total);
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SizedBox(
        height: 3,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: CanvasSkin.white.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: c.maxWidth * value,
                child: const ColoredBox(color: _accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineImageLayer(EditableLine line) {
    if (line.image.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 178),
        child: Center(
          child: GestureDetector(
            onTap: () => _openMedia(line.image),
            child: editorAssetImage(
              context,
              _pack,
              line.image,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topMediaChips(EditableLine line) {
    final chips = <Widget>[
      if (line.audio.isNotEmpty)
        _mediaChip(line.audio, Icons.audiotrack_outlined),
      if (line.video.isNotEmpty)
        _mediaChip(line.video, Icons.videocam_outlined),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Positioned(
      right: 12,
      top: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _bottomOverlay(EditableLine line, int totalLines) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_dialogue(line, totalLines)],
        ),
      ),
    );
  }

  Widget _mediaChip(String rel, IconData icon) {
    return GestureDetector(
      onTap: () => _openMedia(rel),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: CanvasSkin.black.withValues(alpha: 0.52),
          borderRadius: FiftyRadii.fullRadius,
          border: Border.all(color: CanvasSkin.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: CanvasSkin.accentSoft),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                rel.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: CanvasSkin.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogue(EditableLine line, int totalLines) {
    if (_editing) return _editableDialogue(line, totalLines);
    final speaker = line.speaker.trim();
    final isLast = totalLines > 0 && _lineIndex >= totalLines - 1;
    return _dialogueCard(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (speaker.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: FiftyRadii.fullRadius,
              ),
              child: Text(
                speaker,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: CanvasSkin.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: SingleChildScrollView(
              child: Text(
                line.text,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.65,
                  color: CanvasSkin.white,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 16,
            child: isLast
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      t('editor.preview.tapHint'),
                      style: TextStyle(
                        fontSize: 11,
                        color: CanvasSkin.white.withValues(alpha: 0.36),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _editableDialogue(EditableLine line, int totalLines) {
    return _dialogueCard(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewDialogueEditor(
            key: ObjectKey(line),
            line: line,
            onChanged: _pack.notify,
          ),
          SizedBox(
            height: 16,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                t('editor.preview.editHint'),
                style: TextStyle(
                  fontSize: 11,
                  color: CanvasSkin.white.withValues(alpha: 0.36),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogueCard(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(
            color: CanvasSkin.black.withValues(alpha: 0.68),
            borderRadius: FiftyRadii.xlRadius,
            border: Border.all(color: CanvasSkin.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: CanvasSkin.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _choices(List<EditableCheckpoint> checkpoints) {
    return Positioned.fill(
      child: ColoredBox(
        color: CanvasSkin.black.withValues(alpha: 0.62),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.alt_route_rounded,
                          size: 16,
                          color: _accent,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          t('editor.preview.choices'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CanvasSkin.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (checkpoints.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 26,
                      ),
                      decoration: BoxDecoration(
                        color: CanvasSkin.white.withValues(alpha: 0.06),
                        borderRadius: FiftyRadii.xlRadius,
                        border: Border.all(
                          color: CanvasSkin.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        t('editor.preview.empty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: CanvasSkin.white54),
                      ),
                    )
                  else
                    for (var i = 0; i < checkpoints.length; i++)
                      _choiceButton(checkpoints[i], i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choiceButton(EditableCheckpoint cp, int index) {
    final met = _met(cp.condition);
    final label = cp.text.trim().isEmpty
        ? t('editor.cp.number', args: {'n': index + 1})
        : cp.text;
    final condition = cp.condition.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: met ? 1 : 0.45,
        child: Material(
          color: met
              ? CanvasSkin.white.withValues(alpha: 0.10)
              : CanvasSkin.white.withValues(alpha: 0.05),
          borderRadius: FiftyRadii.xlRadius,
          child: InkWell(
            borderRadius: FiftyRadii.xlRadius,
            onTap: _editing ? null : (met ? () => _choose(cp) : null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: FiftyRadii.xlRadius,
                border: Border.all(
                  color: met
                      ? CanvasSkin.white.withValues(alpha: 0.14)
                      : CanvasSkin.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: met
                          ? _accent.withValues(alpha: 0.22)
                          : CanvasSkin.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: met ? CanvasSkin.accentSoft : CanvasSkin.white38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_editing)
                          _PreviewOptionEditor(
                            key: ObjectKey(cp),
                            cp: cp,
                            fallback: label,
                            onChanged: _pack.notify,
                          )
                        else
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: met ? CanvasSkin.white : CanvasSkin.white70,
                            ),
                          ),
                        if (condition.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              condition,
                              style: TextStyle(
                                fontSize: 11,
                                color: met ? CanvasSkin.white54 : CanvasSkin.white38,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _editing
                        ? Icons.edit_outlined
                        : (met ? Icons.chevron_right : Icons.lock_outline),
                    size: 18,
                    color: met ? CanvasSkin.white70 : CanvasSkin.white38,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _endLayer() {
    return Positioned.fill(
      child: ColoredBox(
        color: CanvasSkin.black.withValues(alpha: 0.72),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.fromLTRB(26, 28, 26, 20),
                decoration: BoxDecoration(
                  color: CanvasSkin.panelHigh,
                  borderRadius: FiftyRadii.xlRadius,
                  border: Border.all(
                    color: CanvasSkin.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        size: 26,
                        color: CanvasSkin.accentSoft,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t('editor.preview.end'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CanvasSkin.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(_reset),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: CanvasSkin.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: FiftyRadii.lgRadius,
                          ),
                        ),
                        child: Text(t('editor.preview.restart')),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: CanvasSkin.white54,
                      ),
                      child: Text(t('common.close')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _debugPanel(EditableStage? stage) {
    final width = (MediaQuery.sizeOf(context).width * 0.72).clamp(220.0, 340.0);
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(
          color: CanvasSkin.panelOverlay,
          elevation: 16,
          shadowColor: CanvasSkin.black,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            left: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bug_report, size: 16, color: _accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          t('editor.preview.debug'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CanvasSkin.white,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _debug = false),
                        borderRadius: FiftyRadii.lgRadius,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: CanvasSkin.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _debugSection(
                    t('editor.preview.debug.stage'),
                    [
                      if (stage == null)
                        _debugLine(t('editor.preview.debug.empty'))
                      else ...[
                        _debugLine(
                          '${t('editor.stage.number', args: {'n': _stageIndex + 1})}'
                          ' · ${stage.id.isEmpty ? stage.fileName : stage.id}',
                        ),
                        _debugLine(
                          t(
                            'editor.preview.debug.progress',
                            args: {
                              'n': (_lineIndex + 1).clamp(
                                1,
                                stage.lines.isEmpty ? 1 : stage.lines.length,
                              ),
                              'total': stage.lines.length,
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  _debugSection(
                    t('editor.preview.debug.items'),
                    [
                      if (_pack.items.isEmpty)
                        _debugLine(t('editor.preview.debug.empty'))
                      else
                        for (final item in _pack.items)
                          _debugLine(
                            '${item.name.isEmpty ? item.id : item.name}'
                            ' = ${_values[item.id] ?? item.initial}',
                          ),
                    ],
                  ),
                  _debugSection(
                    t('editor.preview.debug.saves'),
                    _savesRows(),
                  ),
                  _debugSection(
                    t('editor.preview.debug.branches'),
                    [
                      if (stage == null || stage.checkpoints.isEmpty)
                        _debugLine(t('editor.preview.debug.empty'))
                      else
                        for (var i = 0; i < stage.checkpoints.length; i++)
                          _branchDebugRow(stage.checkpoints[i], i),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _savesRows() {
    final rows = <Widget>[];
    for (final item in _pack.items) {
      final value = _values[item.id] ?? item.initial;
      if (value == item.initial) continue;
      final delta = value - item.initial;
      rows.add(
        _debugLine(
          '${item.name.isEmpty ? item.id : item.name}'
          ' ${delta > 0 ? '+' : ''}$delta',
        ),
      );
    }
    if (rows.isEmpty) {
      rows.add(_debugLine(t('editor.preview.debug.empty')));
    }
    return rows;
  }

  Widget _debugSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CanvasSkin.white38,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _debugLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.45,
          color: CanvasSkin.white70,
        ),
      ),
    );
  }

  Widget _branchDebugRow(EditableCheckpoint cp, int index) {
    final met = _met(cp.condition);
    final label = cp.text.trim().isEmpty
        ? t('editor.cp.number', args: {'n': index + 1})
        : cp.text;
    final condition = cp.condition.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: CanvasSkin.white.withValues(alpha: 0.04),
        borderRadius: FiftyRadii.mdRadius,
        border: Border.all(color: CanvasSkin.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: CanvasSkin.white),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: met
                      ? CanvasSkin.success
                      : CanvasSkin.white.withValues(alpha: 0.12),
                  borderRadius: FiftyRadii.mdRadius,
                ),
                child: Text(
                  met
                      ? t('editor.preview.debug.met')
                      : t('editor.preview.debug.unmet'),
                  style: const TextStyle(fontSize: 10, color: CanvasSkin.white),
                ),
              ),
            ],
          ),
          if (condition.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                condition,
                style: const TextStyle(fontSize: 11, color: CanvasSkin.white54),
              ),
            ),
          if (!met)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _conditionReason(cp.condition),
                style: const TextStyle(fontSize: 11, color: CanvasSkin.accentMuted),
              ),
            ),
        ],
      ),
    );
  }

  String _conditionReason(String condition) {
    final rows = EditableConditionRow.parse(condition);
    if (rows.isEmpty) return '';
    for (final row in rows) {
      if (row.isRaw) {
        return t('editor.preview.debug.raw', args: {'text': row.item.trim()});
      }
      final value = _values[row.item] ?? 0;
      final ok = switch (row.op) {
        '>=' => value >= row.value,
        '<=' => value <= row.value,
        '==' => value == row.value,
        '!=' => value != row.value,
        '>' => value > row.value,
        '<' => value < row.value,
        _ => false,
      };
      if (!ok) {
        return '${row.item} ${row.op} ${row.value} · '
            '${t('editor.preview.debug.now', args: {'value': value})}';
      }
    }
    return '';
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0, 0.1),
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, CanvasSkin.deep90],
          stops: [0.0, 0.72],
        ),
      ),
    );
  }
}

class _Scene {
  final String background;
  final List<EditableSprite> sprites;

  const _Scene({
    required this.background,
    required this.sprites,
  });
}

class _PreviewDialogueEditor extends StatefulWidget {
  final EditableLine line;
  final VoidCallback onChanged;

  const _PreviewDialogueEditor({
    super.key,
    required this.line,
    required this.onChanged,
  });

  @override
  State<_PreviewDialogueEditor> createState() => _PreviewDialogueEditorState();
}

class _PreviewDialogueEditorState extends State<_PreviewDialogueEditor> {
  late final TextEditingController _speaker = TextEditingController(
    text: widget.line.speaker,
  );
  late final TextEditingController _text = TextEditingController(
    text: widget.line.text,
  );
  final FocusNode _speakerFocus = FocusNode();
  final FocusNode _textFocus = FocusNode();

  @override
  void didUpdateWidget(covariant _PreviewDialogueEditor oldWidget) {
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
    final hint = CanvasSkin.white.withValues(alpha: 0.35);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: FiftyRadii.fullRadius,
          ),
          child: SizedBox(
            width: 150,
            child: TextField(
              controller: _speaker,
              focusNode: _speakerFocus,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                color: CanvasSkin.white,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: CanvasSkin.white,
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                border: InputBorder.none,
                hintText: t('editor.line.speaker'),
                hintStyle: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: CanvasSkin.white.withValues(alpha: 0.62),
                ),
              ),
              onChanged: (v) {
                widget.line.speaker = v;
                widget.line.type = v.trim().isEmpty ? 'narration' : 'dialogue';
                widget.onChanged();
              },
            ),
          ),
        ),
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: FiftyRadii.mdRadius,
            border: Border.all(color: CanvasSkin.white.withValues(alpha: 0.20)),
          ),
          child: SingleChildScrollView(
            child: TextField(
              controller: _text,
              focusNode: _textFocus,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              style: const TextStyle(
                fontSize: 17,
                height: 1.65,
                color: CanvasSkin.white,
              ),
              cursorColor: _accent,
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                border: InputBorder.none,
                hintText: t('editor.line.text'),
                hintStyle: TextStyle(fontSize: 17, height: 1.65, color: hint),
              ),
              onChanged: (v) {
                widget.line.text = v;
                widget.onChanged();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewOptionEditor extends StatefulWidget {
  final EditableCheckpoint cp;
  final String fallback;
  final VoidCallback onChanged;

  const _PreviewOptionEditor({
    super.key,
    required this.cp,
    required this.fallback,
    required this.onChanged,
  });

  @override
  State<_PreviewOptionEditor> createState() => _PreviewOptionEditorState();
}

class _PreviewOptionEditorState extends State<_PreviewOptionEditor> {
  late final TextEditingController _c = TextEditingController(
    text: widget.cp.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _PreviewOptionEditor oldWidget) {
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
    return TextField(
      controller: _c,
      focusNode: _focus,
      style: const TextStyle(fontSize: 15, height: 1.35, color: CanvasSkin.white),
      cursorColor: _accent,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.fallback,
        hintStyle: TextStyle(
          fontSize: 15,
          height: 1.35,
          color: CanvasSkin.white.withValues(alpha: 0.35),
        ),
      ),
      onChanged: (v) {
        widget.cp.text = v;
        widget.onChanged();
      },
    );
  }
}
