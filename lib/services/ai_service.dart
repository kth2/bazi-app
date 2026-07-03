import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Supported providers. 'other' is any OpenAI-compatible endpoint the user
/// configures (base URL + key), future-proofing new services.
const kAiProviders = ['gemini', 'openrouter', 'agnes', 'other'];

const kAgnesBaseUrl = 'https://apihub.agnes-ai.com/v1';

/// AI provider settings. Every provider keeps its OWN key and model —
/// switching provider never overwrites another provider's key.
class AiSettings {
  final String provider; // gemini | openrouter | agnes | other
  final Map<String, String> keys; // provider -> api key
  final Map<String, String> models; // provider -> model id
  final String otherBaseUrl; // for 'other' (OpenAI-compatible)

  const AiSettings({
    required this.provider,
    required this.keys,
    required this.models,
    required this.otherBaseUrl,
  });

  static const Map<String, String> defaultModels = {
    'gemini': 'gemini-2.5-flash',
    'openrouter': 'openai/gpt-oss-120b:free',
    'agnes': 'agnes-2.0-flash',
    'other': '',
  };

  /// Static fallbacks when the live model list can't be fetched.
  static const Map<String, List<String>> fallbackModels = {
    'gemini': [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
    ],
    'openrouter': [
      'openai/gpt-oss-120b:free',
      'meta-llama/llama-3.3-70b-instruct:free',
      'qwen/qwen3-next-80b-a3b-instruct:free',
      'nvidia/nemotron-3-super-120b-a12b:free',
    ],
    'agnes': ['agnes-2.0-flash'],
    'other': [],
  };

  String get apiKey => keys[provider] ?? '';
  String get model {
    final m = models[provider] ?? '';
    return m.isNotEmpty ? m : (defaultModels[provider] ?? '');
  }

  bool get isConfigured => apiKey.trim().isNotEmpty;

  static Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    // One-time migration from the old single-key storage.
    final legacyKey = prefs.getString('ai_api_key');
    if (legacyKey != null) {
      final legacyProvider = prefs.getString('ai_provider') ?? 'gemini';
      final slot = kAiProviders.contains(legacyProvider) ? legacyProvider : 'gemini';
      if ((prefs.getString('ai_key_$slot') ?? '').isEmpty) {
        await prefs.setString('ai_key_$slot', legacyKey);
        final legacyModel = prefs.getString('ai_model');
        if (legacyModel != null && legacyModel.isNotEmpty) {
          await prefs.setString('ai_model_$slot', legacyModel);
        }
      }
      await prefs.remove('ai_api_key');
      await prefs.remove('ai_model');
    }

    final provider = prefs.getString('ai_provider') ?? 'gemini';
    return AiSettings(
      provider: kAiProviders.contains(provider) ? provider : 'gemini',
      keys: {
        for (final p in kAiProviders) p: prefs.getString('ai_key_$p') ?? '',
      },
      models: {
        for (final p in kAiProviders)
          p: prefs.getString('ai_model_$p') ?? defaultModels[p] ?? '',
      },
      otherBaseUrl: prefs.getString('ai_other_base_url') ?? '',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_provider', provider);
    for (final p in kAiProviders) {
      await prefs.setString('ai_key_$p', keys[p] ?? '');
      await prefs.setString('ai_model_$p', models[p] ?? '');
    }
    await prefs.setString('ai_other_base_url', otherBaseUrl);
  }

  AiSettings copyWith({
    String? provider,
    Map<String, String>? keys,
    Map<String, String>? models,
    String? otherBaseUrl,
  }) =>
      AiSettings(
        provider: provider ?? this.provider,
        keys: keys ?? this.keys,
        models: models ?? this.models,
        otherBaseUrl: otherBaseUrl ?? this.otherBaseUrl,
      );
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

/// Single entry point for LLM completion + model listing across providers.
class AiService {
  final http.Client _client;

  AiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> complete(String prompt, AiSettings settings) async {
    if (!settings.isConfigured) {
      throw const AiException('尚未设置 API Key，请先在设置中填入。');
    }
    switch (settings.provider) {
      case 'openrouter':
        return _openAiCompatible(
            'https://openrouter.ai/api/v1', settings.apiKey, settings.model, prompt,
            providerName: 'OpenRouter');
      case 'agnes':
        return _openAiCompatible(
            kAgnesBaseUrl, settings.apiKey, settings.model, prompt,
            providerName: 'Agnes');
      case 'other':
        final base = _normalizeBase(settings.otherBaseUrl);
        if (base.isEmpty) {
          throw const AiException('自定义服务尚未填写 API 地址（Base URL）。');
        }
        return _openAiCompatible(base, settings.apiKey, settings.model, prompt,
            providerName: '自定义服务');
      default:
        return _gemini(prompt, settings);
    }
  }

