/// 卡片树：关卡 → 条目（台词/分支）→ 子件（媒体/校验/发放）三层封闭树。
///
/// 只做"结构与选中"：点卡片 → 回传选中坐标；简单字段就地可改；复杂字段
/// 交给编辑区。数据来自同一个 EditablePack，不存副本（分布式设计）。
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_models.dart';

/// 树中选中的一个卡片。
class CardSelection {
  final int stage;
  final int? line;
  final int? checkpoint;
  const CardSelection(this.stage, {this.line, this.checkpoint});
}

class CardTree extends StatelessWidget {
  final EditablePack pack;
  final CardSelection? selected;
  final ValueChanged<CardSelection> onSelect;
  final VoidCallback? onAddStage;

  const CardTree({
    super.key,
    required this.pack,
    required this.selected,
    required this.onSelect,
    this.onAddStage,
  });

  @override
  Widget build(BuildContext context) {
    if (pack.stages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('editor.empty')),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onAddStage,
              icon: const Icon(Icons.add),
              label: Text(t('editor.new')),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
      itemCount: pack.stages.length + (onAddStage != null ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == pack.stages.length) {
          return ListTile(
            leading: const Icon(Icons.add),
            title: Text(t('editor.stage.add')),
            onTap: onAddStage,
          );
        }
        return _StageNode(
          stage: pack.stages[i],
          index: i,
          selected: selected,
          onSelect: onSelect,
        );
      },
    );
  }
}

class _StageNode extends StatefulWidget {
  final EditableStage stage;
  final int index;
  final CardSelection? selected;
  final ValueChanged<CardSelection> onSelect;

  const _StageNode({
    required this.stage,
    required this.index,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_StageNode> createState() => _StageNodeState();
}

class _StageNodeState extends State<_StageNode> {
  bool _open = true;

  bool get _isSelected {
    final sel = widget.selected;
    return sel != null &&
        sel.stage == widget.index &&
        sel.line == null &&
        sel.checkpoint == null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: _isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _isSelected ? scheme.primary : scheme.outlineVariant,
          width: _isSelected ? 1.5 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => widget.onSelect(CardSelection(widget.index)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_open ? Icons.expand_more : Icons.chevron_right),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _open = !_open),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.account_tree_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: widget.stage.displayLabel),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      onChanged: (v) => widget.stage.id = v,
                    ),
                  ),
                  Text(
                    '${widget.stage.lines.length}',
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._lineNodes(),
                  ..._checkpointNodes(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _lineNodes() {
    final lines = widget.stage.lines;
    final out = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      out.add(
        _Leaf(
          icon: line.type == 'dialogue' ? Icons.record_voice_over_outlined : Icons.notes_outlined,
          title: line.type == 'dialogue'
              ? '${line.speaker.isNotEmpty ? line.speaker : t('editor.line.dialogue')}: ${line.text}'
              : line.text,
          subtitle: line.id,
          selected: widget.selected?.stage == widget.index && widget.selected?.line == i,
          onTap: () => widget.onSelect(CardSelection(widget.index, line: i)),
          trailing: (line.image.isNotEmpty ||
                  line.audio.isNotEmpty ||
                  line.video.isNotEmpty ||
                  line.background.isNotEmpty)
              ? Icons.attach_file
              : null,
        ),
      );
    }
    return out;
  }

  List<Widget> _checkpointNodes() {
    final cps = widget.stage.checkpoints;
    final out = <Widget>[
      if (cps.isNotEmpty && widget.stage.lines.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            t('editor.choices'),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
    ];
    for (var i = 0; i < cps.length; i++) {
      final cp = cps[i];
      out.add(
        _Leaf(
          icon: Icons.call_split_outlined,
          title: cp.text,
          subtitle: [
            if (cp.check.isNotEmpty) 'check:${cp.check}',
            if (cp.next.isNotEmpty) '→${cp.next}',
            if (cp.reward != 0) '+${cp.reward}',
          ].join(' · '),
          selected: widget.selected?.stage == widget.index && widget.selected?.checkpoint == i,
          onTap: () => widget.onSelect(CardSelection(widget.index, checkpoint: i)),
          trailing: cp.grant.isNotEmpty ? Icons.backpack_outlined : null,
        ),
      );
    }
    return out;
  }
}

/// 叶子卡片：台词/分支/子件的统一长相（控件词典——一种卡片一种结构）。
class _Leaf extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;

  const _Leaf({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurface),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: scheme.outline),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              Icon(trailing, size: 13, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
