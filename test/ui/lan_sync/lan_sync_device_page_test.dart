import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_item_counts.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';
import 'package:node_diary/ui/lan_sync/pages/lan_sync_device_page.dart';
import 'package:node_diary/ui/lan_sync/pages/lan_sync_page.dart';
import 'package:node_diary/ui/lan_sync/sections/lan_sync_history_section.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_session_panel.dart';

import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

final List<LanSyncHistoryEntryView> _history = <LanSyncHistoryEntryView>[
  LanSyncHistoryEntryView(
    at: DateTime(2026, 10, 29, 11, 30),
    duration: const Duration(seconds: 4),
    receivedDiaries: 3,
    sentDiaries: 2,
    otherChanges: 4,
    mediaBytes: 1536 * 1024,
    conflictCopies: 2,
  ),
  LanSyncHistoryEntryView(
    at: DateTime(2026, 10, 29, 9, 5),
    automatic: true,
    failureReason: LanSyncFailureReason.connectionLost,
  ),
  LanSyncHistoryEntryView(
    at: DateTime(2026, 10, 1, 20),
    duration: const Duration(seconds: 12),
    receivedDiaries: 120,
    firstSync: true,
  ),
];

FakeLanSyncController _controller({
  bool online = true,
  LanSyncSessionView? session,
  List<LanSyncHistoryEntryView> history = const <LanSyncHistoryEntryView>[],
  String? alias,
  bool globalAutoSync = true,
}) {
  return FakeLanSyncController(
    LanSyncViewState(
      local: lanSyncTestLocal,
      autoSyncEnabled: globalAutoSync,
      peers: <LanSyncPeerView>[
        lanSyncTestPeer(
          online: online,
          lastSyncAt: lanSyncTestNow.subtract(const Duration(minutes: 5)),
          session: session,
          history: history,
          alias: alias,
        ),
        lanSyncTestPeer(id: 'peer-2', name: 'Tablet', online: false),
      ],
    ),
  );
}

/// 挂上同步页并点按第一台设备，进入详情页。
Future<void> _openDevice(
  WidgetTester tester,
  FakeLanSyncController controller, {
  Brightness brightness = Brightness.light,
  double width = 390,
}) async {
  await pumpLanSyncPage(
    tester,
    controller,
    brightness: brightness,
    width: width,
  );
  final name = controller.stateNotifier.value.peers.first.displayName;
  // 同步中时会话面板里也有对方的名字；设备行的标题在前。
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
  expect(find.byType(LanSyncDevicePage), findsOneWidget);
}

/// 时间线节点（10dp 圆点）的颜色，按显示顺序。
List<Color?> _nodeColors(WidgetTester tester) {
  return tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(LanSyncHistoryEntry),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxWidth == 10 &&
                widget.constraints?.maxHeight == 10,
          ),
        ),
      )
      .map((container) => (container.decoration as BoxDecoration?)?.color)
      .toList();
}

