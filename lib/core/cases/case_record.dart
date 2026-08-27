import 'dart:convert';

import '../analysis/event_inference.dart';
import '../analysis/natal_structure.dart';
import '../analysis/reasoning_report.dart';
import '../analysis/temporal_context.dart';
import '../analysis/yingqi_engine.dart';
import '../models/birth_input.dart';

/// What kind of statement a recorded claim is.
enum ClaimKind {
  /// 格局/成败/用神 — a standing judgement about the chart itself.
  structure,

  /// An inferred event class in a life domain.
  event,

  /// A ranked 应期 window.
  yingQi,
}

extension ClaimKindX on ClaimKind {
  String get label => switch (this) {
        ClaimKind.structure => '格局判定',
        ClaimKind.event => '事件预测',
        ClaimKind.yingQi => '应期窗口',
      };
}

/// How a claim turned out, once the user comes back to fill it in.
enum ClaimVerdict {
  /// Not yet reviewed.
  unverified,

  /// 应验 — happened substantially as stated.
  hit,

  /// 部分应验 — right domain or right timing, but not both.
  partial,

  /// 未应验 — did not happen.
  miss,

  /// 无法判断 — nothing observable either way.
  unclear,
}

extension ClaimVerdictX on ClaimVerdict {
  String get label => switch (this) {
        ClaimVerdict.unverified => '待验证',
        ClaimVerdict.hit => '应验',
        ClaimVerdict.partial => '部分应验',
        ClaimVerdict.miss => '未应验',
        ClaimVerdict.unclear => '无法判断',
      };

  bool get isReviewed => this != ClaimVerdict.unverified;

  /// Counts toward accuracy only when the outcome was observable at all.
  bool get isScorable =>
      this == ClaimVerdict.hit ||
      this == ClaimVerdict.partial ||
      this == ClaimVerdict.miss;

  double get creditWeight => switch (this) {
        ClaimVerdict.hit => 1.0,
        ClaimVerdict.partial => 0.5,
        _ => 0.0,
      };
}

/// One checkable statement the engine made, plus what actually happened.
///
/// Recording the *engine's* structured claims rather than only the AI prose is
/// what makes a case reviewable: "断为事业·职务变动，应期甲午月" can be marked
/// 应验 or 未应验, whereas a paragraph of narrative cannot.
class PredictedClaim {
  /// Stable within its case, so a verdict survives edits and reordering.
  final String id;

  final ClaimKind kind;

  /// 事业·职务变动 / 流月 甲午月（芒种起） / 正官格·破而有救
  final String title;

  /// The engine's basis chain or trigger list.
  final String detail;

  /// 吉 / 凶 / 吉凶参半, where the claim carries one.
  final String? polarity;

  /// Engine confidence or window strength, 0..1.
  final double confidence;

  /// The window a 应期 claim points at.
  final DateTime? windowStart;
  final DateTime? windowEnd;

  // --- filled in by the user, later ---
  final ClaimVerdict verdict;

  /// What actually happened, in the user's words.
  final String note;

  /// The date the thing actually happened, when known — lets 应期 accuracy be
  /// checked against the predicted window rather than guessed at.
  final DateTime? actualDate;

  const PredictedClaim({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    this.polarity,
    this.confidence = 0,
    this.windowStart,
    this.windowEnd,
    this.verdict = ClaimVerdict.unverified,
    this.note = '',
    this.actualDate,
  });

  PredictedClaim copyWith({
    ClaimVerdict? verdict,
    String? note,
    DateTime? actualDate,
    bool clearActualDate = false,
  }) =>
      PredictedClaim(
        id: id,
        kind: kind,
        title: title,
        detail: detail,
        polarity: polarity,
        confidence: confidence,
        windowStart: windowStart,
        windowEnd: windowEnd,
        verdict: verdict ?? this.verdict,
        note: note ?? this.note,
        actualDate: clearActualDate ? null : (actualDate ?? this.actualDate),
      );

  /// Whether [actualDate] fell inside the predicted window. Null when either
  /// side is unknown.
  bool? get landedInWindow {
    if (actualDate == null || windowStart == null || windowEnd == null) {
      return null;
    }
    final d = DateTime(actualDate!.year, actualDate!.month, actualDate!.day);
    return !d.isBefore(_dayOf(windowStart!)) && !d.isAfter(_dayOf(windowEnd!));
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'detail': detail,
        if (polarity != null) 'polarity': polarity,
        'confidence': confidence,
        if (windowStart != null)
          'windowStart': windowStart!.toIso8601String(),
        if (windowEnd != null) 'windowEnd': windowEnd!.toIso8601String(),
        'verdict': verdict.name,
        'note': note,
        if (actualDate != null) 'actualDate': actualDate!.toIso8601String(),
      };

