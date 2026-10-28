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
  static const medication = 'medication';
  static const medHelped = 'med_helped';
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

/// Tageswetter vom Wetterdienst (nur um Migränetage herum abgerufen).
@DataClassName('WeatherDay')
class DayWeather extends Table {
  TextColumn get date => text()();
  RealColumn get pressureMean => real().nullable()(); // hPa auf Meereshöhe
  RealColumn get pressureMin => real().nullable()();
  RealColumn get pressureMax => real().nullable()();
  RealColumn get tempMin => real().nullable()(); // °C
  RealColumn get tempMax => real().nullable()();
  RealColumn get humidity => real().nullable()(); // % Mittel
  RealColumn get precipitation => real().nullable()(); // mm Summe
  RealColumn get windMax => real().nullable()(); // km/h

  @override
  Set<Column> get primaryKey => {date};
}

/// Freie Texte, die nicht an einem Tag hängen (z. B. die Beschreibung der eigenen Migräne).
class AppTexts extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Symptoms, DayValues, DayMeta, DayWeather, AppTexts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'simplemigr'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(dayWeather);
          if (from < 3) {
            final maxOrder = symptoms.sortOrder.max();
            final row = await (selectOnly(symptoms)..addColumns([maxOrder])).getSingle();
            var order = (row.read(maxOrder) ?? -1) + 1;
            for (final (name, key) in [
              ('Medikamente genommen', SymptomKey.medication),
              ('Hat geholfen', SymptomKey.medHelped),
            ]) {
              await into(symptoms).insert(SymptomsCompanion.insert(
                name: name,
                kind: SymptomKind.flag,
                grp: SymptomGroup.general,
                key: Value(key),
                sortOrder: order++,
              ));
            }
          }
          if (from < 4) await m.createTable(appTexts);
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
    await add('Medikamente genommen', SymptomKind.flag, g, SymptomKey.medication);
    await add('Hat geholfen', SymptomKind.flag, g, SymptomKey.medHelped);
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
