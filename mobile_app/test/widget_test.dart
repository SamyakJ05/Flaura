import 'package:flutter_test/flutter_test.dart';
import 'package:flaura/main.dart';

void main() {
  testWidgets('shows the Flaura identification screen', (tester) async {
    await tester.pumpWidget(const FlauraApp());
    expect(find.text('Identify a flower'), findsOneWidget);
  });
}
