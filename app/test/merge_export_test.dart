import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/services/md_exporter.dart';
import 'package:one_page_politics/services/md_parser_service.dart';
import 'package:one_page_politics/services/merge_service.dart';

KnowledgeItem _item(
  String id, {
  String prompt = '题干',
  String answer = '旧结论',
  CardType type = CardType.mapping,
  StudyStatus status = StudyStatus.unseen,
  bool starred = false,
  bool edited = false,
  int reviews = 0,
  String note = '',
}) {
  return KnowledgeItem(
    id: id,
    subject: Subject.mayuan,
    chapter: '1.1',
    cardType: type,
    prompt: prompt,
    answer: answer,
    status: status,
    isStarred: starred,
    isCustomEdited: edited,
    reviewCount: reviews,
    userNote: note,
  );
}

void main() {
  test('合并：更新保留进度，手改保留本地，缺失保留，新条目加入', () {
    final existing = [
      _item(
        'mayuan.mapping.3f2a1b0c',
        status: StudyStatus.fuzzy,
        starred: true,
        reviews: 7,
        note: '我的备注',
      ),
      _item(
        'mayuan.mapping.aaaaaaaa',
        prompt: '本地题干',
        answer: '本地结论',
        edited: true,
      ),
      _item('mayuan.mapping.cccccccc', prompt: '缺失题'),
    ];
    final incoming = [
      _item('mayuan.mapping.3f2a1b0c', answer: '新结论'),
      _item('mayuan.mapping.aaaaaaaa', prompt: '导入题干', answer: '导入结论'),
      _item('mayuan.mapping.bbbbbbbb', prompt: '新题', answer: '新答'),
    ];
    final result = MergeService().merge(existing, incoming);
    expect(result.added, 1);
    expect(result.updated, 1);
    expect(result.keptLocal, 1);
    expect(result.missing, 1);
    expect(result.items, hasLength(4));

    final updated = result.items.firstWhere(
      (item) => item.id == 'mayuan.mapping.3f2a1b0c',
    );
    expect(updated.answer, '新结论');
    expect(updated.status, StudyStatus.fuzzy);
    expect(updated.isStarred, isTrue);
    expect(updated.reviewCount, 7);
    expect(updated.userNote, '我的备注');

    final kept = result.items.firstWhere(
      (item) => item.id == 'mayuan.mapping.aaaaaaaa',
    );
    expect(kept.answer, '本地结论');
    expect(kept.prompt, '本地题干');

    expect(
      result.items.any((item) => item.id == 'mayuan.mapping.cccccccc'),
      isTrue,
    );
    expect(
      result.items.any((item) => item.id == 'mayuan.mapping.bbbbbbbb'),
      isTrue,
    );
  });

  test('导出再导入按 id 命中并保留内容', () {
    final items = [
      const KnowledgeItem(
        id: 'mayuan.mapping.3f2a1b0c',
        subject: Subject.mayuan,
        chapter: '1.1',
        cardType: CardType.mapping,
        prompt: '理解政治经济学的枢纽',
        answer: '劳动二重性理论',
        explanation: '对应关系',
        mnemonic: '劳二枢纽',
        tombstoneWords: ['根本', '唯一'],
        sourceNote: '原文如此',
        isRound2Focus: true,
        isMappingDrill: true,
      ),
      const KnowledgeItem(
        id: 'mayuan.trueFalse.aaaaaaaa',
        subject: Subject.mayuan,
        chapter: '1.4',
        cardType: CardType.trueFalse,
        prompt: '意识／观念具有直接现实性',
        explanation: '直接现实性为实践特有',
        isTrue: false,
      ),
      const KnowledgeItem(
        id: 'mayuan.pair.bbbbbbbb',
        subject: Subject.mayuan,
        chapter: '1.2',
        cardType: CardType.pair,
        prompt: '工作重心转向城市',
        answer: '革命重心转向城市',
        pairAFeature: '七届二中全会',
        pairBFeature: '1949 年进北平',
      ),
    ];
    final markdown = MdExporter().export(items);
    final parsed = MdParserService().parse(markdown);
    expect(parsed.errors, isEmpty);
    expect(parsed.items, hasLength(3));
    for (final original in items) {
      final restored = parsed.items.firstWhere(
        (item) => item.id == original.id,
      );
      expect(restored.prompt, original.prompt);
      expect(restored.answer, original.answer);
      expect(restored.explanation, original.explanation);
      expect(restored.isTrue, original.isTrue);
      expect(restored.pairAFeature, original.pairAFeature);
      expect(restored.pairBFeature, original.pairBFeature);
      expect(restored.isRound2Focus, original.isRound2Focus);
      expect(restored.isMappingDrill, original.isMappingDrill);
    }
  });
}
