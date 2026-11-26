class StoryItem {
  final String id;
  final String name;
  final int initial;
  final String description;
  final String asset;
  final String kind;

  const StoryItem({
    required this.id,
    required this.name,
    this.initial = 0,
    this.description = '',
    this.asset = '',
    this.kind = '',
  });

  factory StoryItem.fromJson(Map<String, dynamic> json, {String fallbackId = ''}) {
    final raw = (json['id'] ?? fallbackId).toString().trim();
    return StoryItem(
      id: raw,
      name: (json['name'] ?? raw).toString().trim(),
      initial: (json['initial'] as num?)?.toInt() ?? 0,
      description: (json['description'] ?? '').toString().trim(),
      asset: (json['asset'] ?? '').toString().trim(),
      kind: (json['kind'] ?? '').toString().trim(),
    );
  }

  bool get isConcrete => asset.isNotEmpty;

  String get resolvedKind {
    if (kind == 'text' || kind == 'image' || kind == 'audio' || kind == 'video') {
      return kind;
    }
    final lower = asset.toLowerCase();
    if (lower.endsWith('.txt')) return 'text';
    if (lower.contains('/audio/') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.flac')) {
      return 'audio';
    }
    if (lower.contains('/video/') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov')) {
      return 'video';
    }
    return asset.isEmpty ? '' : 'image';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (initial != 0) 'initial': initial,
    if (description.isNotEmpty) 'description': description,
    if (asset.isNotEmpty) 'asset': asset,
    if (kind.isNotEmpty) 'kind': kind,
  };
}

class Condition {
  final List<_Term> _terms;

  const Condition._(this._terms);

  static const Condition always = Condition._([]);

  static Condition parse(String source) {
    final text = source.trim();
    if (text.isEmpty) return always;
    final terms = <_Term>[];
    for (final part in text.split('&&')) {
      final term = _Term.parse(part);
      if (term != null) terms.add(term);
    }
    return Condition._(terms);
  }

  bool isSatisfiedBy(Map<String, int> holdings) {
    for (final term in _terms) {
      if (!term.holds(holdings[term.itemId] ?? 0)) return false;
    }
    return true;
  }

  bool get isEmpty => _terms.isEmpty;
}

class _Term {
  final String itemId;
  final String op;
  final int value;

  const _Term(this.itemId, this.op, this.value);

  static final RegExp _pattern = RegExp(
    r'^\s*([^\s<>=!]+)\s*(>=|<=|==|!=|>|<)?\s*(-?\d+)?\s*$',
  );

  static _Term? parse(String raw) {
    final match = _pattern.firstMatch(raw);
    if (match == null) return null;
    final id = match.group(1)!;
    final op = match.group(2);
    final number = match.group(3);
    if (op == null || number == null) return _Term(id, '>=', 1);
    return _Term(id, op, int.parse(number));
  }

  bool holds(int actual) => switch (op) {
    '>=' => actual >= value,
    '<=' => actual <= value,
    '>' => actual > value,
    '<' => actual < value,
    '==' => actual == value,
    '!=' => actual != value,
    _ => actual >= value,
  };
}
