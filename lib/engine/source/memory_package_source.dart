/// 内存来源实现（MemoryPackageSource）。
///
/// 把游戏包的全部文件字节预先读入内存（`包名 → 相对路径 → 字节`），再以
/// 同步接口对外提供，契合引擎核心"纯 Dart、同步读取"的约定。
///
/// 典型用法：App 层用 `rootBundle` 异步读入打进 assets 的游戏包，构建本来源
/// 后注入 [GameEngine]，即可在 **web / 移动端 / 桌面** 全平台一致地解析——
/// 避免 `dart:io`（Platform / File / Directory）在 web 上抛
/// `Unsupported operation: Platform._pathSeparator`，也摆脱对开发机硬编码
/// 路径的依赖。自检脚本亦可用它注入构造数据。
///
/// 约定与 [FilesystemPackageSource] 完全一致：相对路径统一 `/` 分隔、相对包根。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package_source.dart';

/// 基于内存字典的来源实现。
class MemoryPackageSource implements PackageSource {
  @override
  final String root;

  /// `包名 → (相对包根路径 → 文件字节)`（已预载字节的文件，如 JSON）。
  final Map<String, Map<String, Uint8List>> _files;

  /// `包名 → 相对路径集合`：仅登记路径、不预载字节的文件（如图片/音频/视频等媒体）。
  ///
  /// 媒体走 Flutter 的 asset 机制按需加载（Image.asset / 播放器插件），无需在启动时
  /// 读入内存；这样启动阶段只请求 JSON，避免浏览器下载管理器（如 IDM）拦截
  /// .mp3/.mp4/.wav 等媒体请求。
  final Map<String, Set<String>> _lazyPaths;

  MemoryPackageSource({
    required this.root,
    required Map<String, Map<String, Uint8List>> files,
    Map<String, Set<String>> lazyPaths = const {},
  }) : _files = files,
       _lazyPaths = lazyPaths;

  /// 判定一个包是否为游戏包的标志文件名（与文件系统实现一致）。
  static const String manifestFileName = 'basicInfo.json';

  /// 运行期注入/覆盖一个包（供编辑器「保存到本地库」/zip 导入后即时可玩）。
  ///
  /// [files] 为「相对包根路径 → 字节」（含 JSON 与媒体原始字节）；注入后该
  /// 包即可被 [scanPackages] 发现并按现有解析链加载。
  void putPackage(String packageName, Map<String, Uint8List> files) {
    _files[packageName] = files;
    _lazyPaths.remove(packageName);
  }

  /// 是否已存在该包（内存中）。
  bool hasPackage(String packageName) => _files.containsKey(packageName);

  /// 同步取某文件的预载字节；未预载（官方包媒体仅懒登记）时返回 null。
  ///
  /// 供 App 层「按字节渲染」接缝使用：本地导入包经 [putPackage] 全量注入字节，
  /// 命中即返回；官方包媒体不在 `_files`，返回 null 由上层回退 asset bundle。
  Uint8List? tryBytes(String packageName, String relativePath) =>
      _pkg(packageName)[_norm(relativePath)];

  Map<String, Uint8List> _pkg(String packageName) =>
      _files[packageName] ?? const <String, Uint8List>{};

  /// 归一化相对路径：反斜杠转 `/`，去掉开头的 `/`。
  static String _norm(String relativePath) {
    var p = relativePath.replaceAll('\\', '/');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }

  @override
  List<String> scanPackages() {
    final names = _files.entries
        .where((e) => e.value.containsKey(manifestFileName))
        .map((e) => e.key)
        .toList();
    names.sort();
    return names;
  }

  @override
  bool packageExists(String packageName) => _files.containsKey(packageName);

  @override
  List<String> listFiles(String packageName, String relativeDir) {
    final dir = _norm(relativeDir);
    final prefix = dir.isEmpty ? '' : '$dir/';
    // 合并"已预载字节"与"仅登记路径"的文件
    final all = <String>{
      ..._pkg(packageName).keys,
      ...(_lazyPaths[packageName] ?? const <String>{}),
    };
    final result = all.where((k) {
      if (prefix.isEmpty) return true;
      // 命中该目录下的文件（含更深层子目录）
      return k.startsWith(prefix) && k.length > prefix.length;
    }).toList();
    result.sort();
    return result;
  }

  @override
  bool fileExists(String packageName, String relativePath) {
    final p = _norm(relativePath);
    return _pkg(packageName).containsKey(p) ||
        (_lazyPaths[packageName]?.contains(p) ?? false);
  }

  @override
  String readText(String packageName, String relativePath) =>
      utf8.decode(readBytes(packageName, relativePath));

  @override
  Uint8List readBytes(String packageName, String relativePath) {
    final bytes = _pkg(packageName)[_norm(relativePath)];
    if (bytes == null) {
      throw StateError('内存来源缺少文件: $packageName/$relativePath');
    }
    return bytes;
  }

  @override
  int fileSize(String packageName, String relativePath) {
    // 懒登记（无预载字节）的文件返回 0：AssetResolver 据此跳过读字节解析元数据。
    return _pkg(packageName)[_norm(relativePath)]?.length ?? 0;
  }
}
