import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/input/input_page.dart';
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
      home: const InputPage(),
    );
  }
}
