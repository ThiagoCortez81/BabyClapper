import 'package:baby_clapper/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders a fullscreen surface', (tester) async {
    await tester.pumpWidget(const BabyClapperApp());
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF1B1B2F),
      ),
      findsOneWidget,
    );
  });
}
