import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/knowledge_item.dart';
import 'tts_engine.dart';

export 'tts_engine.dart' show TtsEngine, normalizeLanguageTag;

/// 试听固定短句。试听不占用队列索引，也不触碰学习状态。
const String ttsPreviewSentence = '这是一段语音试听，如果你能听到这句话，说明中文语音可用。';

/// 连续失败达到该数量时整队停止，进入降级态。
const int ttsFailureThreshold = 3;

/// 题干朗读文本：为空时用占位文本，避免引擎朗读空白。
///
/// 播放循环与播控条共用它，保证看到的文本与听到的一致。
String ttsPromptText(KnowledgeItem item) {
  final prompt = item.prompt.trim();
  return prompt.isEmpty ? '（空题干）' : prompt;
}

/// 结论/解析朗读文本。是非条目必须包含“正确/错误”与解析。
String ttsAnswerText(KnowledgeItem item) {
  if (item.cardType == CardType.trueFalse) {
    final verdict = item.isTrue == true ? '正确' : '错误';
    final explanation = item.explanation.trim();
    return explanation.isEmpty ? verdict : '$verdict。$explanation';
  }
  return item.answer.trim();
}

enum _SpeakKind { completed, failure, timeout, cancelled }

class _SpeakResult {
  const _SpeakResult(this.kind, [this.message = '']);

  final _SpeakKind kind;
  final String message;
}

/// 朗读队列与播放状态机，不关心语音来自系统引擎还是云端合成。
///
/// 同一时刻只允许一个播放循环；播放、暂停、继续、上一条、下一条、关闭面板
/// 都递增一个会话代次，旧循环在每次 `await` 之后检查代次，不匹配即退出。
class TtsService extends ChangeNotifier {
  TtsService({
    required TtsEngine engine,
    Duration utteranceTimeout = const Duration(seconds: 60),
    Duration promptPause = const Duration(milliseconds: 1500),
    Duration answerPause = const Duration(milliseconds: 600),
  }) : _engine = engine, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _utteranceTimeout = utteranceTimeout,
       _promptPause = _nonNegative(promptPause),
       _answerPause = _nonNegative(answerPause);

  final TtsEngine _engine;
  final Duration _utteranceTimeout;

  Duration _promptPause;
  Duration _answerPause;

  var _available = false;
  var _playing = false;
  var _loop = false;
  var _index = 0;
  var _rate = 0.5;
  var _items = <KnowledgeItem>[];

  var _generation = 0;
  var _degraded = false;
  var _skippedCount = 0;
  var _consecutiveFailures = 0;
  var _lastError = '';
  var _disposed = false;

  Completer<_SpeakResult>? _pending;
  Future<void>? _stopBarrier;

  bool get available => _available;
  bool get playing => _playing;
  bool get loop => _loop;
  int get index => _index;
  int get length => _items.length;
  double get rate => _rate;
  bool get degraded => _degraded;
  int get skippedCount => _skippedCount;
  String get lastError => _lastError;

  bool get supportsRate => _engine.supportsRate;

  Duration get promptPause => _promptPause;
  Duration get answerPause => _answerPause;

  /// 播放队列是否出现过失败（降级或跳过条目）。
  ///
  /// 试听与语速设置的错误只写入 [lastError]，不计入该状态，避免把一次
  /// 试听失败误判成整队失败。
  bool get hasPlaybackFailure => _degraded || _skippedCount > 0;

  String get selectedLanguage => _engine.selectedLanguage;
  String get engineName => _engine.engineName;
  int get languageCount => _engine.languageCount;

  KnowledgeItem? get current =>
      _items.isEmpty || _index >= _items.length ? null : _items[_index];

  String get rateLabel => switch (_rate) {
    0.6 => '1.25x',
    0.7 => '1.5x',
    _ => '1.0x',
  };

  Future<bool> init() async {
    if (_disposed) return false;
    _available = false;
    _lastError = '';

    var ok = false;
    try {
      ok = await _engine.init();
    } catch (error) {
      _lastError = '初始化语音引擎失败：$error';
    }
    if (_disposed) return false;

    _available = ok;
    if (ok) {
      _lastError = '';
    } else {
      final reason = _engine.lastError.trim();
      _lastError = reason.isEmpty
          ? (_lastError.isEmpty ? '语音引擎不可用' : _lastError)
          : reason;
    }
    _notify();
    return ok;
  }

