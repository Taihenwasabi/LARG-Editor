
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/service/file_pick_service.dart';
import 'package:larg_editor/service/media_store.dart';

bool isImagePath(String p) {
  final k = p.toLowerCase();
  return k.endsWith('.png') ||
      k.endsWith('.jpg') ||
      k.endsWith('.jpeg') ||
      k.endsWith('.gif') ||
      k.endsWith('.webp') ||
      k.endsWith('.bmp');
}

bool isAudioPath(String p) {
  final k = p.toLowerCase();
  return k.endsWith('.mp3') ||
      k.endsWith('.wav') ||
      k.endsWith('.ogg') ||
      k.endsWith('.m4a') ||
      k.endsWith('.aac') ||
      k.endsWith('.flac');
}

bool isVideoPath(String p) {
  final k = p.toLowerCase();
  return k.endsWith('.mp4') ||
      k.endsWith('.webm') ||
      k.endsWith('.mov') ||
      k.endsWith('.ogv') ||
      k.endsWith('.avi') ||
      k.endsWith('.mkv');
}


String mediaRelPath(String fileName) {
  final folder = isImagePath(fileName)
      ? 'picture'
      : isAudioPath(fileName)
      ? 'audio'
      : isVideoPath(fileName)
      ? 'video'
      : 'misc';
  return 'assets/$folder/$fileName';
}


Future<String?> importPackMedia(
  EditablePack pack,
  PickedFileData picked, {
  bool toLibrary = false,
}) async {
  final rel = mediaRelPath(picked.name);
  if (toLibrary) {
    pack.addImportedMedia(rel, picked.bytes);
  } else {
    pack.putImportedMedia(rel, picked.bytes);
  }
  try {
    await cacheMedia('${pack.mediaKey}/$rel', picked.bytes);
  } catch (_) {

  }
  return rel;
}


Future<List<String>> importMediaFromDevice(
  EditablePack pack, {
  PickerMedia? kind,
  String? category,
}) async {
  final picked = <PickedFileData>[];
  if (kind == null) {
    if (canPickMultipleFromGallery(PickerMedia.image)) {
      picked.addAll(await pickMultipleFromGallery());
    } else {
      picked.addAll(await pickMultipleAnyFile());
    }
  } else if (canPickMultipleFromGallery(kind)) {
    picked.addAll(await pickMultipleFromGallery());
  } else {
    picked.addAll(await pickMultipleFromFile(kind));
  }
  final matches = kind == null
      ? picked
      : picked.where((f) => switch (kind) {
          PickerMedia.image => isImagePath(f.name),
          PickerMedia.audio => isAudioPath(f.name),
          PickerMedia.video => isVideoPath(f.name),
        });
  final rels = <String>[];
  for (final f in matches) {
    final rel = await importPackMedia(pack, f, toLibrary: true);
    if (rel == null) continue;
    if (category != null && category.isNotEmpty) {
      pack.mediaCategory[rel] = category;
    }
    rels.add(rel);
  }
  if (rels.isNotEmpty) pack.notify();
  return rels;
}

Widget editorAssetImage(
  BuildContext context,
  EditablePack pack,
  String rel, {
  BoxFit fit = BoxFit.cover,
}) {
  final scheme = Theme.of(context).colorScheme;
  Widget fallback() => Container(
    color: scheme.surfaceContainerHighest,
    child: Icon(
      Icons.broken_image_outlined,
      size: 16,
      color: scheme.onSurfaceVariant,
    ),
  );
  final bytes = pack.importedMedia[rel];
  if (bytes != null) {
    return Image.memory(bytes, fit: fit, errorBuilder: (_, _, _) => fallback());
  }
  final key = pack.assetKeyFor(rel);
  if (key == null) return fallback();
  return Image.asset(key, fit: fit, errorBuilder: (_, _, _) => fallback());
}


Future<void> hydratePackMedia(EditablePack pack) async {
  for (final rel in pack.mediaPaths) {
    final key = '${pack.mediaKey}/$rel';
    final held = pack.importedMedia[rel];
    if (held != null) {
      try {
        final cached = await loadCachedMedia(key);
        if (cached == null) await cacheMedia(key, held);
      } catch (_) {}
      continue;
    }
    try {
      final b = await loadCachedMedia(key);
      if (b != null) {
        pack.importedMedia[rel] = b;
      } else if (!pack.mediaKey.startsWith('official-')) {
        final legacy = await loadCachedMedia(rel);
        if (legacy != null) {
          pack.importedMedia[rel] = legacy;
          await cacheMedia(key, legacy);
        }
      }
    } catch (_) {}
  }
  pack.notify();
}
