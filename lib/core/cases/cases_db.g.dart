// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cases_db.dart';

// ignore_for_file: type=lint
class $CaseRowsTable extends CaseRows with TableInfo<$CaseRowsTable, CaseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaseRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baziStringMeta = const VerificationMeta(
    'baziString',
  );
  @override
  late final GeneratedColumn<String> baziString = GeneratedColumn<String>(
    'bazi_string',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputJsonMeta = const VerificationMeta(
    'inputJson',
  );
  @override
  late final GeneratedColumn<String> inputJson = GeneratedColumn<String>(
    'input_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeLabelMeta = const VerificationMeta(
    'scopeLabel',
  );
  @override
  late final GeneratedColumn<String> scopeLabel = GeneratedColumn<String>(
    'scope_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<int> engineVersion = GeneratedColumn<int>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _structureSummaryMeta = const VerificationMeta(
    'structureSummary',
  );
  @override
  late final GeneratedColumn<String> structureSummary = GeneratedColumn<String>(
    'structure_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimsJsonMeta = const VerificationMeta(
    'claimsJson',
  );
  @override
  late final GeneratedColumn<String> claimsJson = GeneratedColumn<String>(
    'claims_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aiTextMeta = const VerificationMeta('aiText');
  @override
  late final GeneratedColumn<String> aiText = GeneratedColumn<String>(
    'ai_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _outcomeNoteMeta = const VerificationMeta(
    'outcomeNote',
  );
  @override
  late final GeneratedColumn<String> outcomeNote = GeneratedColumn<String>(
    'outcome_note',
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
  static const VerificationMeta _reviewDueAtMeta = const VerificationMeta(
    'reviewDueAt',
  );
  @override
  late final GeneratedColumn<DateTime> reviewDueAt = GeneratedColumn<DateTime>(
    'review_due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta(
    'lastReviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewedAt =
      GeneratedColumn<DateTime>(
        'last_reviewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    baziString,
    inputJson,
    scopeLabel,
    engineVersion,
    structureSummary,
    claimsJson,
    aiText,
    outcomeNote,
    createdAt,
    reviewDueAt,
    lastReviewedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'case_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('bazi_string')) {
      context.handle(
        _baziStringMeta,
        baziString.isAcceptableOrUnknown(data['bazi_string']!, _baziStringMeta),
      );
    } else if (isInserting) {
      context.missing(_baziStringMeta);
    }
    if (data.containsKey('input_json')) {
      context.handle(
        _inputJsonMeta,
        inputJson.isAcceptableOrUnknown(data['input_json']!, _inputJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_inputJsonMeta);
    }
    if (data.containsKey('scope_label')) {
      context.handle(
        _scopeLabelMeta,
        scopeLabel.isAcceptableOrUnknown(data['scope_label']!, _scopeLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeLabelMeta);
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineVersionMeta);
    }
    if (data.containsKey('structure_summary')) {
      context.handle(
        _structureSummaryMeta,
        structureSummary.isAcceptableOrUnknown(
          data['structure_summary']!,
          _structureSummaryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_structureSummaryMeta);
    }
    if (data.containsKey('claims_json')) {
      context.handle(
        _claimsJsonMeta,
        claimsJson.isAcceptableOrUnknown(data['claims_json']!, _claimsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_claimsJsonMeta);
    }
    if (data.containsKey('ai_text')) {
      context.handle(
        _aiTextMeta,
        aiText.isAcceptableOrUnknown(data['ai_text']!, _aiTextMeta),
      );
    }
    if (data.containsKey('outcome_note')) {
      context.handle(
        _outcomeNoteMeta,
        outcomeNote.isAcceptableOrUnknown(
          data['outcome_note']!,
          _outcomeNoteMeta,
        ),
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
    if (data.containsKey('review_due_at')) {
      context.handle(
        _reviewDueAtMeta,
        reviewDueAt.isAcceptableOrUnknown(
          data['review_due_at']!,
          _reviewDueAtMeta,
        ),
      );
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(
          data['last_reviewed_at']!,
          _lastReviewedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      baziString: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bazi_string'],
      )!,
      inputJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_json'],
      )!,
      scopeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_label'],
      )!,
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}engine_version'],
      )!,
      structureSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}structure_summary'],
      )!,
      claimsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}claims_json'],
      )!,
      aiText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_text'],
      )!,
      outcomeNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome_note'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      reviewDueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}review_due_at'],
      ),
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed_at'],
      ),
    );
  }

  @override
  $CaseRowsTable createAlias(String alias) {
    return $CaseRowsTable(attachedDatabase, alias);
  }
}

