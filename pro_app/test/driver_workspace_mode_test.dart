import 'package:aule_pro/models/driver/driver_profile.dart';
import 'package:aule_pro/models/driver/driver_workspace_mode.dart';
import 'package:aule_pro/services/driver/driver_workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriverWorkspaceModeX', () {
    test('storage round-trip', () {
      expect(
        DriverWorkspaceModeX.fromStorage('controle'),
        DriverWorkspaceMode.controle,
      );
      expect(
        DriverWorkspaceMode.controle.storageKey,
        'controle',
      );
      expect(DriverWorkspaceModeX.fromStorage(null), isNull);
    });
  });

  group('DriverWorkspaceService.availableModes', () {
    late DriverWorkspaceService workspace;

    setUp(() {
      workspace = DriverWorkspaceService();
    });

    test('conducteur sans MSR → conduite seule', () {
      const profile = DriverProfile(
        id: '1',
        email: 'a@test.com',
        status: 'off',
      );
      expect(workspace.availableModes(profile), [
        DriverWorkspaceMode.conduite,
      ]);
    });

    test('conducteur contrôle seul', () {
      const profile = DriverProfile(
        id: '1',
        email: 'a@test.com',
        status: 'off',
        msrControl: true,
      );
      expect(workspace.availableModes(profile), [
        DriverWorkspaceMode.conduite,
        DriverWorkspaceMode.controle,
      ]);
    });

    test('conducteur dual MSR', () {
      const profile = DriverProfile(
        id: '1',
        email: 'a@test.com',
        status: 'off',
        msrControl: true,
        msrIntervention: true,
      );
      expect(workspace.availableModes(profile), [
        DriverWorkspaceMode.conduite,
        DriverWorkspaceMode.controle,
        DriverWorkspaceMode.intervention,
      ]);
    });
  });

  group('DriverWorkspaceService persistence', () {
    test('load restores saved mode', () async {
      SharedPreferences.setMockInitialValues({
        'aule_pro_workspace_mode': 'intervention',
      });
      final workspace = DriverWorkspaceService();
      await workspace.load();
      expect(workspace.currentMode, DriverWorkspaceMode.intervention);
    });

    test('applySwitch persists mode', () async {
      SharedPreferences.setMockInitialValues({});
      final workspace = DriverWorkspaceService();
      await workspace.load();
      await workspace.applySwitch(DriverWorkspaceMode.controle);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('aule_pro_workspace_mode'), 'controle');
    });
  });

  group('DriverWorkspaceService.reconcileWithProfile', () {
    test('reset to conduite when MSR mode no longer allowed', () async {
      SharedPreferences.setMockInitialValues({
        'aule_pro_workspace_mode': 'controle',
      });
      final workspace = DriverWorkspaceService();
      await workspace.load();
      expect(workspace.currentMode, DriverWorkspaceMode.controle);

      const profile = DriverProfile(
        id: '1',
        email: 'a@test.com',
        status: 'off',
      );
      await workspace.reconcileWithProfile(profile);
      expect(workspace.currentMode, DriverWorkspaceMode.conduite);
    });
  });

  group('DriverWorkspaceService.trySwitchMode', () {
    late DriverWorkspaceService workspace;

    setUp(() {
      workspace = DriverWorkspaceService();
    });

    const msrProfile = DriverProfile(
      id: '1',
      email: 'a@test.com',
      status: 'off',
      msrControl: true,
    );

    test('MSR with active service needs confirmation', () {
      expect(
        workspace.trySwitchMode(
          DriverWorkspaceMode.controle,
          profile: msrProfile,
          hasActiveService: true,
        ),
        WorkspaceSwitchResult.needsConfirmation,
      );
    });

    test('MSR without active service switches immediately', () {
      expect(
        workspace.trySwitchMode(
          DriverWorkspaceMode.controle,
          profile: msrProfile,
          hasActiveService: false,
        ),
        WorkspaceSwitchResult.switched,
      );
    });

    test('return to conduite switches without confirmation', () async {
      await workspace.applySwitch(DriverWorkspaceMode.controle);
      expect(
        workspace.trySwitchMode(
          DriverWorkspaceMode.conduite,
          profile: msrProfile,
          hasActiveService: true,
        ),
        WorkspaceSwitchResult.switched,
      );
    });
  });
}
