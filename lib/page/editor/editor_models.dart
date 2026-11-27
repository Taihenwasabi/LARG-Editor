
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:larg_editor/engine/package_io.dart';
import 'package:larg_editor/engine/model/effects.dart';
import 'package:larg_editor/store/game_packages.dart';


String generateGameId() {
  final rnd = Random();
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final suffix = List.generate(
    6,
    (_) => rnd.nextInt(36).toRadixString(36),
  ).join();
  return 'g-$ts-$suffix';
}


class PackIssue {
  final String code;
  final String detail;
  const PackIssue(this.code, [this.detail = '']);
}


class EditableButtonCoord {
  int id;
  double x;
  double y;

  EditableButtonCoord({required this.id, required this.x, required this.y});

  factory EditableButtonCoord.fromJson(Map<String, dynamic> j) =>
      EditableButtonCoord(
        id: (j['id'] as num?)?.toInt() ?? 0,
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'x': x, 'y': y};

  EditableButtonCoord clone() =>
      EditableButtonCoord(id: id, x: x, y: y);
}


class EditableManifest {
  String gameName;
  String introduction;
  String price;
  String createTime;
  String ageAppropriateness;
  String publicKey;
  String artStyle;
  String map;
  List<EditableButtonCoord> buttonCoordinates;


  String id;


  String official;


  final Map<String, dynamic> _extras;

  EditableManifest({
    this.gameName = '',
    this.introduction = '',
    this.price = '0',
    this.createTime = '',
    this.ageAppropriateness = '12+',
    this.publicKey = '',
    this.artStyle = '',
    this.map = '',
    this.id = '',
    this.official = 'no',
    List<EditableButtonCoord>? buttonCoordinates,
    Map<String, dynamic>? extras,
  }) : buttonCoordinates = buttonCoordinates ?? <EditableButtonCoord>[],
       _extras = extras ?? <String, dynamic>{};


  bool get isOfficial => official.trim().toLowerCase() == 'yes';

  static const Set<String> _known = {
    'gameName',
    'Introduction',
    'introduction',
    'price',
    'createTime',
    'ageAppropriateness',
    'PublicKey',
    'publicKey',
    'artStyle',
    'map',
    'mapImage',
    'buttonCoordinates',
    'Id',
    'id',
    'official',
    'Official',
  };

  factory EditableManifest.fromJson(Map<String, dynamic> j) {
    final buttons = <EditableButtonCoord>[];
    final raw = j['buttonCoordinates'];
    if (raw is List) {
      for (final it in raw) {
        if (it is Map) {
          buttons.add(
            EditableButtonCoord.fromJson(Map<String, dynamic>.from(it)),
          );
        }
      }
    }
    final extras = <String, dynamic>{
      for (final e in j.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    };
    return EditableManifest(
      gameName: (j['gameName'] ?? '').toString(),
      introduction: (j['Introduction'] ?? j['introduction'] ?? '').toString(),
      price: (j['price'] ?? '0').toString(),
      createTime: (j['createTime'] ?? '').toString(),
      ageAppropriateness: (j['ageAppropriateness'] ?? '').toString(),
      publicKey: (j['PublicKey'] ?? j['publicKey'] ?? '').toString(),
      artStyle: (j['artStyle'] ?? '').toString(),
      map: (j['map'] ?? j['mapImage'] ?? '').toString(),
      id: (j['Id'] ?? j['id'] ?? '').toString(),
      official: (j['official'] ?? j['Official'] ?? 'no').toString(),
      buttonCoordinates: buttons,
      extras: extras,
    );
  }

  Map<String, dynamic> toJson() => {
    ..._extras,
    'gameName': gameName,
    'Introduction': introduction,
    'buttonCoordinates': [for (final b in buttonCoordinates) b.toJson()],
    'price': price,
    'createTime': createTime,
    'ageAppropriateness': ageAppropriateness,
    'PublicKey': publicKey,
    'artStyle': artStyle,
    'map': map,
    'Id': id,
    'official': official,
  };

  EditableManifest clone() => EditableManifest.fromJson(toJson());
}


class EditableLine {
  String type;
  String speaker;
  String text;
  String image;
  String audio;
  String video;
  String background;
  List<EditableSprite> sprites;
  bool declaresSprites;
  String id;

  /// 特效声明（原始 JSON 列表）。编辑器不改则原样往返，预览据此播放。
  final List<Map<String, dynamic>> fxRaw;

  /// 解析后的特效（引擎单一实现，编辑器只读使用）。
  List<FxSpec> get fx => parseFxList(fxRaw);

  bool open = false;

  EditableLine({
    this.type = 'narration',
    this.speaker = '',
    this.text = '',
    this.image = '',
    this.audio = '',
    this.video = '',
    this.background = '',
    List<EditableSprite>? sprites,
    bool? declaresSprites,
    this.id = '',
    List<Map<String, dynamic>>? fxRaw,
  }) : sprites = sprites ?? <EditableSprite>[],
       declaresSprites = declaresSprites ?? (sprites?.isNotEmpty ?? false),
       fxRaw = fxRaw ?? <Map<String, dynamic>>[];

