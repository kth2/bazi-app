// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rules_db.dart';

// ignore_for_file: type=lint
class $RuleRowsTable extends RuleRows with TableInfo<$RuleRowsTable, RuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
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
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minMatchRatioMeta = const VerificationMeta(
    'minMatchRatio',
  );
  @override
  late final GeneratedColumn<double> minMatchRatio = GeneratedColumn<double>(
    'min_match_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conditionsJsonMeta = const VerificationMeta(
    'conditionsJson',
  );
  @override
  late final GeneratedColumn<String> conditionsJson = GeneratedColumn<String>(
    'conditions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interpretationMeta = const VerificationMeta(
    'interpretation',
  );
  @override
  late final GeneratedColumn<String> interpretation = GeneratedColumn<String>(
    'interpretation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('原局'),
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<int> tier = GeneratedColumn<int>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    title,
    weight,
    minMatchRatio,
    conditionsJson,
    interpretation,
    source,
    layer,
    tier,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rule_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    } else if (isInserting) {
      context.missing(_weightMeta);
    }
    if (data.containsKey('min_match_ratio')) {
      context.handle(
        _minMatchRatioMeta,
        minMatchRatio.isAcceptableOrUnknown(
          data['min_match_ratio']!,
          _minMatchRatioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minMatchRatioMeta);
    }
    if (data.containsKey('conditions_json')) {
      context.handle(
        _conditionsJsonMeta,
        conditionsJson.isAcceptableOrUnknown(
          data['conditions_json']!,
          _conditionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conditionsJsonMeta);
    }
    if (data.containsKey('interpretation')) {
      context.handle(
        _interpretationMeta,
        interpretation.isAcceptableOrUnknown(
          data['interpretation']!,
          _interpretationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interpretationMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('layer')) {
      context.handle(
        _layerMeta,
        layer.isAcceptableOrUnknown(data['layer']!, _layerMeta),
      );
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      minMatchRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_match_ratio'],
      )!,
      conditionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conditions_json'],
      )!,
      interpretation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interpretation'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      layer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tier'],
      )!,
    );
  }

  @override
  $RuleRowsTable createAlias(String alias) {
    return $RuleRowsTable(attachedDatabase, alias);
  }
}

class RuleRow extends DataClass implements Insertable<RuleRow> {
  final String id;
  final String category;
  final String title;
  final double weight;
  final double minMatchRatio;
  final String conditionsJson;
  final String interpretation;
  final String source;

  /// Temporal layer the rule speaks about (原局/大运/流年/流月/流日).
  final String layer;

