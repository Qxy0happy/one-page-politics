import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/services/tts_service.dart';
import 'package:one_page_politics/services/tts_settings.dart';
import 'package:one_page_politics/widgets/tts_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetTtsEngine implements TtsEngine {
  WidgetTtsEngine({this.supportsRate = false});

  @override
  final bool supportsRate;

  @override
  String get engineName => 'DeepSeek TTS';

  @override
  String get selectedLanguage => 'zh';

  @override
  int get languageCount => 0;

  @override
  String get lastError => '';

  @override
  Future<bool> init() async => true;

  @override
  Future<bool> speak(String text) async => true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> dispose() async {}
}

KnowledgeItem makeItem(String prompt) => KnowledgeItem(
  id: prompt,
  subject: Subject.mayuan,
  chapter: '测试章',
  cardType: CardType.mapping,
  prompt: prompt,
  answer: '结论',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('选择 DeepSeek、保存密钥并拖动题干停顿滑杆', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final created = <TtsService>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TtsSheet(
            items: [makeItem('题干')],
            serviceFactory: (settings) {
              final service = TtsService(
                engine: WidgetTtsEngine(supportsRate: settings.backend == TtsBackend.system),
              );
              created.add(service);
              return service;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(created, hasLength(1));

    await tester.tap(find.text('朗读设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DeepSeek'));
    await tester.pumpAndSettle();

    expect(find.text('尚未配置 DeepSeek'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  sk-widget  ');
    await tester.tap(find.text('保存并连接'));
    await tester.pumpAndSettle();

    expect(prefs.getString('tts.deepseekApiKey'), 'sk-widget');
    expect(created, hasLength(2));
    expect(created.last.supportsRate, isFalse);
    expect(find.text('DeepSeek 云端合成不支持调节语速'), findsOneWidget);

    final slider = find.byType(Slider).first;
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(prefs.getInt('tts.promptPauseMs'), 5000);
    expect(created.last.promptPause, const Duration(seconds: 5));
    expect(find.text('5 秒'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
