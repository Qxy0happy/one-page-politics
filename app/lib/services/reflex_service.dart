import 'dart:math';

import '../models/knowledge_item.dart';

class ReflexService {
  ReflexService({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const trueFalseSize = 15;
  static const pairSize = 15;
  static const mappingBatch = 4;
  static const mappingSize = mappingBatch * 4;

  int sessionSize(CardType type) => type == CardType.mapping ? mappingSize : 15;

  bool isUsable(KnowledgeItem item) {
    if (item.cardType == CardType.pair) {
      return (item.pairAFeature?.isNotEmpty ?? false) &&
          (item.pairBFeature?.isNotEmpty ?? false);
    }
    return true;
  }

  int availableCount(List<KnowledgeItem> items, CardType type) =>
      _sourcePool(items, type).where(isUsable).length;

  bool canStart(List<KnowledgeItem> items, CardType type) {
    final count = availableCount(items, type);
    return type == CardType.mapping ? count >= mappingBatch : count > 0;
  }

  List<KnowledgeItem> _sourcePool(List<KnowledgeItem> items, CardType type) {
    if (type != CardType.mapping) {
      return items
          .where((item) => item.cardType == type)
          .toList(growable: false);
    }
    final drill = items
        .where((item) => item.cardType == type && item.isMappingDrill)
        .toList(growable: false);
    if (drill.isNotEmpty) return drill;
    // 兼容旧数据：没有 `#配对` 标记时退回全部配对卡。
    return items.where((item) => item.cardType == type).toList(growable: false);
  }

  List<KnowledgeItem> buildQueue(
    List<KnowledgeItem> items,
    CardType type, {
    int? size,
  }) {
    final target = size ?? sessionSize(type);
    final pool = _sourcePool(items, type).where(isUsable).toList()
      ..shuffle(_random);
    pool.sort((a, b) {
      final byPriority = _priority(a).compareTo(_priority(b));
      if (byPriority != 0) return byPriority;
      return a.reviewCount.compareTo(b.reviewCount);
    });

    if (type != CardType.mapping) {
      return pool.take(target).toList(growable: false);
    }

    final selected = <KnowledgeItem>[];
    for (final item in pool) {
      if (selected.length >= target) break;
      final batchStart = (selected.length ~/ mappingBatch) * mappingBatch;
      final batch = selected.sublist(batchStart);
      final duplicate = batch.any(
        (entry) => entry.prompt == item.prompt || entry.answer == item.answer,
      );
      if (duplicate) continue;
      selected.add(item);
    }
    if (selected.length < target) {
      for (final item in pool) {
        if (selected.length >= target) break;
        if (!selected.contains(item)) selected.add(item);
      }
    }
    return selected;
  }

  static int _priority(KnowledgeItem item) {
    if (item.status == StudyStatus.fuzzy || item.isStarred) return 0;
    if (item.status == StudyStatus.unseen) return 1;
    return 2;
  }
}
