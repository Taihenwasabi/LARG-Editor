enum GameItemKind { text, image, audio, video }
enum GameItemSource { player, ai, pack }
enum GameItemStatus { stored, ready, failed }

class GameItemRecord {
  final String id;
  final GameItemKind kind;
  final GameItemSource source;
  final String name;
  final String summary;
  final String description;
  final GameItemStatus status;
  final String mime;
  final int quantity;
  final int submitCount;
  final bool showInInventory;
  final bool showInStory;

  const GameItemRecord({
    required this.id,
    required this.kind,
    required this.source,
    required this.name,
    required this.summary,
    required this.status,
    required this.mime,
    this.description = '',
    this.quantity = 1,
    this.submitCount = 0,
    this.showInInventory = true,
    this.showInStory = true,
  });

  GameItemRecord copyWith({
    String? name,
    String? summary,
    String? description,
    GameItemStatus? status,
    String? mime,
    int? quantity,
    int? submitCount,
  }) {
    return GameItemRecord(
      id: id,
      kind: kind,
      source: source,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      status: status ?? this.status,
      mime: mime ?? this.mime,
      quantity: quantity ?? this.quantity,
      submitCount: submitCount ?? this.submitCount,
      showInInventory: showInInventory,
      showInStory: showInStory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'source': source.name,
    'name': name,
    'summary': summary,
    if (description.isNotEmpty) 'description': description,
    'status': status.name,
    'mime': mime,
    'quantity': quantity,
    if (submitCount > 0) 'submit_count': submitCount,
    'show_in_inventory': showInInventory,
    'show_in_story': showInStory,
  };

  factory GameItemRecord.fromJson(Map<String, dynamic> j) {
    return GameItemRecord(
      id: (j['id'] ?? '').toString(),
      kind: GameItemKind.values.firstWhere(
        (e) => e.name == j['kind'],
        orElse: () => GameItemKind.text,
      ),
      source: GameItemSource.values.firstWhere(
        (e) => e.name == j['source'],
        orElse: () => GameItemSource.player,
      ),
      name: (j['name'] ?? '').toString(),
      summary: (j['summary'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      status: GameItemStatus.values.firstWhere(
        (e) => e.name == j['status'],
        orElse: () => GameItemStatus.stored,
      ),
      mime: (j['mime'] ?? '').toString(),
      quantity: ((j['quantity'] as num?)?.toInt() ?? 1).clamp(1, 99),
      submitCount: ((j['submit_count'] as num?)?.toInt() ?? 0).clamp(0, 9999),
      showInInventory: (j['show_in_inventory'] ?? true) != false,
      showInStory: (j['show_in_story'] ?? true) != false,
    );
  }
}
