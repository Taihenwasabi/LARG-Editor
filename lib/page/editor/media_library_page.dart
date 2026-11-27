import 'package:flutter/material.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/page/editor/editor_media.dart';
import 'package:larg_editor/service/file_pick_service.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

class MediaLibraryPage extends StatefulWidget {
  final EditablePack pack;
  final PickerMedia? media;

  const MediaLibraryPage({super.key, required this.pack, this.media});

  static Future<String?> pick(
    BuildContext context,
    EditablePack pack, [
    PickerMedia? media,
  ]) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaLibraryPage(pack: pack, media: media),
      ),
    );
  }

  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends State<MediaLibraryPage> {
  static const String _allCategories = '__all__';
  static const String _albumCategory = '__album__';

  final TextEditingController _search = TextEditingController();
  String _category = _allCategories;

  EditablePack get pack => widget.pack;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  PickerMedia _kindOf(String rel) {
    if (isAudioPath(rel)) return PickerMedia.audio;
    if (isVideoPath(rel)) return PickerMedia.video;
    return PickerMedia.image;
  }

  String _categoryLabel(String key) => switch (key) {
    'people' => t('editor.library.cat.people'),
    'background' => t('editor.library.cat.background'),
    'music' => t('editor.library.cat.music'),
    'video' => t('editor.library.cat.video'),
    'item' => t('editor.library.cat.item'),
    _ => t('editor.library.cat.other'),
  };

  IconData _mediaIcon(PickerMedia m) => switch (m) {
    PickerMedia.image => Icons.image_outlined,
    PickerMedia.audio => Icons.audiotrack,
    PickerMedia.video => Icons.videocam,
  };

  bool _matchType(String rel) {
    final type = widget.media;
    return switch (type) {
      null => true,
      PickerMedia.image => isImagePath(rel),
      PickerMedia.audio => isAudioPath(rel),
      PickerMedia.video => isVideoPath(rel),
    };
  }

  bool _categoryFits(String key) => switch (widget.media) {
    null => true,
    PickerMedia.image =>
      key == 'people' || key == 'background' || key == 'item' || key == 'other',
    PickerMedia.audio => key == 'music',
    PickerMedia.video => key == 'video',
  };

  bool _matchCategory(String rel) {
    if (_category == _allCategories) return true;
    final category = pack.categoryOf(rel);
    if (_category == _albumCategory) return category == null;
    return category == _category;
  }

  List<String> _items() {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final rel in pack.mediaPaths)
        if (_matchType(rel) &&
            _matchCategory(rel) &&
            (q.isEmpty || rel.toLowerCase().contains(q)))
          rel,
    ]..sort();
  }

  Future<void> _upload() async {
    final rels = await importMediaFromDevice(pack, kind: widget.media);
    if (!mounted || rels.isEmpty) return;
    setState(() {});
  }

  List<String> _presentCategories() => [
    for (final key in EditablePack.mediaCategories)
      if (_categoryFits(key) &&
          pack.mediaPaths.any(
            (rel) => pack.categoryOf(rel) == key && _matchType(rel),
          ))
        key,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items();
    final categories = _presentCategories();
    final hasAlbum = pack.mediaPaths.any(
      (rel) => pack.categoryOf(rel) == null && _matchType(rel),
    );
    final chips = _filterChips(categories, hasAlbum);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('editor.library.pickTitle')),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: t('editor.library.upload'),
            onPressed: _upload,
            icon: const Icon(Icons.upload_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: t('editor.library.search'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: t('common.close'),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SizedBox(
                  height: 34,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: chips),
                  ),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          t('editor.library.pickEmpty'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 168,
                        mainAxisExtent: 148,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _card(context, items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _filterChips(List<String> categories, bool hasAlbum) {
    final chips = <Widget>[];
    if (hasAlbum) {
      chips.add(
        _chip(
          t('editor.library.album'),
          _category == _albumCategory,
          () => setState(
            () => _category =
                _category == _albumCategory ? _allCategories : _albumCategory,
          ),
        ),
      );
    }
    for (final key in categories) {
      chips.add(
        _chip(
          _categoryLabel(key),
          _category == key,
          () => setState(
            () => _category = _category == key ? _allCategories : key,
          ),
        ),
      );
    }
    return chips;
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
    );
  }

  Widget _card(BuildContext context, String rel) {
    final scheme = Theme.of(context).colorScheme;
    final kind = _kindOf(rel);
    final category = pack.categoryOf(rel);
    return Material(
      color: scheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: FiftyRadii.mdRadius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => Navigator.pop(context, rel),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumb(context, rel, kind),
                  if (category != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 84),
                        child: _badge(
                          _categoryLabel(category),
                          Icons.folder_outlined,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _badge(null, _mediaIcon(kind)),
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              color: scheme.surfaceContainerHigh,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                rel.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String? label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 4 : 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: CanvasSkin.black54,
        borderRadius: FiftyRadii.mdRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: CanvasSkin.white),
          if (label != null) ...[
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: CanvasSkin.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context, String rel, PickerMedia kind) {
    final scheme = Theme.of(context).colorScheme;
    if (kind != PickerMedia.image) {
      return Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          _mediaIcon(kind),
          size: 34,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    Widget broken() => Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        size: 28,
        color: scheme.onSurfaceVariant,
      ),
    );
    final bytes = pack.importedMedia[rel];
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => broken(),
      );
    }
    final key = pack.assetKeyFor(rel);
    if (key == null) return broken();
    return Image.asset(
      key,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => broken(),
    );
  }
}
