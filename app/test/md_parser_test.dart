import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/services/md_parser_service.dart';

void main() {
  group('MD 协议', () {
    test('四类行与扩展字段', () {
      const text = '''
# 马原
## 1.1 基础概念与帽子
- [配对] 理解政治经济学的枢纽 == 劳动二重性理论 | 口诀: 劳二枢纽 | 备注: 原文如此 #二轮 #配对
- [错] 意识和观念具有直接现实性 | 解析: 直接现实性是实践的特有属性。 | 墓碑词: 直接现实性
- [对] 人体解剖是猴体解剖的一把钥匙 | 解析: 马克思在《资本论》中的比喻。
- [对比] 工作重心转向城市（七届二中全会） <> 革命重心转向城市（1949 年进北平） | 口诀: 工作七二，革命进京 #二轮
''';
      final result = MdParserService().parse(text);
      expect(result.errors, isEmpty);
      expect(result.items, hasLength(4));

      final mapping = result.items[0];
      expect(mapping.cardType, CardType.mapping);
      expect(mapping.prompt, '理解政治经济学的枢纽');
      expect(mapping.answer, '劳动二重性理论');
      expect(mapping.mnemonic, '劳二枢纽');
      expect(mapping.sourceNote, '原文如此');
      expect(mapping.isRound2Focus, isTrue);
      expect(mapping.isMappingDrill, isTrue);
      expect(mapping.status, StudyStatus.unseen);
      expect(mapping.isStarred, isFalse);

      final wrong = result.items[1];
      expect(wrong.cardType, CardType.trueFalse);
      expect(wrong.isTrue, isFalse);
      expect(wrong.tombstoneWords, ['直接现实性']);

      final right = result.items[2];
      expect(right.isTrue, isTrue);

      final pair = result.items[3];
      expect(pair.cardType, CardType.pair);
      expect(pair.prompt, '工作重心转向城市');
      expect(pair.pairAFeature, '七届二中全会');
      expect(pair.answer, '革命重心转向城市');
      expect(pair.pairBFeature, '1949 年进北平');
      expect(pair.mnemonic, '工作七二，革命进京');
    });

    test('重复 id 报错', () {
      const text = '''
# 马原
## 章
- [对] 同一句话
- [对] 同一句话
''';
      final result = MdParserService().parse(text);
      expect(result.errors.any((e) => e.contains('重复 id')), isTrue);
    });

    test('未知科目报错', () {
      const text = '''
# 未知科目
## 章
- [对] 一句话
''';
      final result = MdParserService().parse(text);
      expect(result.errors.any((e) => e.contains('科目标题无法唯一匹配')), isTrue);
    });

    test('对比侧缺少括号时保留条目并警告', () {
      const text = '''
# 马原
## 章
- [对比] A <> B
''';
      final result = MdParserService().parse(text);
      expect(result.errors, isEmpty);
      expect(result.items.single.pairAFeature, isNull);
      expect(result.warnings, isNotEmpty);
    });

    test('规范化后相同题干得到相同 id', () {
      final a = MdParserService().parse('''
# 马原
## 章
- [配对] 实践是检验真理的唯一标准（之一） == 对
''');
      final b = MdParserService().parse('''
# 马原
## 章
- [配对] 实践是检验真理的唯一标准(之一) == 对
''');
      expect(a.errors, isEmpty);
      expect(b.errors, isEmpty);
      expect(a.items.single.id, b.items.single.id);
      expect(
        a.items.single.id,
        matches(RegExp(r'^mayuan\.mapping\.[0-9a-f]{8}$')),
      );
    });

    test('显式 id 必须与科目和类型一致', () {
      final ok = MdParserService().parse('''
# 马原
## 章
- [配对] 题干 == 结论 | id: mayuan.mapping.3f2a1b0c
''');
      expect(ok.errors, isEmpty);
      expect(ok.items.single.id, 'mayuan.mapping.3f2a1b0c');

      final bad = MdParserService().parse('''
# 马原
## 章
- [配对] 题干 == 结论 | id: shigang.mapping.3f2a1b0c
''');
      expect(bad.errors.any((e) => e.contains('id 前缀')), isTrue);
    });
  });
}
