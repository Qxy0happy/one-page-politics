import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/services/tts_audio_store.dart';

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

  const channel = MethodChannel(PlatformTtsAudioStore.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  var hasResult = false;
  Object? hasError;

  setUp(() {
    calls = [];
    hasResult = false;
    hasError = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'has') {
        if (hasError != null) throw hasError!;
        return hasResult;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  PlatformTtsAudioStore buildStore() {
    final store = PlatformTtsAudioStore(channel: channel);
    addTearDown(store.dispose);
    return store;
  }

  Future<void> deliver(String method, Object? arguments) async {
    await messenger.handlePlatformMessage(
      PlatformTtsAudioStore.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }

  const key = '0123456789abcdef';

  group('缓存查询', () {
    test('has 透传结果', () async {
      final store = buildStore();
      expect(await store.has(key), isFalse);
      hasResult = true;
      expect(await store.has(key), isTrue);
      expect(calls.where((call) => call.method == 'has'), hasLength(2));
    });

    test('has 平台异常转换为可读错误', () async {
      hasError = PlatformException(code: 'io', message: '缓存损坏');
      final store = buildStore();

      await expectLater(
        store.has(key),
        throwsA(
          isA<TtsPlaybackException>().having(
            (error) => error.message,
            'message',
            '缓存损坏',
          ),
        ),
      );
    });
  });

  group('播放', () {
    test('play 发送键与令牌，完成后结束等待', () async {
      final store = buildStore();
      final playing = store.play(key);
      await waitFor(() => calls.any((call) => call.method == 'play'));

      final play = calls.firstWhere((call) => call.method == 'play');
      expect(play.arguments, {'key': key, 'token': 'tts-0'});

      await deliver('completed', 'tts-0');
      await playing.timeout(const Duration(seconds: 1));
    });

    test('storeAndPlay 发送 WAV 字节并等待播放完成', () async {
      final store = buildStore();
      final bytes = Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0]);
      final playing = store.storeAndPlay(key, bytes);
      await waitFor(() => calls.any((call) => call.method == 'storeAndPlay'));

      final storeCall = calls.firstWhere(
        (call) => call.method == 'storeAndPlay',
      );
      final arguments = storeCall.arguments as Map;
      expect(arguments['key'], key);
      expect(arguments['bytes'], bytes);
      expect(arguments['token'], 'tts-0');

      await deliver('completed', 'tts-0');
      await playing.timeout(const Duration(seconds: 1));
    });

    test('空字节不调用平台通道', () async {
      final store = buildStore();

      await expectLater(
        store.storeAndPlay(key, Uint8List(0)),
        throwsA(isA<TtsPlaybackException>()),
      );
      expect(calls, isEmpty);
    });

    test('过期令牌的完成回调被忽略', () async {
      final store = buildStore();
      final first = store.play(key);
      await waitFor(() => calls.any((call) => call.method == 'play'));
      await store.stop();
      await expectLater(first, throwsA(isA<TtsPlaybackInterrupted>()));

      final second = store.play(key);
      await waitFor(
        () => calls.where((call) => call.method == 'play').length == 2,
      );
      await deliver('completed', 'tts-0');

      var done = false;
      unawaited(second.then((_) => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isFalse);

      await deliver('completed', 'tts-1');
      await second.timeout(const Duration(seconds: 1));
      expect(done, isTrue);
    });

    test('错误回调携带消息', () async {
      final store = buildStore();
      final playing = store.play(key);
      await waitFor(() => calls.any((call) => call.method == 'play'));

      final expectation = expectLater(
        playing,
        throwsA(
          isA<TtsPlaybackException>().having(
            (error) => error.message,
            'message',
            '原生播放器错误',
          ),
        ),
      );
      await deliver('error', {'token': 'tts-0', 'message': '原生播放器错误'});
      await expectation;
    });

    test('stop 结束悬挂的播放并调用平台停止', () async {
      final store = buildStore();
      final playing = store.play(key);
      await waitFor(() => calls.any((call) => call.method == 'play'));

      await store.stop();

      await expectLater(playing, throwsA(isA<TtsPlaybackInterrupted>()));
      expect(calls.any((call) => call.method == 'stop'), isTrue);
    });
  });
}
