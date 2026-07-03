import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/birth_input.dart';

/// Holds the confirmed birth input; chart/rules/AI providers derive from it.
final birthInputProvider = StateProvider<BirthInput?>((ref) => null);
