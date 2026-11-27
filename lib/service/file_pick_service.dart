/// 跨平台「选文件」服务。
///
/// - 文件：`file_picker`，桌面全平台可用。
/// - 相册：LARG Editor 是桌面工具，无系统图库概念，故不提供。
///
/// 业务层统一拿回 [PickedFileData]（文件名 + 字节），不感知具体插件。
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 媒体类别。
enum PickerMedia { image, audio, video }

/// 一次选中的文件（名字 + 字节）。
class PickedFileData {
  final String name;
  final Uint8List bytes;
  const PickedFileData(this.name, this.bytes);
}

/// 当前平台能否「从相册选择」。桌面工具恒为 false。
bool canPickFromGallery(PickerMedia media) => false;

/// 当前平台能否「从相册多选」。桌面工具恒为 false。
bool canPickMultipleFromGallery(PickerMedia media) => false;

/// 从「相册」选（桌面无相册概念，退化为从文件系统选同类文件）。
Future<PickedFileData?> pickFromGallery(PickerMedia media) =>
    pickFromFile(media);

/// 从「相册」多选（桌面无相册概念，退化为从文件系统选同类文件）。
Future<List<PickedFileData>> pickMultipleFromGallery() =>
    pickMultipleAnyFile();

List<String> _extsFor(PickerMedia media) => switch (media) {
  PickerMedia.image => const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
  PickerMedia.audio => const ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'],
  PickerMedia.video => const ['mp4', 'webm', 'mov', 'ogv', 'avi', 'mkv'],
};

/// 从系统文件选择（单个）。取消返回 null。
Future<PickedFileData?> pickFromFile(PickerMedia media) async {
  final res = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: _extsFor(media),
  );
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  final bytes = f.bytes;
  if (bytes == null) return null;
  return PickedFileData(f.name, Uint8List.fromList(bytes));
}

/// 从系统文件选择（多个，图片/音频/视频全放开）。取消返回空列表。
Future<List<PickedFileData>> pickMultipleAnyFile() async {
  final res = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
    type: FileType.custom,
    allowedExtensions: [
      ..._extsFor(PickerMedia.image),
      ..._extsFor(PickerMedia.audio),
      ..._extsFor(PickerMedia.video),
    ],
  );
  if (res == null) return const [];
  final out = <PickedFileData>[];
  for (final f in res.files) {
    final bytes = f.bytes;
    if (bytes == null) continue;
    out.add(PickedFileData(f.name, Uint8List.fromList(bytes)));
  }
  return out;
}

/// 从系统文件选择（多个）。取消返回空列表。
Future<List<PickedFileData>> pickMultipleFromFile(PickerMedia media) async {
  final res = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
    type: FileType.custom,
    allowedExtensions: _extsFor(media),
  );
  if (res == null) return const [];
  final out = <PickedFileData>[];
  for (final f in res.files) {
    final bytes = f.bytes;
    if (bytes == null) continue;
    out.add(PickedFileData(f.name, Uint8List.fromList(bytes)));
  }
  return out;
}
