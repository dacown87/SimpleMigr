import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'data/dates.dart';
import 'ui/util.dart' show monthName;

/// Am letzten Tag jedes Monats um 20 Uhr: „Schau mal rein, du wirst gefeiert“.
abstract class Celebration {
  bool get enabled;

  /// Schaltet ein. `false`, wenn die Benachrichtigungs-Berechtigung fehlt.
  Future<bool> enable();
  Future<void> disable();
}

/// Payload der Monatsfeier: `celebration:YYYY-MM`.
const celebrationPayloadPrefix = 'celebration:';

/// Monat aus dem Payload, `null` bei anderen Benachrichtigungen.
({int year, int month})? celebrationMonth(String? payload) {
  if (payload == null || !payload.startsWith(celebrationPayloadPrefix)) return null;
  final p = payload.substring(celebrationPayloadPrefix.length).split('-');
  if (p.length != 2) return null;
  final year = int.tryParse(p[0]), month = int.tryParse(p[1]);
  if (year == null || month == null) return null;
  return (year: year, month: month);
}

/// Die nächsten [count] Monatsenden um 20 Uhr ab [now] (lokal).
List<DateTime> upcomingMonthEnds(DateTime now, {int count = 12}) {
  final out = <DateTime>[];
  var y = now.year, m = now.month;
  while (out.length < count) {
    final at = DateTime(y, m, daysInMonth(y, m), 20);
    if (at.isAfter(now)) out.add(at);
    if (++m > 12) {
      m = 1;
      y++;
    }
  }
  return out;
}

/// Android kennt kein „letzter Tag im Monat“ als Wiederholung, darum werden
/// die nächsten zwölf Monatsenden einzeln geplant und bei jedem Start erneuert.
class LocalCelebration implements Celebration {
  LocalCelebration._(this._prefs, this._plugin);

  static const _firstId = 100;
  static const _count = 12;
  static const _kEnabled = 'celebration_enabled';

  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin;

  /// [plugin] muss schon initialisiert sein (siehe [LocalReminder.create]).
  static Future<LocalCelebration> create(FlutterLocalNotificationsPlugin plugin) async {
    final c = LocalCelebration._(await SharedPreferences.getInstance(), plugin);
    if (c.enabled) await c._schedule();
    return c;
  }

  @override
  bool get enabled => _prefs.getBool(_kEnabled) ?? false;

  @override
  Future<bool> enable() async {
    final granted = await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false;
    if (!granted) {
      await _prefs.setBool(_kEnabled, false);
      return false;
    }
    await _prefs.setBool(_kEnabled, true);
    await _schedule();
    return true;
  }

  @override
  Future<void> disable() async {
    await _prefs.setBool(_kEnabled, false);
    await _cancelAll();
  }

  Future<void> _cancelAll() async {
    for (var i = 0; i < _count; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
  }

  Future<void> _schedule() async {
    await _cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    final ends = upcomingMonthEnds(
        DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second),
        count: _count);
    for (var i = 0; i < ends.length; i++) {
      final e = ends[i];
      await _plugin.zonedSchedule(
        id: _firstId + i,
        title: 'Du hast den ${monthName(e.month)} geschafft! 🎉',
        body: 'Schau kurz in die App, da wartet etwas auf dich.',
        payload: '$celebrationPayloadPrefix${e.year}-${e.month.toString().padLeft(2, '0')}',
        scheduledDate: tz.TZDateTime(tz.local, e.year, e.month, e.day, e.hour),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'monthly_celebration',
            'Monatsfeier',
            channelDescription: 'Feiert dich am Ende jedes Monats',
          ),
        ),
      );
    }
  }
}
