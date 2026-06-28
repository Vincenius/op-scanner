import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:op_scanner/src/app.dart';

void main() {
  testWidgets('Home screen renders the placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OpScannerApp()));
    await tester.pumpAndSettle();

    expect(find.text('OP Scanner'), findsOneWidget);
    expect(find.text('One Piece TCG Collection'), findsOneWidget);
  });
}
