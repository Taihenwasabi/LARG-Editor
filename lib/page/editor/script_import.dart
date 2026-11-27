import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_models.dart';

Future<void> openScriptImport(BuildContext context, EditablePack pack) async {
  final messenger = ScaffoldMessenger.of(context);
  final count = await showDialog<int>(
    context: context,
    builder: (ctx) => _ScriptImportDialog(pack: pack),
  );
  if (count == null || count <= 0) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        t('editor.scriptImport.done', args: {'count': count}),
      ),
    ),
  );
}

enum _ScriptMode { chapter, lines }

class _ScriptBlock {
  String title;
  final List<EditableLine> lines;

  _ScriptBlock({this.title = '', List<EditableLine>? lines})
    : lines = lines ?? <EditableLine>[];

  bool get isEmpty => title.trim().isEmpty && lines.isEmpty;
}

class _ScriptImportDialog extends StatefulWidget {
  final EditablePack pack;

  const _ScriptImportDialog({required this.pack});

  @override
  State<_ScriptImportDialog> createState() => _ScriptImportDialogState();
}

class _ScriptImportDialogState extends State<_ScriptImportDialog> {
  static final RegExp _chapterPattern = RegExp(
    r'^\s*(第\s*[0-9一二三四五六七八九十百千万零〇两]+\s*[章节回幕]|chapter\s*(?:[0-9]+|[ivxlcdm]+)\b|#{1,6}\s)',
    caseSensitive: false,
  );

  static final RegExp _markdownPrefix = RegExp(r'^#{1,6}\s*');

  static final RegExp _dialoguePattern = RegExp(
    r'^\s*([^：:\s][^：:]{0,19})[：:]\s*(.*)$',
  );

  static final RegExp _bracketPattern = RegExp(r'^[（(].*[）)]$');

  static const List<int> _chunkOptions = [10, 20, 30, 50];

  final TextEditingController _controller = TextEditingController();

  _ScriptMode _mode = _ScriptMode.chapter;
  int _chunk = 20;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isChapterTitle(String line) => _chapterPattern.hasMatch(line);

  String _chapterTitle(String line) {
    final trimmed = line.trim();
    return trimmed.replaceFirst(_markdownPrefix, '').trim();
  }

  EditableLine? _parseLine(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return null;
    if (_bracketPattern.hasMatch(line)) {
      return EditableLine(type: 'narration', text: line);
    }
    final m = _dialoguePattern.firstMatch(line);
    if (m != null) {
      final speaker = (m.group(1) ?? '').trim();
      final text = (m.group(2) ?? '').trim();
      if (speaker.isNotEmpty) {
        return EditableLine(type: 'dialogue', speaker: speaker, text: text);
      }
    }
    return EditableLine(type: 'narration', text: line);
  }

  List<_ScriptBlock> _parse(String source) {
    final rows = [
      for (final r in const LineSplitter().convert(source))
        if (r.trim().isNotEmpty) r.trim(),
    ];
    final blocks = <_ScriptBlock>[];
    if (_mode == _ScriptMode.lines) {
      for (var i = 0; i < rows.length; i += _chunk) {
        final end = (i + _chunk < rows.length) ? i + _chunk : rows.length;
        final block = _ScriptBlock();
        for (var k = i; k < end; k++) {
          final line = _parseLine(rows[k]);
          if (line != null) block.lines.add(line);
        }
        if (!block.isEmpty) blocks.add(block);
      }
      return blocks;
    }
    _ScriptBlock? current;
    for (final row in rows) {
      if (_isChapterTitle(row)) {
        current = _ScriptBlock(title: _chapterTitle(row));
        blocks.add(current);
        continue;
      }
      final line = _parseLine(row);
      if (line == null) continue;
      if (current == null) {
        current = _ScriptBlock();
        blocks.add(current);
      }
      current.lines.add(line);
    }
    return [for (final b in blocks) if (!b.isEmpty) b];
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickFile() async {
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'md'],
        withData: true,
      );
    } catch (_) {
      if (mounted) _snack(t('editor.scriptImport.fileFailed'));
      return;
    }
    if (!mounted) return;
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.first.bytes;
    if (bytes == null) {
      _snack(t('editor.scriptImport.fileFailed'));
      return;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  void _confirm() {
    final blocks = _parse(_controller.text);
    if (blocks.isEmpty) {
      _snack(t('editor.scriptImport.empty'));
      return;
    }
    final pack = widget.pack;
    var count = 0;
    for (final block in blocks) {
      pack.addStage();
      final stage = pack.stages.last;
      final title = block.title.trim();
      if (title.isNotEmpty) {
        stage.lines.add(EditableLine(type: 'narration', text: title));
      }
      for (final line in block.lines) {
        stage.lines.add(line);
      }
      count++;
    }
    pack.renumberStages();
    pack.notify();
    Navigator.of(context).pop(count);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(t('editor.scriptImport.title')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('editor.scriptImport.help'),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              SegmentedButton<_ScriptMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: _ScriptMode.chapter,
                    label: Text(t('editor.scriptImport.mode.chapter')),
                  ),
                  ButtonSegment(
                    value: _ScriptMode.lines,
                    label: Text(t('editor.scriptImport.mode.lines')),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              if (_mode == _ScriptMode.lines) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _chunk,
                  decoration: InputDecoration(
                    labelText: t('editor.scriptImport.chunk'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    for (final n in _chunkOptions)
                      DropdownMenuItem<int>(value: n, child: Text('$n')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _chunk = v);
                  },
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                minLines: 6,
                maxLines: 8,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: t('editor.scriptImport.hint'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: Text(t('editor.scriptImport.pickFile')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(t('editor.scriptImport.confirm')),
        ),
      ],
    );
  }
}
