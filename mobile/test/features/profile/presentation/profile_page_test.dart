import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/presentation/pages/profile_page.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('ProfilePage', () {
    testWidgets('renders profile stats, menu items, and logout button', (tester) async {
      await pumpApp(tester, const ProfilePage(), overrides: signedOutOverrides());

      expect(find.text('CONSISTENCY'), findsOneWidget);
      expect(find.text('HABITS'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Privacy & Security'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });
  });
}
