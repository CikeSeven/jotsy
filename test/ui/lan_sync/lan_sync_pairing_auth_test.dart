import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/lan_sync/controllers/lan_sync_pairing_auth_gate.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_pairing_auth.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_pairing_sheet.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

/// 记下每次验证的说明，按预设结果依次返回。
class _FakeAuth extends DeviceAuthService {
  _FakeAuth({this.supported = true, List<bool>? results})
    : results = results ?? <bool>[];

  bool supported;
  final List<bool> results;
  final List<String> reasons = <String>[];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String reason,
    bool persistAcrossBackgrounding = true,
  }) async {
    reasons.add(reason);
    return results.isEmpty ? false : results.removeAt(0);
  }
}

NotebookView _notebook(String id, NotebookVisibility visibility) {
  final created = DateTime(2026, 10, 1);
  return NotebookView(
    NotebookRow(
      id: id.hashCode,
      notebookId: id,
      name: id,
      kind: NotebookKind.manual.name,
      visibility: visibility.name,
      payload: NotebookPayload.defaults.encode(),
      isPinned: false,
      isClosed: false,
      sortOrder: 0,
      createdAt: created,
      updatedAt: created,
    ),
  );
}

LanSyncPairingAuthGate _gate(
  _FakeAuth auth, {
  bool appLock = false,
  List<NotebookView> notebooks = const <NotebookView>[],
  bool canLock = true,
  Future<bool> Function()? loadAppLockEnabled,
}) {
  return LanSyncPairingAuthGate(
    isAvailable: auth.isSupported,
    verify: (BuildContext context, String reason) =>
        auth.authenticate(reason: reason, persistAcrossBackgrounding: false),
    loadAppLockEnabled: loadAppLockEnabled ?? () async => appLock,
    loadNotebooks: () async => notebooks,
    canLockOnThisDevice: () async => canLock,
  );
}

/// 一个挂在树上的 context（验证门要用它打开应用密码页）。
Future<BuildContext> _context(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  return tester.element(find.byType(SizedBox));
}

void main() {
  group('LanSyncPairingAuthGate', () {
    testWidgets('asks for authentication when app lock is on', (tester) async {
      final auth = _FakeAuth(results: <bool>[true]);
      final outcome = await _gate(
        auth,
        appLock: true,
      ).authorize(await _context(tester), reason: 'r');
      expect(outcome, LanSyncPairingAuthOutcome.allowed);
      expect(auth.reasons, <String>['r']);
    });

    testWidgets('asks for authentication when a locked notebook exists', (
      tester,
    ) async {
      final auth = _FakeAuth(results: <bool>[false]);
      final outcome = await _gate(
        auth,
        notebooks: <NotebookView>[
          _notebook('a', NotebookVisibility.normal),
          _notebook('b', NotebookVisibility.locked),
        ],
      ).authorize(await _context(tester), reason: 'r');
      expect(outcome, LanSyncPairingAuthOutcome.failed);
      expect(auth.reasons, hasLength(1));
    });

    testWidgets('skips authentication without app lock or locked notebooks', (
      tester,
    ) async {
      final auth = _FakeAuth();
      final outcome = await _gate(
        auth,
        notebooks: <NotebookView>[_notebook('h', NotebookVisibility.hidden)],
      ).authorize(await _context(tester), reason: 'r');
      expect(outcome, LanSyncPairingAuthOutcome.allowed);
      expect(auth.reasons, isEmpty);
    });

    testWidgets('reports unsupported when the device has no screen lock', (
      tester,
    ) async {
      final auth = _FakeAuth(supported: false);
      final outcome = await _gate(
        auth,
        appLock: true,
      ).authorize(await _context(tester), reason: 'r');
      expect(outcome, LanSyncPairingAuthOutcome.unsupported);
      expect(auth.reasons, isEmpty);
    });

    testWidgets('requires authentication when the state cannot be read', (
      tester,
    ) async {
      final auth = _FakeAuth(results: <bool>[true]);
      final gate = _gate(
        auth,
        loadAppLockEnabled: () async => throw StateError('settings'),
      );
      expect(
        await gate.authorize(await _context(tester), reason: 'r'),
        LanSyncPairingAuthOutcome.allowed,
      );
      expect(auth.reasons, hasLength(1));
    });

    testWidgets('a device that cannot lock never authenticates', (
      tester,
    ) async {
      final auth = _FakeAuth();
      final gate = _gate(
        auth,
        appLock: true,
        notebooks: <NotebookView>[_notebook('b', NotebookVisibility.locked)],
        canLock: false,
      );
      expect(
        await gate.authorize(await _context(tester), reason: 'r'),
        LanSyncPairingAuthOutcome.allowed,
      );
      expect(auth.reasons, isEmpty);
    });

    testWidgets('Linux without an app password never authenticates', (
      tester,
    ) async {
      final auth = _FakeAuth();
      final gate = LanSyncPairingAuthGate(
        isAvailable: auth.isSupported,
        verify: (_, String reason) => auth.authenticate(reason: reason),
        loadAppLockEnabled: () async => true,
        loadNotebooks: () async => const <NotebookView>[],
      );
      expect(
        await gate.authorize(await _context(tester), reason: 'r'),
        LanSyncPairingAuthOutcome.allowed,
      );
      expect(auth.reasons, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Android authenticates through the default platform check', (
      tester,
    ) async {
      final auth = _FakeAuth(results: <bool>[true]);
      final gate = LanSyncPairingAuthGate(
        isAvailable: auth.isSupported,
        verify: (_, String reason) => auth.authenticate(reason: reason),
        loadAppLockEnabled: () async => true,
        loadNotebooks: () async => const <NotebookView>[],
      );
      await gate.authorize(await _context(tester), reason: 'r');
      expect(auth.reasons, hasLength(1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  testWidgets('a failed authentication keeps the code on screen with a hint', (
    tester,
  ) async {
    final auth = _FakeAuth(results: <bool>[false, true]);
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(
      tester,
      controller,
      authGate: _gate(auth, appLock: true),
    );
    final pairing = FakeLanSyncPairing(
      initial: const LanSyncPairingAwaitingUser('482916'),
    );
    controller.emit(pairing.event);
    await tester.pumpAndSettle();

    await tester.tap(find.text('一致，配对'));
    await tester.pumpAndSettle();
    expect(auth.reasons, <String>['验证身份后确认与「ThinkPad」配对']);
    expect(pairing.responses, isEmpty);
    expect(find.byType(LanSyncPairingSheet), findsOneWidget);
    expect(find.text('身份验证没有通过，配对还没有确认'), findsOneWidget);

    await tester.tap(find.text('一致，配对'));
    await tester.pumpAndSettle();
    expect(pairing.responses, <bool>[true]);
    expect(find.text('身份验证没有通过，配对还没有确认'), findsNothing);
  });

  testWidgets('no screen lock explains why pairing cannot be confirmed', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(
      tester,
      controller,
      authGate: _gate(_FakeAuth(supported: false), appLock: true),
    );
    final pairing = FakeLanSyncPairing(
      initial: const LanSyncPairingAwaitingUser('482916'),
    );
    controller.emit(pairing.event);
    await tester.pumpAndSettle();

    await tester.tap(find.text('一致，配对'));
    await tester.pumpAndSettle();
    expect(pairing.responses, isEmpty);
    expect(find.textContaining('没有设置锁屏密码'), findsOneWidget);
  });
}
