import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.apkUrl, this.size = 0});

  /// Versionsnummer ohne „v“, z. B. `1.0.5`.
  final String version;
  final String apkUrl;

  /// Größe der APK in Bytes laut Release, 0 = unbekannt.
  final int size;
}

/// Fehler beim Update mit einem Text, den die App so anzeigen kann.
class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Sucht nach einer neueren Version und installiert sie.
abstract class Updater {
  /// `null`, wenn die App aktuell ist oder die Prüfung nicht möglich war (z. B. offline).
  Future<UpdateInfo?> check();

  /// Darf die App Apps installieren („Unbekannte Apps installieren“)?
  Future<bool> canInstall();

  /// Öffnet die Android-Einstellung dafür; liefert nach der Rückkehr, ob es jetzt erlaubt ist.
  Future<bool> requestInstallPermission();

  /// Lädt die APK und öffnet den Android-Installer. [onProgress] bekommt 0–1.
  Future<void> install(UpdateInfo info, {void Function(double progress)? onProgress});
}

/// Ist [tag] (`v1.0.5` oder `1.0.5`) neuer als [current] (`1.0.4`)? Ungültige Tags: nein.
bool isNewerVersion(String tag, String current) {
  List<int>? parse(String v) {
    final parts = v.trim().replaceFirst(RegExp('^[vV]'), '').split('+').first.split('.');
    final nums = [for (final p in parts) int.tryParse(p)];
    return nums.contains(null) ? null : nums.cast<int>();
  }

  final a = parse(tag), b = parse(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Zieht das neueste Release aus den GitHub-Releases des Projekts.
class GithubUpdater implements Updater {
  GithubUpdater({this.repo = 'dacown87/SimpleMigr', HttpClient? client})
      : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 10);
  }

  final String repo;
  final HttpClient _client;

  /// Gegenstück in `MainActivity.kt`.
  static const _channel = MethodChannel('simplemigr/install');

  @override
  Future<UpdateInfo?> check() async {
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      final req = await _client.getUrl(Uri.https('api.github.com', '/repos/$repo/releases/latest'));
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'SimpleMigr')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return null;
      return parseRelease(jsonDecode(body) as Map<String, dynamic>, current);
    } catch (_) {
      return null;
    }
  }

  /// Aus der Antwort der Release-Abfrage: Update, wenn neuer und eine APK angehängt ist.
  static UpdateInfo? parseRelease(Map<String, dynamic> json, String current) {
    final tag = json['tag_name'];
    if (tag is! String || !isNewerVersion(tag, current)) return null;
    for (final a in (json['assets'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final url = a['browser_download_url'];
      if (url is String && (a['name'] as String? ?? '').endsWith('.apk')) {
        final size = a['size'];
        return UpdateInfo(
          version: tag.replaceFirst(RegExp('^[vV]'), ''),
          apkUrl: url,
          size: size is int ? size : 0,
        );
      }
    }
    return null;
  }

  @override
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? true;

  @override
  Future<bool> requestInstallPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<void> install(UpdateInfo info, {void Function(double progress)? onProgress}) async {
    final dir = await getTemporaryDirectory();
    // Reste früherer Versuche weg, jede APK ist ~70 MB.
    await for (final f in dir.list()) {
      if (f is File && RegExp(r'SimpleMigr-.*\.apk$').hasMatch(f.path)) await f.delete();
    }
    final file = File('${dir.path}/SimpleMigr-${info.version}.apk');
    final HttpClientResponse res;
    try {
      final req = await _client.getUrl(Uri.parse(info.apkUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'SimpleMigr');
      res = await req.close();
    } on SocketException catch (e) {
      throw UpdateException('Keine Verbindung zum Server.\n${e.message}');
    }
    if (res.statusCode != 200) {
      throw UpdateException('Download fehlgeschlagen (HTTP ${res.statusCode}).');
    }
    final total = info.size > 0 ? info.size : res.contentLength;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } catch (e) {
      throw UpdateException('Download abgebrochen nach ${_mb(received)}.\n$e');
    } finally {
      await sink.close();
    }
    if (total > 0 && received != total) {
      throw UpdateException('Download unvollständig: ${_mb(received)} von ${_mb(total)}.');
    }
    final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw UpdateException('Installer ließ sich nicht öffnen.\n${result.message}');
    }
  }

  static String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
