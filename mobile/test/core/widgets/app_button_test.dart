import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/theme.dart';
import 'package:mobile/core/widgets/app_button.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('AppButton', () {
    testWidgets('draws a leading icon before the label', (tester) async {
      await pumpApp(
        tester,
        const AppButton(label: 'Save', icon: Icons.check_rounded),
      );

      expect(
        tester.getCenter(find.byIcon(Icons.check_rounded)).dx,
        lessThan(tester.getCenter(find.text('Save')).dx),
      );
    });

    testWidgets('draws a trailing icon after the label', (tester) async {
      await pumpApp(
        tester,
        const AppButton(
          label: 'Continue',
          trailingIcon: Icons.arrow_forward_rounded,
        ),
      );

      expect(
        tester.getCenter(find.byIcon(Icons.arrow_forward_rounded)).dx,
        greaterThan(tester.getCenter(find.text('Continue')).dx),
      );
    });

    testWidgets('hides both icons while loading', (tester) async {
      // The spinner never stops animating, so this one cannot pumpAndSettle.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AppButton(
              label: 'Continue',
              icon: Icons.check_rounded,
              trailingIcon: Icons.arrow_forward_rounded,
              isLoading: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
