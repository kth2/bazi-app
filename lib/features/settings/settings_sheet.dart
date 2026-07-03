import 'package:flutter/material.dart';

import '../../services/ai_service.dart';
import '../../theme.dart';

/// Bottom sheet for AI provider + API key configuration.
/// The key is stored locally on the device only.
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
  final _keyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AiSettings.load().then((s) {
      if (!mounted) return;
      setState(() {
        _provider = s.provider;
        _keyController.text = s.apiKey;
        _modelController.text = s.model;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _onProviderChanged(String p) {
    setState(() {
      _provider = p;
      _modelController.text = p == 'gemini'
          ? AiSettings.defaultGeminiModel
          : AiSettings.defaultOpenRouterModel;
    });
  }

  Future<void> _save() async {
    await AiSettings(
      provider: _provider,
      apiKey: _keyController.text.trim(),
      model: _modelController.text.trim().isEmpty
          ? (_provider == 'gemini'
              ? AiSettings.defaultGeminiModel
              : AiSettings.defaultOpenRouterModel)
          : _modelController.text.trim(),
    ).save();
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
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 设置',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: kPrimaryRed, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'API Key 仅保存在本机，用于调用免费 AI 服务。'
                  'Gemini Key 可在 aistudio.google.com 免费申请；'
                  'OpenRouter Key 在 openrouter.ai 申请（选 :free 模型）。',
                  style: TextStyle(
                      fontSize: 12, color: kInkBlack.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'gemini', label: Text('Gemini')),
                    ButtonSegment(
                        value: 'openrouter', label: Text('OpenRouter')),
                  ],
                  selected: {_provider},
                  onSelectionChanged: (s) => _onProviderChanged(s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    helperText: '一般保持默认即可',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
    );
  }
}
