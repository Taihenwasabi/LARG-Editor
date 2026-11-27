import 'dart:typed_data';

import 'package:larg_editor/model/game_item.dart';

class CompressedPart {
  final Uint8List bytes;
  final String mime;

  const CompressedPart({required this.bytes, required this.mime});
}

class CompressedItem {
  final GameItemKind kind;
  final List<CompressedPart> parts;

  const CompressedItem({required this.kind, required this.parts});

  int get totalBytes => parts.fold(0, (sum, e) => sum + e.bytes.length);
}
