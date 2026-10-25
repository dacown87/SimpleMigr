import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplemigr/data/database.dart';
import 'package:simplemigr/data/repository.dart';

void main() {
  late AppDatabase db;
  late Repository repo;
  late int migraine, pain, period;
  final day = DateTime(2026, 9, 4);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db);
    final all = await db.select(db.symptoms).get();
    int id(String k) => all.firstWhere((s) => s.key == k).id;
    migraine = id(SymptomKey.migraine);
    pain = id(SymptomKey.pain);
    period = id(SymptomKey.period);
  });
  tearDown(() => db.close());

  test('Vorbelegung: alle Symptome und Keys da', () async {
    final all = await db.select(db.symptoms).get();
    expect(
      all.where((s) => s.key != null).map((s) => s.key).toSet(),
      {'migraine', 'pain', 'period', 'aura', 'nausea'},
    );
    expect(all.where((s) => s.grp == SymptomGroup.aura).map((s) => s.name), ['Sicht', 'Sprache']);
    expect(all.where((s) => s.grp == SymptomGroup.trigger), hasLength(6));
    expect(all.firstWhere((s) => s.key == 'pain').kind, SymptomKind.scale0to3);
  });

  test('Wert setzen → Zeile; 0 → gelöscht', () async {
    await repo.setValue(day, pain, 2);
    expect((await repo.getDay(day)).value(pain), 2);
    await repo.setValue(day, pain, 3);
    expect(await db.select(db.dayValues).get(), hasLength(1));
    await repo.setValue(day, pain, 0);
    expect(await db.select(db.dayValues).get(), isEmpty);
  });

  test('Migräne aus → new_attack gelöscht', () async {
    await repo.setValue(day, migraine, 1);
    await repo.setNewAttack(day, true);
    expect((await repo.getDay(day)).newAttack, isTrue);
    await repo.setValue(day, migraine, 0);
    expect((await repo.getDay(day)).newAttack, isFalse);
    expect(await db.select(db.dayMeta).get(), isEmpty);
  });

  test('Migräne aus behält die Notiz', () async {
    await repo.setValue(day, migraine, 1);
    await repo.setNewAttack(day, true);
    await repo.setNote(day, 'Tablette');
    await repo.setValue(day, migraine, 0);
    final d = await repo.getDay(day);
    expect(d.newAttack, isFalse);
    expect(d.note, 'Tablette');
  });

  test('Notiz leer + kein / → day_meta gelöscht', () async {
    await repo.setNote(day, 'Hallo');
    expect(await db.select(db.dayMeta).get(), hasLength(1));
    await repo.setNote(day, '  ');
    expect(await db.select(db.dayMeta).get(), isEmpty);
  });

  test('Archiviertes Symptom: alte Werte im Monat sichtbar, nicht mehr in der Liste', () async {
    final id = await repo.addSymptom('Licht', SymptomGroup.trigger);
    await repo.setValue(day, id, 1);
    await repo.setArchived(id, true);
    expect((await repo.watchSymptoms().first).map((s) => s.id), isNot(contains(id)));
    final sept = await repo.getMonth(2026, 9);
    expect(sept.symptoms.map((s) => s.id), contains(id));
    expect(sept.day(day).value(id), 1);
    final okt = await repo.getMonth(2026, 10);
    expect(okt.symptoms.map((s) => s.id), isNot(contains(id)));
  });

  test('Umbenennen ändert key nicht', () async {
    await repo.renameSymptom(migraine, 'Kopfweh');
    final s = await (db.select(db.symptoms)..where((t) => t.id.equals(migraine))).getSingle();
    expect(s.name, 'Kopfweh');
    expect(s.key, 'migraine');
  });

  test('Systemsymptom nicht archivierbar, eigenes schon', () async {
    expect(() => repo.setArchived(period, true), throwsStateError);
    final id = await repo.addSymptom('Käse', SymptomGroup.trigger);
    await repo.setArchived(id, true);
    await repo.setArchived(id, false);
  });

  test('Auslöser anlegen → erscheint in der Auslöserliste', () async {
    await repo.addSymptom('Koffein', SymptomGroup.trigger);
    final list = await repo.watchSymptoms().first;
    expect(
      list.where((s) => s.grp == SymptomGroup.trigger).map((s) => s.name),
      contains('Koffein'),
    );
    expect(() => repo.addSymptom('  ', SymptomGroup.trigger), throwsArgumentError);
  });

  test('Monat beobachten liefert Update nach Schreiben', () async {
    final stream = repo.watchMonth(2026, 9);
    final results = <int>[];
    final sub = stream.listen((m) => results.add(m.migraineDays));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.setValue(day, migraine, 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    expect(results.first, 0);
    expect(results.last, 1);
  });

  test('Tag beobachten liefert Update nach Schreiben', () async {
    final first = repo.watchDay(day).skip(1).first;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.setValue(day, pain, 2);
    expect((await first.timeout(const Duration(seconds: 2))).value(pain), 2);
  });

  test('Monatssummen über Monatsgrenze', () async {
    for (final d in [DateTime(2026, 8, 30), DateTime(2026, 8, 31), DateTime(2026, 9, 1)]) {
      await repo.setValue(d, migraine, 1);
    }
    final aug = await repo.getMonth(2026, 8);
    final sep = await repo.getMonth(2026, 9);
    expect((aug.migraineDays, aug.attacks), (2, 1));
    expect((sep.migraineDays, sep.attacks), (1, 0));
  });
}
