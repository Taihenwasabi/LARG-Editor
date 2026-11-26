import 'package:larg_editor/engine/model/check.dart';
import 'package:larg_editor/model/game_item.dart';

class AiSendItemConfig {
  final GameItemKind kind;
  final String name;
  final String requirement;
  final int quantity;
  final bool showInInventory;
  final bool showInStory;

  const AiSendItemConfig({
    required this.kind,
    this.name = '',
    this.requirement = '',
    this.quantity = 1,
    this.showInInventory = true,
    this.showInStory = true,
  });

  factory AiSendItemConfig.fromJson(Map<String, dynamic> j) {
    return AiSendItemConfig(
      kind: GameItemKind.values.firstWhere(
        (e) => e.name == j['kind'],
        orElse: () => GameItemKind.text,
      ),
      name: (j['name'] ?? '').toString(),
      requirement: (j['requirement'] ?? '').toString(),
      quantity: ((j['quantity'] as num?)?.toInt() ?? 1).clamp(1, 99),
      showInInventory: (j['show_in_inventory'] ?? 'yes').toString() != 'no',
      showInStory: (j['show_in_story'] ?? 'yes').toString() != 'no',
    );
  }
}

const List<String> kCheckTypes = [
  'photo_submit',
  'media_submit',
  'text_answer',
  'condition',
];

class SubmitRequirement {
  final int need;
  final Set<GameItemKind> kinds;
  final String label;
  final bool needText;

  const SubmitRequirement({
    this.need = 0,
    this.kinds = const {},
    this.label = '',
    this.needText = false,
  });

  bool allows(GameItemKind kind) => kinds.isEmpty || kinds.contains(kind);

  bool get showsTypes =>
      label.isNotEmpty ||
      (kinds.isNotEmpty && kinds.length < GameItemKind.values.length);
}

extension CheckAiConfig on Check {
  bool get aiEnabled => aiCriteria.isNotEmpty || aiPoints.isNotEmpty;

  String get aiCriteria => (params['ai_criteria'] ?? '').toString().trim();

  List<String> get aiPoints {
    final raw = params['ai_points'];
    if (raw is! List) return const [];
    return [
      for (final it in raw)
        if (it.toString().trim().isNotEmpty) it.toString().trim(),
    ];
  }

  bool get aiPassAny => (params['ai_pass'] ?? '').toString() == 'any';

  String get failText => (params['fail_text'] ?? '').toString().trim();

  bool get showAuthorHint => (params['show_author_hint'] ?? 'yes').toString() != 'no';

  bool get showAiReasons => (params['show_ai_reasons'] ?? 'no').toString() == 'yes';

  int get requireCount => ((params['requireCount'] as num?)?.toInt() ?? 0).clamp(
    0,
    99,
  );

  bool get supportsLocalJudge => kCheckTypes.contains(type);

  SubmitRequirement get submitRequirement {
    final rawKinds = params['submit_kinds'];
    final kinds = <GameItemKind>{
      if (rawKinds is List)
        for (final raw in rawKinds)
          ...GameItemKind.values.where((e) => e.name == raw.toString()),
    };
    final label = (params['submit_label'] ?? '').toString().trim();
    final rawNeedText = params['need_text'];
    final rawNeed = params['submit_need'];
    if (rawNeed is num) {
      return SubmitRequirement(
        need: rawNeed.toInt().clamp(0, 99),
        kinds: kinds,
        label: label,
        needText: rawNeedText is bool ? rawNeedText : type == 'text_answer',
      );
    }
    final required = requireCount == 0 ? 1 : requireCount;
    if (type == 'photo_submit') {
      return SubmitRequirement(
        need: required,
        kinds: {GameItemKind.image},
        label: label,
      );
    }
    if (type == 'media_submit') {
      return SubmitRequirement(
        need: required,
        kinds: {GameItemKind.image, GameItemKind.audio, GameItemKind.video},
        label: label,
      );
    }
    if (type == 'text_answer') {
      return SubmitRequirement(
        label: label,
        needText: rawNeedText is bool ? rawNeedText : true,
      );
    }
    return SubmitRequirement(label: label, needText: rawNeedText == true);
  }

  List<AiSendItemConfig> get aiSendItems {
    final raw = params['ai_send_items'];
    if (raw is! List) return const [];
    final seen = <GameItemKind>{};
    final out = <AiSendItemConfig>[];
    for (final it in raw) {
      if (it is! Map) continue;
      final cfg = AiSendItemConfig.fromJson(Map<String, dynamic>.from(it));
      if (!seen.add(cfg.kind)) continue;
      out.add(cfg);
    }
    return out;
  }
}
