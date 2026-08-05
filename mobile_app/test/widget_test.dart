import 'package:flutter_test/flutter_test.dart';
import 'package:flaura/main.dart';

void main() {
  testWidgets('shows the Flaura identification experience', (tester) async {
    await tester.pumpWidget(const FlauraApp());
    expect(find.text('Meet a flower\nin the wild.'), findsOneWidget);
    expect(find.text('Use camera'), findsOneWidget);
    expect(find.text('Choose from library'), findsOneWidget);
  });
}
