import 'package:flutter/material.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_fields.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/page/editor/media_library_page.dart';

class ItemTab extends StatelessWidget {
  final EditablePack pack;

  const ItemTab({super.key, required this.pack});

  void _add() {
    final id = pack.uniqueItemId();
    pack.items.add(EditableStoryItem(id: id, fileName: '$id.json'));
    pack.notify();
  }

  void _remove(EditableStoryItem item) {
    pack.removeItem(item);
  }

  void _rename(BuildContext context, EditableStoryItem item, String raw) {
    final next = raw.trim();
    if (next.isEmpty || next == item.id) return;
    if (!pack.renameItem(item, next)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t('editor.item.idDup'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        for (final item in pack.items)
          EditorCard(
            title: item.name.trim().isEmpty ? item.id : item.name.trim(),
            onDelete: () => _remove(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldGrid(
                  children: [
                    LabeledTextField(
                      key: ValueKey('itemId-${identityHashCode(item)}'),
                      label: t('editor.item.id'),
                      initial: item.id,
                      onChanged: (v) {
                        final next = v.trim();
                        if (next.isEmpty || next == item.id) return;
                        _rename(context, item, next);
                      },
                    ),
                    LabeledTextField(
                      key: ValueKey('itemName-${identityHashCode(item)}'),
                      label: t('editor.item.name'),
                      initial: item.name,
                      onChanged: (v) {
                        item.name = v;
                        pack.notify();
                      },
                    ),
                  ],
                ),
                FieldGrid(
                  children: [
                    LabeledDropdown<String>(
                      label: t('editor.item.kind'),
                      value: item.kind.isEmpty ? 'auto' : item.kind,
                      items: const ['auto', 'text', 'image', 'audio', 'video'],
                      labelOf: (v) => switch (v) {
                        'text' => t('editor.item.kind.text'),
                        'image' => t('editor.item.kind.image'),
                        'audio' => t('editor.item.kind.audio'),
                        'video' => t('editor.item.kind.video'),
                        _ => t('editor.item.kind.auto'),
                      },
                      onChanged: (v) {
                        item.kind = (v == null || v == 'auto') ? '' : v;
                        pack.notify();
                      },
                    ),
                    LabeledIntField(
                      key: ValueKey('itemInitial-${identityHashCode(item)}'),
                      label: t('editor.item.initial'),
                      initial: item.initial,
                      onChanged: (v) {
                        item.initial = v;
                        pack.notify();
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Text(
                        t('editor.item.asset'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      HelpDot(
                        message: t('editor.item.assetHelp'),
                        title: t('editor.item.asset'),
                      ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: LabeledTextField(
                        key: ValueKey('itemDesc-${identityHashCode(item)}'),
                        label: t('editor.item.description'),
                        initial: item.description,
                        maxLines: 2,
                        dense: true,
                        onChanged: (v) {
                          item.description = v;
                          pack.notify();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ItemAsset(
                      pack: pack,
                      item: item,
                      onChanged: pack.notify,
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            t('editor.item.add'),
            style: const TextStyle(fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }
}

class _ItemAsset extends StatelessWidget {
  static const double size = 64;
  final EditablePack pack;
  final EditableStoryItem item;
  final VoidCallback onChanged;

  const _ItemAsset({
    required this.pack,
    required this.item,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final rel = await MediaLibraryPage.pick(context, pack);
    if (rel == null) return;
    item.asset = rel;
    onChanged();
  }

  void _clear() {
    if (item.asset.isEmpty) return;
    item.asset = '';
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final rel = item.asset.trim();
    if (rel.isEmpty) {
      return SlotAdd(
        width: size,
        height: size,
        onTap: () => _pick(context),
        icon: Icons.add_photo_alternate_outlined,
      );
    }
    return SlotTile(
      pack: pack,
      rel: rel,
      width: size,
      height: size,
      onRemove: _clear,
    );
  }
}
