import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.apkUrl});

  /// Versionsnummer ohne „v“, z. B. `1.0.5`.
  final String version;
  final String apkUrl;
}

/// Sucht nach einer neueren Version und installiert sie.
abstract class Updater {
  /// `null`, wenn die App aktuell ist oder die Prüfung nicht möglich war (z. B. offline).
  Future<UpdateInfo?> check();

  /// Lädt die APK und öffnet den Android-Installer.
  Future<void> install(UpdateInfo info);
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
        return UpdateInfo(version: tag.replaceFirst(RegExp('^[vV]'), ''), apkUrl: url);
      }
    }
    return null;
  }

  @override
  Future<void> install(UpdateInfo info) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/SimpleMigr-${info.version}.apk');
    final req = await _client.getUrl(Uri.parse(info.apkUrl));
    req.headers.set(HttpHeaders.userAgentHeader, 'SimpleMigr');
    final res = await req.close();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(info.apkUrl));
    final sink = file.openWrite();
    try {
      await res.pipe(sink);
    } catch (_) {
      await sink.close().catchError((_) {});
      rethrow;
    }
    if (res.contentLength > 0 && await file.length() != res.contentLength) {
      throw const HttpException('Download unvollständig');
    }
    final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) throw Exception(result.message);
  }
}
