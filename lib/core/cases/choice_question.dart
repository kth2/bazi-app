/// Reads an A/B 选择题 and the AI's answer to it, so the journal can tell
/// *which way* a verdict leaned, not only whether it was right.
///
/// This exists because 应验率 alone could not explain the numbers. Across the
/// first 76 judged A/B questions the app scored 58% while choosing the plainer
/// option 94% of the time, then 59% while choosing each side about equally,
/// then 17% while choosing the brighter option every time. In every period
/// the score was what a coin weighted by that preference would have scored:
/// the rate was tracking the lean, not the chart. Seeing that needs the lean
/// recorded per question, and nobody is going to tag it by hand.
///
/// Deliberately lexical and conservative. It answers only for exactly two
/// options, a clearly stated pick, and options whose wording differs in
/// fortune; everything else is [OptionLean.none] and can be set by hand.
library;

/// Whether the option the AI picked was the brighter or the plainer of the
/// two offered.
enum OptionLean {
  /// 发财 over 破财, 千万 over 温饱, 升职 over 降职.
  brighter,

  /// The other way round.
  plainer,

  /// Not a two-way choice between better and worse — or the answer could not
  /// be read.
  none,
}

extension OptionLeanX on OptionLean {
  String get label => switch (this) {
        OptionLean.brighter => '较好一项',
        OptionLean.plainer => '较平一项',
        OptionLean.none => '不适用',
      };
}

/// What a two-way question is about. The bias differs by kind: 层次 questions
/// are written with one grand option against one ordinary one, and grand
/// outcomes are rare; 流年吉凶 questions have no such asymmetry.
enum QuestionTopic {
  /// 某年破财/发财、吉/凶.
  yearFortune,

  /// 层次、财富、职级、职业.
  level,

  /// 升职/车祸、奖学金/住院 and the like.
  event,
}

extension QuestionTopicX on QuestionTopic {
  String get label => switch (this) {
        QuestionTopic.yearFortune => '流年吉凶',
        QuestionTopic.level => '层次财富',
        QuestionTopic.event => '具体事件',
      };
}

class ChoiceOption {
  final String key;
  final String text;
  const ChoiceOption(this.key, this.text);
}

/// A parsed two-option question with the AI's pick.
class ChoiceReading {
  final List<ChoiceOption> options;
  final String picked;
  final OptionLean lean;
  final QuestionTopic topic;

  const ChoiceReading({
    required this.options,
    required this.picked,
    required this.lean,
    required this.topic,
  });
}

class ChoiceQuestion {
  ChoiceQuestion._();

  /// Signed fortune words. Matched longest first and consumed as they match,
  /// so 不稳定 is not also read as 稳定, nor 没嫁成富二代 as 富.
  ///
  /// The weights only have to *order* two options, not measure them.
  static const Map<String, int> kLexicon = {
    // brighter
    '发财': 3, '亿': 3, '千万': 3, '厅': 3,
    '百万': 2, '富': 2, '老板': 2, '老总': 2, '处级': 2, '干部': 2,
    '升职': 2, '升任': 2, '加薪': 2, '奖学金': 2, '中奖': 2, '考取': 2,
    '高薪': 2, '吉': 2,
    '科级': 1, '经理': 1, '中产': 1, '稳定': 1, '有成': 1, '贵': 1,
    '优异': 1,
    // plainer
    '没嫁成': -4,
    '破财': -3, '负债': -3, '车祸': -3, '去世': -3, '去逝': -3, '死': -3,
    '牢狱': -3, '入狱': -3, '犯罪': -3, '癌': -3, '白血病': -3,
    '凶': -2, '离婚': -2, '住院': -2, '生病': -2, '赌博': -2, '失信': -2,
    '辍学': -2, '工人': -2, '打工': -2, '温饱': -2, '种地': -2, '穷': -2,
    '合同工': -2, '降职': -2, '出轨': -2, '不稳定': -2, '小商贩': -2,
    '卖菜': -2, '三无': -2, '不务正业': -2, '小三': -2, '灾': -2,
    '月薪': -1, '普通': -1, '常人': -1, '小康': -1, '较低': -1, '司机': -1,
    '维修': -1, '木工': -1, '未婚': -1, '摆摊': -1,
  };

