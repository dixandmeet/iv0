import 'package:aule_pro/models/driver/driver_profile.dart';
import 'package:aule_pro/services/driver/driver_workspace_service.dart';
import 'package:aule_pro/widgets/driver/driver_mode_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('DriverModeSwitcher', () {
    testWidgets('hidden when no MSR capabilities', (tester) async {
      const profile = DriverProfile(
        id: '1',
        email: 'a@test.com',
        status: 'off',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => DriverWorkspaceService(),
            child: Scaffold(
              body: DriverModeSwitcher(
                profile: profile,
                onModeSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Conduite'), findsNothing);
    });

    testWidgets('visible when MSR control enabled', (tester) async {
      const profile = DriverProfile(
        id: '1',
        email: 'a@test.com',
        status: 'off',
        msrControl: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => DriverWorkspaceService(),
            child: Scaffold(
              body: DriverModeSwitcher(
                profile: profile,
                onModeSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Conduite'), findsOneWidget);
      expect(find.text('Contrôle'), findsOneWidget);
      expect(find.text('Intervention'), findsNothing);
    });
  });
}
