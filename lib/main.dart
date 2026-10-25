import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'reminder.dart';
import 'ui/export_tile.dart';
import 'ui/reminder_tile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = Repository(AppDatabase());
  final shellKey = GlobalKey<HomeShellState>();
  final navKey = GlobalKey<NavigatorState>();
  final reminder = await LocalReminder.create(onTap: () {
    // Antippen der Erinnerung öffnet „Heute“.
    navKey.currentState?.popUntil((r) => r.isFirst);
    shellKey.currentState?.showToday();
  });
  runApp(SimpleMigrApp(
    repo: repo,
    navigatorKey: navKey,
    shellKey: shellKey,
    settingsTiles: [
      ReminderTile(reminder: reminder),
      ExportTile(repo: repo),
    ],
  ));
}
