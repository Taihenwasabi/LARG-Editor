library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/service/file_pick_service.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

enum _PickSource { gallery, file, library }

class MediaPickerField extends StatefulWidget {
  const MediaPickerField({
    super.key,
    required this.label,
    required this.media,
    required this.items,
    required this.onPickFile,
    required this.onRemove,
    this.multiple = false,
    this.bytesOf,
    this.assetKeyOf,
    this.enabled = true,
    this.tile = 92,
    this.onOpenLibrary,
    this.onPickLibrary,
  });

  final String label;
  final PickerMedia media;
  final List<String> items;
  final Future<String?> Function(PickedFileData picked) onPickFile;
  final void Function(String relPath) onRemove;
  final bool multiple;
  final Uint8List? Function(String relPath)? bytesOf;
  final String? Function(String relPath)? assetKeyOf;
  final bool enabled;
  final double tile;
  final Future<String?> Function()? onOpenLibrary;
  final Future<String?> Function(String rel)? onPickLibrary;

  @override
  State<MediaPickerField> createState() => _MediaPickerFieldState();
}

class _MediaPickerFieldState extends State<MediaPickerField> {
  bool _busy = false;

  Future<void> _pick() async {
    if (!widget.enabled || _busy) return;
    setState(() => _busy = true);
    try {
      if (widget.multiple) {
        final list = canPickMultipleFromGallery(widget.media)
            ? await pickMultipleFromGallery()
            : await pickMultipleFromFile(widget.media);
        for (final p in list) {
          await widget.onPickFile(p);
        }
        return;
      }
      final sources = <_PickSource>[
        if (canPickFromGallery(widget.media)) _PickSource.gallery,
        _PickSource.file,
        if (widget.onOpenLibrary != null) _PickSource.library,
      ];
      _PickSource? src;
      if (sources.length == 1) {
        src = sources.first;
      } else {
        src = await showModalBottomSheet<_PickSource>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in sources)
                  ListTile(
                    leading: Icon(_sourceIcon(s)),
                    title: Text(_sourceLabel(s)),
                    onTap: () => Navigator.pop(ctx, s),
                  ),
              ],
            ),
          ),
        );
      }
      if (src == null) return;
      switch (src) {
        case _PickSource.gallery:
          final picked = await pickFromGallery(widget.media);
          if (picked != null) await widget.onPickFile(picked);
        case _PickSource.file:
          final picked = await pickFromFile(widget.media);
          if (picked != null) await widget.onPickFile(picked);
        case _PickSource.library:
          final open = widget.onOpenLibrary;
          if (open == null) return;
          final rel = await open();
          if (rel != null) await widget.onPickLibrary?.call(rel);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData _sourceIcon(_PickSource s) => switch (s) {
    _PickSource.gallery => Icons.photo_library_outlined,
    _PickSource.file => Icons.folder_open,
    _PickSource.library => Icons.collections_outlined,
  };

  String _sourceLabel(_PickSource s) => switch (s) {
    _PickSource.gallery => t('editor.pick.fromGallery'),
    _PickSource.file => t('editor.pick.fromFile'),
    _PickSource.library => t('editor.pick.fromLibrary'),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showAdd = widget.multiple || widget.items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final rel in widget.items) _tileFor(context, rel),
            if (showAdd) _addTile(context),
          ],
        ),
      ],
    );
  }

  Widget _addTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: widget.enabled && !_busy ? 1 : 0.4,
      child: GestureDetector(
        onTap: _pick,
        child: Container(
          width: widget.tile,
          height: widget.tile,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: FiftyRadii.mdRadius,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: _busy
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  Icons.add,
                  size: 30,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
        ),
      ),
    );
  }

  Widget _tileFor(BuildContext context, String rel) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: FiftyRadii.mdRadius,
      child: SizedBox(
        width: widget.tile,
        height: widget.tile,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _preview(context, scheme, rel),
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: CanvasSkin.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => widget.onRemove(rel),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.close, size: 14, color: CanvasSkin.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, ColorScheme scheme, String rel) {
    final bytes = widget.bytesOf?.call(rel);
    final assetKey = widget.assetKeyOf?.call(rel);
    if (widget.media == PickerMedia.image) {
      Widget fallback(BuildContext _, Object _, StackTrace? _) => Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
      );
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: fallback,
        );
      }
      if (assetKey != null) {
        return Image.asset(
          assetKey,
          fit: BoxFit.cover,
          errorBuilder: fallback,
        );
      }
      return fallback(context, 'no-source', StackTrace.current);
    }
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.media == PickerMedia.audio
                ? Icons.audiotrack
                : Icons.videocam,
            size: 26,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              rel.split('/').last,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
