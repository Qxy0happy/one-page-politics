import 'package:flutter_test/flutter_test.dart';
import 'package:one_page_politics/services/tts_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  test('缺少键时使用系统语音与默认停顿', () async {
    final prefs = await freshPrefs();
    final settings = TtsSettings.load(prefs);

    expect(settings.backend, TtsBackend.system);
    expect(settings.deepseekApiKey, isEmpty);
    expect(settings.deepseekVoiceId, 'stella');
    expect(settings.hasDeepSeekKey, isFalse);
    expect(settings.promptPause, const Duration(milliseconds: 1500));
    expect(settings.answerPause, const Duration(milliseconds: 600));
  });

  test('保存后可完整读回', () async {
    final prefs = await freshPrefs();
    const settings = TtsSettings(
      backend: TtsBackend.deepseek,
      deepseekApiKey: '  sk-local  ',
      deepseekVoiceId: 'tide',
      promptPause: Duration(milliseconds: 2300),
      answerPause: Duration(milliseconds: 400),
    );

    await settings.save(prefs);
    final loaded = TtsSettings.load(prefs);

    expect(loaded.backend, TtsBackend.deepseek);
    expect(loaded.deepseekApiKey, 'sk-local');
    expect(loaded.hasDeepSeekKey, isTrue);
    expect(loaded.deepseekVoiceId, 'tide');
    expect(loaded.promptPause, const Duration(milliseconds: 2300));
    expect(loaded.answerPause, const Duration(milliseconds: 400));
  });

  test('非法后端、音色与越界停顿回退到安全值', () async {
    SharedPreferences.setMockInitialValues({
      'tts.backend': 'bogus',
      'tts.deepseekVoiceId': 'bogus',
      'tts.promptPauseMs': -1,
      'tts.answerPauseMs': 60000,
    });
    final prefs = await SharedPreferences.getInstance();

    final loaded = TtsSettings.load(prefs);

    expect(loaded.backend, TtsBackend.system);
    expect(loaded.deepseekVoiceId, 'stella');
    expect(loaded.promptPause, Duration.zero);
    expect(loaded.answerPause, TtsSettings.maxPause);
  });

  test('copyWith 裁剪停顿并保留未修改字段', () {
    const original = TtsSettings(
      backend: TtsBackend.deepseek,
      deepseekApiKey: 'key',
      deepseekVoiceId: 'tide',
    );

    final changed = original.copyWith(
      promptPause: const Duration(seconds: 9),
      answerPause: const Duration(milliseconds: -20),
    );

    expect(changed.backend, TtsBackend.deepseek);
    expect(changed.deepseekApiKey, 'key');
    expect(changed.deepseekVoiceId, 'tide');
    expect(changed.promptPause, TtsSettings.maxPause);
    expect(changed.answerPause, Duration.zero);
    expect(original.promptPause, TtsSettings.defaultPromptPause);
  });

  test('copyWith 收到非法音色时保留原音色', () {
    const original = TtsSettings(deepseekVoiceId: 'tide');

    final changed = original.copyWith(deepseekVoiceId: 'bogus');

    expect(changed.deepseekVoiceId, 'tide');
  });
}
