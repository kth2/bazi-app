import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rules/custom_rules.dart';

final customRuleStoreProvider =
    Provider<CustomRuleStore>((ref) => CustomRuleStore());

/// The adopted 条例. Invalidate after saving a change.
final customRuleSetProvider = FutureProvider<CustomRuleSet>(
    (ref) => ref.watch(customRuleStoreProvider).load());
