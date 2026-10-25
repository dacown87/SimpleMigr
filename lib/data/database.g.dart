// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SymptomsTable extends Symptoms with TableInfo<$SymptomsTable, Symptom> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SymptomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SymptomKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SymptomKind>($SymptomsTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<SymptomGroup, int> grp =
      GeneratedColumn<int>(
        'grp',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SymptomGroup>($SymptomsTable.$convertergrp);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    grp,
    key,
    sortOrder,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'symptoms';
  @override
  VerificationContext validateIntegrity(
    Insertable<Symptom> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Symptom map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Symptom(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $SymptomsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      grp: $SymptomsTable.$convertergrp.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}grp'],
        )!,
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $SymptomsTable createAlias(String alias) {
    return $SymptomsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SymptomKind, int, int> $converterkind =
      const EnumIndexConverter<SymptomKind>(SymptomKind.values);
  static JsonTypeConverter2<SymptomGroup, int, int> $convertergrp =
      const EnumIndexConverter<SymptomGroup>(SymptomGroup.values);
}

class Symptom extends DataClass implements Insertable<Symptom> {
  final int id;
  final String name;
  final SymptomKind kind;
  final SymptomGroup grp;
  final String? key;
  final int sortOrder;
  final bool archived;
  const Symptom({
    required this.id,
    required this.name,
    required this.kind,
    required this.grp,
    this.key,
    required this.sortOrder,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<int>($SymptomsTable.$converterkind.toSql(kind));
    }
    {
      map['grp'] = Variable<int>($SymptomsTable.$convertergrp.toSql(grp));
    }
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  SymptomsCompanion toCompanion(bool nullToAbsent) {
    return SymptomsCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      grp: Value(grp),
      key: key == null && nullToAbsent ? const Value.absent() : Value(key),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
    );
  }

  factory Symptom.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Symptom(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: $SymptomsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      grp: $SymptomsTable.$convertergrp.fromJson(
        serializer.fromJson<int>(json['grp']),
      ),
      key: serializer.fromJson<String?>(json['key']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<int>(
        $SymptomsTable.$converterkind.toJson(kind),
      ),
      'grp': serializer.toJson<int>($SymptomsTable.$convertergrp.toJson(grp)),
      'key': serializer.toJson<String?>(key),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Symptom copyWith({
    int? id,
    String? name,
    SymptomKind? kind,
    SymptomGroup? grp,
    Value<String?> key = const Value.absent(),
    int? sortOrder,
    bool? archived,
  }) => Symptom(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    grp: grp ?? this.grp,
    key: key.present ? key.value : this.key,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
  );
  Symptom copyWithCompanion(SymptomsCompanion data) {
    return Symptom(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      grp: data.grp.present ? data.grp.value : this.grp,
      key: data.key.present ? data.key.value : this.key,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Symptom(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('grp: $grp, ')
          ..write('key: $key, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, kind, grp, key, sortOrder, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Symptom &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.grp == this.grp &&
          other.key == this.key &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived);
}

class SymptomsCompanion extends UpdateCompanion<Symptom> {
  final Value<int> id;
  final Value<String> name;
  final Value<SymptomKind> kind;
  final Value<SymptomGroup> grp;
  final Value<String?> key;
  final Value<int> sortOrder;
  final Value<bool> archived;
  const SymptomsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.grp = const Value.absent(),
    this.key = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
  });
  SymptomsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required SymptomKind kind,
    required SymptomGroup grp,
    this.key = const Value.absent(),
    required int sortOrder,
    this.archived = const Value.absent(),
  }) : name = Value(name),
       kind = Value(kind),
       grp = Value(grp),
       sortOrder = Value(sortOrder);
  static Insertable<Symptom> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? kind,
    Expression<int>? grp,
    Expression<String>? key,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (grp != null) 'grp': grp,
      if (key != null) 'key': key,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
    });
  }

  SymptomsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<SymptomKind>? kind,
    Value<SymptomGroup>? grp,
    Value<String?>? key,
    Value<int>? sortOrder,
    Value<bool>? archived,
  }) {
    return SymptomsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      grp: grp ?? this.grp,
      key: key ?? this.key,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $SymptomsTable.$converterkind.toSql(kind.value),
      );
    }
    if (grp.present) {
      map['grp'] = Variable<int>($SymptomsTable.$convertergrp.toSql(grp.value));
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SymptomsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('grp: $grp, ')
          ..write('key: $key, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }
}

class $DayValuesTable extends DayValues
    with TableInfo<$DayValuesTable, DayValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symptomIdMeta = const VerificationMeta(
    'symptomId',
  );
  @override
  late final GeneratedColumn<int> symptomId = GeneratedColumn<int>(
    'symptom_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES symptoms (id)',
    ),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date, symptomId, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('symptom_id')) {
      context.handle(
        _symptomIdMeta,
        symptomId.isAcceptableOrUnknown(data['symptom_id']!, _symptomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_symptomIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, symptomId};
  @override
  DayValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayValue(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      symptomId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}symptom_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DayValuesTable createAlias(String alias) {
    return $DayValuesTable(attachedDatabase, alias);
  }
}

class DayValue extends DataClass implements Insertable<DayValue> {
  final String date;
  final int symptomId;
  final int value;
  const DayValue({
    required this.date,
    required this.symptomId,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['symptom_id'] = Variable<int>(symptomId);
    map['value'] = Variable<int>(value);
    return map;
  }

  DayValuesCompanion toCompanion(bool nullToAbsent) {
    return DayValuesCompanion(
      date: Value(date),
      symptomId: Value(symptomId),
      value: Value(value),
    );
  }

  factory DayValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayValue(
      date: serializer.fromJson<String>(json['date']),
      symptomId: serializer.fromJson<int>(json['symptomId']),
      value: serializer.fromJson<int>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'symptomId': serializer.toJson<int>(symptomId),
      'value': serializer.toJson<int>(value),
    };
  }

  DayValue copyWith({String? date, int? symptomId, int? value}) => DayValue(
    date: date ?? this.date,
    symptomId: symptomId ?? this.symptomId,
    value: value ?? this.value,
  );
  DayValue copyWithCompanion(DayValuesCompanion data) {
    return DayValue(
      date: data.date.present ? data.date.value : this.date,
      symptomId: data.symptomId.present ? data.symptomId.value : this.symptomId,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayValue(')
          ..write('date: $date, ')
          ..write('symptomId: $symptomId, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, symptomId, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayValue &&
          other.date == this.date &&
          other.symptomId == this.symptomId &&
          other.value == this.value);
}

class DayValuesCompanion extends UpdateCompanion<DayValue> {
  final Value<String> date;
  final Value<int> symptomId;
  final Value<int> value;
  final Value<int> rowid;
  const DayValuesCompanion({
    this.date = const Value.absent(),
    this.symptomId = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayValuesCompanion.insert({
    required String date,
    required int symptomId,
    required int value,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       symptomId = Value(symptomId),
       value = Value(value);
  static Insertable<DayValue> custom({
    Expression<String>? date,
    Expression<int>? symptomId,
    Expression<int>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (symptomId != null) 'symptom_id': symptomId,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayValuesCompanion copyWith({
    Value<String>? date,
    Value<int>? symptomId,
    Value<int>? value,
    Value<int>? rowid,
  }) {
    return DayValuesCompanion(
      date: date ?? this.date,
      symptomId: symptomId ?? this.symptomId,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (symptomId.present) {
      map['symptom_id'] = Variable<int>(symptomId.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayValuesCompanion(')
          ..write('date: $date, ')
          ..write('symptomId: $symptomId, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayMetaTable extends DayMeta with TableInfo<$DayMetaTable, DayMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _newAttackMeta = const VerificationMeta(
    'newAttack',
  );
  @override
  late final GeneratedColumn<bool> newAttack = GeneratedColumn<bool>(
    'new_attack',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("new_attack" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [date, newAttack, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('new_attack')) {
      context.handle(
        _newAttackMeta,
        newAttack.isAcceptableOrUnknown(data['new_attack']!, _newAttackMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DayMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayMetaData(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      newAttack: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}new_attack'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
    );
  }

  @override
  $DayMetaTable createAlias(String alias) {
    return $DayMetaTable(attachedDatabase, alias);
  }
}

class DayMetaData extends DataClass implements Insertable<DayMetaData> {
  final String date;
  final bool newAttack;
  final String note;
  const DayMetaData({
    required this.date,
    required this.newAttack,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['new_attack'] = Variable<bool>(newAttack);
    map['note'] = Variable<String>(note);
    return map;
  }

  DayMetaCompanion toCompanion(bool nullToAbsent) {
    return DayMetaCompanion(
      date: Value(date),
      newAttack: Value(newAttack),
      note: Value(note),
    );
  }

  factory DayMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayMetaData(
      date: serializer.fromJson<String>(json['date']),
      newAttack: serializer.fromJson<bool>(json['newAttack']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'newAttack': serializer.toJson<bool>(newAttack),
      'note': serializer.toJson<String>(note),
    };
  }

  DayMetaData copyWith({String? date, bool? newAttack, String? note}) =>
      DayMetaData(
        date: date ?? this.date,
        newAttack: newAttack ?? this.newAttack,
        note: note ?? this.note,
      );
  DayMetaData copyWithCompanion(DayMetaCompanion data) {
    return DayMetaData(
      date: data.date.present ? data.date.value : this.date,
      newAttack: data.newAttack.present ? data.newAttack.value : this.newAttack,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayMetaData(')
          ..write('date: $date, ')
          ..write('newAttack: $newAttack, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, newAttack, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayMetaData &&
          other.date == this.date &&
          other.newAttack == this.newAttack &&
          other.note == this.note);
}

class DayMetaCompanion extends UpdateCompanion<DayMetaData> {
  final Value<String> date;
  final Value<bool> newAttack;
  final Value<String> note;
  final Value<int> rowid;
  const DayMetaCompanion({
    this.date = const Value.absent(),
    this.newAttack = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayMetaCompanion.insert({
    required String date,
    this.newAttack = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DayMetaData> custom({
    Expression<String>? date,
    Expression<bool>? newAttack,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (newAttack != null) 'new_attack': newAttack,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayMetaCompanion copyWith({
    Value<String>? date,
    Value<bool>? newAttack,
    Value<String>? note,
    Value<int>? rowid,
  }) {
    return DayMetaCompanion(
      date: date ?? this.date,
      newAttack: newAttack ?? this.newAttack,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (newAttack.present) {
      map['new_attack'] = Variable<bool>(newAttack.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayMetaCompanion(')
          ..write('date: $date, ')
          ..write('newAttack: $newAttack, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SymptomsTable symptoms = $SymptomsTable(this);
  late final $DayValuesTable dayValues = $DayValuesTable(this);
  late final $DayMetaTable dayMeta = $DayMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    symptoms,
    dayValues,
    dayMeta,
  ];
}

typedef $$SymptomsTableCreateCompanionBuilder = SymptomsCompanion Function({
  Value<int> id,
  required String name,
  required SymptomKind kind,
  required SymptomGroup grp,
  Value<String?> key,
  required int sortOrder,
  Value<bool> archived,
});
typedef $$SymptomsTableUpdateCompanionBuilder = SymptomsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<SymptomKind> kind,
  Value<SymptomGroup> grp,
  Value<String?> key,
  Value<int> sortOrder,
  Value<bool> archived,
});

final class $$SymptomsTableReferences
    extends BaseReferences<_$AppDatabase, $SymptomsTable, Symptom> {
  $$SymptomsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DayValuesTable, List<DayValue>>
  _dayValuesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dayValues,
    aliasName: 'symptoms__id__day_values__symptom_id',
  );

  $$DayValuesTableProcessedTableManager get dayValuesRefs {
    final manager = $$DayValuesTableTableManager(
      $_db,
      $_db.dayValues,
    ).filter((f) => f.symptomId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_dayValuesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SymptomsTableFilterComposer
    extends Composer<_$AppDatabase, $SymptomsTable> {
  $$SymptomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SymptomKind, SymptomKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<SymptomGroup, SymptomGroup, int> get grp =>
      $composableBuilder(
        column: $table.grp,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> dayValuesRefs(
    Expression<bool> Function($$DayValuesTableFilterComposer f) f,
  ) {
    final $$DayValuesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayValues,
      getReferencedColumn: (t) => t.symptomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayValuesTableFilterComposer(
            $db: $db,
            $table: $db.dayValues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SymptomsTableOrderingComposer
    extends Composer<_$AppDatabase, $SymptomsTable> {
  $$SymptomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grp => $composableBuilder(
    column: $table.grp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SymptomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SymptomsTable> {
  $$SymptomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SymptomKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SymptomGroup, int> get grp =>
      $composableBuilder(column: $table.grp, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  Expression<T> dayValuesRefs<T extends Object>(
    Expression<T> Function($$DayValuesTableAnnotationComposer a) f,
  ) {
    final $$DayValuesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayValues,
      getReferencedColumn: (t) => t.symptomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayValuesTableAnnotationComposer(
            $db: $db,
            $table: $db.dayValues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SymptomsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SymptomsTable,
          Symptom,
          $$SymptomsTableFilterComposer,
          $$SymptomsTableOrderingComposer,
          $$SymptomsTableAnnotationComposer,
          $$SymptomsTableCreateCompanionBuilder,
          $$SymptomsTableUpdateCompanionBuilder,
          (Symptom, $$SymptomsTableReferences),
          Symptom,
          PrefetchHooks Function({bool dayValuesRefs})
        > {
  $$SymptomsTableTableManager(_$AppDatabase db, $SymptomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SymptomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SymptomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SymptomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<SymptomKind> kind = const Value.absent(),
                Value<SymptomGroup> grp = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
              }) => SymptomsCompanion(
                id: id,
                name: name,
                kind: kind,
                grp: grp,
                key: key,
                sortOrder: sortOrder,
                archived: archived,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required SymptomKind kind,
                required SymptomGroup grp,
                Value<String?> key = const Value.absent(),
                required int sortOrder,
                Value<bool> archived = const Value.absent(),
              }) => SymptomsCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                grp: grp,
                key: key,
                sortOrder: sortOrder,
                archived: archived,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SymptomsTable, Symptom>(table),
                  $$SymptomsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dayValuesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (dayValuesRefs) db.dayValues],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dayValuesRefs)
                    await $_getPrefetchedDataByColumns<
                      Symptom,
                      $SymptomsTable,
                      DayValue,
                      $DayValuesTable
                    >(
                      currentTable: table,
                      referencedTable: $$SymptomsTableReferences
                          ._dayValuesRefsTable(db),
                      managerFromTypedResult: (p0) => $$SymptomsTableReferences(
                        db,
                        table,
                        p0,
                      ).dayValuesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'symptom_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SymptomsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SymptomsTable,
      Symptom,
      $$SymptomsTableFilterComposer,
      $$SymptomsTableOrderingComposer,
      $$SymptomsTableAnnotationComposer,
      $$SymptomsTableCreateCompanionBuilder,
      $$SymptomsTableUpdateCompanionBuilder,
      (Symptom, $$SymptomsTableReferences),
      Symptom,
      PrefetchHooks Function({bool dayValuesRefs})
    >;
typedef $$DayValuesTableCreateCompanionBuilder = DayValuesCompanion Function({
  required String date,
  required int symptomId,
  required int value,
  Value<int> rowid,
});
typedef $$DayValuesTableUpdateCompanionBuilder = DayValuesCompanion Function({
  Value<String> date,
  Value<int> symptomId,
  Value<int> value,
  Value<int> rowid,
});

final class $$DayValuesTableReferences
    extends BaseReferences<_$AppDatabase, $DayValuesTable, DayValue> {
  $$DayValuesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SymptomsTable _symptomIdTable(_$AppDatabase db) =>
      db.symptoms.createAlias('day_values__symptom_id__symptoms__id');

  $$SymptomsTableProcessedTableManager get symptomId {
    final $_column = $_itemColumn<int>('symptom_id')!;

    final manager = $$SymptomsTableTableManager(
      $_db,
      $_db.symptoms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symptomIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DayValuesTableFilterComposer
    extends Composer<_$AppDatabase, $DayValuesTable> {
  $$DayValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$SymptomsTableFilterComposer get symptomId {
    final $$SymptomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symptomId,
      referencedTable: $db.symptoms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SymptomsTableFilterComposer(
            $db: $db,
            $table: $db.symptoms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $DayValuesTable> {
  $$DayValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$SymptomsTableOrderingComposer get symptomId {
    final $$SymptomsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symptomId,
      referencedTable: $db.symptoms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SymptomsTableOrderingComposer(
            $db: $db,
            $table: $db.symptoms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayValuesTable> {
  $$DayValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$SymptomsTableAnnotationComposer get symptomId {
    final $$SymptomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symptomId,
      referencedTable: $db.symptoms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SymptomsTableAnnotationComposer(
            $db: $db,
            $table: $db.symptoms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayValuesTable,
          DayValue,
          $$DayValuesTableFilterComposer,
          $$DayValuesTableOrderingComposer,
          $$DayValuesTableAnnotationComposer,
          $$DayValuesTableCreateCompanionBuilder,
          $$DayValuesTableUpdateCompanionBuilder,
          (DayValue, $$DayValuesTableReferences),
          DayValue,
          PrefetchHooks Function({bool symptomId})
        > {
  $$DayValuesTableTableManager(_$AppDatabase db, $DayValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<int> symptomId = const Value.absent(),
                Value<int> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayValuesCompanion(
                date: date,
                symptomId: symptomId,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                required int symptomId,
                required int value,
                Value<int> rowid = const Value.absent(),
              }) => DayValuesCompanion.insert(
                date: date,
                symptomId: symptomId,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DayValuesTable, DayValue>(table),
                  $$DayValuesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symptomId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symptomId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.symptomId,
                        referencedTable: $$DayValuesTableReferences
                            ._symptomIdTable(db),
                        referencedColumn: $$DayValuesTableReferences
                            ._symptomIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DayValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayValuesTable,
      DayValue,
      $$DayValuesTableFilterComposer,
      $$DayValuesTableOrderingComposer,
      $$DayValuesTableAnnotationComposer,
      $$DayValuesTableCreateCompanionBuilder,
      $$DayValuesTableUpdateCompanionBuilder,
      (DayValue, $$DayValuesTableReferences),
      DayValue,
      PrefetchHooks Function({bool symptomId})
    >;
typedef $$DayMetaTableCreateCompanionBuilder = DayMetaCompanion Function({
  required String date,
  Value<bool> newAttack,
  Value<String> note,
  Value<int> rowid,
});
typedef $$DayMetaTableUpdateCompanionBuilder = DayMetaCompanion Function({
  Value<String> date,
  Value<bool> newAttack,
  Value<String> note,
  Value<int> rowid,
});

class $$DayMetaTableFilterComposer
    extends Composer<_$AppDatabase, $DayMetaTable> {
  $$DayMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get newAttack => $composableBuilder(
    column: $table.newAttack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DayMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $DayMetaTable> {
  $$DayMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get newAttack => $composableBuilder(
    column: $table.newAttack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayMetaTable> {
  $$DayMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<bool> get newAttack =>
      $composableBuilder(column: $table.newAttack, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$DayMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayMetaTable,
          DayMetaData,
          $$DayMetaTableFilterComposer,
          $$DayMetaTableOrderingComposer,
          $$DayMetaTableAnnotationComposer,
          $$DayMetaTableCreateCompanionBuilder,
          $$DayMetaTableUpdateCompanionBuilder,
          (
            DayMetaData,
            BaseReferences<_$AppDatabase, $DayMetaTable, DayMetaData>,
          ),
          DayMetaData,
          PrefetchHooks Function()
        > {
  $$DayMetaTableTableManager(_$AppDatabase db, $DayMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<bool> newAttack = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayMetaCompanion(
                date: date,
                newAttack: newAttack,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<bool> newAttack = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayMetaCompanion.insert(
                date: date,
                newAttack: newAttack,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DayMetaTable, DayMetaData>(table),
                  BaseReferences<_$AppDatabase, $DayMetaTable, DayMetaData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DayMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayMetaTable,
      DayMetaData,
      $$DayMetaTableFilterComposer,
      $$DayMetaTableOrderingComposer,
      $$DayMetaTableAnnotationComposer,
      $$DayMetaTableCreateCompanionBuilder,
      $$DayMetaTableUpdateCompanionBuilder,
      (DayMetaData, BaseReferences<_$AppDatabase, $DayMetaTable, DayMetaData>),
      DayMetaData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SymptomsTableTableManager get symptoms =>
      $$SymptomsTableTableManager(_db, _db.symptoms);
  $$DayValuesTableTableManager get dayValues =>
      $$DayValuesTableTableManager(_db, _db.dayValues);
  $$DayMetaTableTableManager get dayMeta =>
      $$DayMetaTableTableManager(_db, _db.dayMeta);
}
