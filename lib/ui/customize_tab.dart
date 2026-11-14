import 'package:flutter/material.dart';

import 'palette.dart';
import 'theme.dart';

/// Optionen › Anpassen: Grundfarben der App wählen.
class CustomizeTab extends StatelessWidget {
  const CustomizeTab({super.key, required this.controller});

  final PaletteController controller;

  static const _accents = [
    Color(0xFFD97BA4),
    Color(0xFFE88A97),
    Color(0xFFE59866),
    Color(0xFFD9B44A),
    Color(0xFF8FBF8A),
    Color(0xFF6FB5A8),
    Color(0xFF7FA8D9),
    Color(0xFFA98FD9),
    Color(0xFFB59A8A),
    Color(0xFF9AA5B1),
  ];
  static const _backgrounds = [
    Color(0xFFF8ECF0),
    Color(0xFFF7EDE4),
    Color(0xFFF5F0DC),
    Color(0xFFE9F2E6),
    Color(0xFFE6F1F0),
    Color(0xFFE8EEF7),
    Color(0xFFEFE9F7),
    Color(0xFFEFEFEF),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final p = controller.palette;
        return ListView(
          children: [
            _row(
              context,
              'accent',
              'Akzentfarbe',
              'Schalter, Knöpfe, Auswahl',
              AppColors.accent,
              _accents,
              (c) => controller.set(p.copyWith(accent: c)),
              p.accent != null,
              () => controller.set(p.copyWith(resetAccent: true)),
            ),
            _row(
              context,
              'migraine',
              'Migräne',
              'Farbe der Migränetage',
              AppColors.migraine,
              _accents,
              (c) => controller.set(p.copyWith(migraine: c)),
              p.migraine != null,
              () => controller.set(p.copyWith(resetMigraine: true)),
            ),
            _row(
              context,
              'period',
              'Periode',
              'Farbe der Periodentage',
              AppColors.period,
              _accents,
              (c) => controller.set(p.copyWith(period: c)),
              p.period != null,
              () => controller.set(p.copyWith(resetPeriod: true)),
            ),
            _row(
              context,
              'background',
              'Hintergrund',
              'Flächen und Linien passen sich an',
              AppColors.background,
              _backgrounds,
              (c) => controller.set(p.copyWith(background: c)),
              p.background != null,
              () => controller.set(p.copyWith(resetBackground: true)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  key: const ValueKey('colors-reset'),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Alle Farben zurücksetzen'),
                  onPressed: () => controller.set(const AppPalette()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    String id,
    String title,
    String subtitle,
    Color current,
    List<Color> options,
    void Function(Color) onPick,
    bool custom,
    VoidCallback onReset,
  ) {
    return ListTile(
      key: ValueKey('color-$id'),
      title: Text(title),
      subtitle: Text(custom ? subtitle : '$subtitle · Standard'),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: current,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textDim),
        ),
      ),
      onTap: () async {
        final r = await showDialog<Object>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(title),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final c in options)
                      InkWell(
                        key: ValueKey(
                          'swatch-$id-${c.toARGB32().toRadixString(16)}',
                        ),
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(ctx).pop(c),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: c.toARGB32() == current.toARGB32() ? 3 : 1,
                              color: c.toARGB32() == current.toARGB32()
                                  ? AppColors.text
                                  : AppColors.textDim,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (custom)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('reset'),
                  child: const Text('Standard'),
                ),
            ],
          ),
        );
        if (r is Color) onPick(r);
        if (r == 'reset') onReset();
      },
    );
  }
}
