// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_store.dart';

// ignore_for_file: type=lint
class $TimelineEventRowsTable extends TimelineEventRows
    with TableInfo<$TimelineEventRowsTable, TimelineEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimelineEventRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chartKeyMeta = const VerificationMeta(
    'chartKey',
  );
  @override
  late final GeneratedColumn<String> chartKey = GeneratedColumn<String>(
    'chart_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindIdMeta = const VerificationMeta('kindId');
  @override
  late final GeneratedColumn<String> kindId = GeneratedColumn<String>(
    'kind_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAgeMeta = const VerificationMeta(
    'startAge',
  );
  @override
  late final GeneratedColumn<double> startAge = GeneratedColumn<double>(
    'start_age',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAgeMeta = const VerificationMeta('endAge');
  @override
  late final GeneratedColumn<double> endAge = GeneratedColumn<double>(
    'end_age',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intensityMeta = const VerificationMeta(
    'intensity',
  );
  @override
  late final GeneratedColumn<String> intensity = GeneratedColumn<String>(
    'intensity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _polarityMeta = const VerificationMeta(
    'polarity',
  );
  @override
  late final GeneratedColumn<String> polarity = GeneratedColumn<String>(
    'polarity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _basisJsonMeta = const VerificationMeta(
    'basisJson',
  );
  @override
  late final GeneratedColumn<String> basisJson = GeneratedColumn<String>(
    'basis_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chartKey,
    kindId,
    startAge,
    endAge,
    intensity,
    origin,
    hidden,
    confidence,
    polarity,
    basisJson,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timeline_event_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimelineEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chart_key')) {
      context.handle(
        _chartKeyMeta,
        chartKey.isAcceptableOrUnknown(data['chart_key']!, _chartKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_chartKeyMeta);
    }
    if (data.containsKey('kind_id')) {
      context.handle(
        _kindIdMeta,
        kindId.isAcceptableOrUnknown(data['kind_id']!, _kindIdMeta),
      );
    } else if (isInserting) {
      context.missing(_kindIdMeta);
    }
    if (data.containsKey('start_age')) {
      context.handle(
        _startAgeMeta,
        startAge.isAcceptableOrUnknown(data['start_age']!, _startAgeMeta),
      );
    } else if (isInserting) {
      context.missing(_startAgeMeta);
    }
    if (data.containsKey('end_age')) {
      context.handle(
        _endAgeMeta,
        endAge.isAcceptableOrUnknown(data['end_age']!, _endAgeMeta),
      );
    } else if (isInserting) {
      context.missing(_endAgeMeta);
    }
    if (data.containsKey('intensity')) {
      context.handle(
        _intensityMeta,
        intensity.isAcceptableOrUnknown(data['intensity']!, _intensityMeta),
      );
    } else if (isInserting) {
      context.missing(_intensityMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('polarity')) {
      context.handle(
        _polarityMeta,
        polarity.isAcceptableOrUnknown(data['polarity']!, _polarityMeta),
      );
    }
    if (data.containsKey('basis_json')) {
      context.handle(
        _basisJsonMeta,
        basisJson.isAcceptableOrUnknown(data['basis_json']!, _basisJsonMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimelineEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimelineEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chartKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chart_key'],
      )!,
      kindId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind_id'],
      )!,
      startAge: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_age'],
      )!,
      endAge: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_age'],
      )!,
      intensity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intensity'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      polarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}polarity'],
      ),
      basisJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis_json'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $TimelineEventRowsTable createAlias(String alias) {
    return $TimelineEventRowsTable(attachedDatabase, alias);
  }
}

