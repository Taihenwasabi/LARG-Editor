/// 引擎异常类型。
///
/// 用类型区分失败原因，便于上层（前端/自检脚本）分别处理：
/// - [PackageNotFoundException]：指定包目录不存在；
/// - [PackageFormatException]：包内数据格式非法（JSON 解析失败、必需字段缺失、
///   二进制容器头不符等）。本项目不做容错解析，数据须先修正为合法格式；
/// - [LicenseException]：资格校验未通过。
library;

/// 引擎异常基类。
abstract class EngineException implements Exception {
  final String message;
  const EngineException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// 找不到指定的游戏包。
class PackageNotFoundException extends EngineException {
  final String packageName;
  const PackageNotFoundException(this.packageName, super.message);
}

/// 游戏包数据格式非法。
class PackageFormatException extends EngineException {
  /// 出问题的文件相对路径（若可知）。
  final String? source;
  const PackageFormatException(super.message, {this.source});
}

/// 资格（License）校验失败。
class LicenseException extends EngineException {
  const LicenseException(super.message);
}
