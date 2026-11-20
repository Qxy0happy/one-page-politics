import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// 一个可朗读文本的语音后端。
///
/// [TtsService] 只依赖这个接口，负责队列、暂停与降级；具体后端负责初始化、
/// 合成或朗读、停止与诊断信息。实现必须保证同一时刻至多一个 [speak] 在等待
/// 完成，并在 [stop] 后尽快结束尚未完成的 [speak]。
abstract class TtsEngine {
  /// 诊断行显示的引擎名称。
  String get engineName;

  /// 诊断行显示的语言或语音标识；为空时由界面显示“未选择”。
  String get selectedLanguage;

  /// 可用语言数量，仅系统语音引擎有实际意义。
  int get languageCount;

  /// 最近一次失败原因；成功时为空。
  String get lastError;

  /// 是否支持调节语速。
  bool get supportsRate;

  /// 探测并准备后端。返回 false 时 [lastError] 应说明原因。
  Future<bool> init();

  /// 朗读一段文本。返回 false 表示失败或已被 [stop] 取消。
  Future<bool> speak(String text);

  /// 停止当前朗读或合成，并结束悬挂的 [speak]。
  Future<void> stop();

  /// 设置语速；不支持时实现可以忽略。
  Future<void> setRate(double rate);

  /// 释放平台资源。调用后不得再触发平台回调。
  Future<void> dispose();
}

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

/// 使用手机自带文字转语音引擎的离线后端。
class SystemTtsEngine implements TtsEngine {
  SystemTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setErrorHandler(_handlePlatformError);
  }

  final FlutterTts _tts;

  var _engineName = '系统默认';
  var _selectedLanguage = '';
  var _languageCount = 0;
  var _lastError = '';
  var _rate = 0.5;
  var _disposed = false;
  Completer<bool>? _pending;

  @override
  String get engineName => _engineName;

  @override
  String get selectedLanguage => _selectedLanguage;

  @override
  int get languageCount => _languageCount;

  @override
  String get lastError => _lastError;

  @override
  bool get supportsRate => true;

  @override
  Future<bool> init() async {
    if (_disposed) return false;
    _engineName = '系统默认';
    _selectedLanguage = '';
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

    if (_disposed) return false;
    if (selected.isEmpty) {
      _selectedLanguage = '';
      _lastError = _lastError.isEmpty ? '系统未安装中文语音' : _lastError;
      return false;
    }

    _selectedLanguage = selected;
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

  @override
  Future<bool> speak(String text) async {
    if (_disposed || text.isEmpty) return false;
    final pending = Completer<bool>();
    _pending = pending;
    unawaited(_invokeSpeak(text, pending));
    return pending.future;
  }

  Future<void> _invokeSpeak(String text, Completer<bool> pending) async {
    try {
      final result = await _tts.speak(text);
      if (!pending.isCompleted) {
        if (_platformOk(result, nullIsSuccess: true)) {
          pending.complete(true);
        } else {
          _lastError = '朗读未开始';
          pending.complete(false);
        }
      }
    } catch (error) {
      _lastError = '朗读失败：$error';
      if (!pending.isCompleted) pending.complete(false);
    }
    if (identical(_pending, pending)) _pending = null;
  }

  @override
  Future<void> stop() async {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    try {
      await _tts.stop();
    } catch (_) {
      // 停止失败不影响后续状态收敛。
    }
  }

  @override
  Future<void> setRate(double rate) async {
    if (_disposed) return;
    _rate = rate;
    try {
      await _tts.setSpeechRate(rate);
    } catch (error) {
      _lastError = '设置语速失败：$error';
    }
  }

  void _handlePlatformError(dynamic message) {
    if (_disposed) return;
    final text = message?.toString().trim() ?? '';
    _lastError = text.isEmpty ? '语音引擎报错' : text;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(false);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    _tts.setErrorHandler((_) {});
  }
}
