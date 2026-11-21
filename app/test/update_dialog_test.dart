import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:one_page_politics/providers/update_provider.dart';
import 'package:one_page_politics/theme/app_theme.dart';
import 'package:one_page_politics/widgets/update_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/update_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('更新对话框展示版本并可以稍后关闭', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gateway = FakeUpdateGateway();
    final service = FakeUpdateService(gateway: gateway)
      ..manifest = sampleManifest(versionCode: 3);
    final update = UpdateProvider(
      service: service,
      prefs: prefs,
      temporaryDirectory: () async => Directory.systemTemp,
    );
    await update.load();
    await update.check();

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateProvider>.value(
        value: update,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showUpdateDialog(context),
                  child: const Text('打开更新'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开更新'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('发现新版本 v1.2.0'), findsOneWidget);
    expect(find.text('下载并安装'), findsOneWidget);
    expect(find.text('跳过此版本'), findsOneWidget);

    await tester.tap(find.text('稍后'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('发现新版本 v1.2.0'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
