
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/component/media_picker_field.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_fields.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/page/editor/editor_media.dart';
import 'package:larg_editor/page/editor/media_library_page.dart';
import 'package:larg_editor/service/file_pick_service.dart';

class ManifestTab extends StatelessWidget {
  final EditablePack pack;
  const ManifestTab({super.key, required this.pack});

  @override
  Widget build(BuildContext context) {
    final m = pack.manifest;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [

        LabeledTextField(
          label: t('editor.pkgName'),
          initial: pack.name,
          onChanged: (v) {
            pack.name = v;
            pack.notify();
          },
        ),
        LabeledTextField(
          label: t('editor.basic.gameName'),
          initial: m.gameName,
          isRequired: true,
          onChanged: (v) {
            m.gameName = v;
            pack.notify();
          },
        ),
        LabeledTextField(
          label: t('editor.basic.intro'),
          initial: m.introduction,
          maxLines: 3,
          isRequired: true,
          onChanged: (v) {
            m.introduction = v;
            pack.notify();
          },
        ),
        FieldGrid(
          children: [
            LabeledTextField(
              label: t('editor.basic.price'),
              initial: m.price,
              onChanged: (v) {
                m.price = v;
                pack.notify();
              },
            ),
            LabeledTextField(
              label: t('editor.basic.createTime'),
              initial: m.createTime,
              onChanged: (v) {
                m.createTime = v;
                pack.notify();
              },
            ),
          ],
        ),
        FieldGrid(
          children: [
            LabeledTextField(
              label: t('editor.basic.age'),
              initial: m.ageAppropriateness,
              onChanged: (v) {
                m.ageAppropriateness = v;
                pack.notify();
              },
            ),
            LabeledTextField(
              label: t('editor.basic.artStyle'),
              initial: m.artStyle,
              onChanged: (v) {
                m.artStyle = v;
                pack.notify();
              },
            ),
          ],
        ),
        LabeledTextField(
          label: t('editor.basic.publicKey'),
          initial: m.publicKey,
          onChanged: (v) {
            m.publicKey = v;
            pack.notify();
          },
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: MediaPickerField(
            label: t('editor.basic.map'),
            media: PickerMedia.image,
            tile: 64,
            items: m.map.trim().isEmpty ? const <String>[] : <String>[m.map],
            bytesOf: (rel) => pack.importedMedia[rel],
            assetKeyOf: pack.assetKeyFor,
            onOpenLibrary: () =>
                MediaLibraryPage.pick(context, pack, PickerMedia.image),
            onPickLibrary: (rel) async {
              m.map = rel;
              pack.notify();
              return rel;
            },
            onPickFile: (picked) async {
              final rel = await importPackMedia(pack, picked);
              if (rel != null) {
                m.map = rel;
                pack.notify();
              }
              return rel;
            },
            onRemove: (_) {
              m.map = '';
              pack.notify();
            },
          ),
        ),

        SectionTitle(
          t('editor.basic.buttons'),
          trailing: TextButton.icon(
            onPressed: () {
              m.buttonCoordinates.add(
                EditableButtonCoord(id: m.buttonCoordinates.length + 1, x: 0, y: 0),
              );
              pack.notify();
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              t('editor.basic.button.add'),
              style: const TextStyle(fontSize: 13),
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        if (m.buttonCoordinates.isEmpty)
          Text(
            t('editor.empty'),
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        for (var i = 0; i < m.buttonCoordinates.length; i++)
          _ButtonRow(
            key: ObjectKey(m.buttonCoordinates[i]),
            coord: m.buttonCoordinates[i],
            onChanged: pack.notify,
            onDelete: () {
              m.buttonCoordinates.removeAt(i);
              pack.notify();
            },
          ),
      ],
    );
  }
}


class _ButtonRow extends StatelessWidget {
  final EditableButtonCoord coord;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ButtonRow({
    super.key,
    required this.coord,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return EditorCard(
      onDelete: onDelete,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LabeledIntField(
              label: t('editor.basic.button.id'),
              initial: coord.id,
              onChanged: (v) {
                coord.id = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DoubleField(
              label: t('editor.basic.button.x'),
              initial: coord.x,
              onChanged: (v) {
                coord.x = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DoubleField(
              label: t('editor.basic.button.y'),
              initial: coord.y,
              onChanged: (v) {
                coord.y = v;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _DoubleField extends StatefulWidget {
  final String label;
  final double initial;
  final ValueChanged<double> onChanged;

  const _DoubleField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_DoubleField> createState() => _DoubleFieldState();
}

class _DoubleFieldState extends State<_DoubleField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial.toString());

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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
      ),
    );
  }
}
