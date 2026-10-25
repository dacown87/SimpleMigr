import 'package:flutter/material.dart';

import '../data/dates.dart';
import '../data/repository.dart';
import 'day_editor.dart';
import 'util.dart';

/// „Heute“. Berechnet das Datum neu, wenn die App wieder in den Vordergrund kommt.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.repo, this.clock = DateTime.now});

  final Repository repo;
  final DateTime Function() clock;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  late DateTime _today = dateOnly(widget.clock());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = dateOnly(widget.clock());
      if (now != _today) setState(() => _today = now);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(germanDate(_today))),
      body: SafeArea(
        child: DayEditor(key: ValueKey(_today), repo: widget.repo, date: _today),
      ),
    );
  }
}
