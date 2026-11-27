/// 游戏包来源加载器（App 层）。
///
/// 把打进 Flutter assets 的 `gamepacks/` 目录异步读入内存，构建引擎的
/// [MemoryPackageSource]。这样引擎在 **web / 移动端 / 桌面** 上都能一致解析：
/// - web 上 `dart:io` 的 `Platform._pathSeparator` / `File` / `Directory` 会抛
///   `Unsupported operation`，文件系统来源不可用；
/// - 硬编码的开发机路径（如 `d:\AProGRAM\quq1\gamepacks`）在手机上并不存在。
///
/// 依赖注入方向：本类属于 App 层（可用 flutter/services），引擎核心仍保持纯 Dart。
library;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:larg_editor/component/engine.dart';

/// 从 assets 构建游戏包内存来源，并作为 App 层的全局引擎入口。
class GamePackages {
  GamePackages._();

  /// assets 中游戏包的根前缀（对应 pubspec.yaml 里声明的 `gamepacks/...`）。
  static const String assetPrefix = 'gamepacks';

  /// 构造包内某个文件的 Flutter asset key（与 pubspec 声明、AssetManifest 一致）。
  ///
  /// 例：`assetKey('jubenyouEg2', 'assets/picture/x.png')`
  /// → `gamepacks/jubenyouEg2/assets/picture/x.png`，可直接用于
  /// `Image.asset` / `VideoPlayerController.asset` / audioplayers。
  static String assetKey(String packageName, String relativePath) =>
      '$assetPrefix/$packageName/$relativePath';

  /// 按 Flutter asset key 取「内存来源已持有」的媒体字节（本地导入包）。
  ///
  /// assetKey 形如 `gamepacks/<包名>/<相对路径>`；命中内存则返回字节，否则返回
  /// null（官方包媒体不在内存、或非 `gamepacks/` 的 App 自带图）。上层据此在
  /// `Image.memory` / 临时文件 与 `Image.asset` / asset 控制器之间自动切换。
  static Uint8List? tryMediaBytes(String assetKey) {
    final mem = _memSource;
    if (mem == null) return null;
    if (!assetKey.startsWith('$assetPrefix/')) return null;
    final rest = assetKey.substring(assetPrefix.length + 1); // 去 'gamepacks/'
    final slash = rest.indexOf('/');
    if (slash <= 0) return null;
    final pkg = rest.substring(0, slash);
    final rel = rest.substring(slash + 1);
    return mem.tryBytes(pkg, rel);
  }

  /// 全局引擎单例（注入基于 assets 的内存来源）。
  ///
  /// 本工具无后端，不涉及登录态：资格校验用引擎自带的内存 token 占位，
  /// 真正的 PublicKey 校验由 [LicenseVerifier] 实现决定，与登录无关。
  static final GameEngine engine = GameEngine(
    tokenProvider: InMemoryTokenProvider('larg-editor-local'),
  );

  static PackageSource? _source;
  static MemoryPackageSource? _memSource;

  /// 确保引擎已注入 assets 来源（幂等；来源只构建一次并缓存）。
  static Future<GameEngine> ensureEngine() async {
    if (_source == null) {
      final src = await loadAssetSource();
      _source = src;
      _memSource = src is MemoryPackageSource ? src : null;
      engine.useSource(src);
    }
    return engine;
  }

  /// 把一份本地 zip 游戏包解码后注入引擎内存来源，使其可像内置包一样被
  /// [loadPackage] 解析游玩。需先 [ensureEngine]。
  static Future<void> registerLocalPackage(String name, Uint8List zipBytes) async {
    await ensureEngine();
    final mem = _memSource;
    if (mem == null) return;
    final files = <String, Uint8List>{};
    for (final f in ZipDecoder().decodeBytes(zipBytes)) {
      if (!f.isFile) continue;
      var path = f.name.replaceAll(r'\', '/');
      while (path.startsWith('/')) {
        path = path.substring(1);
      }
      final slash = path.indexOf('/');
      if (slash <= 0) continue;
      files[path.substring(slash + 1)] = Uint8List.fromList(f.content as List<int>);
    }
    if (files.isEmpty) return;
    mem.putPackage(name, files);
  }

  /// 按包名加载游戏包（确保引擎就绪）。用于选包与读档恢复。
  static Future<GamePackage> loadPackage(String packageName) async {
    final e = await ensureEngine();
    return e.load(packageName);
  }

  /// 枚举 assets 的 gamepacks/ 下全部包名（AssetManifest 路径首段去重）。
  static Future<List<String>> bundledPackageKeys() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final set = <String>{};
    for (final k in manifest.listAssets()) {
      if (!k.startsWith('$assetPrefix/')) continue;
      final rel = k.substring(assetPrefix.length + 1);
      final slash = rel.indexOf('/');
      if (slash <= 0) continue;
      set.add(rel.substring(0, slash));
    }
    return set.toList()..sort();
  }

  /// 读取内嵌包某文件的字节（不存在返回 null）。
  static Future<Uint8List?> readBundledFile(
    String packageKey,
    String relPath,
  ) async {
    try {
      final bd = await rootBundle.load(assetKey(packageKey, relPath));
      return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  /// 把「文件夹形态」外部包（相对路径 → 字节）直接注入内存来源。
  /// 供 Windows / 桌面等外部 gamepacks 目录的自动检测使用。
  static Future<void> registerFolderPackFiles(
    String name,
    Map<String, Uint8List> files,
  ) async {
    await ensureEngine();
    if (files.isEmpty || _memSource == null) return;
    _memSource!.putPackage(name, files);
  }

  /// 扫描 assets 里的全部游戏包，读入内存并返回一个 [MemoryPackageSource]。
  ///
  /// 通过 [AssetManifest] 枚举所有以 `gamepacks/` 开头的资源键，按键的第一段
  /// 作为包名、其余作为相对包根路径，逐个 `rootBundle.load` 读入字节。
  static Future<PackageSource> loadAssetSource() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest
        .listAssets()
        .where((k) => k.startsWith('$assetPrefix/'))
        .toList()
      ..sort();

    final files = <String, Map<String, Uint8List>>{};
    final lazy = <String, Set<String>>{};
    var jsonCount = 0;
    var lazyCount = 0;
    for (final key in keys) {
      final rel = key.substring(assetPrefix.length + 1); // 去掉 'gamepacks/'
      final slash = rel.indexOf('/');
      if (slash <= 0) continue; // 需要 <包名>/<相对路径...> 结构
      final pkg = rel.substring(0, slash);
      final path = rel.substring(slash + 1);
      if (path.isEmpty) continue;

      if (path.toLowerCase().endsWith('.json')) {
        // 只预载 JSON（basicInfo/stage/check）字节：引擎解析所需，且不触发下载器拦截
        final bd = await rootBundle.load(key);
        final bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
        files.putIfAbsent(pkg, () => <String, Uint8List>{})[path] = bytes;
        jsonCount++;
      } else {
        // 其它媒体（图片/音频/视频/模型）只登记路径，播放时由 Flutter asset 机制按需加载
        lazy.putIfAbsent(pkg, () => <String>{}).add(path);
        lazyCount++;
      }
    }

    EngineLog.log(
      'assets 包来源：发现 ${files.length} 个包 / JSON $jsonCount 个（预载）'
      ' / 媒体 $lazyCount 个（懒加载）'
      '${files.isEmpty ? '（请确认 pubspec.yaml 已声明 gamepacks/ 资源目录）' : ''}',
    );
    return MemoryPackageSource(
      root: 'asset://$assetPrefix',
      files: files,
      lazyPaths: lazy,
    );
  }
}
