import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/repository.dart';
import 'ui/month_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/theme.dart';
import 'ui/today_screen.dart';

class SimpleMigrApp extends StatelessWidget {
  const SimpleMigrApp({
    super.key,
    required this.repo,
    this.settingsTiles = const [],
    this.clock = DateTime.now,
    this.navigatorKey,
    this.shellKey,
  });

  final Repository repo;
  final List<Widget> settingsTiles;
  final DateTime Function() clock;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<HomeShellState>? shellKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimpleMigr',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: navigatorKey,
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeShell(key: shellKey, repo: repo, settingsTiles: settingsTiles, clock: clock),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repo,
    required this.settingsTiles,
    required this.clock,
  });

  final Repository repo;
  final List<Widget> settingsTiles;
  final DateTime Function() clock;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  void showToday() => setState(() => _index = 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(repo: widget.repo, clock: widget.clock),
          MonthScreen(repo: widget.repo, clock: widget.clock),
          SettingsScreen(repo: widget.repo, extraTiles: widget.settingsTiles),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Heute'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Monat'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Einstellungen'),
        ],
      ),
    );
  }
}
