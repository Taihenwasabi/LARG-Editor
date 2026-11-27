import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createItemVideoController(
  List<int> bytes,
  String mime,
) async {
  final dir = await getTemporaryDirectory();
  final suffix = _suffix(mime);
  final file = File(
    '${dir.path}${Platform.pathSeparator}larg-${DateTime.now().microsecondsSinceEpoch}.$suffix',
  );
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  final controller = VideoPlayerController.file(file);
  await controller.initialize();
  return controller;
}

String _suffix(String mime) {
  if (mime.contains('webm')) return 'webm';
  if (mime.contains('quicktime')) return 'mov';
  if (mime.contains('ogg')) return 'ogv';
  return 'mp4';
}