  factory PredictedClaim.fromJson(Map<String, dynamic> json) => PredictedClaim(
        id: json['id'] as String,
        kind: ClaimKind.values.byName(json['kind'] as String),
        title: json['title'] as String,
        detail: json['detail'] as String? ?? '',
        polarity: json['polarity'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        windowStart: _parseDate(json['windowStart']),
        windowEnd: _parseDate(json['windowEnd']),
        verdict: ClaimVerdict.values.byName(
            json['verdict'] as String? ?? ClaimVerdict.unverified.name),
        note: json['note'] as String? ?? '',
        actualDate: _parseDate(json['actualDate']),
      );

  static DateTime? _parseDate(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String);
}

/// Where a case sits in the review cycle.
enum CaseStatus {
  /// Window has not closed yet — nothing to verify.
  pending,

  /// The period has elapsed and no verdicts are filled in.
  awaitingReview,

  /// Some claims reviewed, some not.
  partiallyReviewed,

  /// Every claim has a verdict.
  reviewed,
}

extension CaseStatusX on CaseStatus {
  String get label => switch (this) {
        CaseStatus.pending => '进行中',
        CaseStatus.awaitingReview => '待回填',
        CaseStatus.partiallyReviewed => '部分回填',
        CaseStatus.reviewed => '已回填',
      };
}

/// One saved reading, with room for the outcome to be filled in later.
///
/// Deliberately a *record*, not a training signal. Nothing under
/// `lib/core/analysis` or `lib/core/rules` may read this store: the app's
/// stated principle is 理论固定，推演结构化，AI负责解释 — history is kept so a
/// person can judge the theory, not so the program can quietly rewrite it.
/// `test/case_guardrail_test.dart` enforces the import direction.
class CaseRecord {
  final String id;

  /// User's own label, e.g. 客户A·2026流年.
  final String title;

  final BirthInput input;
  final String baziString;

  /// 整体命局 / 大运 癸酉（29-38岁）/ 流年 2026 丙午 …
  final String scopeLabel;

  /// Which engine version produced the claims, so a verdict is always
  /// attributable to the reasoning that actually made it.
  final int engineVersion;

  final String structureSummary;
  final List<PredictedClaim> claims;

  /// The AI narrative as shown to the user, kept verbatim for review.
  final String aiText;

  /// Overall note on how the period actually went.
  final String outcomeNote;

  final DateTime createdAt;

  /// When the predicted period closes — after this the case is worth
  /// revisiting. Null for whole-life readings, which never "come due".
  final DateTime? reviewDueAt;

  final DateTime? lastReviewedAt;

  const CaseRecord({
    required this.id,
    required this.title,
    required this.input,
    required this.baziString,
    required this.scopeLabel,
    required this.engineVersion,
    required this.structureSummary,
    required this.claims,
    required this.createdAt,
    this.aiText = '',
    this.outcomeNote = '',
    this.reviewDueAt,
    this.lastReviewedAt,
  });

  CaseRecord copyWith({
    String? title,
    List<PredictedClaim>? claims,
    String? outcomeNote,
    DateTime? lastReviewedAt,
  }) =>
      CaseRecord(
        id: id,
        title: title ?? this.title,
        input: input,
        baziString: baziString,
        scopeLabel: scopeLabel,
        engineVersion: engineVersion,
        structureSummary: structureSummary,
        claims: claims ?? this.claims,
        aiText: aiText,
        outcomeNote: outcomeNote ?? this.outcomeNote,
        createdAt: createdAt,
        reviewDueAt: reviewDueAt,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      );

  int get reviewedCount => claims.where((c) => c.verdict.isReviewed).length;

  /// True once the predicted period has elapsed, so there is something to
  /// judge. Whole-life readings are never "due".
  bool isDue([DateTime? now]) =>
      reviewDueAt != null && !(now ?? DateTime.now()).isBefore(reviewDueAt!);

  CaseStatus status([DateTime? now]) {
    if (claims.isNotEmpty && reviewedCount == claims.length) {
      return CaseStatus.reviewed;
    }
    if (reviewedCount > 0) return CaseStatus.partiallyReviewed;
    return isDue(now) ? CaseStatus.awaitingReview : CaseStatus.pending;
  }