class CaseRow extends DataClass implements Insertable<CaseRow> {
  final String id;
  final String title;
  final String baziString;
  final String inputJson;
  final String scopeLabel;
  final int engineVersion;
  final String structureSummary;
  final String claimsJson;
  final String aiText;
  final String outcomeNote;
  final DateTime createdAt;
  final DateTime? reviewDueAt;
  final DateTime? lastReviewedAt;
  const CaseRow({
    required this.id,
    required this.title,
    required this.baziString,
    required this.inputJson,
    required this.scopeLabel,
    required this.engineVersion,
    required this.structureSummary,
    required this.claimsJson,
    required this.aiText,
    required this.outcomeNote,
    required this.createdAt,
    this.reviewDueAt,
    this.lastReviewedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['bazi_string'] = Variable<String>(baziString);
    map['input_json'] = Variable<String>(inputJson);
    map['scope_label'] = Variable<String>(scopeLabel);
    map['engine_version'] = Variable<int>(engineVersion);
    map['structure_summary'] = Variable<String>(structureSummary);
    map['claims_json'] = Variable<String>(claimsJson);
    map['ai_text'] = Variable<String>(aiText);
    map['outcome_note'] = Variable<String>(outcomeNote);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || reviewDueAt != null) {
      map['review_due_at'] = Variable<DateTime>(reviewDueAt);
    }
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt);
    }
    return map;
  }

  CaseRowsCompanion toCompanion(bool nullToAbsent) {
    return CaseRowsCompanion(
      id: Value(id),
      title: Value(title),
      baziString: Value(baziString),
      inputJson: Value(inputJson),
      scopeLabel: Value(scopeLabel),
      engineVersion: Value(engineVersion),
      structureSummary: Value(structureSummary),
      claimsJson: Value(claimsJson),
      aiText: Value(aiText),
      outcomeNote: Value(outcomeNote),
      createdAt: Value(createdAt),
      reviewDueAt: reviewDueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewDueAt),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
    );
  }

  factory CaseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaseRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      baziString: serializer.fromJson<String>(json['baziString']),
      inputJson: serializer.fromJson<String>(json['inputJson']),
      scopeLabel: serializer.fromJson<String>(json['scopeLabel']),
      engineVersion: serializer.fromJson<int>(json['engineVersion']),
      structureSummary: serializer.fromJson<String>(json['structureSummary']),
      claimsJson: serializer.fromJson<String>(json['claimsJson']),
      aiText: serializer.fromJson<String>(json['aiText']),
      outcomeNote: serializer.fromJson<String>(json['outcomeNote']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      reviewDueAt: serializer.fromJson<DateTime?>(json['reviewDueAt']),
      lastReviewedAt: serializer.fromJson<DateTime?>(json['lastReviewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'baziString': serializer.toJson<String>(baziString),
      'inputJson': serializer.toJson<String>(inputJson),
      'scopeLabel': serializer.toJson<String>(scopeLabel),
      'engineVersion': serializer.toJson<int>(engineVersion),
      'structureSummary': serializer.toJson<String>(structureSummary),
      'claimsJson': serializer.toJson<String>(claimsJson),
      'aiText': serializer.toJson<String>(aiText),
      'outcomeNote': serializer.toJson<String>(outcomeNote),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'reviewDueAt': serializer.toJson<DateTime?>(reviewDueAt),
      'lastReviewedAt': serializer.toJson<DateTime?>(lastReviewedAt),
    };
  }

  CaseRow copyWith({
    String? id,
    String? title,
    String? baziString,
    String? inputJson,
    String? scopeLabel,
    int? engineVersion,
    String? structureSummary,
    String? claimsJson,
    String? aiText,
    String? outcomeNote,
    DateTime? createdAt,
    Value<DateTime?> reviewDueAt = const Value.absent(),
    Value<DateTime?> lastReviewedAt = const Value.absent(),
  }) => CaseRow(
    id: id ?? this.id,
    title: title ?? this.title,
    baziString: baziString ?? this.baziString,
    inputJson: inputJson ?? this.inputJson,
    scopeLabel: scopeLabel ?? this.scopeLabel,
    engineVersion: engineVersion ?? this.engineVersion,
    structureSummary: structureSummary ?? this.structureSummary,
    claimsJson: claimsJson ?? this.claimsJson,
    aiText: aiText ?? this.aiText,
    outcomeNote: outcomeNote ?? this.outcomeNote,
    createdAt: createdAt ?? this.createdAt,
    reviewDueAt: reviewDueAt.present ? reviewDueAt.value : this.reviewDueAt,
    lastReviewedAt: lastReviewedAt.present
        ? lastReviewedAt.value
        : this.lastReviewedAt,
  );
  CaseRow copyWithCompanion(CaseRowsCompanion data) {
    return CaseRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      baziString: data.baziString.present
          ? data.baziString.value
          : this.baziString,
      inputJson: data.inputJson.present ? data.inputJson.value : this.inputJson,
      scopeLabel: data.scopeLabel.present
          ? data.scopeLabel.value
          : this.scopeLabel,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      structureSummary: data.structureSummary.present
          ? data.structureSummary.value
          : this.structureSummary,
      claimsJson: data.claimsJson.present
          ? data.claimsJson.value
          : this.claimsJson,
      aiText: data.aiText.present ? data.aiText.value : this.aiText,
      outcomeNote: data.outcomeNote.present
          ? data.outcomeNote.value
          : this.outcomeNote,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      reviewDueAt: data.reviewDueAt.present
          ? data.reviewDueAt.value
          : this.reviewDueAt,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaseRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('baziString: $baziString, ')
          ..write('inputJson: $inputJson, ')
          ..write('scopeLabel: $scopeLabel, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('structureSummary: $structureSummary, ')
          ..write('claimsJson: $claimsJson, ')
          ..write('aiText: $aiText, ')
          ..write('outcomeNote: $outcomeNote, ')
          ..write('createdAt: $createdAt, ')
          ..write('reviewDueAt: $reviewDueAt, ')
          ..write('lastReviewedAt: $lastReviewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    baziString,
    inputJson,
    scopeLabel,
    engineVersion,
    structureSummary,
    claimsJson,
    aiText,
    outcomeNote,
    createdAt,
    reviewDueAt,
    lastReviewedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaseRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.baziString == this.baziString &&
          other.inputJson == this.inputJson &&
          other.scopeLabel == this.scopeLabel &&
          other.engineVersion == this.engineVersion &&
          other.structureSummary == this.structureSummary &&
          other.claimsJson == this.claimsJson &&
          other.aiText == this.aiText &&
          other.outcomeNote == this.outcomeNote &&
          other.createdAt == this.createdAt &&
          other.reviewDueAt == this.reviewDueAt &&
          other.lastReviewedAt == this.lastReviewedAt);
}

class CaseRowsCompanion extends UpdateCompanion<CaseRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> baziString;
  final Value<String> inputJson;
  final Value<String> scopeLabel;
  final Value<int> engineVersion;
  final Value<String> structureSummary;
  final Value<String> claimsJson;
  final Value<String> aiText;
  final Value<String> outcomeNote;
  final Value<DateTime> createdAt;
  final Value<DateTime?> reviewDueAt;
  final Value<DateTime?> lastReviewedAt;
  final Value<int> rowid;
  const CaseRowsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.baziString = const Value.absent(),
    this.inputJson = const Value.absent(),
    this.scopeLabel = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.structureSummary = const Value.absent(),
    this.claimsJson = const Value.absent(),
    this.aiText = const Value.absent(),
    this.outcomeNote = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.reviewDueAt = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaseRowsCompanion.insert({
    required String id,
    required String title,
    required String baziString,
    required String inputJson,
    required String scopeLabel,
    required int engineVersion,
    required String structureSummary,
    required String claimsJson,
    this.aiText = const Value.absent(),
    this.outcomeNote = const Value.absent(),
    required DateTime createdAt,
    this.reviewDueAt = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       baziString = Value(baziString),
       inputJson = Value(inputJson),
       scopeLabel = Value(scopeLabel),
       engineVersion = Value(engineVersion),
       structureSummary = Value(structureSummary),
       claimsJson = Value(claimsJson),
       createdAt = Value(createdAt);
  static Insertable<CaseRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? baziString,
    Expression<String>? inputJson,
    Expression<String>? scopeLabel,
    Expression<int>? engineVersion,
    Expression<String>? structureSummary,
    Expression<String>? claimsJson,
    Expression<String>? aiText,
    Expression<String>? outcomeNote,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? reviewDueAt,
    Expression<DateTime>? lastReviewedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (baziString != null) 'bazi_string': baziString,
      if (inputJson != null) 'input_json': inputJson,
      if (scopeLabel != null) 'scope_label': scopeLabel,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (structureSummary != null) 'structure_summary': structureSummary,
      if (claimsJson != null) 'claims_json': claimsJson,
      if (aiText != null) 'ai_text': aiText,
      if (outcomeNote != null) 'outcome_note': outcomeNote,
      if (createdAt != null) 'created_at': createdAt,
      if (reviewDueAt != null) 'review_due_at': reviewDueAt,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaseRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? baziString,
    Value<String>? inputJson,
    Value<String>? scopeLabel,
    Value<int>? engineVersion,
    Value<String>? structureSummary,
    Value<String>? claimsJson,
    Value<String>? aiText,
    Value<String>? outcomeNote,
    Value<DateTime>? createdAt,
    Value<DateTime?>? reviewDueAt,
    Value<DateTime?>? lastReviewedAt,
    Value<int>? rowid,
  }) {
    return CaseRowsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      baziString: baziString ?? this.baziString,
      inputJson: inputJson ?? this.inputJson,
      scopeLabel: scopeLabel ?? this.scopeLabel,
      engineVersion: engineVersion ?? this.engineVersion,
      structureSummary: structureSummary ?? this.structureSummary,
      claimsJson: claimsJson ?? this.claimsJson,
      aiText: aiText ?? this.aiText,
      outcomeNote: outcomeNote ?? this.outcomeNote,
      createdAt: createdAt ?? this.createdAt,
      reviewDueAt: reviewDueAt ?? this.reviewDueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (baziString.present) {
      map['bazi_string'] = Variable<String>(baziString.value);
    }
    if (inputJson.present) {
      map['input_json'] = Variable<String>(inputJson.value);
    }
    if (scopeLabel.present) {
      map['scope_label'] = Variable<String>(scopeLabel.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<int>(engineVersion.value);
    }
    if (structureSummary.present) {
      map['structure_summary'] = Variable<String>(structureSummary.value);
    }
    if (claimsJson.present) {
      map['claims_json'] = Variable<String>(claimsJson.value);
    }
    if (aiText.present) {
      map['ai_text'] = Variable<String>(aiText.value);
    }
    if (outcomeNote.present) {
      map['outcome_note'] = Variable<String>(outcomeNote.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (reviewDueAt.present) {
      map['review_due_at'] = Variable<DateTime>(reviewDueAt.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaseRowsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('baziString: $baziString, ')
          ..write('inputJson: $inputJson, ')
          ..write('scopeLabel: $scopeLabel, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('structureSummary: $structureSummary, ')
          ..write('claimsJson: $claimsJson, ')
          ..write('aiText: $aiText, ')
          ..write('outcomeNote: $outcomeNote, ')
          ..write('createdAt: $createdAt, ')
          ..write('reviewDueAt: $reviewDueAt, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CasesDatabase extends GeneratedDatabase {
  _$CasesDatabase(QueryExecutor e) : super(e);
  $CasesDatabaseManager get managers => $CasesDatabaseManager(this);
  late final $CaseRowsTable caseRows = $CaseRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [caseRows];
}

typedef $$CaseRowsTableCreateCompanionBuilder =
    CaseRowsCompanion Function({
      required String id,
      required String title,
      required String baziString,
      required String inputJson,
      required String scopeLabel,
      required int engineVersion,
      required String structureSummary,
      required String claimsJson,
      Value<String> aiText,
      Value<String> outcomeNote,
      required DateTime createdAt,
      Value<DateTime?> reviewDueAt,
      Value<DateTime?> lastReviewedAt,
      Value<int> rowid,
    });
typedef $$CaseRowsTableUpdateCompanionBuilder =
    CaseRowsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> baziString,
      Value<String> inputJson,
      Value<String> scopeLabel,
      Value<int> engineVersion,
      Value<String> structureSummary,
      Value<String> claimsJson,
      Value<String> aiText,
      Value<String> outcomeNote,
      Value<DateTime> createdAt,
      Value<DateTime?> reviewDueAt,
      Value<DateTime?> lastReviewedAt,
      Value<int> rowid,
    });

class $$CaseRowsTableFilterComposer
    extends Composer<_$CasesDatabase, $CaseRowsTable> {
  $$CaseRowsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baziString => $composableBuilder(
    column: $table.baziString,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputJson => $composableBuilder(
    column: $table.inputJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeLabel => $composableBuilder(
    column: $table.scopeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get structureSummary => $composableBuilder(
    column: $table.structureSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get claimsJson => $composableBuilder(
    column: $table.claimsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiText => $composableBuilder(
    column: $table.aiText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcomeNote => $composableBuilder(
    column: $table.outcomeNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reviewDueAt => $composableBuilder(
    column: $table.reviewDueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CaseRowsTableOrderingComposer
    extends Composer<_$CasesDatabase, $CaseRowsTable> {
  $$CaseRowsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baziString => $composableBuilder(
    column: $table.baziString,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputJson => $composableBuilder(
    column: $table.inputJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeLabel => $composableBuilder(
    column: $table.scopeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get structureSummary => $composableBuilder(
    column: $table.structureSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get claimsJson => $composableBuilder(
    column: $table.claimsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiText => $composableBuilder(
    column: $table.aiText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcomeNote => $composableBuilder(
    column: $table.outcomeNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reviewDueAt => $composableBuilder(
    column: $table.reviewDueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaseRowsTableAnnotationComposer
    extends Composer<_$CasesDatabase, $CaseRowsTable> {
  $$CaseRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get baziString => $composableBuilder(
    column: $table.baziString,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inputJson =>
      $composableBuilder(column: $table.inputJson, builder: (column) => column);

  GeneratedColumn<String> get scopeLabel => $composableBuilder(
    column: $table.scopeLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get structureSummary => $composableBuilder(
    column: $table.structureSummary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get claimsJson => $composableBuilder(
    column: $table.claimsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiText =>
      $composableBuilder(column: $table.aiText, builder: (column) => column);

  GeneratedColumn<String> get outcomeNote => $composableBuilder(
    column: $table.outcomeNote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewDueAt => $composableBuilder(
    column: $table.reviewDueAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => column,
  );
}

class $$CaseRowsTableTableManager
    extends
        RootTableManager<
          _$CasesDatabase,
          $CaseRowsTable,
          CaseRow,
          $$CaseRowsTableFilterComposer,
          $$CaseRowsTableOrderingComposer,
          $$CaseRowsTableAnnotationComposer,
          $$CaseRowsTableCreateCompanionBuilder,
          $$CaseRowsTableUpdateCompanionBuilder,
          (CaseRow, BaseReferences<_$CasesDatabase, $CaseRowsTable, CaseRow>),
          CaseRow,
          PrefetchHooks Function()
        > {
  $$CaseRowsTableTableManager(_$CasesDatabase db, $CaseRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaseRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaseRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaseRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> baziString = const Value.absent(),
                Value<String> inputJson = const Value.absent(),
                Value<String> scopeLabel = const Value.absent(),
                Value<int> engineVersion = const Value.absent(),
                Value<String> structureSummary = const Value.absent(),
                Value<String> claimsJson = const Value.absent(),
                Value<String> aiText = const Value.absent(),
                Value<String> outcomeNote = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> reviewDueAt = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseRowsCompanion(
                id: id,
                title: title,
                baziString: baziString,
                inputJson: inputJson,
                scopeLabel: scopeLabel,
                engineVersion: engineVersion,
                structureSummary: structureSummary,
                claimsJson: claimsJson,
                aiText: aiText,
                outcomeNote: outcomeNote,
                createdAt: createdAt,
                reviewDueAt: reviewDueAt,
                lastReviewedAt: lastReviewedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String baziString,
                required String inputJson,
                required String scopeLabel,
                required int engineVersion,
                required String structureSummary,
                required String claimsJson,
                Value<String> aiText = const Value.absent(),
                Value<String> outcomeNote = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> reviewDueAt = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaseRowsCompanion.insert(
                id: id,
                title: title,
                baziString: baziString,
                inputJson: inputJson,
                scopeLabel: scopeLabel,
                engineVersion: engineVersion,
                structureSummary: structureSummary,
                claimsJson: claimsJson,
                aiText: aiText,
                outcomeNote: outcomeNote,
                createdAt: createdAt,
                reviewDueAt: reviewDueAt,
                lastReviewedAt: lastReviewedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CaseRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$CasesDatabase,
      $CaseRowsTable,
      CaseRow,
      $$CaseRowsTableFilterComposer,
      $$CaseRowsTableOrderingComposer,
      $$CaseRowsTableAnnotationComposer,
      $$CaseRowsTableCreateCompanionBuilder,
      $$CaseRowsTableUpdateCompanionBuilder,
      (CaseRow, BaseReferences<_$CasesDatabase, $CaseRowsTable, CaseRow>),
      CaseRow,
      PrefetchHooks Function()
    >;

class $CasesDatabaseManager {
  final _$CasesDatabase _db;
  $CasesDatabaseManager(this._db);
  $$CaseRowsTableTableManager get caseRows =>
      $$CaseRowsTableTableManager(_db, _db.caseRows);
}
