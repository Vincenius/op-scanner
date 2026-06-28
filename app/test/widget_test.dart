import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:op_scanner/src/app.dart';
import 'package:op_scanner/src/providers.dart';

void main() {
  testWidgets('Catalog shows the empty state when nothing is synced',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        // Avoid touching the real drift DB / plugins in a widget test.
        overrides: [localVariantCountProvider.overrideWith((ref) async => 0)],
        child: const OpScannerApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Catalog'), findsWidgets); // app bar + nav label
    expect(find.text('No catalog yet'), findsOneWidget);
    expect(find.text('Sync catalog'), findsWidgets);
  });
}
