
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/engine/model/scene.dart';
import 'package:larg_editor/engine/model/stage.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/model/check_ai_config.dart';
import 'package:larg_editor/page/editor/editor_fields.dart';
import 'package:larg_editor/page/editor/editor_media.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/page/editor/media_library_page.dart';
import 'package:larg_editor/service/file_pick_service.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/story_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

const double _gap = 10;
final double _cardRadius = FiftyRadii.lg;

const TextStyle _sectionStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
);

TextStyle _labelStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

TextStyle _captionStyle(BuildContext context) => TextStyle(
  fontSize: 12,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

class StageTab extends StatefulWidget {
  final EditablePack pack;
  const StageTab({super.key, required this.pack});

  @override
  State<StageTab> createState() => _StageTabState();
}

class _StageTabState extends State<StageTab> {
  int _selected = 0;

  EditablePack get pack => widget.pack;

  @override
  Widget build(BuildContext context) {
    if (_selected >= pack.stages.length) {
      _selected = pack.stages.isEmpty ? 0 : pack.stages.length - 1;
    }
    return Column(
      children: [
        _stageSelector(),
        if (pack.stages.isNotEmpty)
          _StageNameField(
            key: ObjectKey(pack.stages[_selected]),
            pack: pack,
            stage: pack.stages[_selected],
          ),
        Expanded(
          child: pack.stages.isEmpty
              ? Center(
                  child: Text(
                    t('editor.empty'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              : _stageForm(pack.stages[_selected]),
        ),
      ],
    );
  }

  Widget _stageSelector() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              avatar: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text(t('editor.stage.manage')),
              onPressed: _showStageManager,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 12),
              itemCount: pack.stages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Center(
                child: ChoiceChip(
                  selected: i == _selected,
                  label: Text(t('editor.stage.number', args: {'n': i + 1})),
                  onSelected: (_) => setState(() => _selected = i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStageManager() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _StageManagerDialog(
        pack: pack,
        selected: _selected,
        onSelect: (i) => setState(() => _selected = i),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _stageForm(EditableStage stage) {
    final scenes = sceneTimeline(_previewStage(stage));
    final number = pack.stages.indexOf(stage) + 1;
    return ListView(
      key: ObjectKey(stage),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      children: [
        _SectionHeader(
          icon: Icons.movie_outlined,
          title: t('editor.stage.number', args: {'n': number}),
        ),
        for (var i = 0; i < stage.lines.length; i++)
          _LineCard(
            key: ObjectKey(stage.lines[i]),
            stage: stage,
            line: stage.lines[i],
            index: i,
            scene: scenes[i],
            pack: pack,
            onChanged: pack.notify,
            onDelete: () {
              stage.lines.removeAt(i);
              pack.notify();
            },
          ),
        _AddTile(
          label: t('editor.stage.line.add'),
          onPressed: () {
            final prev = stage.lines.isEmpty ? null : stage.lines.last;
            final line = EditableLine.inheritFrom(prev);
            line.id = pack.nextLineId(stage);
            line.open = true;
            stage.lines.add(line);
            pack.notify();
          },
        ),
        _SectionHeader(
          icon: Icons.alt_route,
          title: t('editor.stage.checkpoints'),
          meta: '${stage.checkpoints.length}',
        ),
        for (var i = 0; i < stage.checkpoints.length; i++)
          _CheckpointCard(
            key: ObjectKey(stage.checkpoints[i]),
            index: i,
            cp: stage.checkpoints[i],
            pack: pack,
            targets: pack.stageTargets,
            onChanged: pack.notify,
            onDelete: () {
              final old = stage.checkpoints[i].check;
              stage.checkpoints.removeAt(i);
              if (old.isNotEmpty) pack.pruneCheck(old);
              pack.notify();
            },
          ),
        _AddTile(
          label: t('editor.stage.cp.add'),
          onPressed: () {
            stage.checkpoints.add(EditableCheckpoint());
            pack.notify();
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? meta;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(child: Text(title, style: _sectionStyle)),
          if (meta != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                meta!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _captionStyle(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget? header;
  final Widget child;
  final VoidCallback? onDelete;

  const _Panel({
    required this.child,
    this.header,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasHeader = header != null || onDelete != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: _gap),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
              child: Row(
                children: [
                  Expanded(child: header ?? const SizedBox.shrink()),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      tooltip: t('common.delete'),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 19,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, hasHeader ? 4 : 12, 12, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _StageNameField extends StatefulWidget {
  final EditablePack pack;
  final EditableStage stage;

  const _StageNameField({
    super.key,
    required this.pack,
    required this.stage,
  });

  @override
  State<_StageNameField> createState() => _StageNameFieldState();
}

class _StageNameFieldState extends State<_StageNameField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.stage.id,
  );
  final FocusNode _focus = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      setState(() {
        _invalid = false;
        _ctrl.text = widget.stage.id;
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final accepted = widget.pack.renameStage(widget.stage, v);
    final invalid = !accepted && v.trim().isNotEmpty;
    if (invalid != _invalid) setState(() => _invalid = invalid);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: _onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          labelText: t('editor.stage.name'),
          errorText: _invalid ? t('editor.stage.name.dup') : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _LineIdField extends StatefulWidget {
  final EditableStage stage;
  final EditableLine line;
  final EditablePack pack;

  const _LineIdField({
    required this.stage,
    required this.line,
    required this.pack,
  });

  @override
  State<_LineIdField> createState() => _LineIdFieldState();
}

class _LineIdFieldState extends State<_LineIdField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.line.id,
  );
  final FocusNode _focus = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      setState(() {
        _invalid = false;
        _ctrl.text = widget.line.id;
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final accepted = widget.pack.renameLineId(widget.stage, widget.line, v);
    final invalid = !accepted && v.trim().isNotEmpty;
    if (invalid != _invalid) setState(() => _invalid = invalid);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      onChanged: _onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: t('editor.line.id'),
        errorText: _invalid ? t('editor.line.id.dup') : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _StageManagerDialog extends StatefulWidget {
  final EditablePack pack;
  final int selected;
  final ValueChanged<int> onSelect;

  const _StageManagerDialog({
    required this.pack,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_StageManagerDialog> createState() => _StageManagerDialogState();
}

class _StageManagerDialogState extends State<_StageManagerDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  bool _jiggle = false;
  late int _selected = widget.selected;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _select(int index) {
    _selected = index;
    widget.onSelect(index);
  }

  void _enterJiggle() {
    if (_jiggle) return;
    setState(() => _jiggle = true);
    _shake.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ListenableBuilder(
      listenable: widget.pack,
      builder: (context, _) {
        final stages = widget.pack.stages;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: SizedBox(
            width: (size.width - 48).clamp(280.0, 460.0),
            height: (size.height - 120).clamp(320.0, 520.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('editor.stage.manage'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_jiggle)
                        TextButton(
                          onPressed: () {
                            _shake.stop();
                            setState(() => _jiggle = false);
                          },
                          child: Text(t('editor.stage.manage.done')),
                        ),
                    ],
                  ),
                  Text(
                    _jiggle
                        ? t('editor.stage.manage.jiggleHint')
                        : t('editor.stage.manage.hint'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(right: 8),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 150,
                            mainAxisExtent: 92,
                            crossAxisSpacing: _gap,
                            mainAxisSpacing: _gap,
                          ),
                      itemCount: stages.length + 1,
                      itemBuilder: (context, i) => i >= stages.length
                          ? _addTile(context)
                          : _tile(context, i, stages[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, int idx, EditableStage stage) {
    final scheme = Theme.of(context).colorScheme;
    final selected = idx == _selected;
    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : null,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              borderRadius: BorderRadius.circular(_cardRadius),
              onTap: () {
                if (_jiggle) return;
                _select(idx);
                Navigator.pop(context);
              },
              onLongPress: _enterJiggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t('editor.stage.number', args: {'n': idx + 1}),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (stage.id.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          stage.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_jiggle)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: CanvasSkin.grey400,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _delete(idx),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: CanvasSkin.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (_jiggle) {
      tile = RotationTransition(
        turns: Tween<double>(begin: -0.005, end: 0.005).animate(_shake),
        child: tile,
      );
    }
    return tile;
  }

  Widget _addTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        widget.pack.addStage();
        setState(() => _select(widget.pack.stages.length - 1));
      },
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(Icons.add, size: 28, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Future<void> _delete(int idx) async {
    final stages = widget.pack.stages;
    if (idx >= stages.length) return;
    final v = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('common.notice')),
        content: Text(t('editor.del.confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('common.confirm')),
          ),
        ],
      ),
    );
    if (v != true || !mounted) return;
    widget.pack.removeStage(stages[idx]);
    if (_selected >= widget.pack.stages.length) {
      setState(
        () => _select(
          widget.pack.stages.isEmpty ? 0 : widget.pack.stages.length - 1,
        ),
      );
    } else if (idx < _selected) {
      setState(() => _select(_selected - 1));
    }
  }
}

class _AddTile extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _AddTile({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: _gap),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          minimumSize: const Size.fromHeight(44),
        ),
      ),
    );
  }
}

class _LineCard extends StatefulWidget {
  final EditableStage stage;
  final EditableLine line;
  final int index;
  final SceneState scene;
  final EditablePack pack;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _LineCard({
    super.key,
    required this.stage,
    required this.line,
    required this.index,
    required this.scene,
    required this.pack,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  EditableLine get line => widget.line;

  bool get _open => line.open;

  void _toggle() {
    setState(() => line.open = !line.open);
  }

  String get _hint {
    final speaker = line.speaker.trim();
    return speaker.isEmpty
        ? t('editor.line.narration')
        : t('editor.line.dialogue');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: _gap),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(
          color: _open
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _open
                    ? t('editor.line.collapse')
                    : t('editor.line.edit'),
                onPressed: _toggle,
                icon: AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: _LineTextEditor(
                    key: ObjectKey(line),
                    line: line,
                    open: _open,
                    hint: _hint,
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: t('common.delete'),
                onPressed: widget.onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (_open) ...[
            Container(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SceneBand(
                    pack: widget.pack,
                    line: line,
                    scene: widget.scene,
                    onChanged: widget.onChanged,
                  ),
                  FieldGrid(
                    children: [
                      _LineIdField(
                        stage: widget.stage,
                        line: line,
                        pack: widget.pack,
                      ),
                      LabeledTextField(
                        label: t('editor.line.speaker'),
                        initial: line.speaker,
                        onChanged: (v) {
                          line.speaker = v;
                          line.type = v.trim().isEmpty
                              ? 'narration'
                              : 'dialogue';
                          widget.onChanged();
                        },
                      ),
                    ],
                  ),
                  _MediaRow(
                    line: line,
                    pack: widget.pack,
                    onChanged: widget.onChanged,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LineTextEditor extends StatefulWidget {
  final EditableLine line;
  final bool open;
  final String hint;
  final VoidCallback onChanged;

  const _LineTextEditor({
    super.key,
    required this.line,
    required this.open,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_LineTextEditor> createState() => _LineTextEditorState();
}

class _LineTextEditorState extends State<_LineTextEditor> {
  late final TextEditingController _c = TextEditingController(
    text: widget.line.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _LineTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _c.text != widget.line.text) {
      _c.text = widget.line.text;
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
      maxLines: widget.open ? 3 : 1,
      style: const TextStyle(fontSize: 13.5, height: 1.66),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: widget.hint,
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      onChanged: (v) {
        widget.line.text = v;
        widget.onChanged();
      },
    );
  }
}

class _MediaRow extends StatelessWidget {
  final EditableLine line;
  final EditablePack pack;
  final VoidCallback onChanged;
  const _MediaRow({
    required this.line,
    required this.pack,
    required this.onChanged,
  });

  void _apply(String rel) {
    if (isAudioPath(rel)) {
      line.audio = rel;
    } else if (isVideoPath(rel)) {
      line.video = rel;
    } else {
      line.image = rel;
    }
  }

  Future<void> _add(BuildContext context) async {
    final rel = await MediaLibraryPage.pick(context, pack);
    if (rel == null) return;
    _apply(rel);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return TileBlock(
      label: t('editor.line.media'),
      minTile: 56,
      maxTile: 76,
      tiles: (w, h) => [
        if (line.image.trim().isNotEmpty)
          SlotTile(
            pack: pack,
            rel: line.image,
            width: w,
            height: h,
            onRemove: () {
              line.image = '';
              onChanged();
            },
          ),
        if (line.audio.trim().isNotEmpty)
          SlotTile(
            pack: pack,
            rel: line.audio,
            width: w,
            height: h,
            onRemove: () {
              line.audio = '';
              onChanged();
            },
          ),
        if (line.video.trim().isNotEmpty)
          SlotTile(
            pack: pack,
            rel: line.video,
            width: w,
            height: h,
            onRemove: () {
              line.video = '';
              onChanged();
            },
          ),
        SlotAdd(width: w, height: h, onTap: () => _add(context)),
      ],
    );
  }
}

Stage _previewStage(EditableStage stage) => Stage(
  id: stage.id,
  order: 0,
  sourceFile: stage.fileName,
  lines: [
    for (final line in stage.lines)
      StageLine(
        id: line.id,
        type: line.type,
        text: line.text,
        background: line.background.isEmpty ? null : line.background,
        sprites: [
          for (final sprite in line.sprites)
            StageSprite(asset: sprite.asset, position: sprite.position),
        ],
        declaresSprites: line.declaresSprites,
      ),
  ],
  checkpoints: const [],
);

class _SceneBand extends StatelessWidget {
  final EditableLine line;
  final EditablePack pack;
  final SceneState scene;
  final VoidCallback onChanged;

  const _SceneBand({
    required this.line,
    required this.pack,
    required this.scene,
    required this.onChanged,
  });

  static const List<String> _positions = ['left', 'center', 'right'];

  Future<void> _pickBackground(BuildContext context) async {
    final rel = await MediaLibraryPage.pick(context, pack, PickerMedia.image);
    if (rel == null) return;
    line.background = rel;
    onChanged();
  }

  Future<void> _addSprite(BuildContext context) async {
    final rel = await MediaLibraryPage.pick(context, pack, PickerMedia.image);
    if (rel == null) return;
    line.sprites.add(EditableSprite(asset: rel));
    line.declaresSprites = true;
    onChanged();
  }

  void _toggleDeclared() {
    line.sprites.clear();
    line.declaresSprites = !line.declaresSprites;
    onChanged();
  }

  String _positionLabel(String v) => switch (v) {
    'left' => t('editor.line.spriteLeft'),
    'right' => t('editor.line.spriteRight'),
    _ => t('editor.line.spriteCenter'),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = line.background.trim();
    return FieldGrid(
      children: [
        TileBlock(
          label: t('editor.line.background'),
          minTile: 168,
          maxTile: 240,
          aspect: 16 / 9,
          action: IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: t('editor.scene.preview'),
            onPressed: () => _showScenePreview(context, pack, scene),
            icon: Icon(
              Icons.visibility_outlined,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
          tiles: (w, h) => [
            if (background.isEmpty)
              SlotAdd(
                width: w,
                height: h,
                onTap: () => _pickBackground(context),
                icon: Icons.add_photo_alternate_outlined,
              )
            else
              SlotTile(
                pack: pack,
                rel: background,
                width: w,
                height: h,
                onRemove: () {
                  line.background = '';
                  onChanged();
                },
              ),
          ],
        ),
        TileBlock(
          label: t('editor.line.sprite'),
          minTile: 56,
          maxTile: 76,
          action: line.declaresSprites
              ? TextButton(
                  onPressed: _toggleDeclared,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    t('editor.sprite.restore'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                )
              : null,
          tiles: (w, h) => [
            for (final sprite in line.sprites)
              SlotTile(
                pack: pack,
                rel: sprite.asset,
                width: w,
                height: h,
                corner: _PositionChip(
                  label: _positionLabel(sprite.position),
                  onTap: () {
                    final i = _positions.indexOf(sprite.position);
                    sprite.position = _positions[(i + 1) % _positions.length];
                    onChanged();
                  },
                ),
                onRemove: () {
                  line.sprites.remove(sprite);
                  onChanged();
                },
              ),
            SlotAdd(width: w, height: h, onTap: () => _addSprite(context)),
          ],
        ),
      ],
    );
  }
}

class _PositionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PositionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(
          color: CanvasSkin.black54,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, color: CanvasSkin.white),
        ),
      ),
    );
  }
}

Future<void> _showScenePreview(
  BuildContext context,
  EditablePack pack,
  SceneState scene,
) {
  return showDialog<void>(
    context: context,
    barrierColor: CanvasSkin.black87,
    builder: (ctx) => Dialog(
      backgroundColor: CanvasSkin.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (scene.background.isNotEmpty)
                  editorAssetImage(ctx, pack, scene.background)
                else
                  const ColoredBox(color: StorySkin.panel),
                for (final sprite in scene.sprites)
                  Align(
                    alignment: Alignment(
                      spriteAlignX(sprite.position),
                      0.35,
                    ),
                    child: FractionallySizedBox(
                      heightFactor: 0.62,
                      child: editorAssetImage(
                        ctx,
                        pack,
                        sprite.asset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: CanvasSkin.white),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GrantField extends StatelessWidget {
  final EditablePack pack;
  final Map<String, int> value;
  final ValueChanged<Map<String, int>> onChanged;

  const _GrantField({
    required this.pack,
    required this.value,
    required this.onChanged,
  });

  List<String> get _ids {
    final known = [for (final item in pack.items) item.id];
    return [
      ...known,
      for (final id in value.keys)
        if (!known.contains(id)) id,
    ];
  }

  String _nameOf(String id) {
    for (final item in pack.items) {
      if (item.id == id) return item.name.isEmpty ? id : item.name;
    }
    return id;
  }

  void _set(String id, int amount) {
    final next = Map<String, int>.from(value);
    next[id] = amount;
    onChanged(Map.unmodifiable(next));
  }

  void _remove(String id) {
    final next = Map<String, int>.from(value)..remove(id);
    onChanged(Map.unmodifiable(next));
  }

  void _move(String from, String to) {
    if (from == to) return;
    final next = Map<String, int>.from(value);
    final amount = next.remove(from) ?? 0;
    next[to] = amount;
    onChanged(Map.unmodifiable(next));
  }

  void _add() {
    final free = _ids.firstWhere(
      (id) => !value.containsKey(id),
      orElse: () => '',
    );
    if (free.isEmpty) return;
    _set(free, 1);
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    final rows = [
      for (final id in ids)
        if (value.containsKey(id)) id,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldHeader(
          label: t('editor.cp.grant'),
          help: t('editor.cp.grant.help'),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              ids.isEmpty
                  ? t('editor.cp.grant.noItem')
                  : t('editor.cp.grant.empty'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        for (final id in rows)
          Padding(
            key: ValueKey('grant-$id'),
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: LabeledDropdown<String>(
                    label: t('editor.cp.grant.item'),
                    value: id,
                    items: ids,
                    labelOf: _nameOf,
                    onChanged: (v) {
                      if (v != null) _move(id, v);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 84,
                  child: LabeledIntField(
                    label: t('editor.cp.grant.value'),
                    initial: value[id] ?? 0,
                    allowNegative: true,
                    onChanged: (v) => _set(id, v),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: t('common.delete'),
                  onPressed: () => _remove(id),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        _ChipAdd(
          label: t('editor.cp.grant.add'),
          onPressed: rows.length >= ids.length || ids.isEmpty ? null : _add,
        ),
      ],
    );
  }
}

const List<String> _checkTypes = kCheckTypes;

String _checkTypeLabel(String v) {
  switch (v) {
    case 'photo_submit':
      return t('editor.check.type.photo_submit');
    case 'media_submit':
      return t('editor.check.type.media_submit');
    case 'text_answer':
      return t('editor.check.type.text_answer');
    case 'condition':
      return t('editor.check.type.condition');
    default:
      return v;
  }
}

class _CheckpointCard extends StatelessWidget {
  final int index;
  final EditableCheckpoint cp;
  final EditablePack pack;
  final List<String> targets;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _CheckpointCard({
    super.key,
    required this.index,
    required this.cp,
    required this.pack,
    required this.targets,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nextItems = <String>['', ...targets];
    final enabled = cp.check.isNotEmpty;
    final check = enabled ? pack.findCheck(cp.check) : null;
    final scheme = Theme.of(context).colorScheme;
    return _Panel(
      header: Row(
        children: [
          Icon(Icons.alt_route, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            t('editor.cp.number', args: {'n': index + 1}),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      onDelete: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledTextField(
            label: t('editor.cp.text'),
            initial: cp.text,
            onChanged: (v) {
              cp.text = v;
              onChanged();
            },
          ),
          FieldGrid(
            children: [
              LabeledDropdown<String>(
                label: t('editor.cp.next'),
                value: cp.next,
                items: nextItems,
                labelOf: (v) {
                  if (v.isEmpty) return t('editor.cp.next.end');
                  final n = pack.stageNumber(v);
                  return n > 0 ? t('editor.stage.number', args: {'n': n}) : v;
                },
                onChanged: (v) {
                  cp.next = v ?? '';
                  onChanged();
                },
              ),
              LabeledIntField(
                label: t('editor.cp.reward'),
                initial: cp.reward,
                onChanged: (v) {
                  cp.reward = v;
                  onChanged();
                },
              ),
            ],
          ),
          _ConditionField(cp: cp, pack: pack, onChanged: onChanged),
          _GrantField(
            pack: pack,
            value: cp.grant,
            onChanged: (v) {
              cp.grant = v;
              onChanged();
            },
          ),
          const Divider(height: 24),
          Row(
            children: [
              Checkbox(
                value: enabled,
                visualDensity: VisualDensity.compact,
                onChanged: (v) {
                  if (v == true) {
                    final id = pack.newCheckId();
                    cp.check = id;
                    pack.ensureCheck(id);
                  } else {
                    final old = cp.check;
                    cp.check = '';
                    if (old.isNotEmpty) pack.pruneCheck(old);
                  }
                  onChanged();
                },
              ),
              Expanded(
                child: Text(
                  t('editor.cp.check.enable'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          if (enabled && check != null)
            FieldGrid(
              children: [
                LabeledDropdown<String>(
                  label: t('editor.check.type'),
                  value: check.type,
                  items: {
                    ..._checkTypes,
                    if (check.type.isNotEmpty && !_checkTypes.contains(check.type))
                      check.type,
                  }.toList(),
                  labelOf: _checkTypeLabel,
                  onChanged: (v) {
                    check.type = v ?? _checkTypes.first;
                    onChanged();
                  },
                ),
                LabeledDropdown<String>(
                  label: t('editor.check.verify'),
                  value: check.verify,
                  items: {
                    'local',
                    if (check.verify.isNotEmpty && check.verify != 'local')
                      check.verify,
                  }.toList(),
                  labelOf: (v) => switch (v) {
                    'local' => t('editor.check.verify.local'),
                    'server' => t('editor.check.verify.server'),
                    _ => v,
                  },
                  onChanged: (v) {
                    check.verify = v ?? 'local';
                    onChanged();
                  },
                ),
              ],
            ),
          if (enabled && check != null && check.type == 'condition')
            _CheckConditionField(
              key: ValueKey('checkCondition-${check.fileName}'),
              check: check,
              pack: pack,
              onChanged: onChanged,
            ),
          if (enabled && check != null && check.type == 'condition')
            LabeledTextField(
              key: ValueKey('failText-${check.fileName}'),
              label: t('editor.check.failText'),
              initial: (check.params['fail_text'] ?? '').toString(),
              dense: true,
              maxLines: 2,
              onChanged: (v) {
                final value = v.trim();
                if (value.isEmpty) {
                  check.params.remove('fail_text');
                } else {
                  check.params['fail_text'] = value;
                }
                onChanged();
              },
            ),
          if (enabled &&
              check != null &&
              check.type != 'condition' &&
              (check.type == 'text_answer' ||
                  check.params.containsKey('answer')))
            LabeledTextField(
              key: ValueKey('answer-${check.fileName}'),
              label: t('editor.check.answer'),
              initial: (check.params['answer'] ?? '').toString(),
              dense: true,
              onChanged: (v) {
                check.params['answer'] = v;
                onChanged();
              },
            ),
          if (enabled &&
              check != null &&
              (check.type == 'photo_submit' || check.type == 'media_submit'))
            _SubmitQuotaField(
              key: ValueKey('submitQuota-${check.fileName}'),
              check: check,
              onChanged: onChanged,
            ),
          if (enabled && check != null)
            _AiJudgeField(
              key: ValueKey('aiJudge-${check.fileName}'),
              check: check,
              onChanged: onChanged,
            ),
          if (enabled && check != null)
            _AiSendField(
              key: ValueKey('aiSend-${check.fileName}'),
              check: check,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _FieldHeader extends StatelessWidget {
  final String label;
  final String help;

  const _FieldHeader({required this.label, required this.help});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Flexible(child: Text(label, style: _labelStyle(context))),
          HelpDot(message: help, title: label),
        ],
      ),
    );
  }
}

class _ChipAdd extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _ChipAdd({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add, size: 15),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.primary,
            side: BorderSide(color: scheme.outlineVariant),
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

class _CheckConditionField extends StatefulWidget {
  final EditableCheck check;
  final EditablePack pack;
  final VoidCallback onChanged;

  const _CheckConditionField({
    super.key,
    required this.check,
    required this.pack,
    required this.onChanged,
  });

  @override
  State<_CheckConditionField> createState() => _CheckConditionFieldState();
}

class _CheckConditionFieldState extends State<_CheckConditionField> {
  List<EditableConditionRow> _rows = [];
  String _written = '';

  List<String> get _ids => [for (final item in widget.pack.items) item.id];

  String get _raw => (widget.check.params['condition'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load(_raw);
  }

  @override
  void didUpdateWidget(covariant _CheckConditionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_raw != _written) _load(_raw);
  }

  void _load(String raw) {
    _rows = EditableConditionRow.parse(raw);
    _written = raw;
    final ids = _ids;
    if (ids.isEmpty) return;
    for (final row in _rows) {
      if (row.item.isEmpty) row.item = ids.first;
    }
  }

  String _nameOf(String id) {
    for (final item in widget.pack.items) {
      if (item.id == id) return item.name.isEmpty ? id : item.name;
    }
    return id;
  }

  void _sync() {
    final serialized = _rows.isEmpty
        ? ''
        : [
            for (final row in _rows) row.serialize(),
          ].join(' && ');
    if (_rows.isEmpty) {
      widget.check.params.remove('condition');
    } else {
      widget.check.params['condition'] = serialized;
    }
    _written = serialized;
    widget.onChanged();
    setState(() {});
  }

  void _add() {
    final ids = _ids;
    if (ids.isEmpty) return;
    _rows.add(EditableConditionRow(item: ids.first));
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldHeader(
          label: t('editor.check.type.condition'),
          help: t('editor.check.condition.help'),
        ),
        if (ids.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              t('editor.check.condition.noItem'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        if (ids.isNotEmpty && _rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              t('editor.cp.condition.empty'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        _ConditionRows(
          rows: _rows,
          ids: ids,
          nameOf: _nameOf,
          onChanged: _sync,
          onRemove: (row) {
            _rows.remove(row);
            _sync();
          },
          deleteTooltip: t('common.delete'),
          allowNegative: true,
        ),
        _ChipAdd(
          label: t('editor.check.condition.add'),
          onPressed: ids.isEmpty ? null : _add,
        ),
      ],
    );
  }
}

class _ConditionRows extends StatelessWidget {
  final List<EditableConditionRow> rows;
  final List<String> ids;
  final String Function(String) nameOf;
  final VoidCallback onChanged;
  final ValueChanged<EditableConditionRow> onRemove;
  final String deleteTooltip;
  final bool allowNegative;

  const _ConditionRows({
    required this.rows,
    required this.ids,
    required this.nameOf,
    required this.onChanged,
    required this.onRemove,
    required this.deleteTooltip,
    this.allowNegative = false,
  });

  static const List<String> ops = ['>=', '>', '==', '<=', '<', '!='];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          KeyedSubtree(
            key: ObjectKey(row),
            child: row.isRaw ? _raw(context, row) : _term(row),
          ),
      ],
    );
  }

  Widget _raw(BuildContext context, EditableConditionRow row) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
          ),
          TextButton(
            onPressed: () {
              row.op = ops.first;
              row.value = 1;
              onChanged();
            },
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              t('editor.cp.condition.convert'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          _deleteButton(row),
        ],
      ),
    );
  }

  Widget _term(EditableConditionRow row) {
    final list = ids.contains(row.item) || row.item.isEmpty
        ? ids
        : [row.item, ...ids];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: LabeledDropdown<String>(
              label: t('editor.cp.condition.item'),
              value: row.item,
              items: list,
              labelOf: nameOf,
              onChanged: (v) {
                row.item = v ?? '';
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: LabeledDropdown<String>(
              label: t('editor.cp.condition.op'),
              value: ops.contains(row.op) ? row.op : ops.first,
              items: ops,
              labelOf: (v) => v,
              onChanged: (v) {
                row.op = v ?? '>=';
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 76,
            child: LabeledIntField(
              label: t('editor.cp.condition.value'),
              initial: row.value,
              allowNegative: allowNegative,
              onChanged: (v) {
                row.value = v;
                onChanged();
              },
            ),
          ),
          _deleteButton(row),
        ],
      ),
    );
  }

  Widget _deleteButton(EditableConditionRow row) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: deleteTooltip,
      onPressed: () => onRemove(row),
      icon: const Icon(Icons.close, size: 18),
    );
  }
}

class _ConditionField extends StatefulWidget {
  final EditableCheckpoint cp;
  final EditablePack pack;
  final VoidCallback onChanged;

  const _ConditionField({
    required this.cp,
    required this.pack,
    required this.onChanged,
  });

  @override
  State<_ConditionField> createState() => _ConditionFieldState();
}

class _ConditionFieldState extends State<_ConditionField> {
  late final List<EditableConditionRow> _rows = EditableConditionRow.parse(
    widget.cp.condition,
  );


  void _sync() {
    widget.cp.setConditionRows(_rows);
    widget.onChanged();
    setState(() {});
  }

  String _itemLabel(String id) {
    for (final item in widget.pack.items) {
      if (item.id == id) return item.name.isEmpty ? id : item.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final ids = [for (final i in widget.pack.items) i.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldHeader(
          label: t('editor.cp.condition'),
          help: t('editor.cp.condition.help'),
        ),
        if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              ids.isEmpty
                  ? t('editor.cp.condition.noItem')
                  : t('editor.cp.condition.empty'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        _ConditionRows(
          rows: _rows,
          ids: ids,
          nameOf: _itemLabel,
          onChanged: _sync,
          onRemove: (row) {
            _rows.remove(row);
            _sync();
          },
          deleteTooltip: t('common.delete'),
        ),
        _ChipAdd(
          label: t('editor.cp.condition.add'),
          onPressed: ids.isEmpty ? null : _add,
        ),
      ],
    );
  }

  void _add() {
    final ids = [for (final i in widget.pack.items) i.id];
    if (ids.isEmpty) return;
    _rows.add(EditableConditionRow(item: ids.first));
    _sync();
  }
}

String _kindLabelOf(String kind) => switch (kind) {
  'image' => t('editor.check.aiKind.image'),
  'audio' => t('editor.check.aiKind.audio'),
  'video' => t('editor.check.aiKind.video'),
  _ => t('editor.check.aiKind.text'),
};

class _SubmitQuotaField extends StatelessWidget {
  final EditableCheck check;
  final VoidCallback onChanged;

  const _SubmitQuotaField({
    super.key,
    required this.check,
    required this.onChanged,
  });

  Set<String> get _kinds {
    final raw = check.params['submit_kinds'];
    if (raw is List) return {for (final e in raw) e.toString()};
    return switch (check.type) {
      'photo_submit' => {'image'},
      'media_submit' => {'image', 'audio', 'video'},
      _ => <String>{},
    };
  }

  int get _need {
    final raw = check.params['submit_need'];
    if (raw is num) return raw.toInt();
    final rc = (check.params['requireCount'] as num?)?.toInt() ?? 0;
    return rc == 0 ? 1 : rc;
  }

  static List<String> _ordered(Set<String> set) => [
    for (final k in EditableAiSendItem.kinds)
      if (set.contains(k)) k,
  ];

  void _commitNeed(int v) {
    check.params['submit_need'] = v < 0 ? 0 : v;
    check.params['submit_kinds'] = _ordered(_kinds);
    check.params.remove('requireCount');
    onChanged();
  }

  void _commitKinds(Set<String> next) {
    final ordered = _ordered(next);
    if (ordered.isEmpty) {
      check.params.remove('submit_kinds');
    } else {
      check.params['submit_kinds'] = ordered;
    }
    if (check.params['submit_need'] is! num) {
      check.params['submit_need'] = _need;
      check.params.remove('requireCount');
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final kinds = _kinds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldGrid(
          children: [
            LabeledIntField(
              key: ValueKey('submitNeed-${check.fileName}'),
              label: t('editor.check.submitNeed'),
              initial: _need,
              onChanged: _commitNeed,
            ),
            LabeledTextField(
              key: ValueKey('submitLabel-${check.fileName}'),
              label: t('editor.check.submitLabel'),
              initial: (check.params['submit_label'] ?? '').toString(),
              dense: true,
              onChanged: (v) {
                final value = v.trim();
                if (value.isEmpty) {
                  check.params.remove('submit_label');
                } else {
                  check.params['submit_label'] = value;
                }
                onChanged();
              },
            ),
          ],
        ),
        _FieldHeader(
          label: t('editor.check.submitKinds'),
          help: t('editor.check.submitKinds.help'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final kind in EditableAiSendItem.kinds)
                FilterChip(
                  label: Text(
                    _kindLabelOf(kind),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: kinds.contains(kind),
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) {
                    final next = {...kinds};
                    if (on) {
                      next.add(kind);
                    } else {
                      next.remove(kind);
                    }
                    _commitKinds(next);
                  },
                ),
            ],
          ),
        ),
        YesNoField(
          label: t('editor.check.needText'),
          value: check.params['need_text'] == true,
          help: t('editor.check.needText.help'),
          onChanged: (v) {
            check.params['need_text'] = v;
            onChanged();
          },
        ),
      ],
    );
  }
}

class _AiJudgeField extends StatefulWidget {
  final EditableCheck check;
  final VoidCallback onChanged;

  const _AiJudgeField({super.key, required this.check, required this.onChanged});

  @override
  State<_AiJudgeField> createState() => _AiJudgeFieldState();
}

class _AiJudgeFieldState extends State<_AiJudgeField> {
  late final List<String> _points = _read();

  List<String> _read() {
    final raw = widget.check.params['ai_points'];
    final pts = raw is List ? [for (final e in raw) e.toString()] : <String>[];
    if (pts.isNotEmpty) return pts;
    final legacy = (widget.check.params['ai_criteria'] ?? '').toString().trim();
    return legacy.isEmpty ? <String>[] : [legacy];
  }

  bool get _passAny => (widget.check.params['ai_pass'] ?? '') == 'any';

  void _sync() {
    final params = widget.check.params;
    final pts = [
      for (final p in _points)
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (pts.isEmpty) {
      params.remove('ai_points');
    } else {
      params['ai_points'] = pts;
    }
    params.remove('ai_criteria');
    if (_passAny) {
      params['ai_pass'] = 'any';
    } else {
      params.remove('ai_pass');
    }
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final aiOn = _points.any((p) => p.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _points.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    key: ValueKey('aiPoint-${widget.check.fileName}-$i'),
                    label: t('editor.check.aiPoint', args: {'n': i + 1}),
                    initial: _points[i],
                    dense: true,
                    maxLines: 2,
                    onChanged: (v) {
                      _points[i] = v;
                      _sync();
                    },
                  ),
                ),
                IconButton(
                  tooltip: t('editor.check.aiPoint.remove'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _points.removeAt(i);
                    _sync();
                  },
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _points.add('');
              _sync();
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text(t('editor.check.aiPoint.add')),
          ),
        ),
        if (aiOn) ...[
          LabeledDropdown<String>(
            label: t('editor.check.aiPass'),
            value: _passAny ? 'any' : 'all',
            items: const ['all', 'any'],
            labelOf: (v) => v == 'any'
                ? t('editor.check.aiPass.any')
                : t('editor.check.aiPass.all'),
            onChanged: (v) {
              widget.check.params['ai_pass'] = v == 'any' ? 'any' : 'all';
              _sync();
            },
          ),
          LabeledTextField(
            key: ValueKey('aiFail-${widget.check.fileName}'),
            label: t('editor.check.failText'),
            initial: (widget.check.params['fail_text'] ?? '').toString(),
            dense: true,
            maxLines: 2,
            onChanged: (v) {
              final value = v.trim();
              if (value.isEmpty) {
                widget.check.params.remove('fail_text');
              } else {
                widget.check.params['fail_text'] = value;
              }
              widget.onChanged();
            },
          ),
          YesNoField(
            label: t('editor.check.showAuthorHint'),
            value: (widget.check.params['show_author_hint'] ?? 'yes') != 'no',
            help: t('editor.check.showAuthorHint.help'),
            onChanged: (v) {
              if (v) {
                widget.check.params.remove('show_author_hint');
              } else {
                widget.check.params['show_author_hint'] = 'no';
              }
              _sync();
            },
          ),
          YesNoField(
            label: t('editor.check.showAiReasons'),
            value: (widget.check.params['show_ai_reasons'] ?? '') == 'yes',
            help: t('editor.check.showAiReasons.help'),
            onChanged: (v) {
              if (v) {
                widget.check.params['show_ai_reasons'] = 'yes';
              } else {
                widget.check.params.remove('show_ai_reasons');
              }
              _sync();
            },
          ),
        ],
      ],
    );
  }
}

class _AiSendField extends StatefulWidget {
  final EditableCheck check;
  final VoidCallback onChanged;

  const _AiSendField({super.key, required this.check, required this.onChanged});

  @override
  State<_AiSendField> createState() => _AiSendFieldState();
}

class _AiSendFieldState extends State<_AiSendField> {
  List<EditableAiSendItem> get _items => widget.check.aiSendItems;

  String _kindLabel(String kind) => switch (kind) {
    'image' => t('editor.check.aiKind.image'),
    'audio' => t('editor.check.aiKind.audio'),
    'video' => t('editor.check.aiKind.video'),
    _ => t('editor.check.aiKind.text'),
  };

  void _changed() {
    widget.onChanged();
    setState(() {});
  }

  void _add() {
    final used = {for (final i in _items) i.kind};
    final free = EditableAiSendItem.kinds.firstWhere(
      (k) => !used.contains(k),
      orElse: () => '',
    );
    if (free.isEmpty) return;
    _items.add(EditableAiSendItem(kind: free));
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldHeader(
          label: t('editor.check.aiSendItems'),
          help: t('editor.check.aiSend.help'),
        ),
        for (final item in _items)
          KeyedSubtree(
            key: ObjectKey(item),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 10),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: FiftyRadii.mdRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LabeledDropdown<String>(
                          label: t('editor.check.aiSend.type'),
                          value: item.kind,
                          items: EditableAiSendItem.kinds
                              .where(
                                (k) =>
                                    k == item.kind ||
                                    !_items.any(
                                      (o) => o != item && o.kind == k,
                                    ),
                              )
                              .toList(),
                          labelOf: _kindLabel,
                          onChanged: (v) {
                            item.kind = v ?? 'text';
                            _changed();
                          },
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: t('common.delete'),
                        onPressed: () {
                          _items.remove(item);
                          _changed();
                        },
                        icon: Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  FieldGrid(
                    children: [
                      LabeledTextField(
                        label: t('editor.check.aiSend.name'),
                        initial: item.name,
                        dense: true,
                        onChanged: (v) {
                          item.name = v;
                          _changed();
                        },
                      ),
                      LabeledIntField(
                        label: t('editor.check.aiSend.quantity'),
                        initial: item.quantity,
                        onChanged: (v) {
                          item.quantity = v.clamp(1, 99);
                          _changed();
                        },
                      ),
                    ],
                  ),
                  LabeledTextField(
                    label: t('editor.check.aiSend.requirement'),
                    initial: item.requirement,
                    dense: true,
                    maxLines: 2,
                    onChanged: (v) {
                      item.requirement = v;
                      _changed();
                    },
                  ),
                  YesNoField(
                    label: t('editor.check.aiSend.inInventory'),
                    help: t('editor.check.aiSend.visibilityHelp'),
                    value: item.showInInventory,
                    onChanged: (v) {
                      item.showInInventory = v;
                      _changed();
                    },
                  ),
                  YesNoField(
                    label: t('editor.check.aiSend.inStory'),
                    value: item.showInStory,
                    onChanged: (v) {
                      item.showInStory = v;
                      _changed();
                    },
                  ),
                ],
              ),
            ),
          ),
        _ChipAdd(
          label: t('editor.check.aiSend.add'),
          onPressed: _items.length >= EditableAiSendItem.kinds.length
              ? null
              : _add,
        ),
      ],
    );
  }
}
