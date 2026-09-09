import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/activation_engine.dart';
import 'package:bazi_app/core/analysis/event_inference.dart';
import 'package:bazi_app/core/analysis/reasoning_report.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/rules/rule.dart';

List<Rule> loadSeedRules() {
  final json = jsonDecode(
      File('assets/rules/seed_rules.json').readAsStringSync()) as Map;
  return [
    for (final r in json['rules'] as List)
      Rule.fromJson(r as Map<String, dynamic>),
  ];
}

/// Guards against the engine drifting back into systematic pessimism.
///
/// Saved cases showed the app answering the negative option on 24 of 26 A/B
/// questions — including charts whose own candidates were entirely 吉. Part of
/// that was the prompt, but the engine had its own skew: 冲合刑害 land
/// disproportionately on things the 格局 wants (相神 average ~1.2 per chart
/// against ~0.4 忌神), so uncapped relationships made almost every year read
/// 偏凶.
///
/// Over many charts and one year, neither outcome should dominate. These
/// bounds are deliberately wide — the point is to catch a 2:1 skew, not to pin
/// an exact ratio.
void main() {
  final rules = loadSeedRules();

  ({int favourable, int adverse, int mixed, int leanPos, int leanNeg, int charts})
      survey() {
    var fav = 0, adv = 0, mix = 0, leanPos = 0, leanNeg = 0, charts = 0;
    for (var y = 1970; y <= 1998; y += 2) {
      for (final m in [2, 5, 8, 11]) {
        for (final d in [7, 21]) {
          for (final g in [Gender.male, Gender.female]) {
            final c = ChartService.compute(BirthInput(
              calendarType: CalendarType.solar,
              year: y,
              month: m,
              day: d,
              hour: 10,
              minute: 0,
              gender: g,
              location: '北京',
              longitude: 116.41,
            ));
            final decade = c.decades.firstWhere(
                (x) => x.startYear <= 2026 && x.endYear >= 2026,
                orElse: () => c.decades.last);
            final year = ChartService.flowYearsOf(c, decade).first;
            final report =
                ReasoningReport.build(c, rules, decade: decade, year: year);
            charts++;
            for (final e in report.events) {
              switch (e.polarity) {
                case EventPolarity.favourable:
                  fav++;
                case EventPolarity.adverse:
                  adv++;
                case EventPolarity.mixed:
                  mix++;
              }
            }
            switch (report.assessment.lean) {
              case '整体偏吉':
                leanPos++;
              case '整体偏凶':
                leanNeg++;
            }
          }
        }
      }
    }
    return (
      favourable: fav,
      adverse: adv,
      mixed: mix,
      leanPos: leanPos,
      leanNeg: leanNeg,
      charts: charts
    );
  }

  test('neither polarity dominates across a 240-chart grid', () {
    final s = survey();
    expect(s.charts, 240);
    expect(s.favourable, greaterThan(0));
    expect(s.adverse, greaterThan(0));

    final ratio = s.favourable / s.adverse;
    // ignore: avoid_print
    print('CALIB ratio=${ratio.toStringAsFixed(2)} 吉${s.favourable}/凶${s.adverse} '
        '偏吉${s.leanPos}/偏凶${s.leanNeg}');
    expect(ratio, greaterThan(0.6),
        reason: 'engine has drifted pessimistic: 吉${s.favourable}/凶${s.adverse}');
    expect(ratio, lessThan(1.7),
        reason: 'engine has drifted optimistic: 吉${s.favourable}/凶${s.adverse}');
  });

  test('per-chart verdicts are not one-sided', () {
    final s = survey();
    final total = s.leanPos + s.leanNeg;
    expect(total, greaterThan(100));
    final positiveShare = s.leanPos / total;
    expect(positiveShare, greaterThan(0.33),
        reason: 'most charts read 偏凶: 偏吉${s.leanPos}/偏凶${s.leanNeg}');
    expect(positiveShare, lessThan(0.67),
        reason: 'most charts read 偏吉: 偏吉${s.leanPos}/偏凶${s.leanNeg}');
  });

  test('the rule table can express both outcomes in comparable measure', () {
    // 去忌神则吉 was entirely missing: every release/damage/bind rule was
    // stance-blind, so the engine could not report 冲去忌神 as a good thing.
    var fav = 0, adv = 0;
    for (final subtypes in EventDomain.subtypes.values) {
      expect(subtypes, isNotEmpty);
    }
    final src = File('lib/core/analysis/event_inference.dart').readAsStringSync();
    fav = 'EventPolarity.favourable'.allMatches(src).length;
    adv = 'EventPolarity.adverse'.allMatches(src).length;
    expect(fav / adv, greaterThan(0.7),
        reason: 'favourable outcomes under-represented in the rule table');
  });

  test('ambient 克 does not manufacture events', () {
    // 克 is a standing relation, not an occurrence, and 天干相克 spans most of
    // the chart at once.
    final c = ChartService.compute(BirthInput(
      calendarType: CalendarType.solar,
      year: 1990,
      month: 1,
      day: 1,
      hour: 12,
      minute: 0,
      gender: Gender.male,
      location: '北京',
      longitude: 116.41,
    ));
    final decade =
        c.decades.firstWhere((d) => d.startYear <= 2026 && d.endYear >= 2026);
    final year =
        ChartService.flowYearsOf(c, decade).firstWhere((y) => y.year == 2026);
    final report =
        ReasoningReport.build(c, rules, decade: decade, year: year);

    final weakenTargets = {
      for (final a in report.activations)
        if (a.effect == ActivationEffect.weaken) a.target,
    };
    // The activation is still reported (it is real information) …
    expect(weakenTargets, isNotEmpty);
    // … but nothing downstream turned it into a life event.
    for (final e in report.events) {
      expect(e.basis.join(), isNot(contains('被克制')));
    }
  });

  test('relationships modify rather than outvote what the year brings', () {
    final c = ChartService.compute(BirthInput(
      calendarType: CalendarType.solar,
      year: 1990,
      month: 1,
      day: 1,
      hour: 12,
      minute: 0,
      gender: Gender.male,
      location: '北京',
      longitude: 116.41,
    ));
    final decade =
        c.decades.firstWhere((d) => d.startYear <= 2026 && d.endYear >= 2026);
    final year =
        ChartService.flowYearsOf(c, decade).firstWhere((y) => y.year == 2026);
    final report =
        ReasoningReport.build(c, rules, decade: decade, year: year);

    for (final layer in {for (final a in report.activations) a.layer}) {
      final interactions = report.activations
          .where((a) =>
              a.layer == layer &&
              a.effect != ActivationEffect.strengthen &&
              a.targetKind != '调候')
          .length;
      expect(interactions, lessThanOrEqualTo(5), reason: '$layer');
    }
  });
}
