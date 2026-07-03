import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bazi_app/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keys are stored per provider and never overwrite each other', () async {
    SharedPreferences.setMockInitialValues({});

    var s = await AiSettings.load();
    s = s.copyWith(
      provider: 'gemini',
      keys: {...s.keys, 'gemini': 'GEMINI_KEY'},
      models: {...s.models, 'gemini': 'gemini-2.5-flash'},
    );
    await s.save();

    // Switch to openrouter with its own key.
    var s2 = await AiSettings.load();
    s2 = s2.copyWith(
      provider: 'openrouter',
      keys: {...s2.keys, 'openrouter': 'OPENROUTER_KEY'},
      models: {...s2.models, 'openrouter': 'openai/gpt-oss-120b:free'},
    );
    await s2.save();

    final s3 = await AiSettings.load();
    expect(s3.provider, 'openrouter');
    expect(s3.apiKey, 'OPENROUTER_KEY');
    expect(s3.keys['gemini'], 'GEMINI_KEY'); // untouched!
    expect(s3.models['gemini'], 'gemini-2.5-flash');

    // Switching back to gemini restores its key.
    final back = s3.copyWith(provider: 'gemini');
    await back.save();
    final s4 = await AiSettings.load();
    expect(s4.apiKey, 'GEMINI_KEY');
  });

  test('legacy single-key storage migrates into the active provider slot',
      () async {
    SharedPreferences.setMockInitialValues({
      'ai_provider': 'gemini',
      'ai_api_key': 'OLD_KEY',
      'ai_model': 'gemini-2.0-flash',
    });

    final s = await AiSettings.load();
    expect(s.provider, 'gemini');
    expect(s.keys['gemini'], 'OLD_KEY');
    expect(s.models['gemini'], 'gemini-2.0-flash');

    // Legacy keys removed.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai_api_key'), isNull);
  });

  test('agnes and other providers have separate slots and defaults', () async {
    SharedPreferences.setMockInitialValues({});
    var s = await AiSettings.load();
    s = s.copyWith(
      provider: 'agnes',
      keys: {...s.keys, 'agnes': 'AGNES_KEY'},
      otherBaseUrl: 'https://api.example.com/v1/',
    );
    await s.save();

    final r = await AiSettings.load();
    expect(r.provider, 'agnes');
    expect(r.apiKey, 'AGNES_KEY');
    expect(r.model, 'agnes-2.0-flash'); // default model
    expect(r.otherBaseUrl, 'https://api.example.com/v1/');
    expect(r.keys['gemini'], isEmpty);
  });

  test('model falls back to provider default when unset', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await AiSettings.load();
    expect(s.copyWith(provider: 'gemini').model, 'gemini-2.5-flash');
    expect(s.copyWith(provider: 'openrouter').model,
        'openai/gpt-oss-120b:free');
    expect(s.copyWith(provider: 'agnes').model, 'agnes-2.0-flash');
  });

  test('fallback model lists exist for every provider', () {
    for (final p in kAiProviders) {
      expect(AiSettings.fallbackModels.containsKey(p), isTrue, reason: p);
    }
    // OpenRouter fallbacks must all be :free.
    for (final m in AiSettings.fallbackModels['openrouter']!) {
      expect(m, endsWith(':free'));
    }
  });
}
