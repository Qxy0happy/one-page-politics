import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/services/tts_service.dart';

/// 语音引擎替身：记录朗读、控制并发数，并可手动完成、失败或阻塞。
class FakeTtsEngine implements TtsEngine {
  var available = true;
  var blockSpeak = false;
  var throwOnSpeak = false;
  var failNextSpeaks = 0;
  var throwNextSpeaks = 0;

  final List<String> spoken = [];
  var activeSpeaks = 0;
  var maxActiveSpeaks = 0;
  var stopCalls = 0;
  var disposed = false;

  Completer<bool>? _utterance;

  @override
  var engineName = '假引擎';

  @override
  var selectedLanguage = 'zh-CN';

  @override
  var languageCount = 1;

  @override
  var lastError = '';

  @override
  var supportsRate = true;

  @override
  Future<bool> init() async {
    lastError = available ? '' : '系统未安装中文语音';
    return available;
  }

  @override
  Future<bool> speak(String text) async {
    if (throwOnSpeak) throw StateError('speak failed');
    if (throwNextSpeaks > 0) {
      throwNextSpeaks--;
      throw StateError('speak failed');
    }
    if (failNextSpeaks > 0) {
      failNextSpeaks--;
      lastError = '朗读未开始';
      return false;
    }

    spoken.add(text);
    activeSpeaks++;
    if (activeSpeaks > maxActiveSpeaks) maxActiveSpeaks = activeSpeaks;
    if (blockSpeak) {
      final completer = Completer<bool>();
      _utterance = completer;
      final completed = await completer.future;
      activeSpeaks--;
      return completed;
    }
    await Future<void>.delayed(Duration.zero);
    activeSpeaks--;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    final completer = _utterance;
    _utterance = null;
    if (completer != null && !completer.isCompleted) completer.complete(false);
  }

  void completeCurrent() {
    final completer = _utterance;
    _utterance = null;
    if (completer != null && !completer.isCompleted) completer.complete(true);
  }

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }
}

TtsService buildService(FakeTtsEngine fake) => TtsService(
  engine: fake,
  utteranceTimeout: const Duration(milliseconds: 40),
  promptPause: Duration.zero,
  answerPause: Duration.zero,
);

/// 建服务并完成初始化，供只关心播放行为的测试复用。
Future<TtsService> startedService(FakeTtsEngine fake) async {
  final service = buildService(fake);
  addTearDown(service.dispose);
  await service.init();
  return service;
}

