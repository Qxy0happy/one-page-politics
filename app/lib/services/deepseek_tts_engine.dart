import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'tts_audio_store.dart';
import 'tts_engine.dart';

/// DeepSeek 语音合成接口。文档：https://api-docs.deepseek.com/zh-cn/guides/tts
const String deepSeekTtsEndpoint = 'https://api.deepseek.com/v1/tools/tts';

/// 可用的音色标识；首个为默认音色。
const List<String> deepSeekVoiceIds = ['stella', 'tide'];

String deepSeekVoiceLabel(String voiceId) => switch (voiceId) {
  'tide' => '暗潮（男声）',
  _ => '海星（女声）',
};

/// 本地音频缓存键：64 位 FNV-1a，输入包含格式版本、音色与原文。
///
/// 使用 [BigInt] 避免依赖哈希实现细节；同一音色与原文在应用重启后仍得到
/// 同一个键。修改缓存格式或音色语义时应递增前缀版本。
String ttsCacheKey(String voiceId, String text) {
  final mask = (BigInt.one << 64) - BigInt.one;
  final prime = BigInt.parse('100000001b3', radix: 16);
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  for (final byte in utf8.encode('v2|$voiceId|$text')) {
    hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// 一次最小的 HTTP JSON 响应。响应体可能是一段 WAV，也可能是错误 JSON。
class TtsHttpResponse {
  const TtsHttpResponse({required this.statusCode, required this.bytes});

  final int statusCode;
  final Uint8List bytes;
}

/// 把网络层隔离出来，便于用假传输层覆盖状态码、超时与响应体。
abstract class TtsHttpTransport {
  Future<TtsHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  });
}

/// 使用 `dart:io` 的 JSON POST 传输。超时或失败时强制关闭连接，避免请求悬挂。
class IoHttpTransport implements TtsHttpTransport {
  @override
  Future<TtsHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      headers.forEach(request.headers.set);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(body));
      final response = await request.close().timeout(timeout);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        builder.add(chunk);
      }
      return TtsHttpResponse(
        statusCode: response.statusCode,
        bytes: builder.takeBytes(),
      );
    } finally {
      client.close(force: true);
    }
  }
}

/// DeepSeek 云端语音合成后端。
///
/// 每次朗读按“音色 + 文本”查本地缓存；未命中时把题干或结论整段提交，取回
/// WAV 后交给 [TtsAudioStore] 压制、保存并播放。DeepSeek 不支持调节语速，
/// 因此 [supportsRate] 为 false。API Key 只写入 Authorization 头，不进入
/// 任何错误文案。
class DeepSeekTtsEngine implements TtsEngine {
  DeepSeekTtsEngine({
    required String apiKey,
    String voiceId = 'stella',
    TtsHttpTransport? transport,
    TtsAudioStore? store,
    Uri? endpoint,
    Duration requestTimeout = const Duration(seconds: 30),
  }) : _apiKey = apiKey.trim(),
       _voiceId = deepSeekVoiceIds.contains(voiceId) ? voiceId : 'stella',
       _transport = transport ?? IoHttpTransport(),
       _store = store ?? PlatformTtsAudioStore(),
       _endpoint = endpoint ?? Uri.parse(deepSeekTtsEndpoint),
       // ignore: prefer_initializing_formals
       _requestTimeout = requestTimeout;

  final String _apiKey;
  final String _voiceId;
  final TtsHttpTransport _transport;
  final TtsAudioStore _store;
  final Uri _endpoint;
  final Duration _requestTimeout;

  var _initialized = false;
  var _disposed = false;
  var _lastError = '';
  var _generation = 0;

  @override
  String get engineName => 'DeepSeek TTS';

  @override
  String get selectedLanguage => 'zh';

  @override
  int get languageCount => 0;

  @override
  String get lastError => _lastError;

  @override
  bool get supportsRate => false;