  /// Reasoning tier: 1 基础事实 / 2 命局结构 / 3 格局成败 / 4 岁运引动.
  final int tier;
  const RuleRow({
    required this.id,
    required this.category,
    required this.title,
    required this.weight,
    required this.minMatchRatio,
    required this.conditionsJson,
    required this.interpretation,
    required this.source,
    required this.layer,
    required this.tier,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['title'] = Variable<String>(title);
    map['weight'] = Variable<double>(weight);
    map['min_match_ratio'] = Variable<double>(minMatchRatio);
    map['conditions_json'] = Variable<String>(conditionsJson);
    map['interpretation'] = Variable<String>(interpretation);
    map['source'] = Variable<String>(source);
    map['layer'] = Variable<String>(layer);
    map['tier'] = Variable<int>(tier);
    return map;
  }

  RuleRowsCompanion toCompanion(bool nullToAbsent) {
    return RuleRowsCompanion(
      id: Value(id),
      category: Value(category),
      title: Value(title),
      weight: Value(weight),
      minMatchRatio: Value(minMatchRatio),
      conditionsJson: Value(conditionsJson),
      interpretation: Value(interpretation),
      source: Value(source),
      layer: Value(layer),
      tier: Value(tier),
    );
  }

  factory RuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleRow(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      title: serializer.fromJson<String>(json['title']),
      weight: serializer.fromJson<double>(json['weight']),
      minMatchRatio: serializer.fromJson<double>(json['minMatchRatio']),
      conditionsJson: serializer.fromJson<String>(json['conditionsJson']),
      interpretation: serializer.fromJson<String>(json['interpretation']),
      source: serializer.fromJson<String>(json['source']),
      layer: serializer.fromJson<String>(json['layer']),
      tier: serializer.fromJson<int>(json['tier']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'title': serializer.toJson<String>(title),
      'weight': serializer.toJson<double>(weight),
      'minMatchRatio': serializer.toJson<double>(minMatchRatio),
      'conditionsJson': serializer.toJson<String>(conditionsJson),
      'interpretation': serializer.toJson<String>(interpretation),
      'source': serializer.toJson<String>(source),
      'layer': serializer.toJson<String>(layer),
      'tier': serializer.toJson<int>(tier),
    };
  }

  RuleRow copyWith({
    String? id,
    String? category,
    String? title,
    double? weight,
    double? minMatchRatio,
    String? conditionsJson,
    String? interpretation,
    String? source,
    String? layer,
    int? tier,
  }) => RuleRow(
    id: id ?? this.id,
    category: category ?? this.category,
    title: title ?? this.title,
    weight: weight ?? this.weight,
    minMatchRatio: minMatchRatio ?? this.minMatchRatio,
    conditionsJson: conditionsJson ?? this.conditionsJson,
    interpretation: interpretation ?? this.interpretation,
    source: source ?? this.source,
    layer: layer ?? this.layer,
    tier: tier ?? this.tier,
  );
  RuleRow copyWithCompanion(RuleRowsCompanion data) {
    return RuleRow(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      title: data.title.present ? data.title.value : this.title,
      weight: data.weight.present ? data.weight.value : this.weight,
      minMatchRatio: data.minMatchRatio.present
          ? data.minMatchRatio.value
          : this.minMatchRatio,
      conditionsJson: data.conditionsJson.present
          ? data.conditionsJson.value
          : this.conditionsJson,
      interpretation: data.interpretation.present
          ? data.interpretation.value
          : this.interpretation,
      source: data.source.present ? data.source.value : this.source,
      layer: data.layer.present ? data.layer.value : this.layer,
      tier: data.tier.present ? data.tier.value : this.tier,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleRow(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('title: $title, ')
          ..write('weight: $weight, ')
          ..write('minMatchRatio: $minMatchRatio, ')
          ..write('conditionsJson: $conditionsJson, ')
          ..write('interpretation: $interpretation, ')
          ..write('source: $source, ')
          ..write('layer: $layer, ')
          ..write('tier: $tier')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    title,
    weight,
    minMatchRatio,
    conditionsJson,
    interpretation,
    source,
    layer,
    tier,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleRow &&
          other.id == this.id &&
          other.category == this.category &&
          other.title == this.title &&
          other.weight == this.weight &&
          other.minMatchRatio == this.minMatchRatio &&
          other.conditionsJson == this.conditionsJson &&
          other.interpretation == this.interpretation &&
          other.source == this.source &&
          other.layer == this.layer &&
          other.tier == this.tier);
}

class RuleRowsCompanion extends UpdateCompanion<RuleRow> {
  final Value<String> id;
  final Value<String> category;
  final Value<String> title;
  final Value<double> weight;
  final Value<double> minMatchRatio;
  final Value<String> conditionsJson;
  final Value<String> interpretation;
  final Value<String> source;
  final Value<String> layer;
  final Value<int> tier;
  final Value<int> rowid;
  const RuleRowsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.title = const Value.absent(),
    this.weight = const Value.absent(),
    this.minMatchRatio = const Value.absent(),
    this.conditionsJson = const Value.absent(),
    this.interpretation = const Value.absent(),
    this.source = const Value.absent(),
    this.layer = const Value.absent(),
    this.tier = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuleRowsCompanion.insert({
    required String id,
    required String category,
    required String title,
    required double weight,
    required double minMatchRatio,
    required String conditionsJson,
    required String interpretation,
    required String source,
    this.layer = const Value.absent(),
    this.tier = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       title = Value(title),
       weight = Value(weight),
       minMatchRatio = Value(minMatchRatio),
       conditionsJson = Value(conditionsJson),
       interpretation = Value(interpretation),
       source = Value(source);
  static Insertable<RuleRow> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<String>? title,
    Expression<double>? weight,
    Expression<double>? minMatchRatio,
    Expression<String>? conditionsJson,
    Expression<String>? interpretation,
    Expression<String>? source,
    Expression<String>? layer,
    Expression<int>? tier,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (title != null) 'title': title,
      if (weight != null) 'weight': weight,
      if (minMatchRatio != null) 'min_match_ratio': minMatchRatio,
      if (conditionsJson != null) 'conditions_json': conditionsJson,
      if (interpretation != null) 'interpretation': interpretation,
      if (source != null) 'source': source,
      if (layer != null) 'layer': layer,
      if (tier != null) 'tier': tier,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuleRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<String>? title,
    Value<double>? weight,
    Value<double>? minMatchRatio,
    Value<String>? conditionsJson,
    Value<String>? interpretation,
    Value<String>? source,
    Value<String>? layer,
    Value<int>? tier,
    Value<int>? rowid,
  }) {
    return RuleRowsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      weight: weight ?? this.weight,
      minMatchRatio: minMatchRatio ?? this.minMatchRatio,
      conditionsJson: conditionsJson ?? this.conditionsJson,
      interpretation: interpretation ?? this.interpretation,
      source: source ?? this.source,
      layer: layer ?? this.layer,
      tier: tier ?? this.tier,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (minMatchRatio.present) {
      map['min_match_ratio'] = Variable<double>(minMatchRatio.value);
    }
    if (conditionsJson.present) {
      map['conditions_json'] = Variable<String>(conditionsJson.value);
    }
    if (interpretation.present) {
      map['interpretation'] = Variable<String>(interpretation.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (tier.present) {
      map['tier'] = Variable<int>(tier.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuleRowsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('title: $title, ')
          ..write('weight: $weight, ')
          ..write('minMatchRatio: $minMatchRatio, ')
          ..write('conditionsJson: $conditionsJson, ')
          ..write('interpretation: $interpretation, ')
          ..write('source: $source, ')
          ..write('layer: $layer, ')
          ..write('tier: $tier, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaRowsTable extends MetaRows with TableInfo<$MetaRowsTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaRowsTable createAlias(String alias) {
    return $MetaRowsTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaRowsCompanion toCompanion(bool nullToAbsent) {
    return MetaRowsCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaRowsCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaRowsCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RulesDatabase extends GeneratedDatabase {
  _$RulesDatabase(QueryExecutor e) : super(e);
  $RulesDatabaseManager get managers => $RulesDatabaseManager(this);
  late final $RuleRowsTable ruleRows = $RuleRowsTable(this);
  late final $MetaRowsTable metaRows = $MetaRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [ruleRows, metaRows];
}

typedef $$RuleRowsTableCreateCompanionBuilder =
    RuleRowsCompanion Function({
      required String id,
      required String category,
      required String title,
      required double weight,
      required double minMatchRatio,
      required String conditionsJson,
      required String interpretation,
      required String source,
      Value<String> layer,
      Value<int> tier,
      Value<int> rowid,
    });
typedef $$RuleRowsTableUpdateCompanionBuilder =
    RuleRowsCompanion Function({
      Value<String> id,
      Value<String> category,
      Value<String> title,
      Value<double> weight,
      Value<double> minMatchRatio,
      Value<String> conditionsJson,
      Value<String> interpretation,
      Value<String> source,
      Value<String> layer,
      Value<int> tier,
      Value<int> rowid,
    });

class $$RuleRowsTableFilterComposer
    extends Composer<_$RulesDatabase, $RuleRowsTable> {
  $$RuleRowsTableFilterComposer({
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

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minMatchRatio => $composableBuilder(
    column: $table.minMatchRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interpretation => $composableBuilder(
    column: $table.interpretation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuleRowsTableOrderingComposer
    extends Composer<_$RulesDatabase, $RuleRowsTable> {
  $$RuleRowsTableOrderingComposer({
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

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minMatchRatio => $composableBuilder(
    column: $table.minMatchRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interpretation => $composableBuilder(
    column: $table.interpretation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuleRowsTableAnnotationComposer
    extends Composer<_$RulesDatabase, $RuleRowsTable> {
  $$RuleRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<double> get minMatchRatio => $composableBuilder(
    column: $table.minMatchRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get interpretation => $composableBuilder(
    column: $table.interpretation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<int> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);
}

class $$RuleRowsTableTableManager
    extends
        RootTableManager<
          _$RulesDatabase,
          $RuleRowsTable,
          RuleRow,
          $$RuleRowsTableFilterComposer,
          $$RuleRowsTableOrderingComposer,
          $$RuleRowsTableAnnotationComposer,
          $$RuleRowsTableCreateCompanionBuilder,
          $$RuleRowsTableUpdateCompanionBuilder,
          (RuleRow, BaseReferences<_$RulesDatabase, $RuleRowsTable, RuleRow>),
          RuleRow,
          PrefetchHooks Function()
        > {
  $$RuleRowsTableTableManager(_$RulesDatabase db, $RuleRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuleRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuleRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RuleRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<double> minMatchRatio = const Value.absent(),
                Value<String> conditionsJson = const Value.absent(),
                Value<String> interpretation = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<int> tier = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleRowsCompanion(
                id: id,
                category: category,
                title: title,
                weight: weight,
                minMatchRatio: minMatchRatio,
                conditionsJson: conditionsJson,
                interpretation: interpretation,
                source: source,
                layer: layer,
                tier: tier,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                required String title,
                required double weight,
                required double minMatchRatio,
                required String conditionsJson,
                required String interpretation,
                required String source,
                Value<String> layer = const Value.absent(),
                Value<int> tier = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleRowsCompanion.insert(
                id: id,
                category: category,
                title: title,
                weight: weight,
                minMatchRatio: minMatchRatio,
                conditionsJson: conditionsJson,
                interpretation: interpretation,
                source: source,
                layer: layer,
                tier: tier,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuleRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RulesDatabase,
      $RuleRowsTable,
      RuleRow,
      $$RuleRowsTableFilterComposer,
      $$RuleRowsTableOrderingComposer,
      $$RuleRowsTableAnnotationComposer,
      $$RuleRowsTableCreateCompanionBuilder,
      $$RuleRowsTableUpdateCompanionBuilder,
      (RuleRow, BaseReferences<_$RulesDatabase, $RuleRowsTable, RuleRow>),
      RuleRow,
      PrefetchHooks Function()
    >;
typedef $$MetaRowsTableCreateCompanionBuilder =
    MetaRowsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaRowsTableUpdateCompanionBuilder =
    MetaRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaRowsTableFilterComposer
    extends Composer<_$RulesDatabase, $MetaRowsTable> {
  $$MetaRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaRowsTableOrderingComposer
    extends Composer<_$RulesDatabase, $MetaRowsTable> {
  $$MetaRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaRowsTableAnnotationComposer
    extends Composer<_$RulesDatabase, $MetaRowsTable> {
  $$MetaRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaRowsTableTableManager
    extends
        RootTableManager<
          _$RulesDatabase,
          $MetaRowsTable,
          MetaRow,
          $$MetaRowsTableFilterComposer,
          $$MetaRowsTableOrderingComposer,
          $$MetaRowsTableAnnotationComposer,
          $$MetaRowsTableCreateCompanionBuilder,
          $$MetaRowsTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$RulesDatabase, $MetaRowsTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaRowsTableTableManager(_$RulesDatabase db, $MetaRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaRowsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaRowsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$RulesDatabase,
      $MetaRowsTable,
      MetaRow,
      $$MetaRowsTableFilterComposer,
      $$MetaRowsTableOrderingComposer,
      $$MetaRowsTableAnnotationComposer,
      $$MetaRowsTableCreateCompanionBuilder,
      $$MetaRowsTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$RulesDatabase, $MetaRowsTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $RulesDatabaseManager {
  final _$RulesDatabase _db;
  $RulesDatabaseManager(this._db);
  $$RuleRowsTableTableManager get ruleRows =>
      $$RuleRowsTableTableManager(_db, _db.ruleRows);
  $$MetaRowsTableTableManager get metaRows =>
      $$MetaRowsTableTableManager(_db, _db.metaRows);
}
