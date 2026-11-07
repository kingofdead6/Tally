import 'package:tally_app/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('IconBadge draws a built-in icon (no images)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IconBadge(icon: 'food', color: '#F97316'))),
    );
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
  });

  testWidgets('Unknown icon key falls back safely', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IconBadge(icon: 'nope', color: 'bad'))),
    );
    expect(find.byIcon(Icons.category_rounded), findsOneWidget);
  });
}
