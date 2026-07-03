import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/engine/chart_service.dart';
import '../core/models/chart_result.dart';
import 'birth_input_provider.dart';

/// Derives the full chart from the confirmed birth input.
final chartResultProvider = Provider<ChartResult?>((ref) {
  final input = ref.watch(birthInputProvider);
  if (input == null) return null;
  return ChartService.compute(input);
});
