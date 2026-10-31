import 'package:flutter/material.dart';

import 'app.dart';
import 'celebration.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'data/transfer.dart';
import 'reminder.dart';
import 'ui/celebration_screen.dart';
import 'ui/celebration_tile.dart';
import 'ui/data_tiles.dart';
import 'ui/export_tile.dart';
import 'ui/reminder_tile.dart';
import 'ui/report_tile.dart';
import 'ui/version_tile.dart';
import 'ui/weather_tile.dart';
import 'update/updater.dart';
import 'weather/weather_api.dart';
import 'weather/weather_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = Repository(AppDatabase());
  final shellKey = GlobalKey<HomeShellState>();
  final navKey = GlobalKey<NavigatorState>();
  void openCelebration(({int year, int month}) m) =>
      navKey.currentState?.push(MaterialPageRoute<void>(
        builder: (_) => CelebrationScreen(repo: repo, year: m.year, month: m.month),
      ));
  final reminder = await LocalReminder.create(onTap: (payload) {
    navKey.currentState?.popUntil((r) => r.isFirst);
    final month = celebrationMonth(payload);
    if (month != null) {
      openCelebration(month);
    } else {
      // Antippen der Erinnerung öffnet „Heute“.
      shellKey.currentState?.showToday();
    }
  });
  final celebration = await LocalCelebration.create(reminder.plugin);
  final weatherApi = OpenMeteoApi();
  final location = await LocationStore.load();
  final weatherSync = WeatherSync(repo: repo, api: weatherApi, location: location)..start();
  final updater = GithubUpdater();
  runApp(SimpleMigrApp(
    repo: repo,
    navigatorKey: navKey,
    shellKey: shellKey,
    updater: updater,
    generalTiles: [
      ReminderTile(reminder: reminder),
      CelebrationTile(celebration: celebration, repo: repo),
      WeatherPlaceTile(location: location, api: weatherApi),
      VersionTile(updater: updater),
    ],
    dataTiles: [
      ReportTile(repo: repo),
      ExportTile(repo: repo),
      DataTiles(
        transfer: DataTransfer(repo),
        // Importierte Migränetage bekommen ihr Wetter wie neu eingetragene.
        afterImport: () {
          if (location.value == null) {
            return 'Für Wetterdaten unter „Allgemein“ einen Ort setzen.';
          }
          weatherSync.run();
          return 'Wetter wird nachgeladen.';
        },
      ),
    ],
  ));
  // App wurde über die Monatsfeier-Benachrichtigung gestartet.
  final launch = await reminder.plugin.getNotificationAppLaunchDetails();
  final launchMonth = launch?.didNotificationLaunchApp == true
      ? celebrationMonth(launch?.notificationResponse?.payload)
      : null;
  if (launchMonth != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => openCelebration(launchMonth));
  }
}
