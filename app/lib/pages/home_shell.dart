import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/update_provider.dart';
import 'tab1_sheet_page.dart';
import 'tab2_reflex_page.dart';
import 'tab3_toolbox_page.dart';
import 'tab4_war_room_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  var _index = 0;

  static const _pages = [
    Tab1SheetPage(),
    Tab2ReflexPage(),
    Tab3ToolboxPage(),
    Tab4WarRoomPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<UpdateProvider>().refreshInstalled());
    }
  }

  Future<void> _checkForUpdates() async {
    final update = context.read<UpdateProvider>();
    if (!update.checkOnLaunch) return;
    await update.check(silent: true);
    if (!mounted) return;
    final available = update.available;
    if (available == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('发现新版本 v${available.versionName}'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => setState(() => _index = 3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '一页纸',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: '反射场',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: '工具箱',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '作战室',
          ),
        ],
      ),
    );
  }
}
