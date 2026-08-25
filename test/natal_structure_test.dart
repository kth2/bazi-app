import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/core/analysis/natal_structure.dart';
import 'package:bazi_app/core/analysis/pattern_detector.dart';
import 'package:bazi_app/core/engine/chart_service.dart';
import 'package:bazi_app/core/models/birth_input.dart';
import 'package:bazi_app/core/models/chart_result.dart';

ChartResult _chart(int y, int m, int d, int h) =>
    ChartService.compute(BirthInput(
      calendarType: CalendarType.solar,
      year: y,
      month: m,
      day: d,
      hour: h,
      minute: 0,
      gender: Gender.male,
      location: '北京',
      longitude: 116.41,
    ));

NatalStructure _resolve(int y, int m, int d, int h) {
  final c = _chart(y, m, d, h);
  return NatalStructureResolver.resolve(c, PatternDetector.detect(c));
}

void main() {
  group('格局成败 is judged, not assumed', () {
    test('伤官透干通根破正官格，印星配印制伤为救', () {
      // 己巳 丙子 丙寅 甲午: 己土伤官透年干、通根午中己土，克月令癸正官.
      final ns = _resolve(1990, 1, 1, 12);
      expect(ns.pattern.geJu, '正官格');
      expect(ns.status, GeJuStatus.jiuYing);
      expect(ns.poFactors.join(), contains('伤官'));
      expect(ns.jiShen, contains('伤官'));
      expect(ns.jiuFactors.join(), contains('配印制伤'));
      expect(ns.xiangShen, contains('印星'));
      expect(ns.summary, contains('破而有救'));
    });

    test('官印财俱全、无物破格 → 成格', () {
      // 己丑 癸酉 甲子 己巳.
      final ns = _resolve(1949, 10, 1, 10);
      expect(ns.pattern.geJu, '正官格');
      expect(ns.status, GeJuStatus.cheng);
      expect(ns.poFactors, isEmpty);
      expect(ns.xiangShen, containsAll(['财星', '印星']));
    });

    test('七杀格财透助杀为破，印绶化杀为救', () {
      // 戊辰 戊午 辛丑 乙未: 乙木偏财透时干生午中丁火七杀.
      final ns = _resolve(1988, 6, 15, 14);
      expect(ns.pattern.geJu, '七杀格');
      expect(ns.status, GeJuStatus.jiuYing);
      expect(ns.jiShen, contains('财星'));
      expect(ns.jiuFactors.join(), contains('印绶化杀'));
    });
  });

  group('presence / strength / operability are distinguished', () {
    test('a 十神 seen only as 余气藏干 exists but is not operative', () {
      final ns = _resolve(1949, 10, 1, 10);
      final shiShang = ns.presence['食伤']!;
      expect(shiShang.exists, isTrue);
      expect(shiShang.isOperative, isFalse);
      expect(shiShang.level, '仅见其气');
    });

    test('透干通根 is the operative case', () {
      final ns = _resolve(1990, 1, 1, 12);
      final shangGuan = ns.presence['伤官']!;
      expect(shangGuan.transparent, greaterThan(0));
      expect(shangGuan.rooted, isTrue);
      expect(shangGuan.isOperative, isTrue);
      expect(shangGuan.level, '有力可用');
    });

    test('一个十神不继承整组的力量', () {
      // 己丑 癸酉 甲子 己巳: 官杀 group is strong, but the lone hidden 庚
      // 七杀 must not inherit all of it and fake a 官杀混杂 破格.
      final ns = _resolve(1949, 10, 1, 10);
      final group = ns.presence['官杀']!;
      final qiSha = ns.presence['七杀']!;
      final zhengGuan = ns.presence['正官']!;
      expect(qiSha.strength, lessThan(group.strength));
      expect(zhengGuan.strength, greaterThan(qiSha.strength));
      expect(qiSha.isOperative, isFalse);
      expect(ns.poFactors.join(), isNot(contains('七杀')));
    });
  });

  group('太过与不及俱为病', () {
    test('印重身旺取食伤泄秀，而非再取官杀生印', () {
      // 乙卯 戊寅 丁酉 甲辰: 印星 62%.
      final ns = _resolve(1975, 2, 20, 9);
      expect(ns.pattern.geJu, '正印格');
      expect(ns.presence['印星']!.strength, greaterThan(40));
      expect(ns.xiangShen, contains('食伤'));
      expect(ns.chengFactors.join(), contains('太旺'));
      expect(ns.status, GeJuStatus.cheng);
    });
  });

  group('调候', () {
    test('冬生取火暖局', () {
      final ns = _resolve(1990, 1, 1, 12); // 子月
      expect(ns.tiaoHou.climate, '寒');
      expect(ns.tiaoHou.needed, contains('火'));
    });

    test('冬生水旺无火 → 调候不济，并提示戊土制水', () {
      final ns = _resolve(1981, 12, 11, 1); // 辛酉 庚子 癸亥 壬子
      expect(ns.tiaoHou.climate, '寒');
      expect(ns.tiaoHou.satisfied, isFalse);
      expect(ns.tiaoHou.needed, containsAll(['火', '土']));
      expect(ns.tiaoHou.note, contains('制水'));
    });

    test('夏生取水润局', () {
      final ns = _resolve(1988, 6, 15, 14); // 午月
      expect(ns.tiaoHou.climate, '暖燥');
      expect(ns.tiaoHou.needed, contains('水'));
      expect(ns.tiaoHou.satisfied, isFalse);
    });
  });

  group('变格 gets a 从格 reading, not a 正格 one', () {
    test('从旺格: 用神顺势，忌神为财官', () {
      final ns = _resolve(1981, 12, 11, 1);
      expect(ns.pattern.isBianGe, isTrue);
      expect(ns.jiShen, containsAll(['财星', '官杀']));
      expect(ns.xiangShen, contains('比劫'));
      expect(ns.status, GeJuStatus.cheng);
    });

    test('从杀格: 忌神为印比', () {
      final ns = _resolve(1981, 3, 11, 7);
      expect(ns.pattern.geJu, '从杀格');
      expect(ns.jiShen, containsAll(['印星', '比劫']));
      expect(ns.xiangShen, contains('官杀'));
    });
  });

  test('every 正格 the detector can emit has a 顺逆用 spec', () {
    // Guards against a 格局 being added to PatternDetector without the
    // corresponding 成败 rules, which would silently yield 格局待定.
    const emitted = [
      '正官格', '七杀格', '正印格', '偏印格', '食神格', '伤官格',
      '正财格', '偏财格', '建禄格', '阳刃格', '月劫格',
    ];
    for (final ge in emitted) {
      final ns = NatalStructureResolver.resolve(
        _chart(1990, 1, 1, 12),
        ChartPattern(
          geJu: ge,
          yongShen: 'x',
          specialScenarios: const [],
          tags: {ge},
        ),
      );
      expect(ns.status, isNot(GeJuStatus.unknown),
          reason: '$ge has no _GeJuSpec entry');
    }
  });
}