KnowledgeItem makeItem(
  String prompt, {
  String answer = '',
  CardType cardType = CardType.mapping,
  bool? isTrue,
  String explanation = '',
}) => KnowledgeItem(
  id: prompt,
  subject: Subject.mayuan,
  chapter: '测试章',
  cardType: cardType,
  prompt: prompt,
  answer: answer,
  isTrue: isTrue,
  explanation: explanation,
);

Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('等待条件超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('播放状态机', () {
    test('看门狗触发时跳过当前条目并继续', () async {
      final fake = FakeTtsEngine()..blockSpeak = true;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b')])
          .timeout(const Duration(seconds: 2));

      expect(service.skippedCount, greaterThanOrEqualTo(1));
      expect(service.index, greaterThanOrEqualTo(1));
      expect(service.lastError, isNotEmpty);
      expect(fake.stopCalls, greaterThan(0));
    });

    test('朗读失败按失败处理并继续下一条', () async {
      final fake = FakeTtsEngine()..failNextSpeaks = 1;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b')])
          .timeout(const Duration(seconds: 2));

      expect(service.skippedCount, 1);
      expect(fake.spoken, ['b']);
      expect(service.degraded, isFalse);
      expect(service.hasPlaybackFailure, isTrue);
    });

    test('朗读抛异常按失败处理并继续下一条', () async {
      final fake = FakeTtsEngine()..throwNextSpeaks = 1;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b')])
          .timeout(const Duration(seconds: 2));

      expect(service.skippedCount, 1);
      expect(fake.spoken, ['b']);
      expect(service.degraded, isFalse);
    });

    test('连续 3 条失败后停止并进入降级态', () async {
      final fake = FakeTtsEngine()..failNextSpeaks = 100;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b'), makeItem('c'), makeItem('d')])
          .timeout(const Duration(seconds: 2));

      expect(service.degraded, isTrue);
      expect(service.playing, isFalse);
      expect(service.lastError, '朗读未开始');
      expect(service.skippedCount, 3);
      expect(fake.spoken, isEmpty);
      expect(service.hasPlaybackFailure, isTrue);
    });

    test('快速播放、暂停、继续时最大并发朗读数为 1', () async {
      final fake = FakeTtsEngine()..blockSpeak = true;
      final service = await startedService(fake);

      unawaited(service.play([makeItem('a'), makeItem('b')]));
      await waitFor(() => fake.spoken.length == 1);
      unawaited(service.pause());
      unawaited(service.resume());
      await waitFor(() => fake.spoken.length == 2);
      await service.pause();

      expect(fake.maxActiveSpeaks, 1);
      expect(service.playing, isFalse);
    });

    test('播放中下一条只朗读新索引一次，旧索引不再推进', () async {
      final fake = FakeTtsEngine()..blockSpeak = true;
      final service = await startedService(fake);

      unawaited(service.play([makeItem('a'), makeItem('b'), makeItem('c')]));
      await waitFor(() => fake.spoken.length == 1);
      unawaited(service.next());
      await waitFor(() => fake.spoken.length == 2);

      expect(service.index, 1);
      expect(fake.spoken, ['a', 'b']);
      await service.pause();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fake.spoken, ['a', 'b']);
    });

    test('暂停后继续从当前索引开始，不回到 0', () async {
      final fake = FakeTtsEngine()..blockSpeak = true;
      final service = await startedService(fake);

      unawaited(service.play([makeItem('a'), makeItem('b'), makeItem('c')]));
      await waitFor(() => fake.spoken.length == 1);
      fake.completeCurrent();
      await waitFor(() => fake.spoken.length == 2);
      expect(service.index, 1);

      await service.pause();
      expect(service.index, 1);

      unawaited(service.resume());
      await waitFor(() => fake.spoken.length == 3);
      expect(fake.spoken, ['a', 'b', 'b']);
      await service.pause();
    });

    test('循环模式在一轮结束后回到索引 0', () async {
      final fake = FakeTtsEngine();
      final service = await startedService(fake);
      service.toggleLoop();

      unawaited(service.play([makeItem('a'), makeItem('b')]));
      await waitFor(() => fake.spoken.length >= 3);
      await service.pause();

      expect(fake.spoken.take(3), ['a', 'b', 'a']);
    });

    test('试听不改变队列索引，也不写学习状态', () async {
      final fake = FakeTtsEngine();
      final service = await startedService(fake);

      final items = [makeItem('a'), makeItem('b')];
      unawaited(service.play(items));
      await waitFor(() => fake.spoken.isNotEmpty);
      await service.pause();
      final indexBefore = service.index;
      final stateBefore = items.first.status;

      expect(await service.preview(), isTrue);

      expect(service.index, indexBefore);
      expect(fake.spoken.last, ttsPreviewSentence);
      expect(items.first.status, stateBefore);
      expect(service.playing, isFalse);
    });

    test('试听被暂停打断视为取消，不报失败', () async {
      final fake = FakeTtsEngine()..blockSpeak = true;
      final service = await startedService(fake);

      final preview = service.preview();
      await waitFor(() => fake.spoken.length == 1);
      await service.pause();

      expect(await preview, isTrue);
      expect(service.lastError, isEmpty);
      expect(fake.spoken.single, ttsPreviewSentence);
    });

    test('试听失败只写最近错误，不进入播放失败态', () async {
      final fake = FakeTtsEngine()..failNextSpeaks = 1;
      final service = await startedService(fake);

      expect(await service.preview(), isFalse);

      expect(service.lastError, isNotEmpty);
      expect(service.skippedCount, 0);
      expect(service.degraded, isFalse);
      expect(service.hasPlaybackFailure, isFalse);
    });

    test('关闭时停止朗读，之后不再推进索引', () async {
      final fake = FakeTtsEngine()..blockSpeak = true;
      final service = await startedService(fake);

      unawaited(service.play([makeItem('a'), makeItem('b')]));
      await waitFor(() => fake.spoken.length == 1);
      await service.close();

      expect(service.playing, isFalse);
      expect(service.index, 0);
      expect(fake.stopCalls, greaterThan(0));
    });

    test('降级后重试从当前索引继续', () async {
      final fake = FakeTtsEngine()..failNextSpeaks = 100;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b'), makeItem('c')])
          .timeout(const Duration(seconds: 2));
      expect(service.degraded, isTrue);

      fake.failNextSpeaks = 0;
      expect(await service.retry(), isTrue);
      await waitFor(() => fake.spoken.isNotEmpty);
      await service.pause();

      expect(service.degraded, isFalse);
      expect(fake.spoken.first, 'c');
    });

    test('不可用且队列为空时重试只恢复可用状态', () async {
      final fake = FakeTtsEngine()..available = false;
      final service = await startedService(fake);
      expect(service.available, isFalse);

      fake.available = true;
      expect(await service.retry(), isTrue);

      expect(service.available, isTrue);
      expect(service.playing, isFalse);
      expect(fake.spoken, isEmpty);
    });

    test('不可用时重试成功初始化后从当前索引继续', () async {
      final fake = FakeTtsEngine()..blockSpeak = true;
      final service = await startedService(fake);

      unawaited(service.play([makeItem('a'), makeItem('b')]));
      await waitFor(() => fake.spoken.length == 1);
      fake.completeCurrent();
      await waitFor(() => fake.spoken.length == 2);
      await service.pause();
      expect(service.index, 1);

      fake.available = false;
      expect(await service.init(), isFalse);
      expect(service.available, isFalse);
      expect(service.length, 2);

      fake.available = true;
      expect(await service.retry(), isTrue);
      await waitFor(() => fake.spoken.length == 3);
      await service.pause();

      expect(service.available, isTrue);
      expect(service.index, 1);
      expect(fake.spoken.last, 'b');
    });
  });

  group('停顿设置', () {
    test('构造时采用注入的停顿并允许负数归零', () {
      final fake = FakeTtsEngine();
      final service = TtsService(
        engine: fake,
        promptPause: const Duration(seconds: 2),
        answerPause: const Duration(milliseconds: -5),
      );
      addTearDown(service.dispose);

      expect(service.promptPause, const Duration(seconds: 2));
      expect(service.answerPause, Duration.zero);
    });

    test('运行中修改停顿会通知并立即更新属性', () {
      final fake = FakeTtsEngine();
      final service = TtsService(engine: fake);
      addTearDown(service.dispose);
      var notifications = 0;
      service.addListener(() => notifications++);

      service.setPromptPause(const Duration(milliseconds: 2500));
      service.setAnswerPause(const Duration(milliseconds: -1));

      expect(service.promptPause, const Duration(milliseconds: 2500));
      expect(service.answerPause, Duration.zero);
      expect(notifications, 2);
    });

    test('不支持语速调节时服务透传该能力', () {
      final fake = FakeTtsEngine()..supportsRate = false;
      final service = TtsService(engine: fake);
      addTearDown(service.dispose);

      expect(service.supportsRate, isFalse);
    });
  });

  group('朗读文本纯函数', () {
    test('是非条目朗读文本包含正确/错误与解析', () {
      final correct = makeItem(
        '判断',
        cardType: CardType.trueFalse,
        isTrue: true,
        explanation: '因为生产力决定生产关系',
      );
      expect(ttsAnswerText(correct), contains('正确'));
      expect(ttsAnswerText(correct), contains('因为生产力决定生产关系'));

      final wrong = makeItem(
        '判断',
        cardType: CardType.trueFalse,
        isTrue: false,
        explanation: '表述绝对化',
      );
      expect(ttsAnswerText(wrong), contains('错误'));
      expect(ttsAnswerText(wrong), contains('表述绝对化'));
    });

    test('题干空白时使用占位文本，普通条目朗读答案', () {
      expect(ttsPromptText(makeItem('   ')), '（空题干）');
      expect(ttsPromptText(makeItem('  题干  ')), '题干');
      expect(ttsAnswerText(makeItem('题干', answer: '  结论  ')), '结论');
    });
  });
}
