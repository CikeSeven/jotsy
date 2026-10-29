import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/pages/lan_sync_page.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_pairing_sheet.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_qr_sheet.dart';

import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

Future<FakeLanSyncPairing> _startPairing(
  WidgetTester tester,
  FakeLanSyncController controller, {
  LanSyncPairingDirection direction = LanSyncPairingDirection.outgoing,
  LanSyncPairingPhase initial = const LanSyncPairingConnecting(),
}) async {
  final pairing = FakeLanSyncPairing(direction: direction, initial: initial);
  controller.emit(pairing.event);
  await tester.pumpAndSettle();
  return pairing;
}

Future<void> _setPhase(
  WidgetTester tester,
  FakeLanSyncPairing pairing,
  LanSyncPairingPhase phase,
) async {
  pairing.phase.value = phase;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('outgoing pairing walks connecting, code, waiting and success', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);

    final pairing = await _startPairing(tester, controller);
    expect(find.text('正在连接 ThinkPad…'), findsOneWidget);

    await _setPhase(
      tester,
      pairing,
      const LanSyncPairingAwaitingUser('482916'),
    );
    expect(find.text('与「ThinkPad」配对'), findsOneWidget);
    expect(find.text('请确认两台设备上显示的数字一致'), findsOneWidget);
    for (final digit in '482916'.split('')) {
      expect(
        find.descendant(
          of: find.byType(LanSyncPairingSheet),
          matching: find.text(digit),
        ),
        findsOneWidget,
      );
    }
    expect(find.bySemanticsLabel('配对码 482 916'), findsOneWidget);
    expect(find.text('60 秒内没有确认会自动取消'), findsOneWidget);

    await tester.tap(find.text('一致，配对'));
    await tester.pumpAndSettle();
    expect(pairing.responses, <bool>[true]);

    await _setPhase(
      tester,
      pairing,
      const LanSyncPairingAwaitingPeer('482916'),
    );
    expect(find.text('等待对方确认…'), findsOneWidget);
    expect(find.text('一致，配对'), findsNothing);
    expect(find.text('不一致'), findsNothing);

    await _setPhase(tester, pairing, const LanSyncPairingSucceeded('peer-9'));
    expect(find.text('已与 ThinkPad 配对'), findsOneWidget);
    await tester.tap(find.text('立即同步'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncPairingSheet), findsNothing);
    expect(controller.calls, contains('syncNow:peer-9'));
    // 配对已经成功，关闭面板不再放弃。
    expect(pairing.responses, <bool>[true]);
  });

  testWidgets('incoming request shows its title and 不一致 declines', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);

    final pairing = await _startPairing(
      tester,
      controller,
      direction: LanSyncPairingDirection.incoming,
      initial: const LanSyncPairingAwaitingUser('123456'),
    );
    expect(find.text('「ThinkPad」请求配对'), findsOneWidget);

    await tester.tap(find.text('不一致'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncPairingSheet), findsNothing);
    expect(pairing.responses, <bool>[false]);
  });

  testWidgets('closing the sheet while the code is shown declines', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);
    final pairing = await _startPairing(
      tester,
      controller,
      initial: const LanSyncPairingAwaitingUser('123456'),
    );

    // 点面板外的遮罩关闭（与下滑关掉同一条路）。
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncPairingSheet), findsNothing);
    expect(pairing.responses, <bool>[false]);
  });

  testWidgets('failure shows the reason and closes without responding', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);
    final pairing = await _startPairing(tester, controller);

    await _setPhase(
      tester,
      pairing,
      const LanSyncPairingFailed(LanSyncFailureReason.timedOut),
    );
    expect(find.text('配对没有完成'), findsOneWidget);
    expect(find.text('没有在 60 秒内确认，配对已取消。'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncPairingSheet), findsNothing);
    expect(pairing.responses, isEmpty);
  });

  testWidgets('QR pairing goes from connecting straight to success', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);
    final pairing = await _startPairing(tester, controller);
    await _setPhase(tester, pairing, const LanSyncPairingSucceeded('peer-2'));

    expect(find.text('已与 ThinkPad 配对'), findsOneWidget);
    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncPairingSheet), findsNothing);
    expect(controller.calls, isNot(contains('syncNow:peer-2')));
  });

  testWidgets('a pairing that starts while the QR sheet is open replaces it', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);
    await tester.tap(find.text('显示二维码'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncQrSheet), findsOneWidget);

    final pairing = await _startPairing(
      tester,
      controller,
      direction: LanSyncPairingDirection.incoming,
    );
    expect(find.byType(LanSyncQrSheet), findsNothing);
    expect(controller.calls, contains('revokeQrTicket'));
    expect(find.text('正在连接 ThinkPad…'), findsOneWidget);
    expect(pairing.responses, isEmpty);
  });

  testWidgets('requests are declined while another page covers the page', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);
    unawaited(
      Navigator.of(
        tester.element(find.byType(LanSyncPage)),
      ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
    );
    await tester.pumpAndSettle();

    final pairing = await _startPairing(
      tester,
      controller,
      direction: LanSyncPairingDirection.incoming,
    );
    expect(find.byType(LanSyncPairingSheet), findsNothing);
    expect(pairing.responses, <bool>[false]);
  });

  testWidgets('a second pairing while one is open is declined', (tester) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);
    final first = await _startPairing(tester, controller);
    final second = await _startPairing(tester, controller);

    expect(find.byType(LanSyncPairingSheet), findsOneWidget);
    expect(first.responses, isEmpty);
    expect(second.responses, <bool>[false]);
  });

  testWidgets('export backup first cancels pairing and opens the export flow', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);
    final pairing = await _startPairing(
      tester,
      controller,
      initial: const LanSyncPairingAwaitingUser('123456'),
    );

    await tester.tap(find.text('先导出完整备份'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncPairingSheet), findsNothing);
    expect(pairing.responses, <bool>[false]);
    // 复用数据管理页的导出流程：第一步是可选的导出密码。
    expect(find.text('设置导出密码（可选）'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('pairing sheet renders in dark theme on a narrow screen', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(
      tester,
      controller,
      brightness: Brightness.dark,
      width: 320,
      height: 640,
    );
    await _startPairing(
      tester,
      controller,
      initial: const LanSyncPairingAwaitingUser('482916'),
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('配对码 482 916'), findsOneWidget);
  });
}
