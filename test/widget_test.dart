import 'package:flutter_test/flutter_test.dart';
import 'package:pagelab/main.dart';

void main() {
  testWidgets('PageLab smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PageLabApp());
    expect(find.byType(PageLabApp), findsOneWidget);
    // Advance timer past splash duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
