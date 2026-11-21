import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/services/deepseek_tts_engine.dart';
import 'package:one_page_politics/services/tts_audio_store.dart';

class FakeTransport implements TtsHttpTransport {
  TtsHttpResponse response = TtsHttpResponse(
    statusCode: 200,
    bytes: wavBytes(),
  );
  Object? error;
  Completer<void>? block;
  final List<TtsHttpRequest> requests = [];

  @override
  Future<TtsHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  }) async {
    requests.add(TtsHttpRequest(uri, headers, body, timeout));
    if (error != null) throw error!;
    final waiting = block;
    if (waiting != null) await waiting.future;
    return response;
  }
}

class TtsHttpRequest {
  const TtsHttpRequest(this.uri, this.headers, this.body, this.timeout);

  final Uri uri;
  final Map<String, String> headers;
  final String body;
  final Duration timeout;
}

class FakeAudioStore implements TtsAudioStore {
  final Set<String> cached = {};
  final Map<String, Uint8List> stored = {};
  final List<String> played = [];
  final List<String> storedKeys = [];
  Object? hasError;
  Object? playbackError;
  Completer<void>? block;
  var stopCalls = 0;
  var disposed = false;

  @override
  Future<bool> has(String key) async {
    if (hasError != null) throw hasError!;
    return cached.contains(key);
  }

  @override
  Future<void> play(String key) async {
    played.add(key);
    await _waitForPlayback();
  }

  @override
  Future<void> storeAndPlay(String key, Uint8List wavBytes) async {
    stored[key] = wavBytes;
    storedKeys.add(key);
    cached.add(key);
    await _waitForPlayback();
  }

  Future<void> _waitForPlayback() async {
    if (playbackError != null) throw playbackError!;
    final waiting = block;
    if (waiting != null) await waiting.future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    final waiting = block;
    block = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.completeError(const TtsPlaybackInterrupted());
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }
}