  factory EditableLine.fromJson(Map<String, dynamic> j) {
    final rawSprites = j['sprites'];
    final rawFx = j['fx'];
    return EditableLine(
      id: (j['lineId'] ?? j['id'] ?? '').toString().trim(),
      type: (j['type'] ?? 'narration').toString(),
      speaker: (j['speaker'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      image: (j['image'] ?? '').toString(),
      audio: (j['audio'] ?? '').toString(),
      video: (j['video'] ?? '').toString(),
      background: (j['background'] ?? '').toString(),
      sprites: [
        if (rawSprites is List)
          for (final it in rawSprites)
            if (it is Map)
              EditableSprite.fromJson(Map<String, dynamic>.from(it)),
      ],
      declaresSprites: rawSprites is List,
      fxRaw: [
        if (rawFx is List)
          for (final f in rawFx)
            if (f is Map) Map<String, dynamic>.from(f),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'lineId': id,
    'type': type,
    if (type == 'dialogue' && speaker.isNotEmpty) 'speaker': speaker,
    'text': text,
    if (image.isNotEmpty) 'image': image,
    if (audio.isNotEmpty) 'audio': audio,
    if (video.isNotEmpty) 'video': video,
    if (background.isNotEmpty) 'background': background,
    if (declaresSprites) 'sprites': [
      for (final s in sprites)
        if (s.asset.isNotEmpty) s.toJson(),
    ],
    if (fxRaw.isNotEmpty) 'fx': fxRaw,
  };

  EditableLine clone() => EditableLine.fromJson(toJson());


  static EditableLine inheritFrom(EditableLine? prev) {
    final sp = prev?.speaker.trim() ?? '';
    if (sp.isNotEmpty) return EditableLine(type: 'dialogue', speaker: sp);
    return EditableLine();
  }
}


class EditableSprite {
  String asset;
  String position;

  /// 立绘槽位（特效 `target: sprite:<slot>` 寻址）。
  String slot;

  EditableSprite({
    this.asset = '',
    this.position = 'center',
    this.slot = '',
  });

  factory EditableSprite.fromJson(Map<String, dynamic> j) => EditableSprite(
    asset: (j['asset'] ?? '').toString(),
    position: (j['position'] ?? 'center').toString(),
    slot: (j['slot'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'asset': asset,
    'position': position,
    if (slot.isNotEmpty) 'slot': slot,
  };

  EditableSprite clone() => EditableSprite.fromJson(toJson());
}


class EditableConditionRow {
  String item;
  String op;
  int value;

  EditableConditionRow({this.item = '', this.op = '>=', this.value = 1});

  static final RegExp _pattern = RegExp(
    r'^\s*([^\s<>=!]+)\s*(>=|<=|==|!=|>|<|=)?\s*(-?\d+)?\s*$',
  );

  static List<EditableConditionRow> parse(String source) {
    final text = source.trim();
    if (text.isEmpty) return <EditableConditionRow>[];
    final rows = <EditableConditionRow>[];
    for (final part in text.split('&&')) {
      final m = _pattern.firstMatch(part);
      if (m == null) {
        rows.add(EditableConditionRow(item: part.trim(), op: '', value: 0));
        continue;
      }
      var op = m.group(2) ?? '>=';
      if (op == '=') op = '==';
      rows.add(
        EditableConditionRow(
          item: m.group(1) ?? '',
          op: op,
          value: int.tryParse(m.group(3) ?? '') ?? 1,
        ),
      );
    }
    return rows;
  }

  bool get isRaw => op.isEmpty;

  String serialize() =>
      isRaw ? item.trim() : '$item$op$value';
}


class EditableCheckpoint {
  String text;
  String next;
  String condition;
  String check;
  int reward;


  Map<String, int> grant;

  final Map<String, dynamic> _extras;

  static const Set<String> _known = {
    'text',
    'next',
    'condition',
    'check',
    'reward',
    'grant',
  };

  EditableCheckpoint({
    this.text = '',
    this.next = '',
    this.condition = '',
    this.check = '',
    this.reward = 0,
    Map<String, int>? grant,
    Map<String, dynamic>? extras,
  }) : grant = grant ?? <String, int>{},
       _extras = extras ?? <String, dynamic>{};

  factory EditableCheckpoint.fromJson(Map<String, dynamic> j) {
    final extras = <String, dynamic>{
      for (final e in j.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    };
    final rawGrant = j['grant'];
    return EditableCheckpoint(
      text: (j['text'] ?? '').toString(),
      next: (j['next'] ?? '').toString(),
      condition: (j['condition'] ?? '').toString(),
      check: (j['check'] ?? '').toString(),
      reward: (j['reward'] as num?)?.toInt() ?? 0,
      grant: {
        if (rawGrant is Map)
          for (final e in rawGrant.entries)
            e.key.toString(): e.value is num ? (e.value as num).toInt() : 0,
      },
      extras: extras,
    );
  }

  Map<String, dynamic> toJson() {
    final grants = {
      for (final e in grant.entries)
        if (e.value != 0) e.key: e.value,
    };
    return {
      ..._extras,
      'text': text,
      'reward': reward,
      if (next.isNotEmpty) 'next': next,
      if (condition.isNotEmpty) 'condition': condition,
      if (check.isNotEmpty) 'check': check,
      if (grants.isNotEmpty) 'grant': grants,
    };
  }


  void setConditionRows(List<EditableConditionRow> rows) {
    condition = [
      for (final r in rows)
        if (r.serialize().isNotEmpty) r.serialize(),
    ].join(' && ');
  }

  EditableCheckpoint clone() => EditableCheckpoint.fromJson(toJson());
}


class EditableStage {

  String fileName;


  String id;


  List<EditableLine> lines;
  List<EditableCheckpoint> checkpoints;

  final Map<String, dynamic> _extras;

  static const Set<String> _known = {
    'id',
    'lines',
    'checkpoint',
  };

  EditableStage({
    this.fileName = '',
    this.id = '',
    List<EditableLine>? lines,
    List<EditableCheckpoint>? checkpoints,
    Map<String, dynamic>? extras,
  }) : lines = lines ?? <EditableLine>[],
       checkpoints = checkpoints ?? <EditableCheckpoint>[],
       _extras = extras ?? <String, dynamic>{};

  factory EditableStage.fromJson(String fileName, Map<String, dynamic> j) {
    final lines = <EditableLine>[];
    final rawLines = j['lines'];
    if (rawLines is List) {
      for (final it in rawLines) {
        if (it is Map) lines.add(EditableLine.fromJson(Map<String, dynamic>.from(it)));
      }
    }
    final cps = <EditableCheckpoint>[];
    final rawCp = j['checkpoint'];
    if (rawCp is List) {
      for (final it in rawCp) {
        if (it is Map) {
          cps.add(EditableCheckpoint.fromJson(Map<String, dynamic>.from(it)));
        }
      }
    }
    final extras = <String, dynamic>{
      for (final e in j.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    };
    return EditableStage(
      fileName: fileName,
      id: (j['id'] ?? '').toString(),
      lines: lines,
      checkpoints: cps,
      extras: extras,
    );
  }

  Map<String, dynamic> toJson() => {
    ..._extras,
    if (id.isNotEmpty) 'id': id,
    'lines': [for (final l in lines) l.toJson()],
    'checkpoint': [for (final c in checkpoints) c.toJson()],
  };

  /// 关卡默认背景（存于 extras，导出时原样写回 stage JSON）。
  String? get background => _extras['background']?.toString();

  set background(String? value) {
    if (value == null || value.trim().isEmpty) {
      _extras.remove('background');
    } else {
      _extras['background'] = value;
    }
  }

  /// 关卡过场特效（存于 extras 的 fx.transitionIn / transitionOut）。
  List<FxSpec> get transitionIn {
    final fx = _extras['fx'];
    if (fx is! Map) return const [];
    return parseFxList(fx['transitionIn']);
  }

  List<FxSpec> get transitionOut {
    final fx = _extras['fx'];
    if (fx is! Map) return const [];
    return parseFxList(fx['transitionOut']);
  }

  /// 关卡 BGM（存于 extras）。
  String? get bgm => _extras['bgm']?.toString();

  set bgm(String? value) {
    if (value == null || value.trim().isEmpty) {
      _extras.remove('bgm');
    } else {
      _extras['bgm'] = value;
    }
  }


  String get displayLabel {
    if (id.isNotEmpty) return id;
    return fileName.replaceAll('.json', '');
  }

  EditableStage clone() =>
      EditableStage.fromJson(fileName, toJson());
}


class EditableAiSendItem {
  String kind;
  String name;
  String requirement;
  int quantity;
  bool showInInventory;
  bool showInStory;

  EditableAiSendItem({
    this.kind = 'text',
    this.name = '',
    this.requirement = '',
    this.quantity = 1,
    this.showInInventory = true,
    this.showInStory = true,
  });

  static const List<String> kinds = ['text', 'image', 'audio', 'video'];

  factory EditableAiSendItem.fromJson(Map<String, dynamic> j) =>
      EditableAiSendItem(
        kind: kinds.contains(j['kind']) ? j['kind'].toString() : 'text',
        name: (j['name'] ?? '').toString(),
        requirement: (j['requirement'] ?? '').toString(),
        quantity: ((j['quantity'] as num?)?.toInt() ?? 1).clamp(1, 99),
        showInInventory: (j['show_in_inventory'] ?? 'yes').toString() != 'no',
        showInStory: (j['show_in_story'] ?? 'yes').toString() != 'no',
      );

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'name': name,
    'requirement': requirement,
    'quantity': quantity,
    'show_in_inventory': showInInventory ? 'yes' : 'no',
    'show_in_story': showInStory ? 'yes' : 'no',
  };

  EditableAiSendItem clone() => EditableAiSendItem.fromJson(toJson());
}


List<EditableAiSendItem> _legacyQuotaItems(Map<String, dynamic> params) {
  final raw = params['ai_item_quota'];
  if (raw is! Map) return <EditableAiSendItem>[];
  return [
    for (final kind in EditableAiSendItem.kinds)
      if (((raw[kind] as num?)?.toInt() ?? 0) > 0)
        EditableAiSendItem(kind: kind),
  ];
}


class EditableCheck {
  String fileName;
  String type;
  String verify;


  Map<String, dynamic> params;


  List<EditableAiSendItem> aiSendItems;

  EditableCheck({
    this.fileName = '',
    this.type = '',
    this.verify = 'local',
    Map<String, dynamic>? params,
    List<EditableAiSendItem>? aiSendItems,
  }) : params = params ?? <String, dynamic>{},
       aiSendItems = aiSendItems ?? <EditableAiSendItem>[];

  static List<EditableAiSendItem>? _parseAiItems(Map<String, dynamic> p) {
    final raw = p['ai_send_items'];
    if (raw is! List) return null;
    return [
      for (final it in raw)
        if (it is Map)
          EditableAiSendItem.fromJson(Map<String, dynamic>.from(it)),
    ];
  }

  String get id => fileName.replaceAll('.json', '');

  factory EditableCheck.fromJson(String fileName, Map<String, dynamic> j) {
    final params = Map<String, dynamic>.from(j)
      ..remove('type')
      ..remove('verify');
    return EditableCheck(
      fileName: fileName,
      type: (j['type'] ?? '').toString(),
      verify: (j['verify'] ?? 'local').toString(),
      params: params,
      aiSendItems: _parseAiItems(params) ?? _legacyQuotaItems(params),
    );
  }

  Map<String, dynamic> toJson() {
    final out = Map<String, dynamic>.from(params)
      ..remove('ai_item_quota')
      ..remove('ai_text_mode')
      ..remove('ai_voice_mode')
      ..['ai_send_items'] = [for (final i in aiSendItems) i.toJson()]
      ..['type'] = type
      ..['verify'] = verify;
    return out;
  }

  EditableCheck clone() => EditableCheck.fromJson(fileName, toJson());
}


class EditableStoryItem {
  String fileName;
  String id;
  String name;
  String description;
  String asset;
  String kind;
  int initial;

  EditableStoryItem({
    this.fileName = '',
    this.id = '',
    this.name = '',
    this.description = '',
    this.asset = '',
    this.kind = '',
    this.initial = 0,
  });

  static const List<String> kinds = ['text', 'image', 'audio', 'video'];

  factory EditableStoryItem.fromJson(String fileName, Map<String, dynamic> j) {
    final base = fileName.toLowerCase().endsWith('.json')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
    return EditableStoryItem(
      fileName: fileName,
      id: (j['id'] ?? base).toString(),
      name: (j['name'] ?? base).toString(),
      description: (j['description'] ?? '').toString(),
      asset: (j['asset'] ?? '').toString(),
      kind: kinds.contains(j['kind']) ? j['kind'].toString() : '',
      initial: (j['initial'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    if (asset.isNotEmpty) 'asset': asset,
    if (kind.isNotEmpty) 'kind': kind,
    if (initial != 0) 'initial': initial,
  };
}

class EditablePack extends ChangeNotifier {

  String name;

  EditableManifest manifest;
  List<EditableStage> stages;
  List<EditableCheck> checks;


  List<EditableStoryItem> items;


  List<String> mediaPaths;


  final Map<String, List<String>> mediaFolders = <String, List<String>>{};


  final Map<String, String> mediaCategory = <String, String>{};

  static const List<String> mediaCategories = [
    'people',
    'background',
    'music',
    'video',
    'item',
    'other',
  ];


  final Map<String, Uint8List> importedMedia = <String, Uint8List>{};

  String mediaKey;

  EditablePack({
    this.name = 'newPack',
    EditableManifest? manifest,
    List<EditableStage>? stages,
    List<EditableCheck>? checks,
    List<EditableStoryItem>? items,
    List<String>? mediaPaths,
    String? mediaKey,
  }) : manifest = manifest ?? EditableManifest(),
       stages = stages ?? <EditableStage>[],
       checks = checks ?? <EditableCheck>[],
       items = items ?? <EditableStoryItem>[],
       mediaPaths = mediaPaths ?? <String>[],
       mediaKey = mediaKey ?? generateGameId();


  factory EditablePack.empty() => EditablePack(
    name: 'myNewPack',
    manifest: EditableManifest(
      gameName: '未命名游戏',
      createTime: _today(),
    ),
    stages: [
      EditableStage(
        fileName: '1start.json',
        id: 's1',
        lines: [
          EditableLine(id: 'l1', type: 'narration', text: '故事从这里开始。'),
        ],
      ),
    ],
  );

  static String _today() {
    final d = DateTime.now();
    return '${d.year}.${d.month}.${d.day}';
  }


  static Future<EditablePack> fromAssetPackage(String pkgName) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final prefix = '${GamePackages.assetPrefix}/$pkgName/';
    final keys = manifest
        .listAssets()
        .where((k) => k.startsWith(prefix))
        .toList()
      ..sort();

    final pack = EditablePack(name: pkgName, mediaKey: 'official-$pkgName');
    for (final key in keys) {
      final rel = key.substring(prefix.length);
      final lower = rel.toLowerCase();
      if (!lower.endsWith('.json')) {
        pack.mediaPaths.add(rel);
        continue;
      }
      final raw = await rootBundle.loadString(key);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final j = Map<String, dynamic>.from(decoded);
      final fileName = rel.split('/').last;
      if (rel == 'basicInfo.json') {
        pack.manifest = EditableManifest.fromJson(j);
      } else if (rel.startsWith('stage/')) {
        pack.stages.add(EditableStage.fromJson(fileName, j));
      } else if (rel.startsWith('check/')) {
        pack.checks.add(EditableCheck.fromJson(fileName, j));
      } else if (rel.startsWith('item/')) {
        pack.items.add(EditableStoryItem.fromJson(fileName, j));
      }
    }

    pack.sortStagesByNumber();
    pack.checks.sort((a, b) => a.fileName.compareTo(b.fileName));
    return pack;
  }


  /// 解包 zip → 「相对包根路径 → 字节」。
  ///
  /// 路径安全规则统一由引擎侧的 [unpackZipBytes] 负责（拒绝 `..`、绝对路径、
  /// 超大包），编辑器不另写一套。
  static Map<String, Uint8List> unpackZip(List<int> zipBytes) =>
      unpackZipBytes(zipBytes);


  static Map<String, Uint8List> normalizeRoot(Map<String, Uint8List> files) {
    bool hasInfo(Map<String, Uint8List> m) => m.keys.any(
      (k) => !k.contains('/') && k.toLowerCase() == 'basicinfo.json',
    );
    if (hasInfo(files)) return files;
    String? common;
    for (final k in files.keys) {
      final slash = k.indexOf('/');
      if (slash <= 0) return files;
      final top = k.substring(0, slash);
      if (common == null) {
        common = top;
      } else if (common != top) {
        return files;
      }
    }
    if (common == null) return files;
    final cut = common.length + 1;
    final stripped = <String, Uint8List>{
      for (final e in files.entries) e.key.substring(cut): e.value,
    };
    return hasInfo(stripped) ? stripped : files;
  }


  static List<PackIssue> validateFileMap(Map<String, Uint8List> files) {
    final issues = <PackIssue>[];

    Map<String, dynamic>? decode(String rel) {
      final bytes = files[rel];
      if (bytes == null) {
        issues.add(PackIssue('missing', rel));
        return null;
      }
      final String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        issues.add(PackIssue('notUtf8', rel));
        return null;
      }
      final dynamic decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        issues.add(PackIssue('badJson', rel));
        return null;
      }
      if (decoded is! Map) {
        issues.add(PackIssue('notObject', rel));
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    }


    final infoKey = files.keys.firstWhere(
      (k) => !k.contains('/') && k.toLowerCase() == 'basicinfo.json',
      orElse: () => 'basicInfo.json',
    );
    final info = decode(infoKey);
    if (info != null && (info['gameName'] ?? '').toString().trim().isEmpty) {
      issues.add(PackIssue('noGameName', infoKey));
    }


    final stageKeys = files.keys
        .where(
          (k) =>
              k.toLowerCase().startsWith('stage/') &&
              k.toLowerCase().endsWith('.json'),
        )
        .toList();
    if (stageKeys.isEmpty) issues.add(const PackIssue('noStage'));
    for (final k in stageKeys) {
      final j = decode(k);
      if (j == null) continue;
      _checkObjectList(j['lines'], 'lines', k, issues);
      _checkObjectList(j['checkpoint'], 'checkpoint', k, issues);
      _checkLineIds(j['lines'], k, issues);
    }


    final checkKeys = files.keys
        .where(
          (k) =>
              k.toLowerCase().startsWith('check/') &&
              k.toLowerCase().endsWith('.json'),
        )
        .toList();
    for (final k in checkKeys) {
      final j = decode(k);
      if (j == null) continue;
      if ((j['type'] ?? '').toString().trim().isEmpty) {
        issues.add(PackIssue('checkNoType', k));
      }
    }

    return issues;
  }

  static void _checkObjectList(
    Object? v,
    String field,
    String file,
    List<PackIssue> issues,
  ) {
    if (v == null) return;
    if (v is! List) {
      issues.add(PackIssue('notArray', '$file · $field'));
      return;
    }
    for (final it in v) {
      if (it is! Map) {
        issues.add(PackIssue('itemNotObject', '$file · $field'));
        break;
      }
    }
  }


  static void _checkLineIds(Object? lines, String file, List<PackIssue> issues) {
    if (lines is! List) return;
    final seen = <String>{};
    for (final it in lines) {
      if (it is! Map) continue;
      final id = (it['lineId'] ?? it['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (!seen.add(id)) {
        issues.add(PackIssue('dupLineId', '$file · $id'));
        return;
      }
    }
  }


  static EditablePack fromFileMap(
    Map<String, Uint8List> files, {
    String root = 'imported',
  }) {
    final pack = EditablePack(name: root.trim().isEmpty ? 'imported' : root);
    for (final e in files.entries) {
      final rel = e.key;
      final lower = rel.toLowerCase();
      Map<String, dynamic>? j;
      if (lower.endsWith('.json')) {
        try {
          final decoded = jsonDecode(utf8.decode(e.value));
          if (decoded is Map) j = Map<String, dynamic>.from(decoded);
        } catch (_) {
          j = null;
        }
      }
      final fileName = rel.split('/').last;
      if (j != null && !rel.contains('/') && lower == 'basicinfo.json') {
        pack.manifest = EditableManifest.fromJson(j);
      } else if (j != null && lower.startsWith('stage/')) {
        pack.stages.add(EditableStage.fromJson(fileName, j));
      } else if (j != null && lower.startsWith('check/')) {
        pack.checks.add(EditableCheck.fromJson(fileName, j));
      } else if (j != null && lower.startsWith('item/')) {
        pack.items.add(EditableStoryItem.fromJson(fileName, j));
      } else {

        pack.importedMedia[rel] = e.value;
        if (!pack.mediaPaths.contains(rel)) pack.mediaPaths.add(rel);
      }
    }
    pack.sortStagesByNumber();
    pack.checks.sort((a, b) => a.fileName.compareTo(b.fileName));
    return pack;
  }


  /// 从 zip 导入。归一化包根在 [normalizeRoot] 里统一做，调用方不用再管。
  static EditablePack fromZip(List<int> zipBytes, {String root = 'imported'}) =>
      fromFileMap(normalizeRoot(unpackZip(zipBytes)), root: root);


  List<String> get stageTargets {
    final ids = <String>{
      for (final s in stages)
        if (s.id.isNotEmpty) s.id else s.fileName.replaceAll('.json', ''),
    };
    return ids.toList()..sort();
  }


  List<String> get checkIds =>
      [for (final c in checks) c.id]..sort();




  EditableCheck? findCheck(String id) {
    for (final c in checks) {
      if (c.id == id) return c;
    }
    return null;
  }


  EditableCheck ensureCheck(String id) {
    final f = findCheck(id);
    if (f != null) return f;
    final c = EditableCheck(fileName: '$id.json', type: 'photo_submit');
    checks.add(c);
    return c;
  }


  String newCheckId() {
    final taken = checks.map((c) => c.id).toSet();
    var n = checks.length + 1;
    while (taken.contains('check$n')) {
      n++;
    }
    return 'check$n';
  }


  void pruneCheck(String id) {
    final stillUsed = stages.any((s) => s.checkpoints.any((c) => c.check == id));
    if (stillUsed) return;
    final c = findCheck(id);
    if (c != null) checks.remove(c);
  }


  int stageNumber(String id) {
    if (id.isEmpty) return 0;
    for (var i = 0; i < stages.length; i++) {
      final s = stages[i];
      final sid = s.id.isNotEmpty ? s.id : s.fileName.replaceAll('.json', '');
      if (sid == id) return i + 1;
    }
    return 0;
  }




  String nextLineId(EditableStage s) {
    final taken = s.lines.map((l) => l.id).where((e) => e.isNotEmpty).toSet();
    var n = s.lines.length + 1;
    while (taken.contains('l$n')) {
      n++;
    }
    return 'l$n';
  }


  void ensureLineIds(EditableStage s) {
    for (final l in s.lines) {
      if (l.id.trim().isEmpty) l.id = nextLineId(s);
    }
  }


  bool renameLineId(EditableStage s, EditableLine line, String raw) {
    final v = raw.trim();
    if (v.isEmpty) return false;
    if (v == line.id) return true;
    if (s.lines.any((l) => l != line && l.id == v)) return false;
    line.id = v;
    notify();
    return true;
  }


  bool isLineIdDuplicated(EditableStage s, EditableLine line) =>
      line.id.isNotEmpty &&
      s.lines.any((l) => l != line && l.id == line.id);


  void addImportedMedia(String relPath, Uint8List bytes) {
    importedMedia[relPath] = bytes;
    if (!mediaPaths.contains(relPath)) mediaPaths.add(relPath);
    notify();
  }


  void putImportedMedia(String relPath, Uint8List bytes) {
    importedMedia[relPath] = bytes;
    notify();
  }


  void removeMedia(String relPath) {
    importedMedia.remove(relPath);
    mediaPaths.remove(relPath);
    mediaCategory.remove(relPath);
    for (final list in mediaFolders.values) {
      list.remove(relPath);
    }
    notify();
  }




  String? categoryOf(String rel) => mediaCategory[rel];


  void setCategory(String rel, String? category) {
    if (category == null || !mediaCategories.contains(category)) {
      mediaCategory.remove(rel);
    } else {
      mediaCategory[rel] = category;
    }
    notify();
  }


  String? folderOf(String rel) {
    for (final e in mediaFolders.entries) {
      if (e.value.contains(rel)) return e.key;
    }
    return null;
  }


  bool addFolder(String rawName) {
    final n = rawName.trim();
    if (n.isEmpty || mediaFolders.containsKey(n)) return false;
    mediaFolders[n] = <String>[];
    notify();
    return true;
  }


  bool renameFolder(String old, String rawNew) {
    final n = rawNew.trim();
    if (n.isEmpty || (n != old && mediaFolders.containsKey(n))) return false;
    final members = mediaFolders.remove(old);
    if (members == null) return false;
    mediaFolders[n] = members;
    notify();
    return true;
  }


  void removeFolder(String name) {
    if (mediaFolders.remove(name) != null) notify();
  }


  void moveToFolder(String rel, String? folder) {
    for (final list in mediaFolders.values) {
      list.remove(rel);
    }
    if (folder != null) mediaFolders[folder]?.add(rel);
    notify();
  }


  int mediaRefCount(String relPath) {
    if (relPath.trim().isEmpty) return 0;
    var n = 0;
    if (manifest.map == relPath) n++;
    for (final i in items) {
      if (i.asset == relPath) n++;
    }
    for (final s in stages) {
      for (final l in s.lines) {
        if (l.image == relPath) n++;
        if (l.audio == relPath) n++;
        if (l.video == relPath) n++;
        if (l.background == relPath) n++;
        for (final sp in l.sprites) {
          if (sp.asset == relPath) n++;
        }
      }
    }
    return n;
  }


  void clearReferencesTo(String relPath) {
    if (relPath.trim().isEmpty) return;
    if (manifest.map == relPath) manifest.map = '';
    for (final i in items) {
      if (i.asset == relPath) i.asset = '';
    }
    for (final s in stages) {
      for (final l in s.lines) {
        if (l.image == relPath) l.image = '';
        if (l.audio == relPath) l.audio = '';
        if (l.video == relPath) l.video = '';
        if (l.background == relPath) l.background = '';
        for (final sp in l.sprites) {
          if (sp.asset == relPath) sp.asset = '';
        }
      }
    }
  }


  void removeMediaCascade(String relPath) {
    clearReferencesTo(relPath);
    removeMedia(relPath);
  }


  String? assetKeyFor(String relPath) {
    if (relPath.trim().isEmpty) return null;
    return '${GamePackages.assetPrefix}/$name/$relPath';
  }


  List<String> get referencedMediaPaths {
    final set = <String>{...mediaPaths};
    final m = manifest.map;
    if (m.trim().isNotEmpty) set.add(m);
    for (final i in items) {
      if (i.asset.trim().isNotEmpty) set.add(i.asset);
    }
    for (final s in stages) {
      for (final l in s.lines) {
        if (l.background.trim().isNotEmpty) set.add(l.background);
        for (final sp in l.sprites) {
          if (sp.asset.trim().isNotEmpty) set.add(sp.asset);
        }
      }
      for (final l in s.lines) {
        if (l.image.trim().isNotEmpty) set.add(l.image);
        if (l.audio.trim().isNotEmpty) set.add(l.audio);
        if (l.video.trim().isNotEmpty) set.add(l.video);
      }
    }
    set.removeWhere((e) => e.trim().isEmpty);
    return set.toList();
  }

  void notify() => notifyListeners();


  String uniqueItemId() {
    final taken = items.map((e) => e.id).toSet();
    var n = items.length + 1;
    while (taken.contains('item$n')) {
      n++;
    }
    return 'item$n';
  }

  bool renameItem(EditableStoryItem item, String raw) {
    final next = raw.trim();
    if (next.isEmpty) return false;
    if (next == item.id) return true;
    if (items.any((e) => e != item && e.id == next)) return false;
    final old = item.id;
    item.id = next;
    item.fileName = '$next.json';
    for (final s in stages) {
      for (final cp in s.checkpoints) {
        final amount = cp.grant.remove(old);
        if (amount != null) cp.grant[next] = amount;
        _rewriteCondition(cp, old, next);
      }
    }
    _rewriteCheckConditions(old, next);
    notify();
    return true;
  }

  void removeItem(EditableStoryItem item) {
    items.remove(item);
    for (final s in stages) {
      for (final cp in s.checkpoints) {
        cp.grant.remove(item.id);
        final rows = EditableConditionRow.parse(cp.condition);
        final kept = [
          for (final row in rows)
            if (row.item != item.id) row,
        ];
        if (kept.length != rows.length) cp.setConditionRows(kept);
      }
    }
    _removeFromCheckConditions(item.id);
    notify();
  }

  void _rewriteCheckConditions(String oldId, String newId) {
    for (final check in checks) {
      final raw = (check.params['condition'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final rows = EditableConditionRow.parse(raw);
      var hit = false;
      for (final row in rows) {
        if (row.item == oldId) {
          row.item = newId;
          hit = true;
        }
      }
      if (hit) {
        check.params['condition'] = [
          for (final row in rows) row.serialize(),
        ].join(' && ');
      }
    }
  }

  void _removeFromCheckConditions(String id) {
    for (final check in checks) {
      final raw = (check.params['condition'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final rows = EditableConditionRow.parse(raw);
      final kept = [
        for (final row in rows)
          if (row.item != id) row,
      ];
      if (kept.length == rows.length) continue;
      if (kept.isEmpty) {
        check.params.remove('condition');
      } else {
        check.params['condition'] = [
          for (final row in kept) row.serialize(),
        ].join(' && ');
      }
    }
  }

  void _rewriteCondition(EditableCheckpoint cp, String oldId, String newId) {
    final rows = EditableConditionRow.parse(cp.condition);
    var hit = false;
    for (final row in rows) {
      if (row.item == oldId) {
        row.item = newId;
        hit = true;
      }
    }
    if (hit) cp.setConditionRows(rows);
  }

  bool renameStage(EditableStage s, String raw) {
    final newId = raw.trim();
    if (newId.isEmpty) return false;
    if (newId == s.id) return true;
    if (stages.any((e) => e != s && e.id == newId)) return false;
    final old = s.id;
    s.id = newId;
    if (old.isNotEmpty) {
      for (final st in stages) {
        for (final cp in st.checkpoints) {
          if (cp.next == old) cp.next = newId;
        }
      }
    }
    notify();
    return true;
  }

  void addStage() {
    stages.add(EditableStage(fileName: '', id: _uniqueStageId()));
    renumberStages();
    notify();
  }

  /// 在关卡末尾追加一句旁白（编号自动取未占用的 lineId）。
  EditableLine addLine(EditableStage stage) {
    final used = {for (final l in stage.lines) l.id};
    var n = stage.lines.length + 1;
    while (used.contains('l$n')) {
      n++;
    }
    final line = EditableLine(id: 'l$n', type: 'narration', text: '');
    stage.lines.add(line);
    notify();
    return line;
  }

  /// 在关卡末尾追加一个选项（默认跳同一关，避免立刻断链）。
  EditableCheckpoint addCheckpoint(EditableStage stage) {
    final cp = EditableCheckpoint(
      text: '新的选项',
      next: stage.id,
      reward: 0,
    );
    stage.checkpoints.add(cp);
    notify();
    return cp;
  }

  void removeLine(EditableStage stage, int index) {
    if (index < 0 || index >= stage.lines.length) return;
    stage.lines.removeAt(index);
    notify();
  }

  void removeCheckpoint(EditableStage stage, int index) {
    if (index < 0 || index >= stage.checkpoints.length) return;
    stage.checkpoints.removeAt(index);
    notify();
  }

  void removeStage(EditableStage s) {
    final removedId = s.id;
    final removedChecks = {
      for (final cp in s.checkpoints)
        if (cp.check.isNotEmpty) cp.check,
    };
    stages.remove(s);
    renumberStages();
    if (removedId.isNotEmpty) {
      for (final st in stages) {
        for (final cp in st.checkpoints) {
          if (cp.next == removedId) cp.next = '';
        }
      }
    }
    for (final id in removedChecks) {
      pruneCheck(id);
    }
    notify();
  }


  void renumberStages() {
    for (var i = 0; i < stages.length; i++) {
      stages[i].fileName = '${i + 1}.json';
    }
  }


  String _uniqueStageId() {
    final taken = stages.map((s) => s.id).toSet();
    var n = stages.length + 1;
    while (taken.contains('s$n')) {
      n++;
    }
    return 's$n';
  }


  void sortStagesByNumber() {
    stages.sort((a, b) {
      final na = _leadingNumber(a.fileName);
      final nb = _leadingNumber(b.fileName);
      if (na != nb) return na.compareTo(nb);
      return a.fileName.compareTo(b.fileName);
    });
    renumberStages();
  }

  static int _leadingNumber(String name) {
    final m = RegExp(r'^(\d+)').firstMatch(name);
    return m == null ? 0 : int.parse(m.group(1)!);
  }


  void addCheck() {
    final id = newCheckId();
    checks.add(EditableCheck(fileName: '$id.json', type: 'photo_submit'));
    notify();
  }

  void removeCheck(EditableCheck c) {
    checks.remove(c);
    notify();
  }


  Map<String, String> toFiles() {
    const enc = JsonEncoder.withIndent('  ');
    final out = <String, String>{
      'basicInfo.json': enc.convert(manifest.toJson()),
    };
    for (final s in stages) {

      ensureLineIds(s);
      out['stage/${s.fileName}'] = enc.convert(s.toJson());
    }
    for (final c in checks) {
      out['check/${c.fileName}'] = enc.convert(c.toJson());
    }
    for (final i in items) {
      final fileName = i.fileName.isEmpty ? '${i.id}.json' : i.fileName;
      out['item/$fileName'] = enc.convert(i.toJson());
    }
    return out;
  }


  /// 打包条目（zip 内的相对路径 → 字节）。
  ///
  /// 根目录名与条目键的净化由引擎侧的 [sanitizePathSegment] /
  /// [sanitizeRelativePath] 负责，保证导出的 zip 不含穿越路径。
  Map<String, List<int>> toArchiveEntries() {
    final root = name.trim().isEmpty ? 'pack' : name.trim();
    final out = <String, List<int>>{};
    for (final e in toFiles().entries) {
      out['$root/${e.key}'] = utf8.encode(e.value);
    }
    for (final e in importedMedia.entries) {
      out['$root/${e.key}'] = e.value;
    }
    return out;
  }



  Map<String, dynamic> toDraftMap() => {
    'name': name,
    'manifest': manifest.toJson(),
    'stages': [
      for (final s in stages) {'fileName': s.fileName, 'data': s.toJson()},
    ],
    'checks': [
      for (final c in checks) {'fileName': c.fileName, 'data': c.toJson()},
    ],
    'items': [
      for (final i in items) {'fileName': i.fileName, 'data': i.toJson()},
    ],
    'mediaPaths': mediaPaths,
    'mediaKey': mediaKey,
    'mediaFolders': {
      for (final e in mediaFolders.entries) e.key: e.value,
    },
    'mediaCategory': {
      for (final e in mediaCategory.entries) e.key: e.value,
    },
  };

  static EditablePack fromDraftMap(Map<String, dynamic> m) {
    final key = (m['mediaKey'] ?? '').toString();
    final pack = EditablePack(
      name: (m['name'] ?? 'newPack').toString(),
      mediaKey: key.isEmpty ? null : key,
    );
    final mani = m['manifest'];
    if (mani is Map) {
      pack.manifest = EditableManifest.fromJson(Map<String, dynamic>.from(mani));
    }
    final st = m['stages'];
    if (st is List) {
      for (final e in st) {
        if (e is Map) {
          final fn = (e['fileName'] ?? '').toString();
          final data = e['data'];
          if (data is Map) {
            pack.stages.add(
              EditableStage.fromJson(fn, Map<String, dynamic>.from(data)),
            );
          }
        }
      }
    }
    final ck = m['checks'];
    if (ck is List) {
      for (final e in ck) {
        if (e is Map) {
          final fn = (e['fileName'] ?? '').toString();
          final data = e['data'];
          if (data is Map) {
            pack.checks.add(
              EditableCheck.fromJson(fn, Map<String, dynamic>.from(data)),
            );
          }
        }
      }
    }
    final it = m['items'];
    if (it is List) {
      for (final e in it) {
        if (e is Map) {
          final data = e['data'];
          if (data is Map) {
            pack.items.add(
              EditableStoryItem.fromJson(
                (e['fileName'] ?? '').toString(),
                Map<String, dynamic>.from(data),
              ),
            );
          }
        }
      }
    }
    final mp = m['mediaPaths'];
    if (mp is List) pack.mediaPaths.addAll(mp.map((e) => e.toString()));
    final mf = m['mediaFolders'];
    if (mf is Map) {
      for (final e in mf.entries) {
        final v = e.value;
        pack.mediaFolders[e.key.toString()] = v is List
            ? v.map((x) => x.toString()).toList()
            : <String>[];
      }
    }
    final mc = m['mediaCategory'];
    if (mc is Map) {
      for (final e in mc.entries) {
        final v = e.value.toString();
        if (mediaCategories.contains(v)) pack.mediaCategory[e.key.toString()] = v;
      }
    }
    return pack;
  }

  String toDraftJson() => jsonEncode(toDraftMap());

  static EditablePack fromDraftJson(String s) =>
      fromDraftMap(Map<String, dynamic>.from(jsonDecode(s) as Map));
}
