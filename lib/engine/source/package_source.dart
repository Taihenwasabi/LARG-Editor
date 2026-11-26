/// 游戏包来源抽象（PackageSource）与文件系统实现。
///
/// 引擎核心通过该抽象读取包内容，不直接依赖 dart:io，便于日后替换为
/// 网络源/内存源（自检脚本可注入内存实现）。默认实现
/// [FilesystemPackageSource] 按可配置根目录从本地文件系统读包。
///
/// 约定：所有相对路径统一使用 `/` 分隔符，且相对于"包根目录"。
library;

import 'dart:io';
import 'dart:typed_data';

/// 游戏包来源抽象。
abstract class PackageSource {
  /// 根目录（其下每个含 `basicInfo.json` 的子目录即一个包）。
  String get root;

  /// 扫描根目录，返回所有可用包名（目录名）。
  List<String> scanPackages();

  /// 指定包是否存在。
  bool packageExists(String packageName);

  /// 递归列出包内某目录下的所有文件，返回相对包根的路径（`/` 分隔）。
  /// 目录不存在时返回空列表。
  List<String> listFiles(String packageName, String relativeDir);

  /// 包内某文件是否存在。
  bool fileExists(String packageName, String relativePath);

  /// 读取文本内容（UTF-8）。
  String readText(String packageName, String relativePath);

  /// 读取二进制内容。
  Uint8List readBytes(String packageName, String relativePath);

  /// 文件字节数。
  int fileSize(String packageName, String relativePath);
}

/// 基于本地文件系统的来源实现。
class FilesystemPackageSource implements PackageSource {
  /// 判定一个目录是否为游戏包的标志文件名。
  static const String manifestFileName = 'basicInfo.json';

  @override
  final String root;

  FilesystemPackageSource(this.root);

  /// 拼出包内某相对路径的绝对路径。
  String _abs(String packageName, String relativePath) {
    final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
    return '$root${Platform.pathSeparator}$packageName'
        '${Platform.pathSeparator}$normalized';
  }

  /// 包根目录绝对路径。
  String packageRoot(String packageName) =>
      '$root${Platform.pathSeparator}$packageName';

  @override
  List<String> scanPackages() {
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) return const [];
    final result = <String>[];
    for (final entity in rootDir.listSync()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      final manifest = File(
        '${entity.path}${Platform.pathSeparator}$manifestFileName',
      );
      if (manifest.existsSync()) result.add(name);
    }
    result.sort();
    return result;
  }

  @override
  bool packageExists(String packageName) =>
      Directory(packageRoot(packageName)).existsSync();

  @override
  List<String> listFiles(String packageName, String relativeDir) {
    final pkgRoot = packageRoot(packageName);
    final dirPath = relativeDir.isEmpty
        ? pkgRoot
        : '$pkgRoot${Platform.pathSeparator}'
              '${relativeDir.replaceAll('/', Platform.pathSeparator)}';
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];
    final result = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      // 相对包根，统一 `/` 分隔
      var rel = entity.path.substring(pkgRoot.length);
      while (rel.startsWith(Platform.pathSeparator)) {
        rel = rel.substring(1);
      }
      result.add(rel.replaceAll(Platform.pathSeparator, '/'));
    }
    result.sort();
    return result;
  }

  @override
  bool fileExists(String packageName, String relativePath) =>
      File(_abs(packageName, relativePath)).existsSync();

  @override
  String readText(String packageName, String relativePath) =>
      File(_abs(packageName, relativePath)).readAsStringSync();

  @override
  Uint8List readBytes(String packageName, String relativePath) =>
      File(_abs(packageName, relativePath)).readAsBytesSync();

  @override
  int fileSize(String packageName, String relativePath) =>
      File(_abs(packageName, relativePath)).lengthSync();
}
