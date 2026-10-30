import 'package:chorely/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';
import 'support/hub.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'A fresh process reads the accepted deadline and immutable activity',
    (tester) async {
      await app.main();
      await waitFor(tester, find.text('Native fictional home'));
      await tester.tap(find.text('Native fictional home'));
      await openHubTab(tester, 1);
      await ensureReady(tester, find.text('Cook rice'));
      await tester.tap(find.text('Cook rice'));
      const date = String.fromEnvironment('CHORELY_POSTPONE_DATE');
      await waitFor(tester, find.text('$date · By 19:30'));
      await waitFor(
        tester,
        find.text(
          'This occurrence was postponed. Other turns keep their schedule.',
        ),
      );
      await ensureReady(tester, find.text('Postponed this occurrence'));
      expect(find.text('Done'), findsNothing);
      debugPrint('Chorely M13 fresh deadline ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
