import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_qr_sheet.dart';

import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

FakeLanSyncController _pairedController({bool discoveryListening = true}) {
  return FakeLanSyncController(
    LanSyncViewState(
      local: lanSyncTestLocal.copyWith(discoveryListening: discoveryListening),
      peers: <LanSyncPeerView>[lanSyncTestPeer(lastSyncAt: lanSyncTestNow)],
      nearby: const <LanSyncNearbyView>[lanSyncTestNearby],
    ),
  );
}

Future<void> _openFooter(WidgetTester tester, String label) async {
  // 页脚在列表末尾，先滚到它；“手动输入地址”在英雄卡里也有一枚，取最后一个。
  await tester.scrollUntilVisible(find.text('找不到设备？'), 200);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renaming the device calls renameDevice with the trimmed name', (
    tester,
  ) async {
    final controller = _pairedController();
    await pumpLanSyncPage(tester, controller);

    await tester.tap(find.byTooltip('修改设备名'));
    await tester.pumpAndSettle();
    expect(find.text('设备名称'), findsOneWidget);

    // 清空时确认键不可点。
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final confirm = find.widgetWithText(TextButton, '确认');
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  书房电脑 ');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(controller.calls, contains('rename:书房电脑'));
  });

  testWidgets('cancelling the rename dialog changes nothing', (tester) async {
    final controller = _pairedController();
    await pumpLanSyncPage(tester, controller);
    await tester.tap(find.byTooltip('修改设备名'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(controller.calls.where((c) => c.startsWith('rename')), isEmpty);
  });

  testWidgets('row buttons and switches call the controller', (tester) async {
    final controller = _pairedController();
    await pumpLanSyncPage(tester, controller);

    await tester.tap(find.text('同步'));
    expect(controller.calls, contains('syncNow:peer-1'));

    await tester.tap(find.text('可被发现'));
    expect(controller.calls, contains('discoverable:false'));

    await tester.tap(find.text('显示二维码'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('issueQrTicket'));
    // 二维码面板盖在页面上：关掉它再继续点页面上的按钮。
    Navigator.of(tester.element(find.byType(LanSyncQrSheet))).pop();
    await tester.pumpAndSettle();
    expect(controller.calls, contains('revokeQrTicket'));

    await tester.scrollUntilVisible(find.text('配对'), 200);
    await tester.tap(find.text('配对'));
    expect(controller.calls, contains('pair:near-1'));

    await tester.scrollUntilVisible(find.text('找不到设备？'), 200);
    await tester.tap(find.text('自动同步'));
    await tester.tap(find.text('同步设置'));
    expect(
      controller.calls,
      containsAll(<String>['autoSync:false', 'syncSettings:true']),
    );
  });

  testWidgets('tapping the address chip copies address and port', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final controller = _pairedController();
    await pumpLanSyncPage(tester, controller);
    await tester.tap(find.text('192.168.1.23'));
    await tester.pump();
    expect(copied, <String>['192.168.1.23:47562']);
  });

  testWidgets('manual address validates host and port before connecting', (
    tester,
  ) async {
    final controller = _pairedController();
    await pumpLanSyncPage(tester, controller);
    await _openFooter(tester, '手动输入地址');

    final host = find.byKey(const ValueKey<String>('lanSyncManualHost'));
    final port = find.byKey(const ValueKey<String>('lanSyncManualPort'));
    expect(tester.widget<TextField>(port).controller!.text, '47562');

    await tester.enterText(host, '192.168.1');
    await tester.enterText(port, '70000');
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效的 IP 地址或主机名'), findsOneWidget);
    expect(find.text('端口应在 1–65535 之间'), findsOneWidget);
    expect(controller.calls.where((c) => c.startsWith('manual')), isEmpty);

    await tester.enterText(host, ' 192.168.1.5 ');
    await tester.enterText(port, '47562');
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('manual:192.168.1.5:47562'));
    expect(find.text('连接'), findsNothing);
  });

  testWidgets('troubleshooting explains a busy port and leads to the '
      'address sheet', (tester) async {
    final controller = _pairedController(discoveryListening: false);
    await pumpLanSyncPage(tester, controller);
    await _openFooter(tester, '找不到设备？');

    expect(find.textContaining('发现端口 47561 被其他程序占用'), findsOneWidget);
    expect(find.text('如果开着防火墙，请放行 UDP 47561 与 TCP 47562。'), findsOneWidget);

    final manual = find.widgetWithText(FilledButton, '手动输入地址');
    await tester.scrollUntilVisible(
      manual,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('lanSyncManualHost')),
      findsOneWidget,
    );
  });

  testWidgets('troubleshooting hides the port notice when discovery works', (
    tester,
  ) async {
    final controller = _pairedController();
    await pumpLanSyncPage(tester, controller);
    await _openFooter(tester, '找不到设备？');
    expect(find.textContaining('被其他程序占用'), findsNothing);
    expect(find.text('连上同一个 Wi-Fi'), findsOneWidget);
  });

  testWidgets('the page attaches while visible and detaches when covered, '
      'backgrounded or closed', (tester) async {
    final controller = _pairedController();
    await pumpLanSyncPage(tester, controller);
    expect(controller.attachCount, 1);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(controller.attachCount, 0);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(controller.attachCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(controller.attachCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.attachCount, 1);

    await tester.pumpWidget(const SizedBox());
    expect(controller.attachCount, 0);
    expect(
      controller.calls.where((c) => c == 'attachPage').length,
      controller.calls.where((c) => c == 'detachPage').length,
    );
  });
}