  /// 应验率 over the claims that were actually observable.
  ///
  /// Null when nothing scorable has been filled in — an unreviewed case has no
  /// accuracy, which is different from an accuracy of zero.
  double? get hitRate {
    final scorable = claims.where((c) => c.verdict.isScorable).toList();
    if (scorable.isEmpty) return null;
    final credit =
        scorable.fold<double>(0, (sum, c) => sum + c.verdict.creditWeight);
    return credit / scorable.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'input': input.toJson(),
        'baziString': baziString,
        'scopeLabel': scopeLabel,
        'engineVersion': engineVersion,
        'structureSummary': structureSummary,
        'claims': claims.map((c) => c.toJson()).toList(),
        'aiText': aiText,
        'outcomeNote': outcomeNote,
        'createdAt': createdAt.toIso8601String(),
        if (reviewDueAt != null) 'reviewDueAt': reviewDueAt!.toIso8601String(),
        if (lastReviewedAt != null)
          'lastReviewedAt': lastReviewedAt!.toIso8601String(),
      };

  factory CaseRecord.fromJson(Map<String, dynamic> json) => CaseRecord(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        input: BirthInput.fromJson(json['input'] as Map<String, dynamic>),
        baziString: json['baziString'] as String? ?? '',
        scopeLabel: json['scopeLabel'] as String? ?? '',
        engineVersion: json['engineVersion'] as int? ?? 0,
        structureSummary: json['structureSummary'] as String? ?? '',
        claims: [
          for (final c in (json['claims'] as List? ?? const []))
            PredictedClaim.fromJson(c as Map<String, dynamic>),
        ],
        aiText: json['aiText'] as String? ?? '',
        outcomeNote: json['outcomeNote'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        reviewDueAt: PredictedClaim._parseDate(json['reviewDueAt']),
        lastReviewedAt: PredictedClaim._parseDate(json['lastReviewedAt']),
      );

  /// Snapshots a finished reading into a reviewable case.
  ///
  /// [reviewDueAt] is the end of the analysed period, not the strongest
  /// 应期 window: the user should be invited back when the whole period has
  /// elapsed and every claim is checkable.
  factory CaseRecord.fromReport(
    ReasoningReport report, {
    required String id,
    required String title,
    required String scopeLabel,
    required int engineVersion,
    String aiText = '',
    DateTime? createdAt,
    DateTime? reviewDueAt,
    int maxEvents = 6,
    int maxWindows = 3,
  }) {
    final claims = <PredictedClaim>[
      PredictedClaim(
        id: 'structure',
        kind: ClaimKind.structure,
        title: '${report.structure.pattern.geJu}·'
            '${report.structure.status.label}',
        detail: report.structure.summary,
        confidence: 1,
      ),
      for (var i = 0; i < report.events.length && i < maxEvents; i++)
        _eventClaim(report.events[i], i, reviewDueAt),
      for (var i = 0; i < report.yingQi.windows.length && i < maxWindows; i++)
        _windowClaim(report.yingQi.windows[i], i),
    ];

    return CaseRecord(
      id: id,
      title: title,
      input: report.chart.input,
      baziString: report.chart.baziString,
      scopeLabel: scopeLabel,
      engineVersion: engineVersion,
      structureSummary: report.structure.summary,
      claims: claims,
      aiText: aiText,
      createdAt: createdAt ?? DateTime.now(),
      reviewDueAt: reviewDueAt,
    );
  }

  /// When the analysed period closes — the moment every claim in the case
  /// becomes checkable, and therefore when it is worth inviting the user back.
  ///
  /// Null for a whole-life reading: it describes a life, so it never comes due.
  static DateTime? scopeEndOf(TemporalContext context) {
    if (context.day != null) {
      final d = context.day!.date;
      return DateTime(d.year, d.month, d.day, 23, 59);
    }
    if (context.month != null) return context.month!.end;
    // 流年 runs 立春 to 立春; the next year's 立春 is close enough to date a
    // review reminder without another astronomical solve.
    if (context.year != null) return DateTime(context.year!.year + 1, 2, 4);
    if (context.decade != null) return DateTime(context.decade!.endYear, 2, 4);
    return null;
  }

  static PredictedClaim _eventClaim(
      EventCandidate e, int i, DateTime? scopeEnd) {
    return PredictedClaim(
      id: 'event_$i',
      kind: ClaimKind.event,
      title: '${e.domain}·${e.subtype}',
      detail: e.basis.join(' → '),
      polarity: e.polarity.label,
      confidence: e.confidence,
      windowEnd: scopeEnd,
    );
  }

  static PredictedClaim _windowClaim(YingQiWindow w, int i) => PredictedClaim(
        id: 'window_$i',
        kind: ClaimKind.yingQi,
        title: w.label,
        detail: w.triggers.join('；'),
        polarity: w.verdict,
        confidence: w.score,
        windowStart: w.start,
        windowEnd: w.end,
      );

  static String encodeClaims(List<PredictedClaim> claims) =>
      jsonEncode([for (final c in claims) c.toJson()]);

  static List<PredictedClaim> decodeClaims(String raw) => [
        for (final c in jsonDecode(raw) as List)
          PredictedClaim.fromJson(c as Map<String, dynamic>),
      ];
}
