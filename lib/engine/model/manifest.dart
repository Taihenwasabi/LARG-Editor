/// 游戏包清单（Manifest）数据模型。
///
/// 对应游戏包根目录下的 `basicInfo.json`。此处的 Manifest 指"描述包自身
/// 元数据的清单文件"（身份/版本/内容入口/资格公钥等），而非 Android 的
/// AndroidManifest.xml。
library;

/// 单个可点击按钮的坐标（图片原始像素坐标系）。
class ButtonCoordinate {
  final int id;
  final double x;
  final double y;

  const ButtonCoordinate({required this.id, required this.x, required this.y});

  factory ButtonCoordinate.fromJson(Map<String, dynamic> json) {
    return ButtonCoordinate(
      id: (json['id'] as num?)?.toInt() ?? 0,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  String toString() => 'btn#$id@(${x.toStringAsFixed(0)},${y.toStringAsFixed(0)})';
}

/// 游戏包元数据。字段直接映射 `basicInfo.json`。
class Manifest {
  final String gameName;
  final String introduction;
  final List<ButtonCoordinate> buttonCoordinates;
  final String price;
  final String createTime;
  final String ageAppropriateness;
  final String publicKey;
  final String artStyle;

  /// 积分名（如"苹果币"），用于节点/排名/存档显示；缺省"积分"。
  final String points;

  /// 地图图片相对包根路径（如 `assets/picture/map.png`）；缺省空串。
  /// gameMap 界面优先用它作为底图（放在游戏包 assets 内），空则回退到 App 自带图。
  final String mapImage;

  /// 游戏唯一 id（basicInfo `Id`）；缺省空串。官方包据此比对合法名单。
  final String id;

  /// 是否官方包：'yes' / 'no'（basicInfo `official`）；缺省 'no'。
  final String official;

  const Manifest({
    required this.gameName,
    required this.introduction,
    required this.buttonCoordinates,
    required this.price,
    required this.createTime,
    required this.ageAppropriateness,
    required this.publicKey,
    required this.artStyle,
    this.points = '积分',
    this.mapImage = '',
    this.id = '',
    this.official = 'no',
  });

  /// 是否声明为官方包（仅精确 'yes'）。
  bool get isOfficial => official.trim().toLowerCase() == 'yes';

  factory Manifest.fromJson(Map<String, dynamic> json) {
    final rawButtons = json['buttonCoordinates'];
    final buttons = <ButtonCoordinate>[];
    if (rawButtons is List) {
      for (final item in rawButtons) {
        if (item is Map<String, dynamic>) {
          buttons.add(ButtonCoordinate.fromJson(item));
        }
      }
    }
    return Manifest(
      gameName: (json['gameName'] ?? '').toString(),
      introduction: (json['Introduction'] ?? json['introduction'] ?? '')
          .toString(),
      buttonCoordinates: buttons,
      price: (json['price'] ?? '').toString(),
      createTime: (json['createTime'] ?? '').toString(),
      ageAppropriateness: (json['ageAppropriateness'] ?? '').toString(),
      publicKey: (json['PublicKey'] ?? json['publicKey'] ?? '').toString(),
      artStyle: (json['artStyle'] ?? '').toString(),
      points: (json['points'] ?? '积分').toString(),
      mapImage: (json['map'] ?? json['mapImage'] ?? '').toString(),
      id: (json['Id'] ?? json['id'] ?? '').toString(),
      official: (json['official'] ?? json['Official'] ?? 'no').toString(),
    );
  }

  @override
  String toString() =>
      '$gameName | price=$price age=$ageAppropriateness artStyle=$artStyle '
      'points=$points buttons=${buttonCoordinates.length}';
}
