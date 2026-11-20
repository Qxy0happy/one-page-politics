import '../models/knowledge_item.dart';

class MergeResult {
  const MergeResult({
    required this.items,
    required this.added,
    required this.updated,
    required this.keptLocal,
    required this.missing,
  });

  final List<KnowledgeItem> items;
  final int added;
  final int updated;
  final int keptLocal;
  final int missing;
}

class MergeService {
  MergeResult merge(
    List<KnowledgeItem> existing,
    List<KnowledgeItem> incoming, {
    bool overrideLocalEdits = false,
  }) {
    final incomingById = {for (final item in incoming) item.id: item};
    final existingIds = {for (final item in existing) item.id};
    final result = <KnowledgeItem>[];
    var updated = 0;
    var keptLocal = 0;
    var missing = 0;

    for (final old in existing) {
      final next = incomingById[old.id];
      if (next == null) {
        result.add(old);
        missing++;
        continue;
      }
      if (old.isCustomEdited && !overrideLocalEdits) {
        result.add(old);
        keptLocal++;
        continue;
      }
      result.add(
        old.copyWith(
          prompt: next.prompt,
          answer: next.answer,
          explanation: next.explanation,
          isTrue: next.isTrue,
          mnemonic: next.mnemonic,
          pairAFeature: next.pairAFeature,
          pairBFeature: next.pairBFeature,
          tombstoneWords: next.tombstoneWords,
          sourceNote: next.sourceNote,
          isRound2Focus: next.isRound2Focus,
          isCustomEdited: false,
        ),
      );
      updated++;
    }

    var added = 0;
    for (final item in incoming) {
      if (existingIds.contains(item.id)) continue;
      result.add(item);
      added++;
    }

    return MergeResult(
      items: result,
      added: added,
      updated: updated,
      keptLocal: keptLocal,
      missing: missing,
    );
  }
}
