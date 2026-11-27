/// 剧情关卡（Stage）数据模型。
///
/// 对应游戏包 `stage/*.json`。每个关卡由若干"台词/旁白"(lines) 与一个
/// "检查点"(checkpoint) 组成；checkpoint 里的每个选项可带条件门控(condition)、
/// 校验声明(check) 与跳转目标(next)。
library;

import 'effects.dart';

/// 一行剧情内容：对白(dialogue) 或 旁白(narration)。
///
/// 一行可选地携带媒体资源（相对包根路径，如 `assets/picture/x.png`），
/// 对话界面据此在台词旁提供"播放图片/音频/视频"的入口。三类互不排斥，
/// 可同时存在（例如一句旁白既配图又配环境音）。
///
/// [id] 是台词在**关卡内**的稳定编号（JSON 字段 `lineId`）：存档与数据监控
/// 用它定位"玩到第几段话"，因此不随台词增删而漂移。老包没写时按序号兜底
/// （`l1`、`l2`…），保证同一份文件解析结果可复现。
class StageLine {
  final String type; // dialogue | narration
  final String? speaker; // 仅 dialogue 有
  final String text;

  /// 关卡内台词编号（非空）。
  final String id;

  /// 图片资源相对路径（可空）：进入本行即全屏显示。
  final String? image;

  /// 音频资源相对路径（可空）：进入本行即自动播放。
  final String? audio;

  /// 视频资源相对路径（可空）：进入本行即全屏播放。
  final String? video;

  /// 本行背景（可空）：覆盖关卡背景；为空则沿用关卡背景。
  final String? background;

  /// 本行立绘（可空列表）：进入本行替换画面上的立绘。
  ///
  /// [declaresSprites] 为 false 时沿用上一句的立绘；为 true 时整批替换，
  /// 空列表表示本行明确不显示立绘。
  final List<StageSprite> sprites;

  final bool declaresSprites;

  /// 本行特效声明（PACK_FORMAT v2）。缺省空列表 = 无特效。
  final List<FxSpec> fx;

  const StageLine({
    required this.type,
    this.speaker,
    required this.text,
    this.id = '',
    this.image,
    this.audio,
    this.video,
    this.background,
    this.sprites = const [],
    this.declaresSprites = false,
    this.fx = const [],
  });

  /// [index] 为该行在关卡里的下标，仅在 JSON 未写 `lineId` 时用于兜底编号。
  factory StageLine.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final raw = (json['lineId'] ?? json['id'] ?? '').toString().trim();
    final rawSprites = json['sprites'];
    return StageLine(
      id: raw.isEmpty ? 'l${index + 1}' : raw,
      type: (json['type'] ?? 'narration').toString(),
      speaker: json['speaker']?.toString(),
      text: (json['text'] ?? '').toString(),
      image: json['image']?.toString(),
      audio: json['audio']?.toString(),
      video: json['video']?.toString(),
      background: json['background']?.toString(),
      sprites: [
        if (rawSprites is List)
          for (final entry in rawSprites)
            if (entry is Map<String, dynamic>) StageSprite.fromJson(entry),
      ],
      declaresSprites: rawSprites is List,
      fx: parseFxList(json['fx']),
    );
  }

  @override
  String toString() =>
      type == 'dialogue' ? '[$id $speaker] $text' : '(旁白 $id) $text';
}

/// 一行立绘：`{"asset": "assets/picture/a.png", "position": "left"}`。
class StageSprite {
  final String asset;
  final String position; // left | center | right

  /// 立绘槽位（特效 `target: sprite:<slot>` 据此寻址）。空则按位置索引。
  final String slot;

  const StageSprite({
    required this.asset,
    this.position = 'center',
    this.slot = '',
  });

  factory StageSprite.fromJson(Map<String, dynamic> json) => StageSprite(
    asset: (json['asset'] ?? '').toString(),
    position: (json['position'] ?? 'center').toString(),
    slot: (json['slot'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {'asset': asset, 'position': position};
}

/// 检查点里的一个选项（分支）。
class Checkpoint {
  final String text; // 选项文案
  final String? next; // 跳转到的 stage id；null 表示终点
  final String? condition; // 显示该选项所需满足的条件标记
  final String? check; // 关联的 check id（去扩展名后匹配 check/*.json）

  /// 通过该节点奖励的积分（单位见 manifest.points）；默认 0。
  /// 仅当该节点被判为"通过"时计入（需提交的节点在提交成功后计入）。
  final int reward;

  /// 通过该节点时发放的剧情物品：`{"钥匙": 1, "好感度": 2}`；负数为扣减。
  final Map<String, int> grant;

  const Checkpoint({
    required this.text,
    this.next,
    this.condition,
    this.check,
    this.reward = 0,
    this.grant = const {},
  });

  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    final rawGrant = json['grant'];
    return Checkpoint(
      text: (json['text'] ?? '').toString(),
      next: json['next']?.toString(),
      condition: json['condition']?.toString(),
      check: json['check']?.toString(),
      reward: (json['reward'] as num?)?.toInt() ?? 0,
      grant: {
        if (rawGrant is Map)
          for (final entry in rawGrant.entries)
            entry.key.toString(): entry.value is num
                ? (entry.value as num).toInt()
                : 0,
      },
    );
  }

  @override
  String toString() {
    final buf = StringBuffer('"$text"→${next ?? "END"}');
    if (condition != null) buf.write(' cond{$condition}');
    if (check != null) buf.write(' check{$check}');
    if (reward != 0) buf.write(' +$reward');
    return buf.toString();
  }
}

/// 一个剧情关卡。
class Stage {
  /// 关卡唯一标识：优先取 JSON 内的 "id"，否则回退为文件名（去扩展名）。
  final String id;

  /// 排序序号：取文件名数字前缀，用于稳定排序。
  final int order;

  /// 来源文件名（相对 stage/ 目录）。
  final String sourceFile;

  final List<StageLine> lines;
  final List<Checkpoint> checkpoints;

  /// 关卡默认背景（相对包根路径）；台词行可用自己的 `background` 覆盖。
  final String? background;

  /// 关卡背景音乐（相对包根路径）；进入本关循环播放，离开即停。
  final String? bgm;

  /// 过场特效（进入/离开本关）。JSON `fx: {transitionIn/Out: [...]}`。
  final List<FxSpec> transitionIn;
  final List<FxSpec> transitionOut;

  const Stage({
    required this.id,
    required this.order,
    required this.sourceFile,
    required this.lines,
    required this.checkpoints,
    this.background,
    this.bgm,
    this.transitionIn = const [],
    this.transitionOut = const [],
  });

  /// 台词编号 → 关卡内下标；不存在返回 -1。
  int lineIndexOf(String? lineId) {
    if (lineId == null || lineId.isEmpty) return -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].id == lineId) return i;
    }
    return -1;
  }

  /// 第 [index] 段话的编号（越界返回 null）。
  String? lineIdAt(int index) =>
      index >= 0 && index < lines.length ? lines[index].id : null;

  @override
  String toString() {
    final nexts = checkpoints.map((c) => c.next ?? 'END').join(',');
    return '$id(lines${lines.length},cp${checkpoints.length}→{$nexts})';
  }
}