Uint8List wavBytes() {
  final bytes = Uint8List(44);
  bytes.setAll(0, 'RIFF'.codeUnits);
  bytes.setAll(8, 'WAVE'.codeUnits);
  return bytes;
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

DeepSeekTtsEngine buildEngine({
  String apiKey = 'sk-test',
  String voiceId = 'stella',
  FakeTransport? transport,
  FakeAudioStore? store,
}) {
  return DeepSeekTtsEngine(
    apiKey: apiKey,
    voiceId: voiceId,
    transport: transport ?? FakeTransport(),
    store: store ?? FakeAudioStore(),
    requestTimeout: const Duration(seconds: 2),
  );
}

void main() {
  group('缓存键', () {
    test('同一音色与文本得到稳定键', () {
      expect(ttsCacheKey('stella', '文本'), '40d1cfd32f923ccf');
      expect(ttsCacheKey('stella', '文本'), ttsCacheKey('stella', '文本'));
      expect(ttsCacheKey('stella', '文本'), matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('音色或文本不同则键不同', () {
      expect(ttsCacheKey('stella', '文本'), isNot(ttsCacheKey('tide', '文本')));
      expect(ttsCacheKey('stella', '文本'), isNot(ttsCacheKey('stella', '文本。')));
    });
  });

  group('DeepSeek 请求与缓存', () {
    test('未命中缓存时提交文本与音色，保存并播放返回的 WAV', () async {
      final transport = FakeTransport();
      final store = FakeAudioStore();
      final engine = buildEngine(transport: transport, store: store);
      addTearDown(engine.dispose);

      expect(await engine.init(), isTrue);
      expect(await engine.speak('你好，世界'), isTrue);

      final request = transport.requests.single;
      expect(request.uri.toString(), deepSeekTtsEndpoint);
      expect(request.headers['Authorization'], 'Bearer sk-test');
      expect(request.headers['Content-Type'], contains('application/json'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['text'], '你好，世界');
      expect(body['voice_id'], 'stella');
      expect(body['format'], 'wav');
      expect(body['filter_markdown'], isTrue);

      final key = ttsCacheKey('stella', '你好，世界');
      expect(key, '49be95c5aa9cde23');
      expect(store.storedKeys, [key]);
      expect(store.stored[key], wavBytes());
      expect(store.played, isEmpty);
      expect(engine.lastError, isEmpty);
    });

    test('命中缓存时不再请求网络，直接播放本地音频', () async {
      final key = ttsCacheKey('stella', '文本');
      final transport = FakeTransport();
      final store = FakeAudioStore()..cached.add(key);
      final engine = buildEngine(transport: transport, store: store);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('文本'), isTrue);
      expect(transport.requests, isEmpty);
      expect(store.played, [key]);
      expect(store.storedKeys, isEmpty);
    });

    test('缓存读取失败时回退在线合成', () async {
      final transport = FakeTransport();
      final store = FakeAudioStore()
        ..hasError = const TtsPlaybackException('缓存损坏');
      final engine = buildEngine(transport: transport, store: store);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('文本'), isTrue);
      expect(transport.requests, hasLength(1));
      expect(store.storedKeys, [ttsCacheKey('stella', '文本')]);
    });

    test('音色参数透传，非法音色回退到 stella', () async {
      final tideTransport = FakeTransport();
      final tide = buildEngine(
        voiceId: 'tide',
        transport: tideTransport,
        store: FakeAudioStore(),
      );
      addTearDown(tide.dispose);
      await tide.init();
      await tide.speak('文本');
      expect(
        (jsonDecode(tideTransport.requests.single.body)
            as Map<String, dynamic>)['voice_id'],
        'tide',
      );

      final fallbackTransport = FakeTransport();
      final fallback = buildEngine(
        voiceId: 'unknown',
        transport: fallbackTransport,
        store: FakeAudioStore(),
      );
      addTearDown(fallback.dispose);
      await fallback.init();
      await fallback.speak('文本');
      expect(
        (jsonDecode(fallbackTransport.requests.single.body)
            as Map<String, dynamic>)['voice_id'],
        'stella',
      );
    });

    test('未配置 API Key 时初始化失败且不发请求', () async {
      final transport = FakeTransport();
      final engine = buildEngine(apiKey: '  ', transport: transport);
      addTearDown(engine.dispose);

      expect(await engine.init(), isFalse);
      expect(engine.lastError, contains('API Key'));
      expect(await engine.speak('文本'), isFalse);
      expect(transport.requests, isEmpty);
    });

    test('HTTP 401 映射为密钥无效', () async {
      final transport = FakeTransport()
        ..response = TtsHttpResponse(
          statusCode: 401,
          bytes: Uint8List.fromList(utf8.encode('{"error":"auth"}')),
        );
      final engine = buildEngine(transport: transport);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('文本'), isFalse);
      expect(engine.lastError, contains('API Key 无效'));
    });

    test('HTTP 429、503、504 映射为可读原因', () async {
      for (final entry in const [(429, '频繁'), (503, '繁忙'), (504, '超时')]) {
        final transport = FakeTransport()
          ..response = TtsHttpResponse(
            statusCode: entry.$1,
            bytes: Uint8List(0),
          );
        final engine = buildEngine(transport: transport);
        addTearDown(engine.dispose);
        await engine.init();

        expect(await engine.speak('文本'), isFalse);
        expect(engine.lastError, contains(entry.$2));
      }
    });

    test('200 但不是 WAV 时拒绝保存或播放', () async {
      final transport = FakeTransport()
        ..response = TtsHttpResponse(
          statusCode: 200,
          bytes: Uint8List.fromList(utf8.encode('not audio')),
        );
      final store = FakeAudioStore();
      final engine = buildEngine(transport: transport, store: store);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('文本'), isFalse);
      expect(engine.lastError, contains('WAV'));
      expect(store.storedKeys, isEmpty);
      expect(store.played, isEmpty);
    });

    test('请求超时映射为合成超时', () async {
      final transport = FakeTransport()..error = TimeoutException('timeout');
      final engine = buildEngine(transport: transport);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('文本'), isFalse);
      expect(engine.lastError, 'DeepSeek 合成超时');
    });

    test('网络错误映射为连接失败且不回显密钥', () async {
      final transport = FakeTransport()..error = Exception('network down');
      final engine = buildEngine(transport: transport);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('文本'), isFalse);
      expect(engine.lastError, contains('连接 DeepSeek 失败'));
      expect(engine.lastError, isNot(contains('sk-test')));
    });
  });

  group('停止与生命周期', () {
    test('等待网络时停止：请求返回后不再保存或播放', () async {
      final transport = FakeTransport()..block = Completer<void>();
      final store = FakeAudioStore();
      final engine = buildEngine(transport: transport, store: store);
      addTearDown(engine.dispose);
      await engine.init();

      final speaking = engine.speak('文本');
      await waitFor(() => transport.requests.length == 1);
      await engine.stop();
      transport.block!.complete();

      expect(await speaking.timeout(const Duration(seconds: 1)), isFalse);
      expect(store.storedKeys, isEmpty);
      expect(store.played, isEmpty);
      expect(engine.lastError, isEmpty);
    });

    test('播放中停止按取消处理，不写错误', () async {
      final transport = FakeTransport();
      final store = FakeAudioStore()..block = Completer<void>();
      final engine = buildEngine(transport: transport, store: store);
      addTearDown(engine.dispose);
      await engine.init();

      final speaking = engine.speak('文本');
      await waitFor(() => store.storedKeys.length == 1);
      await engine.stop();

      expect(await speaking.timeout(const Duration(seconds: 1)), isFalse);
      expect(engine.lastError, isEmpty);
      expect(store.stopCalls, greaterThan(0));
    });

    test('播放失败写入错误', () async {
      final store = FakeAudioStore()
        ..playbackError = const TtsPlaybackException('原生播放器错误');
      final engine = buildEngine(store: store);
      addTearDown(engine.dispose);
      await engine.init();

      expect(await engine.speak('文本'), isFalse);
      expect(engine.lastError, '原生播放器错误');
    });

    test('释放后停止播放器并拒绝再次合成', () async {
      final transport = FakeTransport();
      final store = FakeAudioStore();
      final engine = buildEngine(transport: transport, store: store);
      await engine.init();
      final before = transport.requests.length;

      await engine.dispose();

      expect(store.disposed, isTrue);
      expect(await engine.speak('文本'), isFalse);
      expect(transport.requests.length, before);
    });

    test('不支持语速调节', () {
      final engine = buildEngine();
      addTearDown(engine.dispose);
      expect(engine.supportsRate, isFalse);
    });
  });
}
