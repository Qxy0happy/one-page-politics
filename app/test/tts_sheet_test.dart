import 'dart:async';

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

class BlockingTtsEngine extends WidgetTtsEngine {
  final _gate = Completer<bool>();

  @override
  Future<bool> speak(String text) => _gate.future;
}

KnowledgeItem makeItem(String prompt) => KnowledgeItem(
  id: prompt,
  subject: Subject.mayuan,
  chapter: '测试章',
  cardType: CardType.mapping,
  prompt: prompt,
  answer: '结论',
);

KnowledgeItem makeTrueFalseItem() => const KnowledgeItem(
  id: 'mayuan.trueFalse.04e9fd74',
  subject: Subject.mayuan,
  chapter: '1.4',
  cardType: CardType.trueFalse,
  prompt: '科技革命是根本动力',
  explanation: '人民群众是根本动力',
  isTrue: false,
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
                engine: WidgetTtsEngine(
                  supportsRate: settings.backend == TtsBackend.system,
                ),
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

  testWidgets('API Key 字段明文显示并使用普通文本键盘', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TtsSheet(
            items: [makeItem('题干')],
            serviceFactory: (settings) => TtsService(
              engine: WidgetTtsEngine(
                supportsRate: settings.backend == TtsBackend.system,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('朗读设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DeepSeek'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isFalse);
    expect(field.keyboardType, TextInputType.text);
    expect(field.enableSuggestions, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(find.byTooltip('显示密钥'), findsNothing);
    expect(find.byTooltip('隐藏密钥'), findsNothing);
  });

  testWidgets('播控条显示实际朗读的判定与括注', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TtsSheet(
            items: [makeTrueFalseItem()],
            serviceFactory: (settings) =>
                TtsService(engine: BlockingTtsEngine()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(find.text('科技革命是根本动力'), findsOneWidget);
    expect(find.text('错误。人民群众是根本动力'), findsOneWidget);
  });
}
