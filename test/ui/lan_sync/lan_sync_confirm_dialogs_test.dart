import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_item_counts.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';

import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

FakeLanSyncController _controller() => FakeLanSyncController(
  LanSyncViewState(
    local: lanSyncTestLocal,
    peers: <LanSyncPeerView>[lanSyncTestPeer(lastSyncAt: lanSyncTestNow)],
  ),
);

/// 发一次“以哪边为准”（默认 3 篇日记），返回记录回应的列表。
List<LanSyncSideChoice?> _emitChooseSide(
  FakeLanSyncController controller, {
  Map<LanSyncItemKind, int> items = const <LanSyncItemKind, int>{
    LanSyncItemKind.diaries: 3,
  },
}) {
  final responses = <LanSyncSideChoice?>[];
  controller.emit(
    LanSyncChooseSideEvent(
      peerId: 'peer-1',
      peerName: 'ThinkPad',
      items: LanSyncItemCounts(items),
      respond: (LanSyncSideChoice? choice) async => responses.add(choice),
    ),
  );
  return responses;
}

List<LanSyncDeletionChoice?> _emitDeletion(
  FakeLanSyncController controller, {
  LanSyncSide onSide = LanSyncSide.peer,
}) {
  final responses = <LanSyncDeletionChoice?>[];
  controller.emit(
    LanSyncDeletionGuardEvent(
      peerId: 'peer-1',
      peerName: 'ThinkPad',
      deleteCount: 4,
      onSide: onSide,
      respond: (LanSyncDeletionChoice? choice) async => responses.add(choice),
    ),
  );
  return responses;
}

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, '继续同步'));
  await tester.pumpAndSettle();
}

void main() {
  group('which side', () {
    testWidgets('defaults to keeping both and answers once', (tester) async {
      final controller = _controller();
      await pumpLanSyncPage(tester, controller);
      final responses = _emitChooseSide(controller);
      await tester.pumpAndSettle();

      expect(find.text('以哪边为准'), findsOneWidget);
      expect(find.text('有 3 篇日记在本机和「ThinkPad」上都改过，要怎么合并？'), findsOneWidget);
      expect(find.text('保留两份（推荐）'), findsOneWidget);
      expect(find.text('用「ThinkPad」的版本覆盖本机的改动'), findsOneWidget);
      expect(find.text('三种方式都不会删除任何日记'), findsOneWidget);
      expect(responses, isEmpty);

      await _tapContinue(tester);
      expect(responses, <LanSyncSideChoice?>[LanSyncSideChoice.keepBoth]);
    });

    testWidgets('lists every kind when more than diaries conflict', (
      tester,
    ) async {
      final controller = _controller();
      await pumpLanSyncPage(tester, controller);
      _emitChooseSide(
        controller,
        items: const <LanSyncItemKind, int>{
          LanSyncItemKind.settings: 1,
          LanSyncItemKind.diaries: 2,
          LanSyncItemKind.tags: 1,
        },
      );
      await tester.pumpAndSettle();

      expect(
        find.text('以下内容在本机和「ThinkPad」上都改过：日记 2 · 标签 1 · 设置 1。要怎么合并？'),
        findsOneWidget,
      );
    });

    for (final (label, choice) in <(String, LanSyncSideChoice)>[
      ('以本机为准', LanSyncSideChoice.preferLocal),
      ('以对方为准', LanSyncSideChoice.preferPeer),
    ]) {
      testWidgets('choosing $label responds with ${choice.name}', (
        tester,
      ) async {
        final controller = _controller();
        await pumpLanSyncPage(tester, controller);
        final responses = _emitChooseSide(controller);
        await tester.pumpAndSettle();

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await _tapContinue(tester);
        expect(responses, <LanSyncSideChoice?>[choice]);
      });
    }

    testWidgets('cancel responds with null once', (tester) async {
      final controller = _controller();
      await pumpLanSyncPage(tester, controller);
      final responses = _emitChooseSide(controller);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(responses, <LanSyncSideChoice?>[null]);
    });

    testWidgets('tapping outside the dialog responds with null once', (
      tester,
    ) async {
      final controller = _controller();
      await pumpLanSyncPage(tester, controller);
      final responses = _emitChooseSide(controller);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('以哪边为准'), findsNothing);
      expect(responses, <LanSyncSideChoice?>[null]);
    });

    testWidgets('a confirmation that arrives while something else covers the '
        'page stays unanswered', (tester) async {
      final controller = _controller();
      await pumpLanSyncPage(tester, controller);
      // 盖上排障面板：同步页不再是当前路由。
      await tester.scrollUntilVisible(find.text('找不到设备？'), 200);
      await tester.tap(find.text('找不到设备？'));
      await tester.pumpAndSettle();

      final responses = _emitChooseSide(controller);
      await tester.pumpAndSettle();
      expect(find.text('以哪边为准'), findsNothing);
      expect(responses, isEmpty);
    });
  });

  group('deletion guard', () {
    testWidgets('defaults to keeping the diaries', (tester) async {
      final controller = _controller();
      await pumpLanSyncPage(tester, controller);
      final responses = _emitDeletion(controller);
      await tester.pumpAndSettle();

      expect(find.text('要彻底删除日记吗'), findsOneWidget);
      expect(
        find.text('这次同步会在「ThinkPad」上彻底删除 4 篇日记（它们已在本机的回收站里清空）'),
        findsOneWidget,
      );
      // 确认键为 error 色。
      final confirm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '继续同步'),
      );
      final colors = Theme.of(
        tester.element(find.text('要彻底删除日记吗')),
      ).colorScheme;
      expect(
        confirm.style?.foregroundColor?.resolve(<WidgetState>{}),
        colors.error,
      );

      await _tapContinue(tester);
      expect(responses, <LanSyncDeletionChoice?>[
        LanSyncDeletionChoice.keepAndRestore,
      ]);
    });

    testWidgets('choosing 同步删除 responds with syncDeletion', (tester) async {
      final controller = _controller();
      await pumpLanSyncPage(tester, controller);
      final responses = _emitDeletion(controller, onSide: LanSyncSide.local);
      await tester.pumpAndSettle();

      expect(
        find.text('这次同步会在本机上彻底删除 4 篇日记（它们已在「ThinkPad」的回收站里清空）'),
        findsOneWidget,
      );
      await tester.tap(find.text('同步删除'));
      await tester.pumpAndSettle();
      await _tapContinue(tester);
      expect(responses, <LanSyncDeletionChoice?>[
        LanSyncDeletionChoice.syncDeletion,
      ]);
    });

    testWidgets('cancel responds with null once', (tester) async {
      final controller = _controller();
      await pumpLanSyncPage(tester, controller);
      final responses = _emitDeletion(controller);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(responses, <LanSyncDeletionChoice?>[null]);
    });

    for (final brightness in Brightness.values) {
      for (final width in <double>[320, 1280]) {
        testWidgets('dialog lays out without overflow '
            '(${brightness.name}, $width)', (tester) async {
          final controller = _controller();
          await pumpLanSyncPage(
            tester,
            controller,
            brightness: brightness,
            width: width,
          );
          _emitDeletion(controller);
          await tester.pumpAndSettle();
          expect(find.text('要彻底删除日记吗'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
