import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'data/cycle.dart';
import 'data/repository.dart';

/// Benachrichtigung [periodReminderLeadDays] Tage vor der erwarteten Periode.
/// Erwartet wird sie [cycleLength] Tage nach dem letzten eingetragenen Beginn.
abstract class PeriodReminder {
  bool get enabled;

  /// Tage von einem Periodenbeginn zum nächsten.
  int get cycleLength;

  /// Schaltet ein. `false`, wenn die Benachrichtigungs-Berechtigung fehlt.
  Future<bool> enable();
  Future<void> disable();
  Future<void> setCycleLength(int days);

  /// Nächster erwarteter Periodenbeginn, `null` ohne eingetragene Periode.
  Future<DateTime?> nextStart();
}

const periodReminderLeadDays = 3;
const periodReminderHour = 9;
const minCycleLength = 15;
const maxCycleLength = 60;

/// Nächster erwarteter Beginn ab [lastStart], dessen Erinnerung noch nach [now]
/// liegt. Ist eine Periode überfällig und nicht eingetragen, wird um weitere
/// Zyklen vorgerückt, damit die Erinnerung nicht verloren geht.
DateTime expectedStart(DateTime lastStart, int cycleLength, DateTime now) {
  var k = 1;
  while (true) {
    final start = DateTime(
      lastStart.year,
      lastStart.month,
      lastStart.day + k * cycleLength,
    );
    final remindAt = DateTime(
      start.year,
      start.month,
      start.day - periodReminderLeadDays,
      periodReminderHour,
    );
    if (remindAt.isAfter(now)) return start;
    k++;
  }
}

/// Erinnerungszeitpunkte für die nächsten [count] erwarteten Perioden.
List<DateTime> upcomingPeriodReminders(
  DateTime lastStart,
  int cycleLength,
  DateTime now, {
  int count = 6,
}) {
  final first = expectedStart(lastStart, cycleLength, now);
  return [
    for (var i = 0; i < count; i++)
      DateTime(
        first.year,
        first.month,
        first.day + i * cycleLength - periodReminderLeadDays,
        periodReminderHour,
      ),
  ];
}

/// Plant mehrere Zyklen im Voraus (falls lange nichts eingetragen wird) und
/// plant neu, sobald sich Periodentage oder die Zykluslänge ändern.
class LocalPeriodReminder implements PeriodReminder {
  LocalPeriodReminder._(this._prefs, this._plugin, this._repo);

  static const _firstId = 200;
  static const _count = 6;
  static const _kEnabled = 'period_reminder_enabled';
  static const _kCycle = 'period_cycle_length';

  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin;
  final Repository _repo;

  /// Zuletzt geplante Zeitpunkte, um bei jeder Datenänderung nicht neu zu planen.
  List<DateTime>? _scheduled;

  /// [plugin] muss schon initialisiert sein (siehe [LocalReminder.create]).
  static Future<LocalPeriodReminder> create(
    FlutterLocalNotificationsPlugin plugin,
    Repository repo,
  ) async {
    final r = LocalPeriodReminder._(
      await SharedPreferences.getInstance(),
      plugin,
      repo,
    );
    if (r.enabled) await r._schedule();
    repo.changes.listen((_) {
      if (r.enabled) r._schedule();
    });
    return r;
  }

  @override
  bool get enabled => _prefs.getBool(_kEnabled) ?? false;

  @override
  int get cycleLength => _prefs.getInt(_kCycle) ?? 28;

  @override
  Future<bool> enable() async {
    final granted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
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
    await (_queue = _queue.then((_) => _cancelAll()));
  }

  @override
  Future<void> setCycleLength(int days) async {
    await _prefs.setInt(_kCycle, days.clamp(minCycleLength, maxCycleLength));
    if (enabled) await _schedule();
  }

  DateTime _now() {
    final n = tz.TZDateTime.now(tz.local);
    return DateTime(n.year, n.month, n.day, n.hour, n.minute, n.second);
  }

  Future<DateTime?> _lastStart() async {
    final starts = periodStarts(await _repo.periodDays());
    return starts.isEmpty ? null : starts.last;
  }

  @override
  Future<DateTime?> nextStart() async {
    final last = await _lastStart();
    return last == null ? null : expectedStart(last, cycleLength, _now());
  }

  Future<void> _cancelAll() async {
    _scheduled = null;
    for (var i = 0; i < _count; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
  }

  Future<void> _queue = Future.value();

  /// Hintereinander statt überlappend, da Datenänderungen schnell aufeinander folgen.
  Future<void> _schedule() =>
      _queue = _queue.then((_) => _doSchedule()).catchError((_) {});

  Future<void> _doSchedule() async {
    final last = await _lastStart();
    final times = last == null
        ? const <DateTime>[]
        : upcomingPeriodReminders(last, cycleLength, _now(), count: _count);
    final prev = _scheduled;
    if (prev != null &&
        prev.length == times.length &&
        Iterable.generate(times.length).every((i) => prev[i] == times[i])) {
      return;
    }
    await _cancelAll();
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      await _plugin.zonedSchedule(
        id: _firstId + i,
        title: 'Deine Periode kommt bald',
        body:
            'In etwa $periodReminderLeadDays Tagen ist es voraussichtlich so weit.',
        scheduledDate: tz.TZDateTime(tz.local, t.year, t.month, t.day, t.hour),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'period_reminder',
            'Periodenerinnerung',
            channelDescription: 'Meldet sich ein paar Tage vor der Periode',
          ),
        ),
      );
    }
    _scheduled = times;
  }
}
