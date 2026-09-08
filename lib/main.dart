import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/input/input_page.dart';
import 'features/update/update_banner.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: BaziApp()));
}

class BaziApp extends StatelessWidget {
  const BaziApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '八字排盘',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      // Wraps every route, so a new deployment is noticed wherever the user
      // happens to be.
      builder: (context, child) =>
          UpdateWatcher(child: child ?? const SizedBox.shrink()),
      home: const InputPage(),
    );
  }
}
