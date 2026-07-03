/// A single matchable condition inside a rule.
///
/// JSON shape: {"type": "...", "value": "...", "position": "...",
/// "scope": "...", "count": n, "op": ">=", "threshold": x,
/// "required": true, "kinds": [...]}
class RuleCondition {
  /// Condition kind, e.g. verdict / hasShiShen / hasShenSha / hasInteraction.
  final String type;

  /// Primary comparison value (十神 name or group, 神煞 name, element, ...).
  final String? value;

  /// Restrict to one pillar: 年柱/月柱/日柱/时柱.
  final String? position;

  /// Where to look for 十神: stem (天干) / main (天干+本气) / any (含藏干).
  final String scope;

  /// Minimum occurrences (shiShenCount, interactionCount).
  final int count;

  /// Comparison operator for elementPercent: ">=" or "<=".
  final String op;

  /// Threshold for elementPercent.
  final double threshold;

  /// Interaction kinds counted by interactionCount.
  final List<String> kinds;

  /// Required conditions must match or the whole rule is discarded.
  final bool required;

  const RuleCondition({
    required this.type,
    this.value,
    this.position,
    this.scope = 'any',
    this.count = 1,
    this.op = '>=',
    this.threshold = 0,
    this.kinds = const [],
    this.required = false,
  });

  factory RuleCondition.fromJson(Map<String, dynamic> json) => RuleCondition(
        type: json['type'] as String,
        value: json['value'] as String?,
        position: json['position'] as String?,
        scope: json['scope'] as String? ?? 'any',
        count: json['count'] as int? ?? 1,
        op: json['op'] as String? ?? '>=',
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
        kinds: (json['kinds'] as List?)?.cast<String>() ?? const [],
        required: json['required'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        if (value != null) 'value': value,
        if (position != null) 'position': position,
        if (scope != 'any') 'scope': scope,
        if (count != 1) 'count': count,
        if (op != '>=') 'op': op,
        if (threshold != 0) 'threshold': threshold,
        if (kinds.isNotEmpty) 'kinds': kinds,
        if (required) 'required': true,
      };

  /// Human-readable label shown in the UI for matched conditions.
  String get label {
    switch (type) {
      case 'gender':
        return '$value命';
      case 'verdict':
        return '日主$value';
      case 'seasonState':
        return '月令$value';
      case 'dayMasterElement':
        return '日主属$value';
      case 'monthBranch':
        return '月支$value';
      case 'branchAt':
        return '$position支$value';
      case 'stemAt':
        return '$position干$value';
      case 'hasShiShen':
        return position != null ? '$position见$value' : '命带$value';
      case 'lacksShiShen':
        return '无$value';
      case 'shiShenCount':
        return '$value≥$count';
      case 'hasShenSha':
        return position != null ? '$position带$value' : '命带$value';
      case 'hasInteraction':
        return position != null ? '$position逢$value' : '局中$value';
      case 'interactionCount':
        return '刑冲害≥$count';
      case 'elementPercent':
        return '$value${op == '>=' ? '偏旺' : '偏弱'}';
      case 'kongWang':
        return '$position落空亡';
      default:
        return type;
    }
  }
}

/// A weighted interpretation rule.
class Rule {
  final String id;
  final String category; // 整体命局 / 婚姻 / 事业 / 健康
  final String title;
  final double weight; // importance, typically 5-10
  final double minMatchRatio; // rule fires when matched ratio >= this
  final List<RuleCondition> conditions;
  final String interpretation;
  final String source; // 渊海子平 / 子平真诠 / 三命通会 / 经验总结 ...

  const Rule({
    required this.id,
    required this.category,
    required this.title,
    required this.weight,
    required this.minMatchRatio,
    required this.conditions,
    required this.interpretation,
    required this.source,
  });

  factory Rule.fromJson(Map<String, dynamic> json) => Rule(
        id: json['id'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        weight: (json['weight'] as num).toDouble(),
        minMatchRatio: (json['minMatchRatio'] as num?)?.toDouble() ?? 1.0,
        conditions: [
          for (final c in json['conditions'] as List)
            RuleCondition.fromJson(c as Map<String, dynamic>),
        ],
        interpretation: json['interpretation'] as String,
        source: json['source'] as String? ?? '经验总结',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'weight': weight,
        'minMatchRatio': minMatchRatio,
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'interpretation': interpretation,
        'source': source,
      };
}

/// Result of evaluating one rule against a chart.
class RuleMatch {
  final Rule rule;
  final double matchRatio; // 0-1
  final double score; // weight × matchRatio
  final List<RuleCondition> matchedConditions;

  const RuleMatch({
    required this.rule,
    required this.matchRatio,
    required this.score,
    required this.matchedConditions,
  });

  Map<String, dynamic> toJson() => {
        'title': rule.title,
        'category': rule.category,
        'score': double.parse(score.toStringAsFixed(2)),
        'matchRatio': double.parse(matchRatio.toStringAsFixed(2)),
        'matched': matchedConditions.map((c) => c.label).toList(),
        'interpretation': rule.interpretation,
        'source': rule.source,
      };
}
