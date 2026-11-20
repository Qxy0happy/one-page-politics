import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/services/tts_service.dart';

/// 覆写平台方法的假引擎：记录朗读、允许手动完成/报错/永不完成。
class FakeFlutterTts extends FlutterTts {
  List<String> languages = const ['zh-CN'];
  List<String>? engines = const ['com.test.engine'];
  String? defaultEngine = 'com.test.engine';
  Object? languagesError;
  Object? enginesError;
  Object? defaultEngineError;
  bool throwOnSetLanguage = false;
  Map<String, Object?> setLanguageResults = {};
  Map<String, bool> availability = {};

  final List<String> setLanguageCalls = [];
  final List<String> spoken = [];
  int activeSpeaks = 0;
  int maxActiveSpeaks = 0;
  int stopCalls = 0;
  bool blockSpeak = false;
  bool throwOnSpeak = false;
  int failNextSpeaks = 0;
  int throwNextSpeaks = 0;

  Completer<dynamic>? _utterance;

  @override
  Future<dynamic> get getLanguages async {
    if (languagesError != null) throw languagesError!;
    return List<String>.of(languages);
  }

  @override
  Future<dynamic> get getEngines async {
    if (enginesError != null) throw enginesError!;
    return engines == null ? null : List<String>.of(engines!);
  }

  @override
  Future<dynamic> get getDefaultEngine async {
    if (defaultEngineError != null) throw defaultEngineError!;
    return defaultEngine;
  }

  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      availability[language] ?? false;

  @override
  Future<dynamic> setLanguage(String language) async {
    setLanguageCalls.add(language);
    if (throwOnSetLanguage) throw StateError('setLanguage failed');
    return setLanguageResults[language] ?? 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (throwOnSpeak) {
      throw StateError('speak failed');
    }
    if (throwNextSpeaks > 0) {
      throwNextSpeaks--;
      throw StateError('speak failed');
    }
    if (failNextSpeaks > 0) {
      failNextSpeaks--;
      return 0;
    }
    spoken.add(text);
    activeSpeaks++;
    if (activeSpeaks > maxActiveSpeaks) maxActiveSpeaks = activeSpeaks;
    if (blockSpeak) {
      final completer = Completer<dynamic>();
      _utterance = completer;
      return completer.future;
    }
    await Future<void>.delayed(Duration.zero);
    activeSpeaks--;
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCalls++;
    final completer = _utterance;
    _utterance = null;
    if (completer != null && !completer.isCompleted) {
      if (activeSpeaks > 0) activeSpeaks--;
      completer.complete(1);
    }
    return 1;
  }

  void completeCurrent([dynamic result = 1]) {
    final completer = _utterance;
    _utterance = null;
    if (completer != null && !completer.isCompleted) {
      if (activeSpeaks > 0) activeSpeaks--;
      completer.complete(result);
    }
  }

  void emitPlatformError([String message = '引擎崩溃']) {
    errorHandler?.call(message);
  }
}

TtsService buildService(FakeFlutterTts fake) => TtsService(
  tts: fake,
  utteranceTimeout: const Duration(milliseconds: 40),
  promptPause: Duration.zero,
  answerPause: Duration.zero,
);

