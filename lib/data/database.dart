import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

enum SymptomKind { flag, scale0to3 }

enum SymptomGroup { general, aura, trigger }

/// Feste Systemschlüssel. Logik und Farben hängen daran, nie am Namen.
class SymptomKey {
  static const migraine = 'migraine';
  static const pain = 'pain';
  static const period = 'period';
  static const aura = 'aura';
  static const nausea = 'nausea';
}

class Symptoms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get kind => intEnum<SymptomKind>()();
  IntColumn get grp => intEnum<SymptomGroup>()();
  TextColumn get key => text().nullable().unique()();
  IntColumn get sortOrder => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class DayValues extends Table {
  TextColumn get date => text()();
  IntColumn get symptomId => integer().references(Symptoms, #id)();
  IntColumn get value => integer()();

  @override
  Set<Column> get primaryKey => {date, symptomId};
}

class DayMeta extends Table {
  TextColumn get date => text()();
  BoolColumn get newAttack => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {date};
}

@DriftDatabase(tables: [Symptoms, DayValues, DayMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'simplemigr'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seed() async {
    var order = 0;
    Future<void> add(String name, SymptomKind kind, SymptomGroup grp, [String? key]) =>
        into(symptoms).insert(SymptomsCompanion.insert(
          name: name,
          kind: kind,
          grp: grp,
          key: Value(key),
          sortOrder: order++,
        ));

    const g = SymptomGroup.general;
    await add('Migräne', SymptomKind.flag, g, SymptomKey.migraine);
    await add('Schmerzen', SymptomKind.scale0to3, g, SymptomKey.pain);
    await add('Periode', SymptomKind.flag, g, SymptomKey.period);
    await add('Aura', SymptomKind.flag, g, SymptomKey.aura);
    await add('Übelkeit', SymptomKind.flag, g, SymptomKey.nausea);
    for (final n in ['Sicht', 'Sprache']) {
      await add(n, SymptomKind.flag, SymptomGroup.aura);
    }
    for (final n in [
      'Stress',
      'Schlafmangel',
      'Wetter',
      'Alkohol',
      'Mahlzeit ausgelassen',
      'Bildschirm',
    ]) {
      await add(n, SymptomKind.flag, SymptomGroup.trigger);
    }
  }
}
