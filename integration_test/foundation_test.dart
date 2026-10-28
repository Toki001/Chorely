import 'package:chorely/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native launch reaches illustrated onboarding and adult sign-in',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();
      expect(find.text('One home.\nOne team.'), findsOneWidget);
      await tester.ensureVisible(find.text('I already have an account'));
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      expect(find.text('Adult email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    },
  );
}