/// 建服务并完成初始化，供只关心播放行为的测试复用。
///
/// 需要断言初始化结果的测试仍直接调用 [TtsService.init]。
Future<TtsService> startedService(FakeFlutterTts fake) async {
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

  group('语言选择', () {
    test('仅 zh-CN 可用时选择 zh-CN，状态为可用', () async {
      final fake = FakeFlutterTts()..languages = const ['zh-CN'];
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isTrue);
      expect(service.available, isTrue);
      expect(service.selectedLanguage, 'zh-CN');
      expect(fake.setLanguageCalls, contains('zh-CN'));
    });

    test('仅 zh-TW 可用时选择 zh-TW', () async {
      final fake = FakeFlutterTts()..languages = const ['zh-TW'];
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isTrue);
      expect(service.available, isTrue);
      expect(service.selectedLanguage, 'zh-TW');
    });

    test('语言列表为空但 zh-CN 探测可用时仍可用', () async {
      final fake = FakeFlutterTts()
        ..languages = const []
        ..availability = {'zh-CN': true};
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isTrue);
      expect(service.available, isTrue);
      expect(service.selectedLanguage, 'zh-CN');
      expect(service.languageCount, 0);
    });

    test('完全没有中文时不可用且播放不产生朗读', () async {
      final fake = FakeFlutterTts()..languages = const ['en-US', 'de-DE'];
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isFalse);
      expect(service.available, isFalse);
      expect(service.selectedLanguage, isEmpty);

      await service.play([makeItem('不会被朗读')]);
      expect(fake.spoken, isEmpty);
      expect(service.playing, isFalse);
    });

    test('setLanguage 失败时回退到下一个候选', () async {
      final fake = FakeFlutterTts()
        ..languages = const ['zh-CN', 'zh-TW']
        ..setLanguageResults = {'zh-CN': 0};
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isTrue);
      expect(service.selectedLanguage, 'zh-TW');
      expect(fake.setLanguageCalls.take(2), ['zh-CN', 'zh-TW']);
    });

    test('BCP-47 标签大小写与下划线归一化', () async {
      final fake = FakeFlutterTts()..languages = const ['ZH_hans_CN'];
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isTrue);
      expect(service.selectedLanguage, 'zh-Hans-CN');
    });

    test('语言列表读取失败不阻止探测', () async {
      final fake = FakeFlutterTts()
        ..languagesError = StateError('no languages')
        ..availability = {'zh-TW': true};
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isTrue);
      expect(service.selectedLanguage, 'zh-TW');
    });

    test('诊断信息暴露引擎、语言数量与最近错误', () async {
      final fake = FakeFlutterTts()
        ..languages = const ['zh-CN', 'en-US']
        ..defaultEngine = 'com.foo.tts';
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isTrue);
      expect(service.engineName, 'com.foo.tts');
      expect(service.languageCount, 2);
      expect(service.lastError, isEmpty);
    });

    test('引擎信息取不到时显示系统默认', () async {
      final fake = FakeFlutterTts()
        ..languages = const ['zh-CN']
        ..enginesError = StateError('engine list')
        ..defaultEngineError = StateError('default engine');
      final service = buildService(fake);
      addTearDown(service.dispose);

      expect(await service.init(), isTrue);
      expect(service.engineName, '系统默认');
    });
  });

  group('播放状态机', () {
    test('看门狗触发时跳过当前条目并继续', () async {
      final fake = FakeFlutterTts()..blockSpeak = true;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b')])
          .timeout(const Duration(seconds: 2));

      expect(service.skippedCount, greaterThanOrEqualTo(1));
      expect(service.index, greaterThanOrEqualTo(1));
      expect(service.lastError, isNotEmpty);
      expect(fake.stopCalls, greaterThan(0));
    });

    test('平台错误回调立即结束等待，不等待看门狗', () async {
      final fake = FakeFlutterTts()..blockSpeak = true;
      final service = TtsService(
        tts: fake,
        utteranceTimeout: const Duration(seconds: 30),
        promptPause: Duration.zero,
        answerPause: Duration.zero,
      );
      addTearDown(service.dispose);
      await service.init();

      final playing = service.play([makeItem('a')]);
      await waitFor(() => fake.spoken.length == 1);
      fake.emitPlatformError('引擎崩溃');
      await playing.timeout(const Duration(seconds: 1));

      expect(service.lastError, contains('引擎崩溃'));
      expect(service.skippedCount, 1);
    });

    test('speak 返回 0 按失败处理并继续下一条', () async {
      final fake = FakeFlutterTts()..failNextSpeaks = 1;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b')])
          .timeout(const Duration(seconds: 2));

      expect(service.skippedCount, 1);
      expect(fake.spoken, ['b']);
      expect(service.degraded, isFalse);
      expect(service.hasPlaybackFailure, isTrue);
    });

    test('speak 抛异常按失败处理并继续下一条', () async {
      final fake = FakeFlutterTts()..throwNextSpeaks = 1;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b')])
          .timeout(const Duration(seconds: 2));

      expect(service.skippedCount, 1);
      expect(fake.spoken, ['b']);
      expect(service.degraded, isFalse);
    });

    test('连续 3 条失败后停止并进入降级态', () async {
      final fake = FakeFlutterTts()..failNextSpeaks = 100;
      final service = await startedService(fake);

      await service
          .play([makeItem('a'), makeItem('b'), makeItem('c'), makeItem('d')])
          .timeout(const Duration(seconds: 2));

      expect(service.degraded, isTrue);
      expect(service.playing, isFalse);
      expect(service.lastError, '语音引擎无响应');
      expect(service.skippedCount, 3);
      expect(fake.spoken, isEmpty);
      expect(service.hasPlaybackFailure, isTrue);
    });

    test('快速播放、暂停、继续时最大并发朗读数为 1', () async {
      final fake = FakeFlutterTts()..blockSpeak = true;
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
      final fake = FakeFlutterTts()..blockSpeak = true;
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
      final fake = FakeFlutterTts()..blockSpeak = true;
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
      final fake = FakeFlutterTts();
      final service = await startedService(fake);
      service.toggleLoop();

      unawaited(service.play([makeItem('a'), makeItem('b')]));
      await waitFor(() => fake.spoken.length >= 3);
      await service.pause();

      expect(fake.spoken.take(3), ['a', 'b', 'a']);
    });

    test('试听不改变队列索引，也不写学习状态', () async {
      final fake = FakeFlutterTts();
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
      final fake = FakeFlutterTts()..blockSpeak = true;
      final service = await startedService(fake);

      final preview = service.preview();
      await waitFor(() => fake.spoken.length == 1);
      await service.pause();

      expect(await preview, isTrue);
      expect(service.lastError, isEmpty);
      expect(fake.spoken.single, ttsPreviewSentence);
    });

    test('试听失败只写最近错误，不进入播放失败态', () async {
      final fake = FakeFlutterTts()..failNextSpeaks = 1;
      final service = await startedService(fake);

      expect(await service.preview(), isFalse);

      expect(service.lastError, isNotEmpty);
      expect(service.skippedCount, 0);
      expect(service.degraded, isFalse);
      expect(service.hasPlaybackFailure, isFalse);
    });

    test('关闭时停止朗读，之后不再推进索引', () async {
      final fake = FakeFlutterTts()..blockSpeak = true;
      final service = await startedService(fake);

      unawaited(service.play([makeItem('a'), makeItem('b')]));
      await waitFor(() => fake.spoken.length == 1);
      await service.close();

      expect(service.playing, isFalse);
      expect(service.index, 0);
      expect(fake.stopCalls, greaterThan(0));
    });

    test('降级后重试从当前索引继续', () async {
      final fake = FakeFlutterTts()..failNextSpeaks = 100;
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
      final fake = FakeFlutterTts()..languages = const ['en-US'];
      final service = await startedService(fake);
      expect(service.available, isFalse);

      fake.languages = const ['zh-CN'];
      expect(await service.retry(), isTrue);

      expect(service.available, isTrue);
      expect(service.playing, isFalse);
      expect(fake.spoken, isEmpty);
    });

    test('不可用时重试成功初始化后从当前索引继续', () async {
      final fake = FakeFlutterTts()..blockSpeak = true;
      final service = await startedService(fake);

      unawaited(service.play([makeItem('a'), makeItem('b')]));
      await waitFor(() => fake.spoken.length == 1);
      fake.completeCurrent();
      await waitFor(() => fake.spoken.length == 2);
      await service.pause();
      expect(service.index, 1);

      fake.languages = const ['en-US'];
      expect(await service.init(), isFalse);
      expect(service.available, isFalse);
      expect(service.length, 2);

      fake.languages = const ['zh-CN'];
      expect(await service.retry(), isTrue);
      await waitFor(() => fake.spoken.length == 3);
      await service.pause();

      expect(service.available, isTrue);
      expect(service.index, 1);
      expect(fake.spoken.last, 'b');
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