class TimelineEventRow extends DataClass
    implements Insertable<TimelineEventRow> {
  final String id;

  /// 八字 + 性别. Events belong to a chart, not to a saved case: the same
  /// person re-entering the same birth data must find their timeline intact.
  final String chartKey;
  final String kindId;
  final double startAge;
  final double endAge;
  final String intensity;
  final String origin;

  /// True for a suggested event the user deleted. Kept as a tombstone: the
  /// scanner is deterministic, so without one the marker returns on the next
  /// rescan and the delete looks broken.
  final bool hidden;
  final double? confidence;
  final String? polarity;
  final String basisJson;
  final String note;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const TimelineEventRow({
    required this.id,
    required this.chartKey,
    required this.kindId,
    required this.startAge,
    required this.endAge,
    required this.intensity,
    required this.origin,
    required this.hidden,
    this.confidence,
    this.polarity,
    required this.basisJson,
    required this.note,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chart_key'] = Variable<String>(chartKey);
    map['kind_id'] = Variable<String>(kindId);
    map['start_age'] = Variable<double>(startAge);
    map['end_age'] = Variable<double>(endAge);
    map['intensity'] = Variable<String>(intensity);
    map['origin'] = Variable<String>(origin);
    map['hidden'] = Variable<bool>(hidden);
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    if (!nullToAbsent || polarity != null) {
      map['polarity'] = Variable<String>(polarity);
    }
    map['basis_json'] = Variable<String>(basisJson);
    map['note'] = Variable<String>(note);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  TimelineEventRowsCompanion toCompanion(bool nullToAbsent) {
    return TimelineEventRowsCompanion(
      id: Value(id),
      chartKey: Value(chartKey),
      kindId: Value(kindId),
      startAge: Value(startAge),
      endAge: Value(endAge),
      intensity: Value(intensity),
      origin: Value(origin),
      hidden: Value(hidden),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      polarity: polarity == null && nullToAbsent
          ? const Value.absent()
          : Value(polarity),
      basisJson: Value(basisJson),
      note: Value(note),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory TimelineEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimelineEventRow(
      id: serializer.fromJson<String>(json['id']),
      chartKey: serializer.fromJson<String>(json['chartKey']),
      kindId: serializer.fromJson<String>(json['kindId']),
      startAge: serializer.fromJson<double>(json['startAge']),
      endAge: serializer.fromJson<double>(json['endAge']),
      intensity: serializer.fromJson<String>(json['intensity']),
      origin: serializer.fromJson<String>(json['origin']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      confidence: serializer.fromJson<double?>(json['confidence']),
      polarity: serializer.fromJson<String?>(json['polarity']),
      basisJson: serializer.fromJson<String>(json['basisJson']),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chartKey': serializer.toJson<String>(chartKey),
      'kindId': serializer.toJson<String>(kindId),
      'startAge': serializer.toJson<double>(startAge),
      'endAge': serializer.toJson<double>(endAge),
      'intensity': serializer.toJson<String>(intensity),
      'origin': serializer.toJson<String>(origin),
      'hidden': serializer.toJson<bool>(hidden),
      'confidence': serializer.toJson<double?>(confidence),
      'polarity': serializer.toJson<String?>(polarity),
      'basisJson': serializer.toJson<String>(basisJson),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  TimelineEventRow copyWith({
    String? id,
    String? chartKey,
    String? kindId,
    double? startAge,
    double? endAge,
    String? intensity,
    String? origin,
    bool? hidden,
    Value<double?> confidence = const Value.absent(),
    Value<String?> polarity = const Value.absent(),
    String? basisJson,
    String? note,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => TimelineEventRow(
    id: id ?? this.id,
    chartKey: chartKey ?? this.chartKey,
    kindId: kindId ?? this.kindId,
    startAge: startAge ?? this.startAge,
    endAge: endAge ?? this.endAge,
    intensity: intensity ?? this.intensity,
    origin: origin ?? this.origin,
    hidden: hidden ?? this.hidden,
    confidence: confidence.present ? confidence.value : this.confidence,
    polarity: polarity.present ? polarity.value : this.polarity,
    basisJson: basisJson ?? this.basisJson,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  TimelineEventRow copyWithCompanion(TimelineEventRowsCompanion data) {
    return TimelineEventRow(
      id: data.id.present ? data.id.value : this.id,
      chartKey: data.chartKey.present ? data.chartKey.value : this.chartKey,
      kindId: data.kindId.present ? data.kindId.value : this.kindId,
      startAge: data.startAge.present ? data.startAge.value : this.startAge,
      endAge: data.endAge.present ? data.endAge.value : this.endAge,
      intensity: data.intensity.present ? data.intensity.value : this.intensity,
      origin: data.origin.present ? data.origin.value : this.origin,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      polarity: data.polarity.present ? data.polarity.value : this.polarity,
      basisJson: data.basisJson.present ? data.basisJson.value : this.basisJson,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimelineEventRow(')
          ..write('id: $id, ')
          ..write('chartKey: $chartKey, ')
          ..write('kindId: $kindId, ')
          ..write('startAge: $startAge, ')
          ..write('endAge: $endAge, ')
          ..write('intensity: $intensity, ')
          ..write('origin: $origin, ')
          ..write('hidden: $hidden, ')
          ..write('confidence: $confidence, ')
          ..write('polarity: $polarity, ')
          ..write('basisJson: $basisJson, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chartKey,
    kindId,
    startAge,
    endAge,
    intensity,
    origin,
    hidden,
    confidence,
    polarity,
    basisJson,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimelineEventRow &&
          other.id == this.id &&
          other.chartKey == this.chartKey &&
          other.kindId == this.kindId &&
          other.startAge == this.startAge &&
          other.endAge == this.endAge &&
          other.intensity == this.intensity &&
          other.origin == this.origin &&
          other.hidden == this.hidden &&
          other.confidence == this.confidence &&
          other.polarity == this.polarity &&
          other.basisJson == this.basisJson &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TimelineEventRowsCompanion extends UpdateCompanion<TimelineEventRow> {
  final Value<String> id;
  final Value<String> chartKey;
  final Value<String> kindId;
  final Value<double> startAge;
  final Value<double> endAge;
  final Value<String> intensity;
  final Value<String> origin;
  final Value<bool> hidden;
  final Value<double?> confidence;
  final Value<String?> polarity;
  final Value<String> basisJson;
  final Value<String> note;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const TimelineEventRowsCompanion({
    this.id = const Value.absent(),
    this.chartKey = const Value.absent(),
    this.kindId = const Value.absent(),
    this.startAge = const Value.absent(),
    this.endAge = const Value.absent(),
    this.intensity = const Value.absent(),
    this.origin = const Value.absent(),
    this.hidden = const Value.absent(),
    this.confidence = const Value.absent(),
    this.polarity = const Value.absent(),
    this.basisJson = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimelineEventRowsCompanion.insert({
    required String id,
    required String chartKey,
    required String kindId,
    required double startAge,
    required double endAge,
    required String intensity,
    required String origin,
    this.hidden = const Value.absent(),
    this.confidence = const Value.absent(),
    this.polarity = const Value.absent(),
    this.basisJson = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chartKey = Value(chartKey),
       kindId = Value(kindId),
       startAge = Value(startAge),
       endAge = Value(endAge),
       intensity = Value(intensity),
       origin = Value(origin),
       createdAt = Value(createdAt);
  static Insertable<TimelineEventRow> custom({
    Expression<String>? id,
    Expression<String>? chartKey,
    Expression<String>? kindId,
    Expression<double>? startAge,
    Expression<double>? endAge,
    Expression<String>? intensity,
    Expression<String>? origin,
    Expression<bool>? hidden,
    Expression<double>? confidence,
    Expression<String>? polarity,
    Expression<String>? basisJson,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chartKey != null) 'chart_key': chartKey,
      if (kindId != null) 'kind_id': kindId,
      if (startAge != null) 'start_age': startAge,
      if (endAge != null) 'end_age': endAge,
      if (intensity != null) 'intensity': intensity,
      if (origin != null) 'origin': origin,
      if (hidden != null) 'hidden': hidden,
      if (confidence != null) 'confidence': confidence,
      if (polarity != null) 'polarity': polarity,
      if (basisJson != null) 'basis_json': basisJson,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimelineEventRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? chartKey,
    Value<String>? kindId,
    Value<double>? startAge,
    Value<double>? endAge,
    Value<String>? intensity,
    Value<String>? origin,
    Value<bool>? hidden,
    Value<double?>? confidence,
    Value<String?>? polarity,
    Value<String>? basisJson,
    Value<String>? note,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return TimelineEventRowsCompanion(
      id: id ?? this.id,
      chartKey: chartKey ?? this.chartKey,
      kindId: kindId ?? this.kindId,
      startAge: startAge ?? this.startAge,
      endAge: endAge ?? this.endAge,
      intensity: intensity ?? this.intensity,
      origin: origin ?? this.origin,
      hidden: hidden ?? this.hidden,
      confidence: confidence ?? this.confidence,
      polarity: polarity ?? this.polarity,
      basisJson: basisJson ?? this.basisJson,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chartKey.present) {
      map['chart_key'] = Variable<String>(chartKey.value);
    }
    if (kindId.present) {
      map['kind_id'] = Variable<String>(kindId.value);
    }
    if (startAge.present) {
      map['start_age'] = Variable<double>(startAge.value);
    }
    if (endAge.present) {
      map['end_age'] = Variable<double>(endAge.value);
    }
    if (intensity.present) {
      map['intensity'] = Variable<String>(intensity.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (polarity.present) {
      map['polarity'] = Variable<String>(polarity.value);
    }
    if (basisJson.present) {
      map['basis_json'] = Variable<String>(basisJson.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimelineEventRowsCompanion(')
          ..write('id: $id, ')
          ..write('chartKey: $chartKey, ')
          ..write('kindId: $kindId, ')
          ..write('startAge: $startAge, ')
          ..write('endAge: $endAge, ')
          ..write('intensity: $intensity, ')
          ..write('origin: $origin, ')
          ..write('hidden: $hidden, ')
          ..write('confidence: $confidence, ')
          ..write('polarity: $polarity, ')
          ..write('basisJson: $basisJson, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TimelineDatabase extends GeneratedDatabase {
  _$TimelineDatabase(QueryExecutor e) : super(e);
  $TimelineDatabaseManager get managers => $TimelineDatabaseManager(this);
  late final $TimelineEventRowsTable timelineEventRows =
      $TimelineEventRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [timelineEventRows];
}

typedef $$TimelineEventRowsTableCreateCompanionBuilder =
    TimelineEventRowsCompanion Function({
      required String id,
      required String chartKey,
      required String kindId,
      required double startAge,
      required double endAge,
      required String intensity,
      required String origin,
      Value<bool> hidden,
      Value<double?> confidence,
      Value<String?> polarity,
      Value<String> basisJson,
      Value<String> note,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$TimelineEventRowsTableUpdateCompanionBuilder =
    TimelineEventRowsCompanion Function({
      Value<String> id,
      Value<String> chartKey,
      Value<String> kindId,
      Value<double> startAge,
      Value<double> endAge,
      Value<String> intensity,
      Value<String> origin,
      Value<bool> hidden,
      Value<double?> confidence,
      Value<String?> polarity,
      Value<String> basisJson,
      Value<String> note,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$TimelineEventRowsTableFilterComposer
    extends Composer<_$TimelineDatabase, $TimelineEventRowsTable> {
  $$TimelineEventRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chartKey => $composableBuilder(
    column: $table.chartKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kindId => $composableBuilder(
    column: $table.kindId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startAge => $composableBuilder(
    column: $table.startAge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endAge => $composableBuilder(
    column: $table.endAge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get polarity => $composableBuilder(
    column: $table.polarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basisJson => $composableBuilder(
    column: $table.basisJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TimelineEventRowsTableOrderingComposer
    extends Composer<_$TimelineDatabase, $TimelineEventRowsTable> {
  $$TimelineEventRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chartKey => $composableBuilder(
    column: $table.chartKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kindId => $composableBuilder(
    column: $table.kindId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startAge => $composableBuilder(
    column: $table.startAge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endAge => $composableBuilder(
    column: $table.endAge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get polarity => $composableBuilder(
    column: $table.polarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basisJson => $composableBuilder(
    column: $table.basisJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TimelineEventRowsTableAnnotationComposer
    extends Composer<_$TimelineDatabase, $TimelineEventRowsTable> {
  $$TimelineEventRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chartKey =>
      $composableBuilder(column: $table.chartKey, builder: (column) => column);

  GeneratedColumn<String> get kindId =>
      $composableBuilder(column: $table.kindId, builder: (column) => column);

  GeneratedColumn<double> get startAge =>
      $composableBuilder(column: $table.startAge, builder: (column) => column);

  GeneratedColumn<double> get endAge =>
      $composableBuilder(column: $table.endAge, builder: (column) => column);

  GeneratedColumn<String> get intensity =>
      $composableBuilder(column: $table.intensity, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get polarity =>
      $composableBuilder(column: $table.polarity, builder: (column) => column);

  GeneratedColumn<String> get basisJson =>
      $composableBuilder(column: $table.basisJson, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TimelineEventRowsTableTableManager
    extends
        RootTableManager<
          _$TimelineDatabase,
          $TimelineEventRowsTable,
          TimelineEventRow,
          $$TimelineEventRowsTableFilterComposer,
          $$TimelineEventRowsTableOrderingComposer,
          $$TimelineEventRowsTableAnnotationComposer,
          $$TimelineEventRowsTableCreateCompanionBuilder,
          $$TimelineEventRowsTableUpdateCompanionBuilder,
          (
            TimelineEventRow,
            BaseReferences<
              _$TimelineDatabase,
              $TimelineEventRowsTable,
              TimelineEventRow
            >,
          ),
          TimelineEventRow,
          PrefetchHooks Function()
        > {
  $$TimelineEventRowsTableTableManager(
    _$TimelineDatabase db,
    $TimelineEventRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimelineEventRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimelineEventRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimelineEventRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chartKey = const Value.absent(),
                Value<String> kindId = const Value.absent(),
                Value<double> startAge = const Value.absent(),
                Value<double> endAge = const Value.absent(),
                Value<String> intensity = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String?> polarity = const Value.absent(),
                Value<String> basisJson = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimelineEventRowsCompanion(
                id: id,
                chartKey: chartKey,
                kindId: kindId,
                startAge: startAge,
                endAge: endAge,
                intensity: intensity,
                origin: origin,
                hidden: hidden,
                confidence: confidence,
                polarity: polarity,
                basisJson: basisJson,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chartKey,
                required String kindId,
                required double startAge,
                required double endAge,
                required String intensity,
                required String origin,
                Value<bool> hidden = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String?> polarity = const Value.absent(),
                Value<String> basisJson = const Value.absent(),
                Value<String> note = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimelineEventRowsCompanion.insert(
                id: id,
                chartKey: chartKey,
                kindId: kindId,
                startAge: startAge,
                endAge: endAge,
                intensity: intensity,
                origin: origin,
                hidden: hidden,
                confidence: confidence,
                polarity: polarity,
                basisJson: basisJson,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TimelineEventRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$TimelineDatabase,
      $TimelineEventRowsTable,
      TimelineEventRow,
      $$TimelineEventRowsTableFilterComposer,
      $$TimelineEventRowsTableOrderingComposer,
      $$TimelineEventRowsTableAnnotationComposer,
      $$TimelineEventRowsTableCreateCompanionBuilder,
      $$TimelineEventRowsTableUpdateCompanionBuilder,
      (
        TimelineEventRow,
        BaseReferences<
          _$TimelineDatabase,
          $TimelineEventRowsTable,
          TimelineEventRow
        >,
      ),
      TimelineEventRow,
      PrefetchHooks Function()
    >;

class $TimelineDatabaseManager {
  final _$TimelineDatabase _db;
  $TimelineDatabaseManager(this._db);
  $$TimelineEventRowsTableTableManager get timelineEventRows =>
      $$TimelineEventRowsTableTableManager(_db, _db.timelineEventRows);
}
