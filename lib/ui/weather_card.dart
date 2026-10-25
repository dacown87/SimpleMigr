import 'package:flutter/material.dart';

import '../data/repository.dart';
import 'theme.dart';

/// Eine Dezimalstelle mit Komma, ohne überflüssige „.0“-Zwänge.
String num1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

String signed1(double v) => '${v >= 0 ? '+' : '−'}${num1(v.abs())}';

/// Wetter eines Tages (nur vorhanden rund um Migränetage).
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.day});

  final DayData day;

  @override
  Widget build(BuildContext context) {
    final w = day.weather!;
    final delta = day.pressureDelta;
    final lines = <String>[
      if (w.pressureMean != null)
        'Luftdruck ${w.pressureMean!.round()} hPa'
            '${delta == null ? '' : ' (${signed1(delta)} zum Vortag)'}',
      if (w.tempMin != null && w.tempMax != null)
        'Temperatur ${w.tempMin!.round()} bis ${w.tempMax!.round()} °C',
      if (w.humidity != null) 'Luftfeuchte ${w.humidity!.round()} %',
      if (w.precipitation != null) 'Niederschlag ${num1(w.precipitation!)} mm',
      if (w.windMax != null) 'Wind bis ${w.windMax!.round()} km/h',
    ];
    return Container(
      key: const ValueKey('weather-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wetter', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final l in lines) Text(l, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
