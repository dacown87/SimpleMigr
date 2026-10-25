import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Tägliche Erinnerung, inexakt (keine Exact-Alarm-Berechtigung nötig).
abstract class Reminder {
  bool get enabled;
  TimeOfDay get time;

  /// Schaltet ein. `false`, wenn die Benachrichtigungs-Berechtigung fehlt;
  /// dann bleibt die Erinnerung aus.
  Future<bool> enable();
  Future<void> disable();
  Future<void> setTime(TimeOfDay time);
}

class LocalReminder implements Reminder {
  LocalReminder._(this._prefs, this._plugin);

  static const _id = 1;
  static const _kEnabled = 'reminder_enabled';
  static const _kHour = 'reminder_hour';
  static const _kMinute = 'reminder_minute';

  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin;

  static Future<LocalReminder> create({required VoidCallback onTap}) async {
    final prefs = await SharedPreferences.getInstance();
    final plugin = FlutterLocalNotificationsPlugin();
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      // Unbekannte Zone: UTC wäre falsch, aber die Erinnerung bleibt nutzbar.
    }
    final r = LocalReminder._(prefs, plugin);
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (_) => onTap(),
    );
    // Geplante Erinnerungen überleben Neustart über den Boot-Receiver des
    // Plugins; hier nur sicherstellen, dass der Zustand zu den Einstellungen passt.
    if (r.enabled) await r._schedule();
    return r;
  }

  @override
  bool get enabled => _prefs.getBool(_kEnabled) ?? false;

  @override
  TimeOfDay get time =>
      TimeOfDay(hour: _prefs.getInt(_kHour) ?? 20, minute: _prefs.getInt(_kMinute) ?? 0);

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> enable() async {
    final granted = await _android?.requestNotificationsPermission() ?? false;
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
    await _plugin.cancel(id: _id);
  }

  @override
  Future<void> setTime(TimeOfDay t) async {
    await _prefs.setInt(_kHour, t.hour);
    await _prefs.setInt(_kMinute, t.minute);
    if (enabled) await _schedule();
  }

  Future<void> _schedule() async {
    final t = time;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _id,
      title: 'SimpleMigr',
      body: 'Heute schon eingetragen?',
      scheduledDate: at,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Tägliche Erinnerung',
          channelDescription: 'Erinnert ans Eintragen',
        ),
      ),
    );
  }
}