  @override
  Future<bool> init() async {
    if (_disposed) return false;
    _lastError = '';
    if (_apiKey.isEmpty) {
      _lastError = '未配置 DeepSeek API Key';
      _initialized = false;
      return false;
    }
    _initialized = true;
    return true;
  }

  @override
  Future<bool> speak(String text) async {
    if (_disposed || !_initialized) {
      if (!_disposed && _lastError.isEmpty) _lastError = '语音引擎未初始化';
      return false;
    }
    if (text.trim().isEmpty) {
      _lastError = '朗读文本为空';
      return false;
    }

    final generation = ++_generation;
    final key = ttsCacheKey(_voiceId, text);

    try {
      if (await _store.has(key)) {
        if (generation != _generation || _disposed) return false;
        return await _playLocal(key, generation);
      }
    } on TtsPlaybackException {
      if (generation != _generation || _disposed) return false;
      // 缓存读取失败不应阻断在线合成；继续走请求路径。
    }

    final body = jsonEncode({
      'text': text,
      'voice_id': _voiceId,
      'format': 'wav',
      'filter_markdown': true,
    });

    TtsHttpResponse response;
    try {
      response = await _transport.postJson(
        _endpoint,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: body,
        timeout: _requestTimeout,
      );
    } on TimeoutException {
      if (generation != _generation || _disposed) return false;
      _lastError = 'DeepSeek 合成超时';
      return false;
    } catch (error) {
      if (generation != _generation || _disposed) return false;
      _lastError = '连接 DeepSeek 失败：$error';
      return false;
    }

    if (generation != _generation || _disposed) return false;
    if (response.statusCode != 200) {
      _lastError = _statusMessage(response.statusCode);
      return false;
    }
    if (!_looksLikeWav(response.bytes)) {
      _lastError = 'DeepSeek 返回的内容不是 WAV 音频';
      return false;
    }

    try {
      await _store.storeAndPlay(key, response.bytes);
      if (generation != _generation || _disposed) return false;
      _lastError = '';
      return true;
    } on TtsPlaybackInterrupted {
      return false;
    } on TtsPlaybackException catch (error) {
      if (generation != _generation || _disposed) return false;
      _lastError = error.message;
      return false;
    } catch (error) {
      if (generation != _generation || _disposed) return false;
      _lastError = '音频保存或播放失败：$error';
      return false;
    }
  }

  Future<bool> _playLocal(String key, int generation) async {
    try {
      await _store.play(key);
      if (generation != _generation || _disposed) return false;
      _lastError = '';
      return true;
    } on TtsPlaybackInterrupted {
      return false;
    } on TtsPlaybackException catch (error) {
      if (generation != _generation || _disposed) return false;
      _lastError = error.message;
      return false;
    } catch (error) {
      if (generation != _generation || _disposed) return false;
      _lastError = '播放本地音频失败：$error';
      return false;
    }
  }

  String _statusMessage(int statusCode) => switch (statusCode) {
    401 || 403 => 'DeepSeek API Key 无效或没有权限',
    400 => 'DeepSeek 无法朗读该文本（可能为空或未通过内容审核）',
    429 => 'DeepSeek 请求过于频繁，请稍后重试',
    503 => 'DeepSeek 服务繁忙，请稍后重试',
    504 => 'DeepSeek 合成超时',
    _ => 'DeepSeek 合成失败（HTTP $statusCode）',
  };

  bool _looksLikeWav(Uint8List bytes) {
    if (bytes.length < 12) return false;
    const riff = [0x52, 0x49, 0x46, 0x46];
    const wave = [0x57, 0x41, 0x56, 0x45];
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != riff[i] || bytes[8 + i] != wave[i]) return false;
    }
    return true;
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _store.stop();
  }

  @override
  Future<void> setRate(double rate) async {
    // 云端合成不支持调节语速；UI 依据 supportsRate 隐藏语速控件。
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    await _store.dispose();
  }
}
