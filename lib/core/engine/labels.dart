import 'package:bazi_core/bazi_core.dart' as bc;

/// Chinese display labels for bazi_core enums.
const Map<bc.ShiShen, String> kShiShenLabels = {
  bc.ShiShen.biJian: '比肩',
  bc.ShiShen.jieCai: '劫财',
  bc.ShiShen.shiShen: '食神',
  bc.ShiShen.shangGuan: '伤官',
  bc.ShiShen.pianCai: '偏财',
  bc.ShiShen.zhengCai: '正财',
  bc.ShiShen.qiSha: '七杀',
  bc.ShiShen.zhengGuan: '正官',
  bc.ShiShen.pianYin: '偏印',
  bc.ShiShen.zhengYin: '正印',
};

const Map<bc.WuXing, String> kWuXingLabels = {
  bc.WuXing.wood: '木',
  bc.WuXing.fire: '火',
  bc.WuXing.earth: '土',
  bc.WuXing.metal: '金',
  bc.WuXing.water: '水',
};

const Map<bc.TwelveLifeStage, String> kLifeStageLabels = {
  bc.TwelveLifeStage.zhangSheng: '长生',
  bc.TwelveLifeStage.muYu: '沐浴',
  bc.TwelveLifeStage.guanDai: '冠带',
  bc.TwelveLifeStage.linGuan: '临官',
  bc.TwelveLifeStage.diWang: '帝旺',
  bc.TwelveLifeStage.shuai: '衰',
  bc.TwelveLifeStage.bing: '病',
  bc.TwelveLifeStage.si: '死',
  bc.TwelveLifeStage.mu: '墓',
  bc.TwelveLifeStage.jue: '绝',
  bc.TwelveLifeStage.tai: '胎',
  bc.TwelveLifeStage.yang: '养',
};

const Map<bc.BaziInteraction, String> kInteractionLabels = {
  bc.BaziInteraction.stemCombination: '天干五合',
  bc.BaziInteraction.stemClash: '天干相冲',
  bc.BaziInteraction.stemRestraint: '天干相克',
  bc.BaziInteraction.branchCombination: '地支六合',
  bc.BaziInteraction.branchClash: '地支六冲',
  bc.BaziInteraction.branchHarm: '地支六害',
  bc.BaziInteraction.branchDestruction: '地支六破',
  bc.BaziInteraction.branchTriplePunishment: '三刑全',
  bc.BaziInteraction.branchPunishment: '相刑',
  bc.BaziInteraction.branchSelfPunishment: '自刑',
  bc.BaziInteraction.branchTripleCombination: '三合局',
  bc.BaziInteraction.branchTripleDirection: '三会局',
  bc.BaziInteraction.branchHalfCombination: '半合',
  bc.BaziInteraction.branchArchingCombination: '拱合',
  bc.BaziInteraction.branchHiddenCombination: '暗合',
  bc.BaziInteraction.branchSeverance: '相绝',
};

const Map<bc.PillarType, String> kPillarTypeLabels = {
  bc.PillarType.year: '年柱',
  bc.PillarType.month: '月柱',
  bc.PillarType.day: '日柱',
  bc.PillarType.hour: '时柱',
  bc.PillarType.mingGong: '命宫',
  bc.PillarType.shenGong: '身宫',
  bc.PillarType.taiYuan: '胎元',
  bc.PillarType.taiXi: '胎息',
  bc.PillarType.decade: '大运',
  bc.PillarType.flowYear: '流年',
  bc.PillarType.flowMonth: '流月',
  bc.PillarType.flowDay: '流日',
  bc.PillarType.flowHour: '流时',
};
