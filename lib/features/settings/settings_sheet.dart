import 'package:flutter/material.dart';

import '../../services/ai_service.dart';
import '../../theme.dart';

/// Bottom sheet for AI provider + API key configuration.
/// Each provider keeps its own key/model; keys are stored locally only.
Future<void> showAiSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AiSettingsSheet(),
  );
}

class _AiSettingsSheet extends StatefulWidget {
  const _AiSettingsSheet();

  @override
  State<_AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<_AiSettingsSheet> {
  String _provider = 'gemini';
  final Map<String, String> _keys = {for (final p in kAiProviders) p: ''};
  final Map<String, String> _models = {for (final p in kAiProviders) p: ''};
  String _otherBaseUrl = '';

  final _keyController = TextEditingController();
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  bool _loaded = false;
  bool _fetchingModels = false;

  static const _providerLabels = {
    'gemini': 'Gemini',
    'openrouter': 'OpenRouter',
    'agnes': 'Agnes',
    'other': '其他',
  };

  static const _providerHints = {
    'gemini': 'Gemini：aistudio.google.com 免费申请 Key。',
    'openrouter': 'OpenRouter：openrouter.ai 申请 Key，仅列出 :free 免费模型。',
    'agnes': 'Agnes：platform.agnes-ai.com 免费申请 Key（免费额度约每分钟20次）。',
    'other': '其他：任何 OpenAI 兼容服务，填入 API 地址（Base URL）、Key 和模型名。',
  };

  @override
  void initState() {
    super.initState();
    AiSettings.load().then((s) {
      if (!mounted) return;
      setState(() {
        _provider = s.provider;
        for (final p in kAiProviders) {
          _keys[p] = s.keys[p] ?? '';
          _models[p] = s.models[p] ?? '';
        }
        _otherBaseUrl = s.otherBaseUrl;
        _syncControllers();
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  /// Persist current text fields into the per-provider maps.
  void _stashControllers() {
    _keys[_provider] = _keyController.text.trim();
    _models[_provider] = _modelController.text.trim();
    if (_provider == 'other') _otherBaseUrl = _baseUrlController.text.trim();
  }

  /// Load the selected provider's stored values into the text fields.
  void _syncControllers() {
    _keyController.text = _keys[_provider] ?? '';
    _modelController.text = (_models[_provider]?.isNotEmpty ?? false)
        ? _models[_provider]!
        : (AiSettings.defaultModels[_provider] ?? '');
    _baseUrlController.text = _otherBaseUrl;
  }

  void _onProviderChanged(String p) {
    setState(() {
      _stashControllers(); // keep what was typed for the previous provider
      _provider = p;
      _syncControllers();
    });
  }

  AiSettings _currentSettings() {
    _stashControllers();
    return AiSettings(
      provider: _provider,
      keys: Map.of(_keys),
      models: Map.of(_models),
      otherBaseUrl: _otherBaseUrl,
    );
  }

  Future<void> _fetchModels() async {
    setState(() => _fetchingModels = true);
    final settings = _currentSettings();
    List<String> models;
    String? error;
    try {
      models = await AiService().listModels(settings);
    } catch (e) {
      models = AiSettings.fallbackModels[_provider] ?? const [];
      error = '$e';
    }
    if (!mounted) return;
    setState(() => _fetchingModels = false);

    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error == null
              ? '未获取到模型，请手动填写模型名'
              : '获取失败：$error')));
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('选择模型（${models.length} 个可用）'),
        children: [
          for (final m in models)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(m),
              child: Text(m, style: const TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() => _modelController.text = picked);
    }
  }

  Future<void> _save() async {
    await _currentSettings().save();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: !_loaded
          ? const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI 设置',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: kPrimaryRed, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '每个服务的 API Key 独立保存、互不覆盖，且仅存于本机。',
                    style: TextStyle(
                        fontSize: 12, color: kInkBlack.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      for (final p in kAiProviders)
                        ButtonSegment(
                            value: p, label: Text(_providerLabels[p]!)),
                    ],
                    selected: {_provider},
                    onSelectionChanged: (s) => _onProviderChanged(s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _providerHints[_provider]!,
                    style: TextStyle(
                        fontSize: 12, color: kInkBlack.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 12),
                  if (_provider == 'other') ...[
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'API 地址（Base URL）',
                        hintText: '例如 https://api.example.com/v1',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '${_providerLabels[_provider]} API Key',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _modelController,
                          decoration: const InputDecoration(
                            labelText: '模型',
                            helperText: '可手动填写，或点右侧按钮获取可用列表',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _fetchingModels
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : IconButton.filledTonal(
                              icon: const Icon(Icons.manage_search),
                              tooltip: '获取可用模型',
                              onPressed: _fetchModels,
                            ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _save, child: const Text('保存')),
                ],
              ),
            ),
    );
  }
}
