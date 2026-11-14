import 'dart:math';

import 'package:flutter/material.dart';

import '../data/dates.dart';
import '../data/repository.dart';
import 'theme.dart';
import 'util.dart';

/// Überschrift und Text der Feier, je nach Zahl der Migränetage.
({String headline, String body}) celebrationText(int migraineDays) {
  final n = migraineDays;
  final tage = n == 1 ? 'Migränetag' : 'Migränetage';
  if (n == 0) {
    return (
      headline: 'Kein einziger Migränetag! 🌈',
      body: 'Ein ganzer Monat ohne Migräne. Genieß das, du hast es dir '
          'so verdient. Heute wirst du gefeiert!',
    );
  }
  if (n <= 3) {
    return (
      headline: 'Nur $n $tage!',
      body: 'Und du hast jeden einzelnen davon gemeistert. '
          'Stark, stark, stark!',
    );
  }
  if (n <= 9) {
    return (
      headline: '$n $tage, und du hast es trotzdem geschafft!',
      body: 'Du bist jedes Mal wieder aufgestanden, hast weitergemacht und '
          'sogar alles eingetragen. Das ist echte Stärke!',
    );
  }
  return (
    headline: '$n $tage. Und du bist immer noch da!',
    body: 'Das war ein richtig harter Monat. Dass du ihn durchgestanden hast, '
        'ist einfach großartig. Du bist unglaublich stark!',
  );
}

const _cheers = [
  'Champion des Monats 🏆',
  'Legende! ✨',
  'Unbesiegbar 💪',
  'Applaus, Applaus 👏',
  'Absolute Heldentat 🦸',
  'Stehende Ovationen 🙌',
  'Goldmedaille 🥇',
  'Konfetti für dich 🎊',
];

/// Großes Monatsende-Fest: Konfetti, Pokal, Medaille, Jubel.
class CelebrationScreen extends StatefulWidget {
  const CelebrationScreen({
    super.key,
    required this.repo,
    required this.year,
    required this.month,
    this.clock = DateTime.now,
  });

  final Repository repo;
  final int year;
  final int month;
  final DateTime Function() clock;

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with TickerProviderStateMixin {
  late final Future<MonthData> _data = widget.repo.getMonth(widget.year, widget.month);
  late final _confetti =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));
  late final _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final _pieces = _Confetti.random(Random(), 90);
  int _cheer = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Wer im System Animationen abschaltet, bekommt das Fest ohne Bewegung.
    if (MediaQuery.disableAnimationsOf(context)) {
      _confetti.stop();
      _pulse.stop();
    } else {
      if (!_confetti.isAnimating) _confetti.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Tage des Monats bis heute (im laufenden Monat für die Vorschau).
  int _daysSoFar() {
    final now = widget.clock();
    if (now.year == widget.year && now.month == widget.month) return now.day;
    return daysInMonth(widget.year, widget.month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.sunny, AppColors.background, AppColors.accent],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(_pieces, _confetti),
                ),
              ),
            ),
            SafeArea(
              child: FutureBuilder<MonthData>(
                future: _data,
                builder: (context, snap) {
                  final m = snap.data;
                  if (m == null) return const SizedBox.shrink();
                  return _content(context, m);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, MonthData m) {
    final text = celebrationText(m.migraineDays);
    final free = (_daysSoFar() - m.migraineDays).clamp(0, 31);
    final monthLabel = '${monthName(widget.month)} ${widget.year}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Eine Zeile, die bei langen Monatsnamen oder großer Schrift schrumpft.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '🎉 ${monthName(widget.month).toUpperCase()} GESCHAFFT! 🎉',
            key: const ValueKey('celebration-title'),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppColors.onSunny,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.12)
              .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: const Icon(
            Icons.emoji_events,
            size: 140,
            color: AppColors.gold,
            shadows: [Shadow(color: Colors.white, blurRadius: 30)],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text.headline,
          key: const ValueKey('celebration-headline'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          text.body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: AppColors.text),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _Stat(value: '${m.migraineDays}', label: 'Migränetage\nüberstanden'),
            _Stat(value: '${m.attacks}', label: 'Attacken\nbesiegt'),
            _Stat(value: '$free', label: 'Tage ohne\nMigräne'),
          ],
        ),
        const SizedBox(height: 20),
        _Medal(label: 'Durchhalte-Medaille\n$monthLabel'),
        const SizedBox(height: 20),
        Center(
          child: ActionChip(
            key: const ValueKey('celebration-cheer'),
            avatar: const Icon(Icons.campaign, color: AppColors.onAccent),
            label: Text(_cheers[_cheer % _cheers.length]),
            onPressed: () => setState(() => _cheer++),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('celebration-close'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.favorite),
          label: const Text('Danke, ich bin großartig!'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
            ),
          ),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.sunny, AppColors.gold, AppColors.sunny],
          ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.5),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.military_tech, size: 40, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSunny,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Konfetti-Schnipsel; Positionen relativ (0..1), damit jede Bildschirmgröße passt.
class _Confetti {
  _Confetti(this.x, this.offset, this.speed, this.size, this.spin, this.sway, this.color);

  final double x, offset, speed, size, spin, sway;
  final Color color;

  static final _colors = [
    AppColors.sunny,
    AppColors.gold,
    AppColors.accent,
    AppColors.period,
    Color(0xFF8FC9E8),
    Color(0xFF9FD8A8),
    Colors.white,
  ];

  static List<_Confetti> random(Random r, int n) => [
        for (var i = 0; i < n; i++)
          _Confetti(
            r.nextDouble(),
            r.nextDouble(),
            // Ganzzahlig, damit beim Neustart der Animation nichts springt.
            1.0 + r.nextInt(2),
            5 + r.nextDouble() * 7,
            (r.nextDouble() - 0.5) * 12,
            r.nextDouble() * 2 * pi,
            _colors[r.nextInt(_colors.length)],
          ),
      ];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t) : super(repaint: t);

  final List<_Confetti> pieces;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final progress = (p.offset + t.value * p.speed) % 1.0;
      final y = progress * (size.height + 40) - 20;
      final x = p.x * size.width + sin(progress * 2 * pi * 2 + p.sway) * 18;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.spin);
      paint.color = p.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
