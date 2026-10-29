import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/repository.dart';
import 'update/updater.dart';
import 'ui/description_screen.dart';
import 'ui/month_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/theme.dart';
import 'ui/today_screen.dart';
import 'ui/version_tile.dart';

class SimpleMigrApp extends StatelessWidget {
  const SimpleMigrApp({
    super.key,
    required this.repo,
    this.generalTiles = const [],
    this.dataTiles = const [],
    this.clock = DateTime.now,
    this.navigatorKey,
    this.shellKey,
    this.updater,
  });

  final Repository repo;
  final List<Widget> generalTiles;
  final List<Widget> dataTiles;
  final DateTime Function() clock;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<HomeShellState>? shellKey;

  /// Prüft beim Start auf eine neuere Version; `null` schaltet das ab.
  final Updater? updater;

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
      home: HomeShell(
        key: shellKey,
        repo: repo,
        generalTiles: generalTiles,
        dataTiles: dataTiles,
        clock: clock,
        updater: updater,
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repo,
    required this.generalTiles,
    required this.dataTiles,
    required this.clock,
    this.updater,
  });

  final Repository repo;
  final List<Widget> generalTiles;
  final List<Widget> dataTiles;
  final DateTime Function() clock;
  final Updater? updater;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  void showToday() => setState(() => _index = 0);

  /// Einmal pro Start: gibt es eine neuere Version, erscheint oben ein Hinweis.
  Future<void> _checkForUpdate() async {
    final updater = widget.updater;
    if (updater == null) return;
    final info = await updater.check();
    if (info == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showMaterialBanner(MaterialBanner(
      key: const ValueKey('update-banner'),
      content: Text('Neue Version ${info.version} verfügbar'),
      leading: const Icon(Icons.system_update),
      actions: [
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: const Text('Später'),
        ),
        TextButton(
          onPressed: () => installUpdate(context, updater, info),
          child: const Text('Installieren'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(repo: widget.repo, clock: widget.clock),
          MonthScreen(repo: widget.repo, clock: widget.clock),
          DescriptionScreen(repo: widget.repo),
          SettingsScreen(
            repo: widget.repo,
            generalTiles: widget.generalTiles,
            dataTiles: widget.dataTiles,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Heute'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Monat'),
          // Kurze Beschriftungen: bei großer Schrift oder Anzeige (z. B. Samsung)
          // brechen längere um oder werden abgeschnitten.
          NavigationDestination(icon: Icon(Icons.psychology_outlined), label: 'Migräne'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Optionen'),
        ],
      ),
    );
  }
}
