import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skore_hodimlar/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SkoreHodimlarApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
