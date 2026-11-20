import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/services/calc_generator.dart';
import 'package:one_page_politics/services/reflex_service.dart';

KnowledgeItem _item(
  String id, {
  CardType type = CardType.trueFalse,
  StudyStatus status = StudyStatus.unseen,
  bool starred = false,
  bool drill = false,
  int reviews = 0,
  String? pairA,
  String? pairB,
}) {
  return KnowledgeItem(
    id: id,
    subject: Subject.mayuan,
    chapter: '章',
    cardType: type,
    prompt: '题干 $id',
    answer: '答案 $id',
    pairAFeature: pairA,
    pairBFeature: pairB,
    status: status,
    isStarred: starred,
    isMappingDrill: drill,
    reviewCount: reviews,
  );
}

void main() {
  test('选题优先级：模糊/标星优先，其次未看，最后眼熟', () {
    final items = [
      _item('familiar', status: StudyStatus.familiar),
      _item('unseen', status: StudyStatus.unseen),
      _item('fuzzy', status: StudyStatus.fuzzy),
      _item('starred', status: StudyStatus.familiar, starred: true),
    ];
    final queue = ReflexService(random: Random(1))
        .buildQueue(items, CardType.trueFalse, size: 4);
    final priorities = queue
        .map(
          (item) => item.status == StudyStatus.fuzzy || item.isStarred
              ? 0
              : item.status == StudyStatus.unseen
              ? 1
              : 2,
        )
        .toList();
    expect(priorities, [0, 0, 1, 2]);
  });

  test('双胞胎缺少特征时不计入可用题量', () {
    final items = [
      _item('ok', type: CardType.pair, pairA: 'A 特征', pairB: 'B 特征'),
      _item('missing', type: CardType.pair, pairA: 'A 特征'),
    ];
    final service = ReflexService(random: Random(2));
    expect(service.availableCount(items, CardType.pair), 1);
    expect(service.canStart(items, CardType.pair), isTrue);
  });

  test('配对队列每批 4 条，题干与答案不重复', () {
    final items = List.generate(
      20,
      (index) => _item(
        'm$index',
        type: CardType.mapping,
        status: index.isEven ? StudyStatus.unseen : StudyStatus.familiar,
      ),
    );
    final queue = ReflexService(random: Random(3))
        .buildQueue(items, CardType.mapping);
    expect(queue.length, 16);
    for (var start = 0; start < queue.length; start += 4) {
      final batch = queue.sublist(start, start + 4);
      expect(batch.map((item) => item.prompt).toSet().length, 4);
      expect(batch.map((item) => item.answer).toSet().length, 4);
    }
  });

  test('配对训练只消费 #配对 标记；旧数据回退全部配对卡', () {
    final marked = _item('marked', type: CardType.mapping, drill: true);
    final plain = _item('plain', type: CardType.mapping);
    final service = ReflexService(random: Random(6));

    expect(service.availableCount([marked, plain], CardType.mapping), 1);
    final queue = service.buildQueue(
      [marked, plain],
      CardType.mapping,
      size: 4,
    );
    expect(queue.map((item) => item.id), ['marked']);

    expect(service.availableCount([plain], CardType.mapping), 1);
  });

  test('计算器生成合法题：答案有限、正数、有解析', () {
    final generator = CalcGenerator(random: Random(4));
    for (final type in CalcQuestionType.values) {
      for (var i = 0; i < 100; i++) {
        final question = generator.next(type);
        expect(question.answer.isFinite, isTrue);
        expect(question.answer, greaterThan(0));
        expect(question.prompt, isNotEmpty);
        expect(question.explanation, isNotEmpty);
        expect(question.type, type);
      }
    }
  });

  test('利润题满足 M = V × m′，且 V 与有机构成一致', () {
    final generator = CalcGenerator(random: Random(5));
    for (var i = 0; i < 100; i++) {
      final question = generator.next(CalcQuestionType.profit);
      final totalMatch = RegExp(r'C\+V = (\d+) 万元').firstMatch(question.prompt);
      final ratioMatch = RegExp(r'C:V = (\d+):(\d+)')
          .firstMatch(question.prompt);
      final rateMatch = RegExp(r'm′ = (\d+)%').firstMatch(question.prompt);
      expect(totalMatch, isNotNull);
      expect(ratioMatch, isNotNull);
      expect(rateMatch, isNotNull);
      final total = int.parse(totalMatch!.group(1)!);
      final cPart = int.parse(ratioMatch!.group(1)!);
      final vPart = int.parse(ratioMatch.group(2)!);
      final rate = int.parse(rateMatch!.group(1)!);
      final v = total / (1 + cPart / vPart);
      final expected = v * rate / 100;
      expect(question.answer, closeTo(expected, 0.0001));
    }
  });
}
