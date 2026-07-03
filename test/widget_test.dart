import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/main.dart';

void main() {
  testWidgets('input form renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BaziApp()));
    expect(find.text('八字排盘'), findsOneWidget);
    expect(find.text('历法'), findsOneWidget);
    expect(find.text('出生日期'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('排 盘'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('排 盘'), findsOneWidget);
  });
}
