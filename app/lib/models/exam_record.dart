class ExamRecord {
  const ExamRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.createdAt,
    required this.singleCorrect,
    required this.multiCorrect,
    this.linkedWrongItemIds = const [],
    this.note = '',
  });

  final String id;
  final String title;
  final DateTime date;
  final DateTime createdAt;
  final int singleCorrect;
  final int multiCorrect;
  final List<String> linkedWrongItemIds;
  final String note;

  int get totalScore => singleCorrect + multiCorrect * 2;

  ExamRecord copyWith({
    String? id,
    String? title,
    DateTime? date,
    DateTime? createdAt,
    int? singleCorrect,
    int? multiCorrect,
    List<String>? linkedWrongItemIds,
    String? note,
  }) {
    return ExamRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      singleCorrect: singleCorrect ?? this.singleCorrect,
      multiCorrect: multiCorrect ?? this.multiCorrect,
      linkedWrongItemIds: linkedWrongItemIds ?? this.linkedWrongItemIds,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'singleCorrect': singleCorrect,
    'multiCorrect': multiCorrect,
    'linkedWrongItemIds': linkedWrongItemIds,
    'note': note,
  };

  factory ExamRecord.fromJson(Map<String, dynamic> json) {
    return ExamRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      singleCorrect: json['singleCorrect'] as int? ?? 0,
      multiCorrect: json['multiCorrect'] as int? ?? 0,
      linkedWrongItemIds:
          (json['linkedWrongItemIds'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      note: json['note'] as String? ?? '',
    );
  }
}
