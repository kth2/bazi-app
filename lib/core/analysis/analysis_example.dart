/// A real-world bazi analysis example (from the Weibo corpus).
/// Used both as style reference and as analogous-case material for the AI.
class AnalysisExample {
  final String id;
  final String? title;
  final String content; // the master's analysis text
  final String? feedback; // real-life outcome
  final String? qianZao; // 乾造/坤造 pillars if present
  final String? daYun;
  final Set<String> tags; // pattern keywords, curated where available

  /// True when [tags] came from the corpus file rather than a text scan.
  final bool curatedTags;

  const AnalysisExample({
    required this.id,
    this.title,
    required this.content,
    this.feedback,
    this.qianZao,
    this.daYun,
    required this.tags,
    this.curatedTags = false,
  });

  /// Pattern vocabulary scanned against title+content when an example has no
  /// curated `tags` field. The same vocabulary is produced by PatternDetector
  /// on the chart side, so matching is a plain tag-overlap score.
  ///
  /// Scanning is a fallback, not the primary source: plain substring matching
  /// over analysis prose cannot tell a structure the author is *asserting*
  /// from one they are dismissing, so a text arguing that 身强身弱 is the
  /// wrong lens gets tagged 身强 and 身弱 for its trouble.
  static const List<String> kPatternVocabulary = [
    // 格局
    '正官格', '七杀格', '偏印格', '印绶格', '正印格', '食神格', '伤官格',
    '正财格', '偏财格', '建禄格', '阳刃格', '月劫格', '三奇格', '杂气',
    // 特殊场景 / 成败关键
    '财破印', '印绶被财破', '伤官见官', '官杀混杂', '食神制杀', '食神坏官',
    '枭神夺食', '比劫合官', '比劫争财', '建禄用官', '月劫用官', '财多身弱',
    '杀印相生', '官印相生', '食伤生财', '拱金', '拱火', '三会', '三合',
    '争合', '相神', '败格', '身强', '身弱',
    // 胡一鸣法 terminology
    '正格', '变格', '从势格', '从弱格', '从旺格', '通关', '身旺',
    '身旺无泄', '食神克官杀', '食伤克官', '伤官生财', '食神生财',
    '财生官', '官生印', '比劫分财', '印克食伤', '连锁反应', '走完',
  ];

  factory AnalysisExample.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String?;
    final content = json['content'] as String? ?? '';
    final baziInfo = json['bazi_info'] as Map<String, dynamic>?;
    final curated = (json['tags'] as List?)?.cast<String>();
    final scanText = '${title ?? ''}\n$content';
    final tags = <String>{
      if (curated != null)
        ...curated
      else
        for (final kw in kPatternVocabulary)
          if (scanText.contains(kw)) kw,
    };
    // Normalize synonyms across corpora (子平真诠 vs 胡一鸣 terminology).
    if (tags.contains('印绶格')) tags.add('正印格');
    if (tags.contains('印绶被财破')) tags.add('财破印');
    if (tags.contains('身旺')) tags.add('身强');
    if (tags.contains('从势格') || tags.contains('从弱格')) {
      tags.addAll(['变格', '身弱']);
    }
    if (tags.contains('从旺格')) tags.addAll(['变格', '身强']);
    if (tags.contains('食神克官杀')) tags.add('食伤克官');

    return AnalysisExample(
      id: '${json['id']}',
      title: title,
      content: content,
      feedback: json['feedback'] as String?,
      qianZao: baziInfo?['qianzao'] as String? ?? baziInfo?['kunzao'] as String?,
      daYun: baziInfo?['dayun'] as String?,
      tags: tags,
      curatedTags: curated != null,
    );
  }
}
