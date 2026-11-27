import 'package:flutter/material.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_media.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/service/file_pick_service.dart';
import 'package:larg_editor/constants/app_palette.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

class MediaTab extends StatefulWidget {
  final EditablePack pack;

  const MediaTab({super.key, required this.pack});

  @override
  State<MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<MediaTab> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _expandedGroups = <String>{};
  final Set<String> _closedSections = <String>{};
  bool _detail = false;

  EditablePack get pack => widget.pack;

  bool get _searching => _search.text.trim().isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _categoryLabel(String key) => switch (key) {
    'people' => t('editor.library.cat.people'),
    'background' => t('editor.library.cat.background'),
    'music' => t('editor.library.cat.music'),
    'video' => t('editor.library.cat.video'),
    'item' => t('editor.library.cat.item'),
    _ => t('editor.library.cat.other'),
  };

  PickerMedia _kindOf(String rel) {
    if (isAudioPath(rel)) return PickerMedia.audio;
    if (isVideoPath(rel)) return PickerMedia.video;
    return PickerMedia.image;
  }

  List<String> _filtered(Iterable<String> items) {
    final q = _search.text.trim().toLowerCase();
    final list = [
      for (final rel in items)
        if (q.isEmpty || rel.toLowerCase().contains(q)) rel,
    ]..sort();
    return list;
  }

  List<String> _albumItems() => _filtered(
    pack.mediaPaths.where((rel) => pack.categoryOf(rel) == null),
  );

