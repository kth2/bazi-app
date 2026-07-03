import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AI provider settings, persisted locally (the user brings their own
/// free-tier API key — no backend).
class AiSettings {
  final String provider; // 'gemini' | 'openrouter'
  final String apiKey;
  final String model;

  const AiSettings({
    required this.provider,
    required this.apiKey,
    required this.model,
  });

  static const defaultGeminiModel = 'gemini-2.0-flash';
  static const defaultOpenRouterModel = 'deepseek/deepseek-chat-v3-0324:free';

  bool get isConfigured => apiKey.trim().isNotEmpty;

  static Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('ai_provider') ?? 'gemini';
    return AiSettings(
      provider: provider,
      apiKey: prefs.getString('ai_api_key') ?? '',
      model: prefs.getString('ai_model') ??
          (provider == 'gemini' ? defaultGeminiModel : defaultOpenRouterModel),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_provider', provider);
    await prefs.setString('ai_api_key', apiKey);
    await prefs.setString('ai_model', model);
  }
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

/// Single entry point for LLM completion across providers.
class AiService {
  final http.Client _client;

  AiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> complete(String prompt, AiSettings settings) async {
    if (!settings.isConfigured) {
      throw const AiException('尚未设置 API Key，请先在设置中填入。');
    }
    switch (settings.provider) {
      case 'openrouter':
        return _openRouter(prompt, settings);
      default:
        return _gemini(prompt, settings);
    }
  }

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

  Future<String> _openRouter(String prompt, AiSettings s) async {
    final resp = await _client
        .post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${s.apiKey}',
          },
          body: jsonEncode({
            'model': s.model,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (resp.statusCode != 200) {
      throw AiException('OpenRouter 请求失败 (${resp.statusCode})：'
          '${_shorten(utf8.decode(resp.bodyBytes))}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final text = ((json['choices'] as List?)?.firstOrNull
        as Map<String, dynamic>?)?['message']?['content'] as String?;
    if (text == null || text.isEmpty) {
      throw const AiException('OpenRouter 返回为空，可能额度用尽。');
    }
    return text;
  }

  static String _shorten(String s) => s.length > 200 ? s.substring(0, 200) : s;
}
