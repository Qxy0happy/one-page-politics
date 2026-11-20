import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:one_page_politics/models/knowledge_item.dart';
import 'package:one_page_politics/models/sheet_path.dart';
import 'package:one_page_politics/pages/tab1_sheet_page.dart';
import 'package:one_page_politics/providers/study_provider.dart';
import 'package:one_page_politics/providers/theme_controller.dart';
import 'package:one_page_politics/services/md_parser_service.dart';
import 'package:one_page_politics/theme/app_theme.dart';
import 'package:one_page_politics/widgets/path_tree_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/sheet_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('路径栏打开目录树，选择章节后列表与芯片计数联动', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = MemoryStorage(prefs)..items = sampleItems();
    final study = StudyProvider(storage: storage, parser: MdParserService());
    await study.load();
    final theme = ThemeController(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StudyProvider>.value(value: study),
          ChangeNotifierProvider<ThemeController>.value(value: theme),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const Tab1SheetPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('5 / 5 条'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheetPathBar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pathTreeSheet')), findsOneWidget);

    await tester.tap(
      find.byKey(sheetPathExpandKey(const SheetPath(subject: Subject.mayuan))),
    );
    await tester.pumpAndSettle();

    final chapterRow = find.byKey(
      sheetPathRowKey(
        const SheetPath(subject: Subject.mayuan, chapter: '1.1 基础概念与“帽子”'),
      ),
    );
    await tester.ensureVisible(chapterRow);
    await tester.tap(chapterRow);
    await tester.pumpAndSettle();

    expect(find.text('马原 › 1.1'), findsOneWidget);
    expect(find.text('2 / 5 条'), findsOneWidget);
    expect(find.text('全量 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '资本');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('2 / 5 条'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('0 / 5 条'), findsOneWidget);
    expect(find.text('没有符合条件的条目'), findsOneWidget);
    expect(find.text('在全部中搜索'), findsOneWidget);

    await tester.tap(find.text('在全部中搜索'));
    await tester.pump();
    expect(find.text('1 / 5 条'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
  });
}