  List<String> _categoryItems(String category) => _filtered(
    pack.mediaPaths.where((rel) => pack.categoryOf(rel) == category),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _topBar(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            children: [
              _albumSection(),
              for (final key in EditablePack.mediaCategories)
                if (!_searching || _categoryItems(key).isNotEmpty)
                  _categorySection(key),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: t('editor.library.search'),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.grid_view, size: 17),
                tooltip: t('editor.library.view.grid'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.view_list, size: 17),
                tooltip: t('editor.library.view.detail'),
              ),
            ],
            selected: {_detail},
            onSelectionChanged: (s) => setState(() => _detail = s.first),
          ),
        ],
      ),
    );
  }

  Widget _albumSection() {
    final items = _albumItems();
    final open = _searching || !_closedSections.contains('album');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead(
          title: t('editor.library.album'),
          count: items.length,
          open: open,
          onToggle: () => setState(
            () => open
                ? _closedSections.add('album')
                : _closedSections.remove('album'),
          ),
          onUpload: () => _uploadForCategory(null),
        ),
        if (open) _block(items, null),
      ],
    );
  }

  Widget _categorySection(String category) {
    final items = _categoryItems(category);
    final open = _searching || !_closedSections.contains(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead(
          title: _categoryLabel(category),
          count: items.length,
          open: open,
          onToggle: () => setState(
            () => open
                ? _closedSections.add(category)
                : _closedSections.remove(category),
          ),
          onUpload: () => _uploadForCategory(category),
        ),
        if (open) _block(items, category),
      ],
    );
  }

  Widget _sectionHead({
    required String title,
    required int count,
    required bool open,
    required VoidCallback onToggle,
    required VoidCallback onUpload,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: FiftyRadii.mdRadius,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            const Spacer(),
            IconButton(
              tooltip: t('editor.library.upload'),
              visualDensity: VisualDensity.compact,
              onPressed: onUpload,
              icon: Icon(
                Icons.add_circle_outline,
                size: 20,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(List<String> items, String? category) {
    final grouped = <String, List<String>>{};
    final loose = <String>[];
    for (final rel in items) {
      final folder = pack.folderOf(rel);
      if (folder == null) {
        loose.add(rel);
      } else {
        grouped.putIfAbsent(folder, () => <String>[]).add(rel);
      }
    }
    final folderButton = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _createFolder,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: Text(t('editor.folder.add')),
        ),
      ),
    );
    if (_detail) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final rel in loose) _detailRow(rel, category),
          _detailUploadRow(category),
          for (final entry in grouped.entries) ...[
            _groupHead(entry.key, category ?? ''),
            if (_groupOpen(entry.key, category)) ...[
              for (final rel in entry.value) _detailRow(rel, category),
              _detailUploadRow(category, folder: entry.key),
            ],
          ],
          folderButton,
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int columns = ((width + 10) / 102).floor().clamp(3, 8).toInt();
        final double size = (width - 10 * (columns - 1)) / columns;
        Widget grid(List<String> items, {String? folder}) {
          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: size,
            ),
            children: [
              for (final rel in items) _tile(rel, size),
              _plusTile(category: category, folder: folder, size: size),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            grid(loose),
            for (final entry in grouped.entries) ...[
              _groupHead(entry.key, category ?? ''),
              if (_groupOpen(entry.key, category))
                grid(entry.value, folder: entry.key),
            ],
            folderButton,
          ],
        );
      },
    );
  }

  bool _groupOpen(String folder, String? category) =>
      _searching || _expandedGroups.contains('${category ?? ''}/$folder');

  Widget _groupHead(String folder, String category) {
    final scheme = Theme.of(context).colorScheme;
    final open = _groupOpen(folder, category);
    return InkWell(
      onTap: () => setState(() {
        final key = '$category/$folder';
        if (open) {
          _expandedGroups.remove(key);
        } else {
          _expandedGroups.add(key);
        }
      }),
      onLongPress: () => _folderMenu(folder),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                folder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            IconButton(
              tooltip: t('editor.folder.menu'),
              visualDensity: VisualDensity.compact,
              onPressed: () => _folderMenu(folder),
              icon: Icon(
                Icons.more_horiz,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String rel, double size) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: FiftyRadii.mdRadius,
      onTap: () => _itemMenu(rel),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: FiftyRadii.mdRadius,
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _preview(rel),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: CanvasSkin.black45,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  rel.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: CanvasSkin.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PickerMedia? _categoryKind(String category) {
    switch (category) {
      case 'music':
        return PickerMedia.audio;
      case 'video':
        return PickerMedia.video;
      case 'people':
      case 'background':
      case 'item':
        return PickerMedia.image;
      default:
        return null;
    }
  }

  bool _fitsCategory(String rel, String category) {
    if (category == 'other') return true;
    if (isImagePath(rel)) {
      return category == 'people' ||
          category == 'background' ||
          category == 'item';
    }
    if (isAudioPath(rel)) return category == 'music';
    if (isVideoPath(rel)) return category == 'video';
    return true;
  }

  Future<void> _uploadForCategory(String? category, {String? folder}) async {
    final rels = await importMediaFromDevice(
      pack,
      kind: category == null ? null : _categoryKind(category),
      category: category,
    );
    if (!mounted || rels.isEmpty || folder == null) return;
    for (final rel in rels) {
      pack.moveToFolder(rel, folder);
    }
    pack.notify();
  }

  Widget _detailUploadRow(String? category, {String? folder}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _uploadForCategory(category, folder: folder),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              t('editor.library.upload'),
              style: TextStyle(fontSize: 13, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String rel, String? category) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _itemMenu(rel),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: FiftyRadii.mdRadius,
              child: SizedBox(
                width: 40,
                height: 40,
                child: _preview(rel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rel.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (pack.folderOf(rel) != null)
              Text(
                pack.folderOf(rel)!,
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
            Icon(Icons.more_horiz, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _preview(String rel) {
    final scheme = Theme.of(context).colorScheme;
    final kind = _kindOf(rel);
    if (kind == PickerMedia.image) {
      return editorAssetImage(context, pack, rel);
    }
    return Center(
      child: Icon(
        kind == PickerMedia.audio ? Icons.audiotrack : Icons.videocam,
        size: 26,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Widget _plusTile({String? category, String? folder, required double size}) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _uploadForCategory(category, folder: folder),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: FiftyRadii.mdRadius,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(
          Icons.add,
          size: 28,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Future<void> _itemMenu(String rel) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                rel.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(t('editor.library.moveCategory')),
              onTap: () => Navigator.pop(ctx, 'category'),
            ),
            if (pack.mediaFolders.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(t('editor.folder.move.title')),
                onTap: () => Navigator.pop(ctx, 'move'),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.palette.danger),
              title: Text(
                t('editor.media.delete'),
                style: TextStyle(color: context.palette.danger),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'category') {
      await _moveCategory(rel);
    } else if (action == 'move') {
      await _moveItem(rel);
    } else {
      await _removeItem(rel);
    }
  }

  Future<void> _moveCategory(String rel) async {
    final current = pack.categoryOf(rel);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('editor.library.moveCategory')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Row(
              children: [
                Expanded(child: Text(t('editor.library.album'))),
                if (current == null) const Icon(Icons.check, size: 18),
              ],
            ),
          ),
          for (final key in EditablePack.mediaCategories)
            if (_fitsCategory(rel, key) || current == key)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, key),
                child: Row(
                  children: [
                    Expanded(child: Text(_categoryLabel(key))),
                    if (current == key) const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    pack.setCategory(rel, picked.isEmpty ? null : picked);
  }

  Future<void> _moveItem(String rel) async {
    final folders = pack.mediaFolders.keys.toList()..sort();
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('editor.folder.move.title')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(t('editor.folder.move.out')),
          ),
          for (final f in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f)),
                  if (pack.folderOf(rel) == f)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    pack.moveToFolder(rel, target.isEmpty ? null : target);
  }

  Future<void> _removeItem(String rel) async {
    final refs = pack.mediaRefCount(rel);
    if (refs > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('common.notice')),
          content: Text(t('editor.library.inUse', args: {'n': refs})),
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
      if (ok != true) return;
      pack.removeMediaCascade(rel);
    } else {
      pack.removeMedia(rel);
    }
  }

  Future<void> _createFolder() async {
    final name = await _promptFolderName(
      title: t('editor.folder.new'),
      initial: '',
    );
    if (name == null || !mounted) return;
    if (!pack.addFolder(name)) {
      _toast(t('editor.folder.dup'));
    }
  }

  Future<void> _folderMenu(String folder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                folder,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(t('editor.folder.rename')),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.folder_delete_outlined,
                color: context.palette.danger,
              ),
              title: Text(
                t('editor.folder.delete'),
                style: TextStyle(color: context.palette.danger),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      final next = await _promptFolderName(
        title: t('editor.folder.rename'),
        initial: folder,
      );
      if (next == null || !mounted) return;
      if (!pack.renameFolder(folder, next)) {
        _toast(t('editor.folder.dup'));
      }
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('editor.folder.delete')),
          content: Text(
            t('editor.folder.deleteConfirm', args: {'name': folder}),
          ),
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
      if (ok == true && mounted) pack.removeFolder(folder);
    }
  }

  Future<String?> _promptFolderName({
    required String title,
    required String initial,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: t('editor.folder.name')),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t('common.confirm')),
          ),
        ],
      ),
    ).whenComplete(() => ctrl.dispose());
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}
