import 'knowledge_item.dart';

/// 一页纸的筛选路径：科目 → 章节 → 卡片类型。空值表示该层不限制。
class SheetPath {
  const SheetPath({this.subject, this.chapter, this.cardType});

  static const root = SheetPath();

  final Subject? subject;
  final String? chapter;
  final CardType? cardType;

  bool get isRoot => subject == null;

  bool matches(KnowledgeItem item) {
    if (subject != null && item.subject != subject) return false;
    if (chapter != null && item.chapter != chapter) return false;
    if (cardType != null && item.cardType != cardType) return false;
    return true;
  }

  /// 当前路径是否落在 [ancestor] 之下（含相等）。
  bool isUnder(SheetPath ancestor) {
    if (ancestor.subject != null && subject != ancestor.subject) return false;
    if (ancestor.chapter != null && chapter != ancestor.chapter) return false;
    if (ancestor.cardType != null && cardType != ancestor.cardType) {
      return false;
    }
    return true;
  }

  /// 路径栏短标签：章节只保留编号，“未分章”不单独显示。
  String get label {
    if (subject == null) return '全部';
    final parts = <String>[subject!.label];
    if (chapter != null && chapter != kUnchaptered) {
      parts.add(_shortChapter(chapter!));
    }
    if (cardType != null) {
      parts.add(cardType!.label);
    }
    return parts.join(' › ');
  }

  static final _chapterNumber = RegExp(r'^(\d+(?:\.\d+)+)\b');

  static String _shortChapter(String chapter) =>
      _chapterNumber.firstMatch(chapter)?.group(1) ?? chapter;

  Map<String, dynamic> toJson() => {
    'subject': subject?.name,
    'chapter': chapter,
    'cardType': cardType?.name,
  };

  factory SheetPath.fromJson(Map<String, dynamic> json) {
    final subject = _subjectByName(json['subject']);
    if (subject == null) return root;
    final chapterValue = json['chapter'];
    final rawChapter = chapterValue is String ? chapterValue.trim() : '';
    final chapter = rawChapter.isEmpty ? null : rawChapter;
    if (chapter == null) return SheetPath(subject: subject);
    final cardType = chapter == kUnchaptered
        ? _cardTypeByName(json['cardType'])
        : null;
    return SheetPath(subject: subject, chapter: chapter, cardType: cardType);
  }

  static Subject? _subjectByName(Object? value) {
    if (value is! String) return null;
    for (final subject in Subject.values) {
      if (subject.name == value) return subject;
    }
    return null;
  }

  static CardType? _cardTypeByName(Object? value) {
    if (value is! String) return null;
    for (final type in CardType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SheetPath &&
      other.subject == subject &&
      other.chapter == chapter &&
      other.cardType == cardType;

  @override
  int get hashCode => Object.hash(subject, chapter, cardType);

  @override
  String toString() => 'SheetPath($label)';
}
