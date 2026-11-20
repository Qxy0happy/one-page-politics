import 'dart:async';

import 'package:flutter/services.dart';

/// 本地音频存储与播放。
///
/// 合成结果按稳定键保存到应用私有目录；同一个键再次朗读时直接播放本地文件，
/// 不再请求网络。原生侧优先把 WAV 压制为有损 AAC/M4A，失败时回退保存 WAV。
abstract class TtsAudioStore {
  /// 本地是否已有该键对应的音频。
  Future<bool> has(String key);

  /// 播放已存储的音频；Future 在播放完成、被 [stop] 打断或失败时结束。
  Future<void> play(String key);

  /// 保存并播放一段 WAV；同一键已有文件时应复用。
  Future<void> storeAndPlay(String key, Uint8List wavBytes);

  Future<void> stop();

  Future<void> dispose();
}

class TtsPlaybackException implements Exception {
  const TtsPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 播放被主动停止；调用方应按取消处理，不记为播放失败。
class TtsPlaybackInterrupted implements Exception {
  const TtsPlaybackInterrupted();
}

/// 通过 Android 平台通道访问本地音频缓存与 MediaPlayer。
///
/// 通道只传输稳定键、WAV 字节与令牌。原生侧在后台线程完成压制与落盘，
/// 播放完成或出错时回传同一个令牌，避免把上一次播放的回调误认为当前播放。
class PlatformTtsAudioStore implements TtsAudioStore {
  PlatformTtsAudioStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handlePlatformCall);
  }

  static const String channelName = 'one_page_politics/tts_audio';

  final MethodChannel _channel;
  Completer<void>? _pending;
  String? _token;
  var _sequence = 0;

  @override
  Future<bool> has(String key) async {
    try {
      return await _channel.invokeMethod<bool>('has', {'key': key}) ?? false;
    } on PlatformException catch (error) {
      throw TtsPlaybackException(error.message ?? '无法读取音频缓存');
    } catch (error) {
      throw TtsPlaybackException('无法读取音频缓存：$error');
    }
  }

  @override
  Future<void> play(String key) => _startAndWait('play', {'key': key});

  @override
  Future<void> storeAndPlay(String key, Uint8List wavBytes) {
    if (wavBytes.isEmpty) {
      return Future.error(const TtsPlaybackException('音频数据为空'));
    }
    return _startAndWait('storeAndPlay', {'key': key, 'bytes': wavBytes});
  }

  Future<void> _startAndWait(
    String method,
    Map<String, Object?> arguments,
  ) async {
    await stop();

    final token = 'tts-${_sequence++}';
    final completer = Completer<void>();
    _pending = completer;
    _token = token;
    try {
      await _channel.invokeMethod<void>(method, {...arguments, 'token': token});
    } on PlatformException catch (error) {
      _clear(completer);
      if (!completer.isCompleted) {
        completer.completeError(
          TtsPlaybackException(error.message ?? '无法播放音频'),
        );
      }
    } catch (error) {
      _clear(completer);
      if (!completer.isCompleted) {
        completer.completeError(TtsPlaybackException('无法播放音频：$error'));
      }
    }
    return completer.future;
  }

  void _clear(Completer<void> completer) {
    if (identical(_pending, completer)) {
      _pending = null;
      _token = null;
    }
  }

  @override
  Future<void> stop() async {
    final pending = _pending;
    _pending = null;
    _token = null;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // 停止失败不影响调用方的状态收敛。
    }
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const TtsPlaybackInterrupted());
    }
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    final pending = _pending;
    final token = _token;
    if (pending == null || token == null) return;

    switch (call.method) {
      case 'completed':
        if (call.arguments != token) return;
        _pending = null;
        _token = null;
        if (!pending.isCompleted) pending.complete();
      case 'error':
        final arguments = call.arguments;
        if (arguments is! Map || arguments['token'] != token) return;
        _pending = null;
        _token = null;
        if (!pending.isCompleted) {
          final message = arguments['message']?.toString().trim() ?? '';
          pending.completeError(
            TtsPlaybackException(message.isEmpty ? '音频播放失败' : message),
          );
        }
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    _channel.setMethodCallHandler(null);
  }
}