  /// List available models for a provider. For OpenRouter only :free models
  /// are returned (paid ones would surprise users expecting a free app).
  Future<List<String>> listModels(AiSettings settings) async {
    try {
      switch (settings.provider) {
        case 'gemini':
          return await _listGemini(settings.apiKey);
        case 'openrouter':
          return await _listOpenAiCompatible(
            'https://openrouter.ai/api/v1',
            apiKey: null, // public endpoint
            filter: (id) => id.endsWith(':free'),
          );
        case 'agnes':
          return await _listOpenAiCompatible(kAgnesBaseUrl,
              apiKey: settings.apiKey);
        case 'other':
          final base = _normalizeBase(settings.otherBaseUrl);
          if (base.isEmpty) return const [];
          return await _listOpenAiCompatible(base, apiKey: settings.apiKey);
      }
    } catch (_) {
      // fall through to static fallback
    }
    return AiSettings.fallbackModels[settings.provider] ?? const [];
  }

  // -------------------------------------------------------------------
  // Gemini
  // -------------------------------------------------------------------

  Future<String> _gemini(String prompt, AiSettings s) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${s.model}:generateContent');
    final resp = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': s.apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (resp.statusCode != 200) {
      throw AiException('Gemini 请求失败 (${resp.statusCode})：'
          '${_shorten(utf8.decode(resp.bodyBytes))}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final text = (((json['candidates'] as List?)?.firstOrNull
            as Map<String, dynamic>?)?['content']
        as Map<String, dynamic>?)?['parts']?[0]?['text'] as String?;
    if (text == null || text.isEmpty) {
      throw const AiException('Gemini 返回为空，可能触发安全过滤或额度用尽。');
    }
    return text;
  }

  Future<List<String>> _listGemini(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      throw const AiException('需要 API Key 才能获取模型列表');
    }
    final resp = await _client.get(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?pageSize=100'),
      headers: {'x-goog-api-key': apiKey},
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw AiException('获取模型列表失败 (${resp.statusCode})');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final models = <String>[
      for (final m in (json['models'] as List? ?? []))
        if (((m as Map<String, dynamic>)['supportedGenerationMethods'] as List?)
                ?.contains('generateContent') ??
            false)
          (m['name'] as String).replaceFirst('models/', ''),
    ];
    // Chat-oriented gemini models first.
    models.sort((a, b) {
      final ag = a.startsWith('gemini') ? 0 : 1;
      final bg = b.startsWith('gemini') ? 0 : 1;
      return ag != bg ? ag - bg : b.compareTo(a);
    });
    return models;
  }

  // -------------------------------------------------------------------
  // OpenAI-compatible (OpenRouter / Agnes / Other)
  // -------------------------------------------------------------------

  Future<String> _openAiCompatible(
    String baseUrl,
    String apiKey,
    String model,
    String prompt, {
    required String providerName,
  }) async {
    if (model.trim().isEmpty) {
      throw AiException('$providerName 尚未选择模型。');
    }
    final resp = await _client
        .post(
          Uri.parse('$baseUrl/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (resp.statusCode != 200) {
      throw AiException('$providerName 请求失败 (${resp.statusCode})：'
          '${_shorten(utf8.decode(resp.bodyBytes))}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final text = ((json['choices'] as List?)?.firstOrNull
        as Map<String, dynamic>?)?['message']?['content'] as String?;
    if (text == null || text.isEmpty) {
      throw AiException('$providerName 返回为空，模型可能暂不可用，请换一个模型试试。');
    }
    return text;
  }

  Future<List<String>> _listOpenAiCompatible(
    String baseUrl, {
    String? apiKey,
    bool Function(String id)? filter,
  }) async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/models'),
      headers: {
        if (apiKey != null && apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      },
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw AiException('获取模型列表失败 (${resp.statusCode})');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final ids = <String>[
      for (final m in (json['data'] as List? ?? []))
        (m as Map<String, dynamic>)['id'] as String,
    ];
    final result = filter == null ? ids : ids.where(filter).toList();
    result.sort();
    if (result.isEmpty) {
      throw const AiException('模型列表为空');
    }
    return result;
  }

  static String _normalizeBase(String url) {
    var u = url.trim();
    if (u.isEmpty) return '';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (u.endsWith('/chat/completions')) {
      u = u.substring(0, u.length - '/chat/completions'.length);
    }
    return u;
  }

  static String _shorten(String s) => s.length > 200 ? s.substring(0, 200) : s;
}
