import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/knowledge_item.dart';

/// 试听固定短句。试听不占用队列索引，也不触碰学习状态。
const String ttsPreviewSentence = '这是一段语音试听，如果你能听到这句话，说明中文语音可用。';

/// 连续失败达到该数量时整队停止，进入降级态。
const int ttsFailureThreshold = 3;

/// 把语言标签归一化为 BCP-47 形式：大小写不敏感，`_` 视为 `-`。
///
/// 服务内部选择语言时使用；同时作为顶层函数公开，只为便于单元测试直接
/// 覆盖归一化规则，不属于 UI 契约。
String normalizeLanguageTag(String tag) {
  final parts = tag
      .trim()
      .replaceAll('_', '-')
      .split('-')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '';
  final normalized = <String>[];
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (i == 0) {
      normalized.add(part.toLowerCase());
    } else if (part.length == 4) {
      normalized.add(
        '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      );
    } else if (part.length == 2) {
      normalized.add(part.toUpperCase());
    } else {
      normalized.add(part.toLowerCase());
    }
  }
  return normalized.join('-');
}

/// 题干朗读文本：为空时用占位文本，避免引擎朗读空白。
///
/// 只有播放循环使用它；播控条显示的是条目原始题干，不经过这里。
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

class TtsService extends ChangeNotifier {
  TtsService({
    FlutterTts? tts,
    Duration utteranceTimeout = const Duration(seconds: 60),
    Duration promptPause = const Duration(milliseconds: 1500),
    Duration answerPause = const Duration(milliseconds: 600),
  }) : this._(tts ?? FlutterTts(), utteranceTimeout, promptPause, answerPause);

  TtsService._(
    this._tts,
    this._utteranceTimeout,
    this._promptPause,
    this._answerPause,
  ) {
    _tts.setErrorHandler(_handlePlatformError);
  }

  final FlutterTts _tts;
  final Duration _utteranceTimeout;
  final Duration _promptPause;
  final Duration _answerPause;

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
  var _selectedLanguage = '';
  var _engineName = '系统默认';
  var _languageCount = 0;
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

  /// 播放队列是否出现过失败（降级或跳过条目）。
  ///
  /// 试听与语速设置的错误只写入 [lastError]，不计入该状态，避免把一次
  /// 试听失败误判成整队失败。
  bool get hasPlaybackFailure => _degraded || _skippedCount > 0;

  String get selectedLanguage => _selectedLanguage;
  String get engineName => _engineName;
  int get languageCount => _languageCount;

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
    _selectedLanguage = '';
    _engineName = '系统默认';
    _languageCount = 0;
    _lastError = '';

    var languages = const <String>[];
    try {
      final rawLanguages = await _tts.getLanguages;
      if (rawLanguages is List) {
        languages = rawLanguages
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false);
      }
    } catch (error) {
      _lastError = '读取语言列表失败：$error';
    }
    _languageCount = languages.length;

    var engines = const <String>[];
    try {
      final rawEngines = await _tts.getEngines;
      if (rawEngines is List) {
        engines = rawEngines
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // 引擎列表失败不影响语言探测。
    }

    try {
      final defaultEngine = await _tts.getDefaultEngine;
      if (defaultEngine is String && defaultEngine.trim().isNotEmpty) {
        _engineName = defaultEngine.trim();
      } else if (engines.isNotEmpty) {
        _engineName = engines.first;
      }
    } catch (_) {
      if (engines.isNotEmpty) _engineName = engines.first;
    }

    var selected = '';
    final candidates = _listedChineseCandidates(languages);
    for (final candidate in candidates) {
      if (await _trySetLanguage(candidate)) {
        selected = candidate;
        break;
      }
    }

    if (selected.isEmpty) {
      for (final probe in const ['zh-CN', 'zh-TW', 'zh-HK', 'zh']) {
        var permitted = true;
        try {
          final available = await _tts.isLanguageAvailable(probe);
          permitted = available != false && available != 0;
        } catch (_) {
          // 可用性探测失败时仍直接尝试 setLanguage。
        }
        if (!permitted) continue;
        if (await _trySetLanguage(probe)) {
          selected = probe;
          break;
        }
      }
    }

    if (selected.isEmpty) {
      _selectedLanguage = '';
      _available = false;
      _lastError = _lastError.isEmpty ? '系统未安装中文语音' : _lastError;
      _notify();
      return false;
    }

    _selectedLanguage = selected;
    _available = true;
    _lastError = '';
    try {
      await _tts.setSpeechRate(_rate);
    } catch (_) {
      // 语速设置失败不影响可用性。
    }
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // 某些平台不支持等待朗读完成，看门狗仍可兜底。
    }
    _notify();
    return true;
  }

  Future<bool> _trySetLanguage(String tag) async {
    try {
      return _platformOk(await _tts.setLanguage(tag), nullIsSuccess: false);
    } catch (_) {
      return false;
    }
  }

  /// `flutter_tts` 的平台方法返回值约定不统一：成功可能是 `1` 或 `true`，
  /// 失败可能是 `0`、`'0'` 或 `false`，部分平台还会返回 `null`。
  ///
  /// 这里用同一个谓词判定成败，`null` 的含义由调用方显式指定：
  /// `setLanguage` 的 `null` 视为失败，`speak` 的 `null` 视为已开始。
  bool _platformOk(Object? result, {required bool nullIsSuccess}) {
    if (result == null) return nullIsSuccess;
    return result != false && result != 0 && result != '0';
  }

  List<String> _listedChineseCandidates(List<String> languages) {
    final normalized = languages
        .map(normalizeLanguageTag)
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final candidates = <String>[];
    void add(String tag) {
      final lower = tag.toLowerCase();
      if (!candidates.any((candidate) => candidate.toLowerCase() == lower)) {
        candidates.add(tag);
      }
    }

    for (final tag in normalized) {
      if (tag.toLowerCase() == 'zh-cn') add(tag);
    }
    for (final tag in normalized) {
      if (tag.toLowerCase().startsWith('zh-hans')) add(tag);
    }
    for (final tag in normalized) {
      if (tag.toLowerCase().startsWith('zh-')) add(tag);
    }
    return candidates;
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
      _lastError = '系统未安装中文语音';
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
    try {
      await _tts.setSpeechRate(value);
    } catch (error) {
      _lastError = '设置语速失败：$error';
      _notify();
    }
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
          _lastError = '语音引擎无响应';
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
      await barrier;
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
      final result = await _tts.speak(text);
      if (completer.isCompleted) return;
      if (!_platformOk(result, nullIsSuccess: true)) {
        completer.complete(const _SpeakResult(_SpeakKind.failure, '朗读未开始'));
      } else {
        completer.complete(const _SpeakResult(_SpeakKind.completed));
      }
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(_SpeakResult(_SpeakKind.failure, '朗读失败：$error'));
      }
    }
  }

  void _handlePlatformError(dynamic message) {
    if (_disposed) return;
    final text = message?.toString().trim() ?? '';
    final error = text.isEmpty ? '语音引擎报错' : text;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(_SpeakResult(_SpeakKind.failure, error));
      return;
    }
    _lastError = error;
    _notify();
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

  Future<void> _safeStop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // 停止失败不影响后续状态收敛。
    }
  }

  Future<void> _stopPlayback() {
    final pending = _safeStop();
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

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _playing = false;
    _cancelPending();
    unawaited(_stopPlayback());
    super.dispose();
  }
}