  static final List<String> _byLength = kLexicon.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  static int scoreOf(String text) {
    var rest = text;
    var score = 0;
    for (final word in _byLength) {
      var i = rest.indexOf(word);
      while (i >= 0) {
        score += kLexicon[word]!;
        rest = rest.replaceRange(i, i + word.length, ' ');
        i = rest.indexOf(word);
      }
    }
    return score;
  }

  /// `A、` `A.` `A ` `B,` or a letter run straight into CJK text (`A戊戌年`),
  /// at the start of the text or after whitespace/punctuation.
  static final RegExp _optionMarker = RegExp(
      r'(?:^|(?<=[\s:：，,。；;]))([A-DＡ-Ｄ])(?:[、.．,，:：)）\s]+|(?=[一-鿿0-9]))');

  static List<ChoiceOption> optionsOf(String question) {
    final marks = _optionMarker.allMatches(question).toList();
    final out = <ChoiceOption>[];
    for (var i = 0; i < marks.length; i++) {
      final end = i + 1 < marks.length ? marks[i + 1].start : question.length;
      final text = question.substring(marks[i].end, end).trim();
      out.add(ChoiceOption(_ascii(marks[i].group(1)!), text));
    }
    return out;
  }

  static final RegExp _pick = RegExp(
      r'答案\s*[:：]\s*[*\s]*(?:第|选项)?\s*([A-DＡ-Ｄ])(?![A-Za-z])');

  static final RegExp _pickAlt = RegExp(r'选项\s*([A-DＡ-Ｄ])\s*更符合');

  /// The single option letter the answer commits to, or null if it names
  /// none or more than one.
  static String? pickOf(String answer) {
    final picks = {
      for (final m in _pick.allMatches(answer)) _ascii(m.group(1)!),
    };
    if (picks.isEmpty) {
      final alt = _pickAlt.firstMatch(answer);
      return alt == null ? null : _ascii(alt.group(1)!);
    }
    return picks.length == 1 ? picks.first : null;
  }

  static String _ascii(String letter) {
    final c = letter.codeUnitAt(0);
    return c >= 0xFF21 ? String.fromCharCode(c - 0xFF21 + 0x41) : letter;
  }

  /// Null when this is not a readable two-way choice.
  static ChoiceReading? read(String question, String answer) {
    final options = optionsOf(question);
    if (options.length != 2) return null;
    if (options[0].key == options[1].key) return null;
    final picked = pickOf(answer);
    if (picked == null) return null;
    final chosen = options.where((o) => o.key == picked).toList();
    if (chosen.length != 1) return null;
    final other = options.firstWhere((o) => o.key != picked);

    final a = scoreOf(chosen.single.text);
    final b = scoreOf(other.text);
    final lean = a == b
        ? OptionLean.none
        : (a > b ? OptionLean.brighter : OptionLean.plainer);

    return ChoiceReading(
      options: options,
      picked: picked,
      lean: lean,
      topic: topicOf(options),
    );
  }

  static final RegExp _yearWords = RegExp(r'破财|发财|吉|凶');
  static final RegExp _levelWords = RegExp(
      r'亿|千万|百万|万|年薪|月薪|年入|身家|身价|富|老板|老总|级|干部|工人|打工|'
      r'温饱|小康|中产|常人|普通|层次|职业');

  static QuestionTopic topicOf(List<ChoiceOption> options) {
    if (options.every((o) => _yearWords.hasMatch(o.text))) {
      return QuestionTopic.yearFortune;
    }
    if (options.any((o) => _levelWords.hasMatch(o.text))) {
      return QuestionTopic.level;
    }
    return QuestionTopic.event;
  }
}