  Future<void> play(List<KnowledgeItem> items) async {
    if (_disposed || !_available || items.isEmpty) return;
    _items = List.of(items);
    _index = 0;
    _playing = true;
    _degraded = false;
    _skippedCount = 0;
    _consecutiveFailures = 0;
    _lastError = '';
    final generation = await _startSession();
    if (!_isCurrent(generation) || !_playing) return;
    await _run(generation);
  }

  Future<void> pause() async {
    if (_disposed || (!_playing && _pending == null)) return;
    _playing = false;
    await _startSession();
  }

  Future<void> resume() async {
    if (_disposed || !_available || _items.isEmpty) return;
    if (_index >= _items.length) _index = 0;
    _playing = true;
    _degraded = false;
    _consecutiveFailures = 0;
    final generation = await _startSession();
    if (!_isCurrent(generation) || !_playing) return;
    await _run(generation);
  }

  Future<void> next() => _moveTo(_index + 1);

  Future<void> previous() => _moveTo(_index - 1);

  Future<void> _moveTo(int target) async {
    if (_disposed || _items.isEmpty) return;
    _index = target.clamp(0, _items.length - 1);
    final generation = await _startSession(stopPlayback: _playing);
    if (!_playing || !_isCurrent(generation)) return;
    unawaited(_run(generation));
  }

  Future<void> close() async {
    if (_disposed) return;
    _playing = false;
    await _startSession();
  }

  /// 从当前索引重试。引擎不可用时先重新初始化；初始化成功后若队列已有条目，
  /// 继续从当前索引朗读。
  Future<bool> retry() async {
    if (_disposed) return false;
    if (!_available) {
      if (!await init() || _disposed) return false;
    }
    _degraded = false;
    _consecutiveFailures = 0;
    if (_items.isEmpty) {
      _notify();
      return _available;
    }
    if (_index >= _items.length) _index = 0;
    _playing = true;
    final generation = await _startSession();
    if (!_isCurrent(generation) || !_playing) return _available;
    unawaited(_run(generation));
    return true;
  }

  /// 朗读试听短句。返回 false 表示失败，原因写入 [lastError]；
  /// 若朗读过程中被播放、暂停或关闭打断，按取消处理：返回 true 且不写错误，
  /// 以免把用户主动切换误报成试听失败。
  Future<bool> preview() async {
    if (_disposed) return false;
    if (!_available) {
      final reason = _engine.lastError.trim();
      _lastError = reason.isEmpty ? '语音引擎不可用' : reason;
      _notify();
      return false;
    }
    _playing = false;
    final generation = await _startSession();
    if (!_isCurrent(generation)) return true;
    final ok = await _speak(ttsPreviewSentence, generation);
    if (!_isCurrent(generation)) return true;
    if (ok) {
      _lastError = '';
      _notify();
    }
    return ok;
  }

  Future<void> setRate(double value) async {
    if (_disposed) return;
    _rate = value;
    _notify();
    await _engine.setRate(value);
    if (_disposed) return;
    final reason = _engine.lastError.trim();
    if (reason.isNotEmpty) {
      _lastError = reason;
      _notify();
    }
  }

  /// 题干与结论之间的停顿。修改后下一次停顿立即采用新值。
  void setPromptPause(Duration value) {
    if (_disposed) return;
    _promptPause = _nonNegative(value);
    _notify();
  }

  /// 结论与下一条之间的停顿。
  void setAnswerPause(Duration value) {
    if (_disposed) return;
    _answerPause = _nonNegative(value);
    _notify();
  }

  void toggleLoop() {
    if (_disposed) return;
    _loop = !_loop;
    _notify();
  }

