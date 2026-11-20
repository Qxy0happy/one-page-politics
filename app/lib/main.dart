import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/home_shell.dart';
import 'providers/study_provider.dart';
import 'providers/theme_controller.dart';
import 'providers/war_room_provider.dart';
import 'services/md_parser_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  final study = StudyProvider(storage: storage, parser: MdParserService());
  await study.load();
  final warRoom = WarRoomProvider(storage: storage, prefs: prefs, study: study);
  await warRoom.load();
  final theme = ThemeController(prefs);

  runApp(OnePageApp(study: study, theme: theme, warRoom: warRoom));
}

class OnePageApp extends StatelessWidget {
  const OnePageApp({
    super.key,
    required this.study,
    required this.theme,
    required this.warRoom,
  });

  final StudyProvider study;
  final ThemeController theme;
  final WarRoomProvider warRoom;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: study),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: warRoom),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: '一页纸',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: themeController.mode,
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
