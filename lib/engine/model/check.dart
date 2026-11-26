/// 校验声明（Check）数据模型。
///
/// 对应游戏包 `check/*.json`。引擎只承认"声明式 JSON"——即关卡通过
/// `check:"check1"` 引用一个 id，具体校验规则（类型/参数/校验方）完全由
/// JSON 描述，引擎不执行任何随包的 Dart 逻辑（Release 包也无法执行）。
library;

/// 一条声明式校验规则。
class Check {
  /// 校验 id：取文件名去扩展名（如 `check1`）。
  final String id;

  /// 校验类型：如 photo_submit / text_answer。
  final String type;

  /// 校验方：server（提交后端）或 local（本地判定）。
  final String verify;

  /// 其余参数原样保留（如 requireCount、answer 等），供运行时按需取用。
  final Map<String, dynamic> params;

  const Check({
    required this.id,
    required this.type,
    required this.verify,
    required this.params,
  });

  /// 从合法 JSON 对象构造。[id] 由调用方（解析器）依据文件名传入。
  factory Check.fromJson(String id, Map<String, dynamic> json) {
    final params = Map<String, dynamic>.from(json)
      ..remove('type')
      ..remove('verify');
    return Check(
      id: id,
      type: (json['type'] ?? '').toString(),
      verify: (json['verify'] ?? 'local').toString(),
      params: params,
    );
  }

  @override
  String toString() => '$id($type,$verify)';
}
