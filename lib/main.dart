import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'data/transfer.dart';
import 'reminder.dart';
import 'ui/data_tiles.dart';
import 'ui/export_tile.dart';
import 'ui/reminder_tile.dart';
import 'ui/weather_tile.dart';
import 'update/updater.dart';
import 'weather/weather_api.dart';
import 'weather/weather_sync.dart';

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
  final weatherApi = OpenMeteoApi();
  final location = await LocationStore.load();
  final weatherSync = WeatherSync(repo: repo, api: weatherApi, location: location)..start();
  runApp(SimpleMigrApp(
    repo: repo,
    navigatorKey: navKey,
    shellKey: shellKey,
    updater: GithubUpdater(),
    generalTiles: [
      ReminderTile(reminder: reminder),
      WeatherPlaceTile(location: location, api: weatherApi),
    ],
    dataTiles: [
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
}
