import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analysis/bazi_analysis_service.dart';
import '../core/analysis/example_repository.dart';
import '../services/ai_service.dart';

final exampleRepositoryProvider =
    Provider<ExampleRepository>((ref) => ExampleRepository());

final aiServiceProvider = Provider<AiService>((ref) => AiService());

final baziAnalysisServiceProvider = Provider<BaziAnalysisService>((ref) {
  return BaziAnalysisService(
    examples: ref.watch(exampleRepositoryProvider),
    ai: ref.watch(aiServiceProvider),
  );
});
