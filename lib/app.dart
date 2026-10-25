import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/repository.dart';
import 'update/updater.dart';
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
    this.updater,
  });

  final Repository repo;
  final List<Widget> settingsTiles;
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
        settingsTiles: settingsTiles,
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
    required this.settingsTiles,
    required this.clock,
    this.updater,
  });

  final Repository repo;
  final List<Widget> settingsTiles;
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
          onPressed: () async {
            messenger
              ..hideCurrentMaterialBanner()
              ..showSnackBar(const SnackBar(content: Text('Update wird geladen …')));
            try {
              await updater.install(info);
            } catch (_) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Update fehlgeschlagen')));
            }
          },
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
