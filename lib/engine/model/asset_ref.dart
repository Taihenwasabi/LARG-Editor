/// 资源引用（AssetRef）模型。
///
/// 扫描 `assets/` 目录得到的每个文件都登记为一个 AssetRef：记录相对路径、
/// 类别、扩展名、字节数；对可结构化解析的类型（glb/mp4/png/wav）附带
/// [AssetInfo] 元数据，其余类型（fbx/txt 等）仅登记路径不深解析。
library;

import 'asset_info.dart';

/// 资源类别。
enum AssetCategory { model, video, picture, audio, other }

/// 一个资源文件的登记项。
class AssetRef {
  /// 相对游戏包根目录的路径（如 `assets/model/xiaohui.glb`）。
  final String relativePath;

  /// 文件名（含扩展名）。
  final String fileName;

  /// 扩展名（小写，不含点，如 `glb`）。
  final String extension;

  final AssetCategory category;
  final int sizeBytes;

  /// 结构化元数据；不可解析的类型为 null。
  final AssetInfo? info;

  const AssetRef({
    required this.relativePath,
    required this.fileName,
    required this.extension,
    required this.category,
    required this.sizeBytes,
    this.info,
  });

  /// 依据扩展名推断资源类别。
  static AssetCategory categoryOf(String ext) {
    switch (ext) {
      case 'glb':
      case 'gltf':
      case 'fbx':
      case 'obj':
        return AssetCategory.model;
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'webm':
        return AssetCategory.video;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'gif':
      case 'bmp':
        return AssetCategory.picture;
      case 'wav':
      case 'mp3':
      case 'ogg':
      case 'm4a':
        return AssetCategory.audio;
      default:
        return AssetCategory.other;
    }
  }

  @override
  String toString() {
    final head = '$fileName [${category.name}] ${sizeBytes}B';
    return info == null ? head : '$head → $info';
  }
}
