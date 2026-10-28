import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/app.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simplemigr/ui/version_tile.dart';
import 'package:simplemigr/update/updater.dart';

import 'helpers.dart';

class _FakeUpdater implements Updater {
  _FakeUpdater(this.info);
  final UpdateInfo? info;
  UpdateInfo? installed;

  @override
  Future<UpdateInfo?> check() async => info;

  @override
  Future<void> install(UpdateInfo i) async => installed = i;
}

void main() {
  test('Versionsvergleich', () {
    expect(isNewerVersion('v1.0.5', '1.0.4'), isTrue);
    expect(isNewerVersion('v1.1.0', '1.0.9'), isTrue);
    expect(isNewerVersion('v2.0.0', '1.9.9'), isTrue);
    expect(isNewerVersion('v1.0.10', '1.0.9'), isTrue);
    expect(isNewerVersion('v1.0.4', '1.0.4'), isFalse);
    expect(isNewerVersion('v1.0.3', '1.0.4'), isFalse);
    expect(isNewerVersion('v1.0', '1.0.0'), isFalse);
    expect(isNewerVersion('v1.0.5', '1.0.4+7'), isTrue);
    expect(isNewerVersion('nightly', '1.0.4'), isFalse);
  });

  test('Release-Antwort: APK-Asset und Version', () {
    final json = {
      'tag_name': 'v1.0.5',
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://x/notes.txt'},
        {'name': 'SimpleMigr-1.0.5.apk', 'browser_download_url': 'https://x/a.apk'},
      ],
    };
    final info = GithubUpdater.parseRelease(json, '1.0.4')!;
    expect(info.version, '1.0.5');
    expect(info.apkUrl, 'https://x/a.apk');
    expect(GithubUpdater.parseRelease(json, '1.0.5'), isNull);
    expect(GithubUpdater.parseRelease({'tag_name': 'v1.0.5', 'assets': []}, '1.0.4'), isNull);
    expect(GithubUpdater.parseRelease({}, '1.0.4'), isNull);
  });

  Widget app(TestEnv env, Updater? u) =>
      SimpleMigrApp(repo: env.repo, updater: u, clock: () => DateTime(2026, 9, 10));

  dbWidgetTest('Hinweis bei neuer Version, Installieren startet den Download', (tester, env) async {
    final u = _FakeUpdater(const UpdateInfo(version: '1.0.5', apkUrl: 'https://x/a.apk'));
    await tester.pumpWidget(app(env, u));
    await settle(tester);
    expect(find.text('Neue Version 1.0.5 verfügbar'), findsOneWidget);
    await tester.pumpAndSettle(); // Banner einblenden
    await tester.tap(find.text('Installieren'));
    await settle(tester);
    await tester.pumpAndSettle(); // Banner ausblenden
    expect(u.installed?.version, '1.0.5');
    expect(find.text('Neue Version 1.0.5 verfügbar'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  dbWidgetTest('Später schließt den Hinweis', (tester, env) async {
    final u = _FakeUpdater(const UpdateInfo(version: '1.0.5', apkUrl: 'https://x/a.apk'));
    await tester.pumpWidget(app(env, u));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Später'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Neue Version 1.0.5 verfügbar'), findsNothing);
    expect(u.installed, isNull);
  });

  dbWidgetTest('Kein Hinweis, wenn aktuell oder kein Updater', (tester, env) async {
    await tester.pumpWidget(app(env, _FakeUpdater(null)));
    await settle(tester);
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    await tester.pumpWidget(app(env, null));
    await settle(tester);
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
  });

  Widget tile(Updater? u, {String date = ''}) => MaterialApp(
        home: Scaffold(body: VersionTile(updater: u, date: date)),
      );

  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'SimpleMigr',
        packageName: 'de.simplemigr.simplemigr',
        version: '1.0.6',
        buildNumber: '7',
        buildSignature: '',
      ));

  testWidgets('Einstellungen: Version mit Datum, ohne Datum „Testversion“', (tester) async {
    await tester.pumpWidget(tile(null, date: '2026-10-28'));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.0.6 (7)'), findsOneWidget);
    expect(find.text('vom 28.10.2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-update')), findsNothing);

    await tester.pumpWidget(tile(null));
    await tester.pumpAndSettle();
    expect(find.text('Testversion'), findsOneWidget);
  });

  testWidgets('Nach Updates suchen: aktuell → Meldung', (tester) async {
    await tester.pumpWidget(tile(_FakeUpdater(null)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check-update')));
    await tester.pumpAndSettle();
    expect(find.text('Keine neuere Version gefunden'), findsOneWidget);
  });

  testWidgets('Nach Updates suchen: neuere Version → Dialog → Installieren', (tester) async {
    final u = _FakeUpdater(const UpdateInfo(version: '1.0.7', apkUrl: 'https://x/a.apk'));
    await tester.pumpWidget(tile(u));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check-update')));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.0.7 verfügbar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('install-update')));
    await tester.pumpAndSettle();
    expect(u.installed?.version, '1.0.7');
  });
}
