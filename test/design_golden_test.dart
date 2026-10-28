import 'dart:convert';
import 'dart:io';

import 'package:chorely/app/theme.dart';
import 'package:chorely/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Test-only SDK fonts; no font files copied into the app bundle.
    final config = File('.dart_tool/package_config.json').absolute;
    final data =
        jsonDecode(await config.readAsString()) as Map<String, dynamic>;
    final packages = data['packages'] as List<dynamic>;
    final flutter = packages.cast<Map<String, dynamic>>().firstWhere(
      (p) => p['name'] == 'flutter',
    );
    final root = config.uri.resolve("${flutter['rootUri']}/").resolve('../../');
    for (final item in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(item.$1)
        ..addFont(
          File.fromUri(
            root.resolve('bin/cache/artifacts/material_fonts/${item.$2}'),
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
    }
  });
  for (final size in [const Size(390, 844), const Size(800, 1100)]) {
    testWidgets('Welcome visual at ${size.width.toInt()}dp', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: chorelyTheme().copyWith(
            platform: TargetPlatform.android,
            filledButtonTheme: FilledButtonThemeData(
              style: chorelyTheme().filledButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          home: OnboardingScreen(onFinish: () {}),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('app/assets/illustrations/welcome.png'),
          tester.element(find.byType(OnboardingScreen)),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/welcome-${size.width.toInt()}.png'),
      );
    });
  }
}