void main() {
  testWidgets('tapping a paired device opens its details and keeps the '
      'discovery attachment balanced', (tester) async {
    final controller = _controller();
    await _openDevice(tester, controller);

    expect(find.text('设备详情'), findsOneWidget);
    expect(find.text('ThinkPad'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
    expect(find.text('Linux'), findsOneWidget);
    expect(find.text('上次同步'), findsOneWidget);
    expect(find.text('5分钟前'), findsOneWidget);
    expect(find.text('配对于'), findsOneWidget);
    expect(find.text('192.168.1.40'), findsOneWidget);
    // 详情页盖在同步页上：同步页 detach、详情页 attach，计数仍为 1。
    expect(controller.attachCount, 1);

    await tester.tap(find.text('立即同步'));
    expect(controller.calls, contains('syncNow:peer-1'));

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncDevicePage), findsNothing);
    expect(controller.attachCount, 1);
  });

  testWidgets('an offline device cannot be synced', (tester) async {
    final controller = _controller(online: false);
    await _openDevice(tester, controller);

    expect(find.text('离线'), findsOneWidget);
    expect(find.text('未知'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '设备不在线'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('立即同步'), findsNothing);
  });

  testWidgets('while syncing the hero shows the session panel and cancel', (
    tester,
  ) async {
    final controller = _controller(
      session: const LanSyncSessionView(
        peerId: 'peer-1',
        stage: LanSyncSessionStage.merging,
      ),
    );
    await _openDevice(tester, controller);

    expect(
      find.descendant(
        of: find.byType(LanSyncDevicePage),
        matching: find.byType(LanSyncSessionPanel),
      ),
      findsOneWidget,
    );
    expect(find.text('立即同步'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(LanSyncDevicePage),
        matching: find.widgetWithText(TextButton, '取消'),
      ),
    );
    expect(controller.calls, contains('cancelSync:peer-1'));
  });

  testWidgets('the auto sync switch and nickname call the controller', (
    tester,
  ) async {
    final controller = _controller(globalAutoSync: false);
    await _openDevice(tester, controller);

    expect(find.text('“同步选项”里的自动同步已关闭，这里暂不生效'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    expect(controller.calls, contains('peerAutoSync:peer-1:false'));

    expect(find.text('未设置 · 只在本机显示'), findsOneWidget);
    await tester.tap(find.text('备注名'));
    await tester.pumpAndSettle();
    expect(find.text('留空则显示「ThinkPad」'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  书房电脑 ');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '确认'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('alias:peer-1:书房电脑'));
  });

  testWidgets('confirming an empty nickname clears it', (tester) async {
    final controller = _controller(alias: '书房电脑');
    await _openDevice(tester, controller);

    expect(find.text('书房电脑 · 只在本机显示'), findsOneWidget);
    await tester.tap(find.text('备注名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '确认'));
    await tester.pumpAndSettle();
    expect(controller.calls, contains('alias:peer-1:null'));
  });

  testWidgets('the timeline shows success, failure, first sync and conflicts', (
    tester,
  ) async {
    final controller = _controller(history: _history);
    await _openDevice(tester, controller);
    await tester.scrollUntilVisible(find.text('取消配对'), 200);

    expect(find.text('同步记录'), findsOneWidget);
    expect(find.byType(LanSyncHistoryEntry), findsNWidgets(3));
    expect(
      find.text('↓ 收到 3 篇 · ↑ 发出 2 篇 · 其他 4 项 · 媒体 1.5 MB'),
      findsOneWidget,
    );
    expect(find.text('4 秒'), findsOneWidget);
    expect(find.text('2 篇冲突副本'), findsOneWidget);
    expect(find.text('连接中断'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);
    expect(find.text('↓ 收到 120 篇 · ↑ 发出 0 篇'), findsOneWidget);

    final colors = Theme.of(
      tester.element(find.byType(LanSyncHistoryEntry).first),
    ).colorScheme;
    expect(_nodeColors(tester), <Color?>[
      colors.primary,
      colors.error,
      colors.outline,
    ]);
  });

  testWidgets('the timeline is capped at 20 entries', (tester) async {
    final controller = _controller(
      history: <LanSyncHistoryEntryView>[
        for (var i = 0; i < 25; i++)
          LanSyncHistoryEntryView(
            at: lanSyncTestNow.subtract(Duration(hours: i)),
            duration: const Duration(seconds: 1),
          ),
      ],
    );
    await _openDevice(tester, controller);
    final section = tester.widget<LanSyncHistorySection>(
      find.byType(LanSyncHistorySection),
    );
    expect(section.history, hasLength(25));
    await tester.scrollUntilVisible(find.text('取消配对'), 400);
    expect(
      find.byType(LanSyncHistoryEntry, skipOffstage: false),
      findsNWidgets(kLanSyncHistoryLimit),
    );
  });

  testWidgets('no history shows the empty state', (tester) async {
    final controller = _controller();
    await _openDevice(tester, controller);
    expect(find.text('还没有与这台设备同步过'), findsOneWidget);
    expect(find.byType(LanSyncHistoryEntry), findsNothing);
  });

  testWidgets('unpairing asks first, then forgets the peer and closes', (
    tester,
  ) async {
    final controller = _controller();
    await _openDevice(tester, controller);
    await tester.scrollUntilVisible(find.text('取消配对'), 200);

    // 先取消一次：什么都不做。
    await tester.tap(find.text('取消配对'));
    await tester.pumpAndSettle();
    expect(find.text('取消与「ThinkPad」的配对？'), findsOneWidget);
    expect(find.text('两台设备上的日记都不会被删除。之后要同步需要重新配对。'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(controller.calls.where((c) => c.startsWith('forget')), isEmpty);
    expect(find.byType(LanSyncDevicePage), findsOneWidget);

    await tester.tap(find.text('取消配对'));
    await tester.pumpAndSettle();
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, '取消配对'),
    );
    final colors = Theme.of(tester.element(confirm)).colorScheme;
    expect(
      tester
          .widget<TextButton>(confirm)
          .style
          ?.foregroundColor
          ?.resolve(<WidgetState>{}),
      colors.error,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(controller.calls, contains('forget:peer-1'));
    expect(find.byType(LanSyncDevicePage), findsNothing);
    expect(find.byType(LanSyncPage), findsOneWidget);
  });

  testWidgets('the page closes itself when the peer disappears', (
    tester,
  ) async {
    final controller = _controller();
    await _openDevice(tester, controller);

    controller.stateNotifier.value = controller.stateNotifier.value.copyWith(
      peers: <LanSyncPeerView>[
        lanSyncTestPeer(id: 'peer-2', name: 'Tablet', online: false),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncDevicePage), findsNothing);
    expect(find.byType(LanSyncPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmations show on the device page, not twice', (
    tester,
  ) async {
    final controller = _controller();
    await _openDevice(tester, controller);

    final responses = <LanSyncSideChoice?>[];
    controller.emit(
      LanSyncChooseSideEvent(
        peerId: 'peer-1',
        peerName: 'ThinkPad',
        items: LanSyncItemCounts(const <LanSyncItemKind, int>{
          LanSyncItemKind.diaries: 1,
        }),
        respond: (LanSyncSideChoice? choice) async => responses.add(choice),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('以哪边为准'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '继续同步'));
    await tester.pumpAndSettle();
    expect(responses, <LanSyncSideChoice?>[LanSyncSideChoice.keepBoth]);
    expect(find.byType(LanSyncDevicePage), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final width in <double>[320, 1280]) {
      testWidgets('device page lays out without overflow '
          '(${brightness.name}, $width)', (tester) async {
        final controller = _controller(
          history: _history,
          alias: 'A very long nickname for the study computer',
          session: const LanSyncSessionView(
            peerId: 'peer-1',
            stage: LanSyncSessionStage.transferring,
            sentDiaries: 12,
            receivedDiaries: 34,
            filesDone: 5,
            filesTotal: 9,
            bytesDone: 1024,
            bytesTotal: 4096,
          ),
        );
        await _openDevice(
          tester,
          controller,
          brightness: brightness,
          width: width,
        );
        await tester.scrollUntilVisible(find.text('取消配对'), 300);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
