import 'package:shared_preferences/shared_preferences.dart';

/// 朗读后端。默认使用手机自带的离线语音。
enum TtsBackend { system, deepseek }

/// 朗读设置：后端、DeepSeek 凭据、音色与两处停顿。
///
/// 所有值都保存在本机 [SharedPreferences]；API Key 不随 Markdown 导出。
class TtsSettings {
  const TtsSettings({
    this.backend = TtsBackend.system,
    this.deepseekApiKey = '',
    this.deepseekVoiceId = 'stella',
    this.promptPause = defaultPromptPause,
    this.answerPause = defaultAnswerPause,
  });

  static const Duration defaultPromptPause = Duration(milliseconds: 1500);
  static const Duration defaultAnswerPause = Duration(milliseconds: 600);
  static const Duration maxPause = Duration(seconds: 5);
  static const List<String> voiceIds = ['stella', 'tide'];

  static const String _backendKey = 'tts.backend';
  static const String _apiKeyKey = 'tts.deepseekApiKey';
  static const String _voiceKey = 'tts.deepseekVoiceId';
  static const String _promptPauseKey = 'tts.promptPauseMs';
  static const String _answerPauseKey = 'tts.answerPauseMs';

  final TtsBackend backend;
  final String deepseekApiKey;
  final String deepseekVoiceId;
  final Duration promptPause;
  final Duration answerPause;

  bool get hasDeepSeekKey => deepseekApiKey.trim().isNotEmpty;

  static TtsSettings load(SharedPreferences prefs) {
    final backendName = prefs.getString(_backendKey);
    final backend = TtsBackend.values.firstWhere(
      (value) => value.name == backendName,
      orElse: () => TtsBackend.system,
    );
    final voice = prefs.getString(_voiceKey) ?? 'stella';
    return TtsSettings(
      backend: backend,
      deepseekApiKey: (prefs.getString(_apiKeyKey) ?? '').trim(),
      deepseekVoiceId: voiceIds.contains(voice) ? voice : 'stella',
      promptPause: _readPause(
        prefs.getInt(_promptPauseKey),
        defaultPromptPause,
      ),
      answerPause: _readPause(
        prefs.getInt(_answerPauseKey),
        defaultAnswerPause,
      ),
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(_backendKey, backend.name);
    await prefs.setString(_apiKeyKey, deepseekApiKey.trim());
    await prefs.setString(_voiceKey, deepseekVoiceId);
    await prefs.setInt(_promptPauseKey, promptPause.inMilliseconds);
    await prefs.setInt(_answerPauseKey, answerPause.inMilliseconds);
  }

  TtsSettings copyWith({
    TtsBackend? backend,
    String? deepseekApiKey,
    String? deepseekVoiceId,
    Duration? promptPause,
    Duration? answerPause,
  }) {
    return TtsSettings(
      backend: backend ?? this.backend,
      deepseekApiKey: (deepseekApiKey ?? this.deepseekApiKey).trim(),
      deepseekVoiceId: voiceIds.contains(deepseekVoiceId)
          ? deepseekVoiceId!
          : this.deepseekVoiceId,
      promptPause: _clampPause(promptPause ?? this.promptPause),
      answerPause: _clampPause(answerPause ?? this.answerPause),
    );
  }

  static Duration _readPause(int? milliseconds, Duration fallback) {
    if (milliseconds == null) return fallback;
    return _clampPause(Duration(milliseconds: milliseconds));
  }

  static Duration _clampPause(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    if (value > maxPause) return maxPause;
    return value;
  }
}
