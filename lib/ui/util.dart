import 'package:flutter/material.dart';

const _months = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];
const _weekdays = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

String monthName(int month) => _months[month - 1];

String germanDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day}. ${monthName(d.month)} ${d.year}';

/// Führt einen Schreibzugriff aus; bei Fehler erscheint „Nicht gespeichert“.
Future<void> guarded(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
  } catch (e) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Nicht gespeichert')));
  }
}
