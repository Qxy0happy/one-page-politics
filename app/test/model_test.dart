import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/exam_record.dart';
import 'package:one_page_politics/models/knowledge_item.dart';

void main() {
  test('KnowledgeItem JSON 往返保留内容与进度', () {
    const item = KnowledgeItem(
      id: 'mayuan.pair.3f2a1b0c',
      subject: Subject.mayuan,
      chapter: '1.1',
      cardType: CardType.pair,
      prompt: '工作重心转向城市',
      answer: '革命重心转向城市',
      explanation: '注意工作重心与革命重心',
      mnemonic: '工作七二，革命进京',
      pairAFeature: '七届二中全会',
      pairBFeature: '1949 年进北平',
      tombstoneWords: ['根本', '唯一'],
      sourceNote: '原文如此',
      isRound2Focus: true,
      isMappingDrill: true,
      status: StudyStatus.fuzzy,
      isStarred: true,
      userNote: '我的备注',
      isCustomEdited: true,
      reviewCount: 7,
    );
    final restored = KnowledgeItem.fromJson(item.toJson());
    expect(restored.id, item.id);
    expect(restored.subject, item.subject);
    expect(restored.cardType, item.cardType);
    expect(restored.prompt, item.prompt);
    expect(restored.answer, item.answer);
    expect(restored.explanation, item.explanation);
    expect(restored.mnemonic, item.mnemonic);
    expect(restored.pairAFeature, item.pairAFeature);
    expect(restored.pairBFeature, item.pairBFeature);
    expect(restored.tombstoneWords, item.tombstoneWords);
    expect(restored.sourceNote, item.sourceNote);
    expect(restored.isRound2Focus, isTrue);
    expect(restored.isMappingDrill, isTrue);
    expect(restored.status, StudyStatus.fuzzy);
    expect(restored.isStarred, isTrue);
    expect(restored.userNote, item.userNote);
    expect(restored.isCustomEdited, isTrue);
    expect(restored.reviewCount, 7);
  });

  test('ExamRecord 总分与 JSON 往返', () {
    final record = ExamRecord(
      id: 'r1',
      title: '2026 真题',
      date: DateTime(2026, 12, 19),
      createdAt: DateTime(2026, 12, 19, 18),
      singleCorrect: 14,
      multiCorrect: 12,
      linkedWrongItemIds: const ['a', 'b'],
      note: '多选失分',
    );
    expect(record.totalScore, 38);
    final restored = ExamRecord.fromJson(record.toJson());
    expect(restored.title, record.title);
    expect(restored.totalScore, 38);
    expect(restored.linkedWrongItemIds, ['a', 'b']);
  });
}