  Future<void> _run(int generation) async {
    while (_isCurrent(generation) && _playing && _items.isNotEmpty) {
      if (_index >= _items.length) {
        if (!_loop) break;
        _index = 0;
        _notify();
      }

      final item = _items[_index];
      final ok = await _speakItem(item, generation);
      if (!_isCurrent(generation) || !_playing) return;

      if (!ok) {
        _skippedCount++;
        _consecutiveFailures++;
        if (_consecutiveFailures >= ttsFailureThreshold) {
          _degraded = true;
          if (_lastError.trim().isEmpty) _lastError = '语音引擎无响应';
          _playing = false;
          _notify();
          await _stopPlayback();
          return;
        }
        _index++;
        _notify();
        continue;
      }

      _consecutiveFailures = 0;
      _index++;
      _notify();
    }

    if (!_isCurrent(generation)) return;
    if (_playing) {
      _playing = false;
      _notify();
    }
  }

  Future<bool> _speakItem(KnowledgeItem item, int generation) async {
    if (!await _speak(ttsPromptText(item), generation)) return false;
    if (!_isCurrent(generation) || !_playing) return false;
    if (_promptPause > Duration.zero) {
      await Future<void>.delayed(_promptPause);
      if (!_isCurrent(generation) || !_playing) return false;
    }
    final answer = ttsAnswerText(item);
    if (answer.isEmpty) return true;
    if (!await _speak(answer, generation)) return false;
    if (!_isCurrent(generation) || !_playing) return false;
    if (_answerPause > Duration.zero) {
      await Future<void>.delayed(_answerPause);
    }
    return true;
  }

  Future<bool> _speak(String text, int generation) async {
    if (!_isCurrent(generation) || text.isEmpty) return false;
    final barrier = _stopBarrier;
    if (barrier != null) {
      try {
        await barrier;
      } catch (_) {
        // 停止阶段的错误已由引擎收敛，不应阻断下一次朗读。
      }
      if (!_isCurrent(generation)) return false;
    }

    final completer = Completer<_SpeakResult>();
    _pending = completer;
    final watchdog = Timer(_utteranceTimeout, () {
      if (!completer.isCompleted) {
        completer.complete(const _SpeakResult(_SpeakKind.timeout));
      }
    });
    unawaited(_invokeSpeak(text, completer));
    final result = await completer.future;
    watchdog.cancel();
    if (identical(_pending, completer)) _pending = null;

    switch (result.kind) {
      case _SpeakKind.completed:
        return true;
      case _SpeakKind.cancelled:
        return false;
      case _SpeakKind.failure:
        _lastError = result.message.isEmpty ? '朗读失败' : result.message;
        await _stopPlayback();
        if (_isCurrent(generation)) _notify();
        return false;
      case _SpeakKind.timeout:
        _lastError = '朗读超时';
        await _stopPlayback();
        if (_isCurrent(generation)) _notify();
        return false;
    }
  }

  Future<void> _invokeSpeak(
    String text,
    Completer<_SpeakResult> completer,
  ) async {
    try {
      final ok = await _engine.speak(text);
      if (completer.isCompleted) return;
      if (ok) {
        completer.complete(const _SpeakResult(_SpeakKind.completed));
      } else {
        final reason = _engine.lastError.trim();
        completer.complete(
          _SpeakResult(_SpeakKind.failure, reason.isEmpty ? '朗读未开始' : reason),
        );
      }
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(_SpeakResult(_SpeakKind.failure, '朗读失败：$error'));
      }
    }
  }

  /// 开始一次新的播放会话：递增代次（令旧循环失效）、结束悬挂的 utterance
  /// 等待、通知 UI，然后等待引擎停止。
  ///
  /// 返回本次会话的代次；调用方在 `await` 之后用 [_isCurrent] 判断会话是否
  /// 仍然有效。`stopPlayback` 为 false 时只更新索引（暂停态切换条目不必再
  /// 停止一次引擎）。
  Future<int> _startSession({bool stopPlayback = true}) async {
    final generation = ++_generation;
    _cancelPending();
    _notify();
    if (stopPlayback) await _stopPlayback();
    return generation;
  }

  void _cancelPending() {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const _SpeakResult(_SpeakKind.cancelled));
    }
  }

  Future<void> _stopPlayback() {
    final pending = _engine.stop();
    _stopBarrier = pending;
    pending.whenComplete(() {
      if (identical(_stopBarrier, pending)) _stopBarrier = null;
    });
    return pending;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static Duration _nonNegative(Duration value) {
    return value < Duration.zero ? Duration.zero : value;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _playing = false;
    _cancelPending();
    unawaited(_engine.dispose().catchError((_) {}));
    super.dispose();
  }
}
