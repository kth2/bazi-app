import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bazi_app/core/analysis/bazi_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI cache keys are engine-versioned', () {
    test('cache keys carry the current engine version', () {
      // Guards against a refactor that changes reasoning but silently keeps
      // serving text produced by the previous engine.
      expect(BaziAnalysisService.kEngineVersion, greaterThanOrEqualTo(2));
    });

    test('stale-version and legacy unversioned entries are purged', () async {
      final v = BaziAnalysisService.kEngineVersion;
      SharedPreferences.setMockInitialValues({
        // Legacy, written before keys were versioned.
        'ai_cache_甲子 甲子 甲子 甲子_male_整体命局': 'legacy',
        'ai_qa_甲子 甲子 甲子 甲子_male_整体命局_123': 'legacy-qa',
        // An older engine version.
        'ai_cache_v1_甲子 甲子 甲子 甲子_male_整体命局': 'v1',
        // Current version — must survive.
        'ai_cache_v${v}_甲子 甲子 甲子 甲子_male_整体命局': 'current',
        'ai_qa_v${v}_甲子 甲子 甲子 甲子_male_整体命局_123': 'current-qa',
        // Unrelated app state — must never be touched.
        'gemini_api_key': 'secret',
        'saved_charts': '[]',
      });
      final prefs = await SharedPreferences.getInstance();

      await BaziAnalysisService.purgeStaleCachesForTesting(prefs);

      expect(prefs.getString('ai_cache_甲子 甲子 甲子 甲子_male_整体命局'), isNull);
      expect(prefs.getString('ai_qa_甲子 甲子 甲子 甲子_male_整体命局_123'), isNull);
      expect(prefs.getString('ai_cache_v1_甲子 甲子 甲子 甲子_male_整体命局'), isNull);
      expect(
          prefs.getString('ai_cache_v${v}_甲子 甲子 甲子 甲子_male_整体命局'), 'current');
      expect(prefs.getString('ai_qa_v${v}_甲子 甲子 甲子 甲子_male_整体命局_123'),
          'current-qa');
      expect(prefs.getString('gemini_api_key'), 'secret');
      expect(prefs.getString('saved_charts'), '[]');
    });
  });
}
