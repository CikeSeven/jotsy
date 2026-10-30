import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';
import 'package:node_diary/ui/lan_sync/sections/lan_sync_hero_card.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_device_glyph.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_session_panel.dart';

import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

Finder _rich(String text) => find.textContaining(text, findRichText: true);

void main() {
  for (final brightness in Brightness.values) {
    for (final width in <double>[390, 1280]) {
      testWidgets('first use shows the explainer and searching line '
          '(${brightness.name}, $width)', (tester) async {
        final controller = FakeLanSyncController(
          const LanSyncViewState(local: lanSyncTestLocal, searching: true),
        );
        await pumpLanSyncPage(
          tester,
          controller,
          brightness: brightness,
          width: width,
        );

        expect(find.text('局域网同步'), findsOneWidget);
        expect(find.text('Pixel 9'), findsOneWidget);
        expect(find.text('本机 · Android'), findsOneWidget);
        expect(find.text('192.168.1.23'), findsOneWidget);
        expect(find.text('可被发现'), findsOneWidget);
        expect(find.text('正在寻找附近的 Jotsy…'), findsOneWidget);
        expect(find.text('还没有配对的设备'), findsOneWidget);
        expect(find.text('我的设备'), findsNothing);
        expect(find.text('正在寻找'), findsOneWidget);
        expect(find.textContaining('附近还没有发现其他 Jotsy'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('找不到设备？'), 200);
        expect(find.text('自动同步'), findsOneWidget);
        expect(find.text('同步设置'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('hero card lays out side by side at 600dp or wider', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller, width: 1280, height: 900);
    final glyph = tester.getCenter(find.byType(LanSyncDeviceGlyph));
    final name = tester.getTopLeft(find.text('Pixel 9'));
    expect(name.dx, greaterThan(glyph.dx));
    expect((name.dy - glyph.dy).abs(), lessThan(120));

    await pumpLanSyncPage(tester, controller, width: 390);
    final narrowGlyph = tester.getCenter(find.byType(LanSyncDeviceGlyph));
    final narrowName = tester.getTopLeft(find.text('Pixel 9'));
    expect(narrowName.dy, greaterThan(narrowGlyph.dy));
  });

  for (final brightness in Brightness.values) {
    testWidgets('paired online, offline and nearby devices render their rows '
        '(${brightness.name})', (tester) async {
      final controller = FakeLanSyncController(
        LanSyncViewState(
          local: lanSyncTestLocal,
          searching: true,
          peers: <LanSyncPeerView>[
            lanSyncTestPeer(
              lastSyncAt: lanSyncTestNow.subtract(const Duration(minutes: 5)),
            ),
            lanSyncTestPeer(id: 'peer-2', name: 'Tablet', online: false),
          ],
          nearby: const <LanSyncNearbyView>[lanSyncTestNearby],
        ),
      );
      await pumpLanSyncPage(tester, controller, brightness: brightness);

      expect(find.text('我的设备'), findsOneWidget);
      expect(find.text('2 台'), findsOneWidget);
      expect(find.text('ThinkPad'), findsOneWidget);
      expect(_rich('在线 · 5分钟前已同步'), findsOneWidget);
      expect(_rich('离线 · 还没有同步过'), findsOneWidget);
      expect(find.text('同步'), findsOneWidget);
      expect(find.text('还没有配对的设备'), findsNothing);
      expect(find.text('正在寻找附近的 Jotsy…'), findsNothing);
      await tester.scrollUntilVisible(find.text('Office PC'), 200);
      expect(find.text('Windows · 192.168.1.50'), findsOneWidget);
      expect(find.text('配对'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an offline peer with a known address keeps its sync button', (
    tester,
  ) async {
    final controller = FakeLanSyncController(
      LanSyncViewState(
        local: lanSyncTestLocal,
        peers: <LanSyncPeerView>[
          lanSyncTestPeer(online: false, lastAddressKnown: true),
        ],
      ),
    );
    await pumpLanSyncPage(tester, controller);
    expect(_rich('离线 · 还没有同步过'), findsOneWidget);
    await tester.tap(find.text('同步'));
    expect(controller.calls, contains('syncNow:peer-1'));
  });

  testWidgets('a syncing peer collapses the hero and gets a bordered card '
      'with the session panel', (tester) async {
    final controller = FakeLanSyncController(
      LanSyncViewState(
        local: lanSyncTestLocal,
        peers: <LanSyncPeerView>[
          lanSyncTestPeer(
            session: const LanSyncSessionView(
              peerId: 'peer-1',
              stage: LanSyncSessionStage.comparing,
            ),
          ),
          lanSyncTestPeer(id: 'peer-2', name: 'Tablet', online: false),
        ],
      ),
    );
    await pumpLanSyncPage(tester, controller);

    expect(
      find.byKey(const ValueKey<String>('lanSyncHeroCollapsed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lanSyncHeroExpanded')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('lanSyncSession:peer-1')),
      findsOneWidget,
    );
    expect(find.byType(LanSyncSessionPanel), findsOneWidget);
    // 行副标题与会话面板的进度区都显示阶段文字。
    expect(_rich('正在比对…'), findsNWidgets(2));
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('同步'), findsNothing);

    await tester.tap(find.text('取消'));
    expect(controller.calls, contains('cancelSync:peer-1'));

    // 会话结束：英雄卡展开回来，设备回到分组卡片。
    controller.stateNotifier.value = controller.stateNotifier.value.copyWith(
      peers: <LanSyncPeerView>[
        lanSyncTestPeer(lastSyncAt: lanSyncTestNow),
        lanSyncTestPeer(id: 'peer-2', name: 'Tablet', online: false),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncHeroCard), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('lanSyncHeroExpanded')),
      findsOneWidget,
    );
    expect(find.byType(LanSyncSessionPanel), findsNothing);
    expect(_rich('在线 · 刚刚已同步'), findsOneWidget);
  });

  testWidgets('a peer waiting for confirmation offers a review button', (
    tester,
  ) async {
    final controller = FakeLanSyncController(
      LanSyncViewState(
        local: lanSyncTestLocal,
        peers: <LanSyncPeerView>[lanSyncTestPeer(needsAttention: true)],
      ),
    );
    await pumpLanSyncPage(tester, controller, brightness: Brightness.dark);

    final status = tester.widget<RichText>(_rich('需要你确认'));
    final span = (status.text as TextSpan).children!.single as TextSpan;
    final context = tester.element(_rich('需要你确认'));
    expect(span.style?.color, Theme.of(context).colorScheme.error);
    expect(find.text('同步'), findsNothing);

    await tester.tap(find.text('查看'));
    expect(controller.calls, contains('review:peer-1'));
  });

  testWidgets('the radar animates only when discoverable and motion allowed', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(
      tester,
      controller,
      reduceMotion: false,
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);

    // 关掉发现：波纹停在静态环，不再出帧。
    controller.stateNotifier.value = controller.stateNotifier.value.copyWith(
      local: lanSyncTestLocal.copyWith(discoverable: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('不可被发现'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduce motion keeps the radar still', (tester) async {
    final controller = FakeLanSyncController(
      const LanSyncViewState(local: lanSyncTestLocal, searching: true),
    );
    await pumpLanSyncPage(tester, controller, settle: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a nearby device that disappears collapses and is removed', (
    tester,
  ) async {
    final controller = FakeLanSyncController(
      const LanSyncViewState(
        local: lanSyncTestLocal,
        nearby: <LanSyncNearbyView>[lanSyncTestNearby],
      ),
    );
    await pumpLanSyncPage(
      tester,
      controller,
      reduceMotion: false,
      settle: false,
    );
    expect(find.text('Office PC'), findsOneWidget);

    controller.stateNotifier.value = controller.stateNotifier.value.copyWith(
      nearby: const <LanSyncNearbyView>[],
    );
    await tester.pump();
    // 收起期间还在原位，按钮已不可点。
    expect(find.text('Office PC'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Office PC'), findsNothing);
    expect(find.textContaining('附近还没有发现其他 Jotsy'), findsOneWidget);
  });
}
