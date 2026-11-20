import '../models/knowledge_item.dart';
import '../models/sheet_path.dart';

class SheetProgress {
  const SheetProgress({
    required this.total,
    required this.familiar,
    required this.fuzzy,
  });

  final int total;
  final int familiar;
  final int fuzzy;

  String get summary => '$total 条 · 眼熟 $familiar · 模糊 $fuzzy';
}

class SheetNode {
  const SheetNode({
    required this.path,
    required this.label,
    required this.progress,
    this.children = const [],
  });

  final SheetPath path;
  final String label;
  final SheetProgress progress;
  final List<SheetNode> children;

  bool get hasChildren => children.isNotEmpty;
}

/// 一次遍历聚合出“科目 → 章节 / 卡片类型”的目录树与三态计数。
///
/// 只有“未分章”的科目（思修、新思想、时政）直接以卡片类型作为子节点；
/// 命名章节不按卡片类型继续拆分。
SheetNode buildSheetTree(List<KnowledgeItem> items) {
  final root = _ProgressCounter();
  final subjects = <Subject, _ProgressCounter>{};
  final chapters = <(Subject, String), _ProgressCounter>{};
  final types = <(Subject, String, CardType), _ProgressCounter>{};

  for (final item in items) {
    root.add(item);
    subjects.putIfAbsent(item.subject, _ProgressCounter.new).add(item);
    chapters
        .putIfAbsent((item.subject, item.chapter), _ProgressCounter.new)
        .add(item);
    types
        .putIfAbsent((
          item.subject,
          item.chapter,
          item.cardType,
        ), _ProgressCounter.new)
        .add(item);
  }

  final subjectNodes = <SheetNode>[];
  for (final subject in Subject.values) {
    final subjectCounter = subjects[subject];
    if (subjectCounter == null) continue;

    final chapterEntries = chapters.entries
        .where((entry) => entry.key.$1 == subject)
        .toList(growable: false);
    final onlyUnchaptered =
        chapterEntries.length == 1 &&
        chapterEntries.first.key.$2 == kUnchaptered;

    final chapterNodes = <SheetNode>[];
    if (onlyUnchaptered) {
      final chapter = chapterEntries.first.key.$2;
      chapterNodes.addAll(_typeNodes(subject, chapter, types));
    } else {
      for (final entry in chapterEntries) {
        final chapter = entry.key.$2;
        chapterNodes.add(
          SheetNode(
            path: SheetPath(subject: subject, chapter: chapter),
            label: chapter,
            progress: entry.value.toProgress(),
            children: chapter == kUnchaptered
                ? _typeNodes(subject, chapter, types)
                : const [],
          ),
        );
      }
    }

    subjectNodes.add(
      SheetNode(
        path: SheetPath(subject: subject),
        label: subject.label,
        progress: subjectCounter.toProgress(),
        children: List.unmodifiable(chapterNodes),
      ),
    );
  }

  return SheetNode(
    path: SheetPath.root,
    label: '全部',
    progress: root.toProgress(),
    children: List.unmodifiable(subjectNodes),
  );
}

List<SheetNode> _typeNodes(
  Subject subject,
  String chapter,
  Map<(Subject, String, CardType), _ProgressCounter> counters,
) {
  final nodes = <SheetNode>[];
  for (final type in CardType.values) {
    final counter = counters[(subject, chapter, type)];
    if (counter == null) continue;
    nodes.add(
      SheetNode(
        path: SheetPath(subject: subject, chapter: chapter, cardType: type),
        label: type.label,
        progress: counter.toProgress(),
      ),
    );
  }
  return List.unmodifiable(nodes);
}

class _ProgressCounter {
  int total = 0;
  int familiar = 0;
  int fuzzy = 0;

  void add(KnowledgeItem item) {
    total++;
    switch (item.status) {
      case StudyStatus.familiar:
        familiar++;
      case StudyStatus.fuzzy:
        fuzzy++;
      case StudyStatus.unseen:
        break;
    }
  }

  SheetProgress toProgress() =>
      SheetProgress(total: total, familiar: familiar, fuzzy: fuzzy);
}
