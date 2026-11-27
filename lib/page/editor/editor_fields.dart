
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/page/editor/editor_media.dart';
import 'package:larg_editor/constants/app_palette.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

const double _tileBlockGap = 10;


class LabeledTextField extends StatefulWidget {
  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final bool dense;


  final bool isRequired;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.maxLines = 1,
    this.dense = false,
    this.isRequired = false,
  });

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );
  late bool _empty = widget.initial.trim().isEmpty;

  bool get _invalid => widget.isRequired && _empty;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.dense ? 3 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _c,
            maxLines: widget.maxLines,
            textAlignVertical: widget.maxLines > 1 ? TextAlignVertical.top : null,
            decoration: InputDecoration(
              labelText: widget.label,
              isDense: true,
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _invalid
                      ? context.palette.dangerStrong
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _invalid
                      ? context.palette.dangerStrong
                      : Theme.of(context).colorScheme.primary,
                  width: _invalid ? 1.6 : 1.0,
                ),
              ),
            ),
            onChanged: (v) {
              setState(() => _empty = v.trim().isEmpty);
              widget.onChanged(v);
            },
          ),
          if (_invalid)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 3),
              child: Text(
                '*${t('editor.field.required')}',
                style: TextStyle(color: context.palette.dangerStrong, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}


class LabeledIntField extends StatefulWidget {
  final String label;
  final int initial;
  final ValueChanged<int> onChanged;
  final bool allowNegative;

  const LabeledIntField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.allowNegative = false,
  });

  @override
  State<LabeledIntField> createState() => _LabeledIntFieldState();
}

class _LabeledIntFieldState extends State<LabeledIntField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial.toString(),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: TextField(
        controller: _c,
        keyboardType: TextInputType.numberWithOptions(
          signed: widget.allowNegative,
        ),
        inputFormatters: [
          widget.allowNegative
              ? FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
              : FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
      ),
    );
  }
}


class LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {

    final list = items.contains(value) ? items : <T>[value, ...items];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
        ),
        isEmpty: false,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: [
              for (final it in list)
                DropdownMenuItem<T>(
                  value: it,
                  child: Text(
                    labelOf(it),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}


class HelpDot extends StatelessWidget {
  final String message;
  final String? title;

  const HelpDot({super.key, required this.message, this.title});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      visualDensity: VisualDensity.compact,
      tooltip: title ?? t('editor.help'),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: title == null ? null : Text(title!),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('common.confirm')),
            ),
          ],
        ),
      ),
      icon: Icon(
        Icons.help_outline,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}


class YesNoField extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? help;

  const YesNoField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                if (help != null) HelpDot(message: help!, title: label),
              ],
            ),
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment(value: true, label: Text(t('common.yes'))),
              ButtonSegment(value: false, label: Text(t('common.no'))),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}


class FieldGrid extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final double breakpoint;

  const FieldGrid({
    super.key,
    required this.children,
    this.gap = 10,
    this.breakpoint = 560,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i += 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: children[i]),
                  SizedBox(width: gap),
                  Expanded(
                    child: i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}


class EditorCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDelete;
  final String? title;
  final Widget? headerTrailing;

  const EditorCard({
    super.key,
    required this.child,
    this.onDelete,
    this.title,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasHeader = title != null || onDelete != null || headerTrailing != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: FiftyRadii.lgRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ?headerTrailing,
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
          child,
        ],
      ),
    );
  }
}

class TileBlock extends StatelessWidget {
  final String label;
  final Widget? action;
  final double minTile;
  final double maxTile;
  final double aspect;
  final List<Widget> Function(double width, double height) tiles;

  const TileBlock({
    super.key,
    required this.label,
    required this.tiles,
    this.action,
    this.minTile = 64,
    this.maxTile = 168,
    this.aspect = 1,
  });

  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: _tileBlockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                ?action,
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final avail = constraints.maxWidth;
              final cols = ((avail + gap) / (minTile + gap)).floor().clamp(1, 8);
              final width = ((avail - gap * (cols - 1)) / cols).clamp(
                0.0,
                maxTile,
              );
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: tiles(width, width / aspect),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SlotTile extends StatelessWidget {
  final EditablePack pack;
  final String rel;
  final double width;
  final double height;
  final VoidCallback onRemove;
  final Widget? corner;

  const SlotTile({
    super.key,
    required this.pack,
    required this.rel,
    required this.width,
    required this.height,
    required this.onRemove,
    this.corner,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isImage = isImagePath(rel);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: FiftyRadii.mdRadius,
            child: isImage
                ? editorAssetImage(context, pack, rel)
                : ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAudioPath(rel) ? Icons.audiotrack : Icons.videocam,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            rel.split('/').last,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (corner != null)
            Align(alignment: Alignment.bottomLeft, child: corner!),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SlotRemove(onTap: onRemove),
            ),
          ),
        ],
      ),
    );
  }
}

class SlotAdd extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback onTap;
  final IconData icon;

  const SlotAdd({
    super.key,
    required this.width,
    required this.height,
    required this.onTap,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: FiftyRadii.mdRadius,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: FiftyRadii.mdRadius,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(
          icon,
          size: 20,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class SlotRemove extends StatelessWidget {
  final VoidCallback onTap;
  const SlotRemove({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CanvasSkin.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(Icons.close, size: 13, color: CanvasSkin.white),
        ),
      ),
    );  }
}
