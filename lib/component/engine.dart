/// 游戏包解析引擎 —— 门面（Facade）+ barrel 导出。
///
/// 这是引擎对外的唯一入口，**保持纯 Dart（不 import flutter）**，因此可用
/// `dart run tool/verify_engine.dart` 独立自检，无需启动整个 App。
///
/// 对外能力：
/// - [GameEngine.configure] 设置可配置根目录（及可选的校验器/token 注入）；
/// - [GameEngine.listPackages] 列出根目录下的可用包；
/// - [GameEngine.load] 加载并解析一个包，返回 [GamePackage]。
///
/// App 层只需 `import 'package:quq1/component/engine.dart';` 即可拿到全部
/// 公开类型（模型/来源/校验/异常/日志），无需深入 lib/engine/ 内部路径。
library;

import '../engine/engine_log.dart';
import '../engine/model/game_package.dart';
import '../engine/package_loader.dart';
import '../engine/security/license_verifier.dart';
import '../engine/source/package_source.dart';

// ---- barrel：对外统一导出引擎公开 API ----
export '../engine/engine_exception.dart';
export '../engine/engine_log.dart';
export '../engine/model/asset_info.dart';
export '../engine/model/asset_ref.dart';
export '../engine/model/check.dart';
export '../engine/model/game_package.dart';
export '../engine/model/manifest.dart';
export '../engine/model/package_summary.dart';
export '../engine/model/scene.dart';
export '../engine/model/stage.dart';
export '../engine/model/story_item.dart';
export '../engine/package_loader.dart';
export '../engine/security/license_verifier.dart';
export '../engine/security/package_provenance.dart';
export '../engine/source/memory_package_source.dart';
export '../engine/source/package_source.dart';

/// 游戏包解析引擎门面。
class GameEngine {
  PackageSource? _source;
  LicenseVerifier _licenseVerifier;
  TokenProvider? _tokenProvider;

  /// 创建一个引擎实例。可先不传 root，稍后调用 [configure]。
  GameEngine({
    String? root,
    LicenseVerifier licenseVerifier = const DemoLicenseVerifier(),
    TokenProvider? tokenProvider,
  }) : _licenseVerifier = licenseVerifier,
       _tokenProvider = tokenProvider {
    if (root != null) configure(root);
  }

  /// 配置可配置根目录；可选注入资格校验器与 token 提供器（依赖注入点）。
  void configure(
    String root, {
    LicenseVerifier? licenseVerifier,
    TokenProvider? tokenProvider,
  }) {
    _source = FilesystemPackageSource(root);
    if (licenseVerifier != null) _licenseVerifier = licenseVerifier;
    if (tokenProvider != null) _tokenProvider = tokenProvider;
    EngineLog.log('根目录 = $root');
  }

  /// 直接注入一个来源实现（与 [configure] 二选一）。
  ///
  /// App 层可注入基于 assets 的 [MemoryPackageSource]，从而在 web 等
  /// 不支持 `dart:io` 文件系统的平台上也能一致地解析游戏包。
  void useSource(
    PackageSource source, {
    LicenseVerifier? licenseVerifier,
    TokenProvider? tokenProvider,
  }) {
    _source = source;
    if (licenseVerifier != null) _licenseVerifier = licenseVerifier;
    if (tokenProvider != null) _tokenProvider = tokenProvider;
    EngineLog.log('来源 = ${source.root}');
  }

  /// 当前根目录（未配置时返回 null）。
  String? get root => _source?.root;

  PackageLoader get _loader =>
      PackageLoader(
        source: _requireSource(),
        licenseVerifier: _licenseVerifier,
        tokenProvider: _tokenProvider,
      );

  /// 列出根目录下所有可用游戏包名。
  List<String> listPackages() => _loader.listPackages();

  /// 加载并解析指定游戏包。
  GamePackage load(String packageName) => _loader.load(packageName);

  PackageSource _requireSource() {
    final s = _source;
    if (s == null) {
      throw StateError('GameEngine 未配置根目录，请先调用 configure(root)');
    }
    return s;
  }
}
