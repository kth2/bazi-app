import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/natal_structure.dart';
import 'package:bazi_app/core/analysis/pattern_detector.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';

/// Four 格局 rules the engine had wrong, each found through a judged case
/// whose feedback carried the correct reading and its classical source.
///
/// These are corrections to *how the engine applies the classics*, checked
/// against the source each cites — not weights tuned to outcomes.
NatalStructure _resolve(int y, int m, int d, int h, int min, Gender g,
    String bazi) {
  final c = ChartService.compute(BirthInput(
    calendarType: CalendarType.solar,
    year: y,
    month: m,
    day: d,
    hour: h,
    minute: min,
    gender: g,
    location: '北京',
    longitude: 116.41,
  ));
  expect(c.baziString, bazi, reason: 'birth data no longer gives this chart');
  return NatalStructureResolver.resolve(c, PatternDetector.detect(c));
}

void main() {
  test('杂气月令本气不透，取透出之中余气为格（甲午 甲戌 己未 丁卯）', () {
    // 《子平真诠·论杂气如何取用》：四墓者，冲气也……透干取之。
    // 戌藏戊辛丁；戊（劫财）不透，丁（偏印）透于时干 → 杂气偏印格。
    // 反馈：2008 年升任厅长，官印双全。
    final ns = _resolve(1954, 10, 30, 6, 14, Gender.male, '甲午 甲戌 己未 丁卯');
    expect(ns.pattern.geJu, '偏印格');
    expect(ns.pattern.yongShen, contains('杂气'));
    expect(ns.pattern.yongShen, contains('丁'));
  });

  test('年月官杀相连只论杀，不作混杂破格（戊午 己未 壬辰 癸卯）', () {
    // 《神峰通考·官煞去留》：官杀相连只论杀，官杀各分为混杂。
    // 年干戊七杀、月干己正官相连 → 统一论七杀格，不以「七杀透干克破格神」论破。
    final ns = _resolve(1978, 7, 29, 6, 14, Gender.female, '戊午 己未 壬辰 癸卯');
    expect(ns.pattern.geJu, '七杀格');
    expect(ns.pattern.yongShen, contains('官杀相连'));
    expect(ns.poFactors.join(), isNot(contains('克破格神')));
    expect(ns.pattern.specialScenarios, isNot(contains('官杀混杂')));
  });

  test('七杀格时透正官，官来混杀不能取清则破格（甲戌 丙寅 戊子 乙卯）', () {
    // 七杀格最怕正官来混；月透丙枭可化杀，但时柱乙卯正官与寅中甲杀各分，
    // 无食伤去官，无从取清。反馈：工作不稳，处处受排挤。
    final ns = _resolve(1994, 3, 3, 6, 14, Gender.male, '甲戌 丙寅 戊子 乙卯');
    expect(ns.pattern.geJu, '七杀格');
    expect(ns.status, GeJuStatus.po);
    expect(ns.poFactors.join(), contains('官来混杀'));
  });

  test('财格佩印而财印紧贴相并，用相失和则破格（戊辰 甲寅 辛亥 乙未）', () {
    // 《子平真诠·论财》：有财格佩印者……然财印不宜相并。
    // 月干甲财紧贴年干戊印而克之，财来坏印。反馈：戊午运印运反败落。
    final ns = _resolve(1988, 2, 26, 14, 14, Gender.male, '戊辰 甲寅 辛亥 乙未');
    expect(ns.pattern.geJu, '正财格');
    expect(ns.status, isNot(GeJuStatus.cheng));
    expect(ns.poFactors.join(), contains('财印相并'));
  });

  test('官杀相连之外的官杀两透仍是混杂', () {
    // 相连只限年月；月时各分依旧论混杂。甲戌 丙寅 戊子 乙卯 的官在时、
    // 杀在月令，上一条已断破格；这里确认场景标签也还在。
    final ns = _resolve(1994, 3, 3, 6, 14, Gender.male, '甲戌 丙寅 戊子 乙卯');
    expect(ns.pattern.specialScenarios, contains('官杀混杂'));
  });
}
