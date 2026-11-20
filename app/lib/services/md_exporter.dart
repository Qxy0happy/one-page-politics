import '../models/knowledge_item.dart';

class MdExporter {
  String export(List<KnowledgeItem> items) {
    final grouped = <Subject, Map<String, List<KnowledgeItem>>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(item.subject, () => {})
          .putIfAbsent(item.chapter, () => [])
          .add(item);
    }

    final buffer = StringBuffer();
    for (final subject in Subject.values) {
      final chapters = grouped[subject];
      if (chapters == null || chapters.isEmpty) continue;
      buffer.writeln('# ${subject.label}');
      for (final entry in chapters.entries) {
        buffer.writeln('## ${entry.key}');
        for (final item in entry.value) {
          buffer.writeln('- ${_line(item)}');
        }
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _line(KnowledgeItem item) {
    final parts = <String>[];
    switch (item.cardType) {
      case CardType.mapping:
        parts.add('[配对] ${_clean(item.prompt)} == ${_clean(item.answer)}');
      case CardType.trueFalse:
        parts.add(
          '[${item.isTrue == true ? '对' : '错'}] ${_clean(item.prompt)}',
        );
      case CardType.pair:
        final a = _withFeature(item.prompt, item.pairAFeature);
        final b = _withFeature(item.answer, item.pairBFeature);
        parts.add('[对比] ${_clean(a)} <> ${_clean(b)}');
    }
    if (item.mnemonic.isNotEmpty) {
      parts.add('口诀: ${_clean(item.mnemonic)}');
    }
    if (item.explanation.isNotEmpty) {
      parts.add('解析: ${_clean(item.explanation)}');
    }
    if (item.tombstoneWords.isNotEmpty) {
      parts.add('墓碑词: ${item.tombstoneWords.map(_clean).join('，')}');
    }
    if (item.sourceNote.isNotEmpty) {
      parts.add('备注: ${_clean(item.sourceNote)}');
    }
    parts.add('id: ${item.id}');

    var line = parts.join(' | ');
    if (item.isRound2Focus) line += ' #二轮';
    if (item.isMappingDrill) line += ' #配对';
    return line;
  }

  String _withFeature(String name, String? feature) {
    if (feature == null || feature.isEmpty) return name;
    return '$name（$feature）';
  }

  String _clean(String value) => value.replaceAll('|', '／').trim();
}
