import 'deepseek_tts_engine.dart';
import 'tts_audio_store.dart';
import 'tts_engine.dart';
import 'tts_service.dart';
import 'tts_settings.dart';

/// 根据持久化设置组装朗读服务。
///
/// [deepSeekStore] 只用于测试或替换本地缓存实现；生产代码使用平台通道。
TtsService createTtsService(
  TtsSettings settings, {
  TtsAudioStore? deepSeekStore,
}) {
  final TtsEngine engine = switch (settings.backend) {
    TtsBackend.system => SystemTtsEngine(),
    TtsBackend.deepseek => DeepSeekTtsEngine(
      apiKey: settings.deepseekApiKey,
      voiceId: settings.deepseekVoiceId,
      store: deepSeekStore,
    ),
  };
  return TtsService(
    engine: engine,
    promptPause: settings.promptPause,
    answerPause: settings.answerPause,
  );
}
