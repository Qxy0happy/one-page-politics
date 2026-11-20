import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/services/tts_engine.dart';

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
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(engine.selectedLanguage, 'zh-CN');
      expect(fake.setLanguageCalls, contains('zh-CN'));
    });

    test('仅 zh-TW 可用时选择 zh-TW', () async {
      final fake = FakeFlutterTts()..languages = const ['zh-TW'];
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(engine.selectedLanguage, 'zh-TW');
    });

    test('语言列表为空但 zh-CN 探测可用时仍可用', () async {
      final fake = FakeFlutterTts()
        ..languages = const []
        ..availability = {'zh-CN': true};
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(engine.selectedLanguage, 'zh-CN');
      expect(engine.languageCount, 0);
    });

    test('完全没有中文时不可用', () async {
      final fake = FakeFlutterTts()..languages = const ['en-US', 'de-DE'];
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isFalse);
      expect(engine.selectedLanguage, isEmpty);
      expect(engine.lastError, contains('中文语音'));
      expect(fake.spoken, isEmpty);
    });

    test('setLanguage 失败时回退到下一个候选', () async {
      final fake = FakeFlutterTts()
        ..languages = const ['zh-CN', 'zh-TW']
        ..setLanguageResults = {'zh-CN': 0};
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(engine.selectedLanguage, 'zh-TW');
      expect(fake.setLanguageCalls.take(2), ['zh-CN', 'zh-TW']);
    });

    test('BCP-47 标签大小写与下划线归一化', () async {
      final fake = FakeFlutterTts()..languages = const ['ZH_hans_CN'];
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(engine.selectedLanguage, 'zh-Hans-CN');
    });

    test('语言列表读取失败不阻止探测', () async {
      final fake = FakeFlutterTts()
        ..languagesError = StateError('no languages')
        ..availability = {'zh-TW': true};
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(engine.selectedLanguage, 'zh-TW');
    });

    test('诊断信息暴露引擎、语言数量与最近错误', () async {
      final fake = FakeFlutterTts()
        ..languages = const ['zh-CN', 'en-US']
        ..defaultEngine = 'com.foo.tts';
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(engine.engineName, 'com.foo.tts');
      expect(engine.languageCount, 2);
      expect(engine.lastError, isEmpty);
    });

    test('引擎信息取不到时显示系统默认', () async {
      final fake = FakeFlutterTts()
        ..languages = const ['zh-CN']
        ..enginesError = StateError('engine list')
        ..defaultEngineError = StateError('default engine');
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(engine.engineName, '系统默认');
    });
  });

  group('系统语音朗读', () {
    test('平台错误回调立即结束等待，不等待看门狗', () async {
      final fake = FakeFlutterTts()..blockSpeak = true;
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);
      await engine.init();

      final speaking = engine.speak('朗读');
      await waitFor(() => fake.spoken.length == 1);
      fake.emitPlatformError('引擎崩溃');

      expect(await speaking.timeout(const Duration(seconds: 1)), isFalse);
      expect(engine.lastError, contains('引擎崩溃'));
    });

    test('speak 返回 0 视为未开始', () async {
      final fake = FakeFlutterTts()..failNextSpeaks = 1;
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('朗读'), isFalse);
      expect(engine.lastError, '朗读未开始');
    });

    test('speak 抛异常时记录失败', () async {
      final fake = FakeFlutterTts()..throwNextSpeaks = 1;
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('朗读'), isFalse);
      expect(engine.lastError, contains('朗读失败'));
    });

    test('停止会结束悬挂的朗读', () async {
      final fake = FakeFlutterTts()..blockSpeak = true;
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);
      await engine.init();

      final speaking = engine.speak('朗读');
      await waitFor(() => fake.spoken.length == 1);
      await engine.stop();

      expect(await speaking.timeout(const Duration(seconds: 1)), isFalse);
      expect(fake.stopCalls, greaterThan(0));
      expect(fake.maxActiveSpeaks, 1);
    });

    test('支持语速调节并转发给平台', () async {
      final fake = FakeFlutterTts();
      final engine = SystemTtsEngine(tts: fake);
      addTearDown(engine.dispose);

      expect(engine.supportsRate, isTrue);
      await engine.setRate(0.7);
    });
  });

  group('语言标签归一化', () {
    test('空值与常见形式', () {
      expect(normalizeLanguageTag('  '), '');
      expect(normalizeLanguageTag('zh_cn'), 'zh-CN');
      expect(normalizeLanguageTag('ZH-hans-cn'), 'zh-Hans-CN');
      expect(normalizeLanguageTag('en-US'), 'en-US');
    });
  });
}
