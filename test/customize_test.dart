import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/ui/customize_tab.dart';
import 'package:simplemigr/ui/palette.dart';
import 'package:simplemigr/ui/theme.dart';

void main() {
  tearDown(() => const AppPalette().apply());

  testWidgets('Farbe wählen ändert AppColors, Zurücksetzen stellt Standard her', (t) async {
    final c = PaletteController();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: CustomizeTab(controller: c))));
    await t.tap(find.byKey(const ValueKey('color-accent')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('swatch-accent-ff7fa8d9')));
    await t.pumpAndSettle();
    expect(AppColors.accent, const Color(0xFF7FA8D9));
    await t.tap(find.byKey(const ValueKey('colors-reset')));
    await t.pumpAndSettle();
    expect(AppColors.accent, AppPalette.defaultAccent);
  });

  test('Hintergrund leitet Flächen ab', () {
    PaletteController(const AppPalette(background: Color(0xFFE8EEF7)));
    expect(AppColors.background, const Color(0xFFE8EEF7));
    expect(AppColors.surface, isNot(const Color(0xFFFCE3EC)));
  });
}
