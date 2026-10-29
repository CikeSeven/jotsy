import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_summary.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_summary_sheet.dart';

import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

FakeLanSyncController _controller() => FakeLanSyncController(
  LanSyncViewState(
    local: lanSyncTestLocal,
    peers: <LanSyncPeerView>[lanSyncTestPeer(lastSyncAt: lanSyncTestNow)],
  ),
);

LanSyncSessionFinishedEvent _finished(LanSyncSessionSummary summary) =>
    LanSyncSessionFinishedEvent(peerId: 'peer-1', summary: summary);

const LanSyncSessionSummary _changed = LanSyncSessionSummary(
  peerName: 'ThinkPad',
  duration: Duration(milliseconds: 3200),
  received: LanSyncChangeCounts(
    added: 3,
    updated: 2,
    deleted: 1,
    mediaCount: 4,
    mediaBytes: 3 * 1024 * 1024,
  ),
  sent: LanSyncChangeCounts(added: 5, updated: 2),
);

/// 记下触觉反馈的类型。
List<String> _recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
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
  return haptics;
}

void main() {
  testWidgets('a finished manual sync shows the summary with both columns', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    final controller = _controller();
    await pumpLanSyncPage(tester, controller);

    controller.emit(_finished(_changed));
    await tester.pumpAndSettle();

    expect(find.byType(LanSyncSummarySheet), findsOneWidget);
    expect(find.text('同步完成'), findsOneWidget);
    expect(find.text('与 ThinkPad · 用时 4 秒'), findsOneWidget);
    expect(find.text('↓ 收到'), findsOneWidget);
    expect(find.text('↑ 发出'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('4 个 · 3 MB'), findsOneWidget);
    // 值放不下时整体缩小，不省略。
    final media = tester.widget<Text>(find.text('4 个 · 3 MB'));
    expect(media.overflow, isNot(TextOverflow.ellipsis));
    expect(
      find.ancestor(
        of: find.text('4 个 · 3 MB'),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
    expect(find.text('标签、日记本、留言与纪念日已一并合并'), findsOneWidget);
    expect(find.textContaining('两边都改过'), findsNothing);
    expect(haptics, contains('HapticFeedbackType.lightImpact'));

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncSummarySheet), findsNothing);
    expect(controller.calls.where((c) => c.startsWith('syncNow')), isEmpty);
  });

  testWidgets('numbers count up from zero when animations are on', (
    tester,
  ) async {
    final controller = _controller();
    await pumpLanSyncPage(
      tester,
      controller,
      reduceMotion: false,
      settle: false,
    );
    controller.emit(_finished(_changed));
    // 面板滑入与数字递增都还在进行中。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('7'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('7'), findsOneWidget);
    // 收尾：关掉面板与页面，停掉雷达等循环。
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nothing changed shows only “已经是最新的了”', (tester) async {
    final controller = _controller();
    await pumpLanSyncPage(tester, controller);
    controller.emit(
      _finished(
        const LanSyncSessionSummary(
          peerName: 'ThinkPad',
          duration: Duration(seconds: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已经是最新的了'), findsOneWidget);
    expect(find.text('同步完成'), findsNothing);
    expect(find.text('↓ 收到'), findsNothing);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncSummarySheet), findsNothing);
  });

  testWidgets('tapping a conflict copy closes the sheet and opens the diary', (
    tester,
  ) async {
    final opened = <String>[];
    final controller = _controller();
    await pumpLanSyncPage(
      tester,
      controller,
      openDiary: (BuildContext context, WidgetRef ref, String id) async {
        opened.add(id);
      },
    );
    controller.emit(
      _finished(
        const LanSyncSessionSummary(
          peerName: 'ThinkPad',
          duration: Duration(seconds: 2),
          received: LanSyncChangeCounts(updated: 2),
          conflictCopies: <LanSyncConflictCopy>[
            LanSyncConflictCopy(diaryId: 'copy-1', title: '周末去海边'),
            LanSyncConflictCopy(diaryId: 'copy-2', title: ''),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 篇日记两边都改过，已保留两份'), findsOneWidget);
    expect(find.text('周末去海边'), findsOneWidget);
    expect(find.text('无标题'), findsOneWidget);
    expect(find.text('原日记保留较新的版本'), findsNWidgets(2));

    await tester.tap(find.text('无标题'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncSummarySheet), findsNothing);
    expect(opened, <String>['copy-2']);
  });

  testWidgets('a failed sync explains the reason and retries', (tester) async {
    final controller = _controller();
    await pumpLanSyncPage(tester, controller);
    controller.emit(
      _finished(
        const LanSyncSessionSummary(
          peerName: 'ThinkPad',
          duration: Duration(seconds: 5),
          failureReason: LanSyncFailureReason.connectionLost,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('同步没有完成'), findsOneWidget);
    expect(find.text('连接中断，已写入的部分下次会自动补齐。'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncSummarySheet), findsNothing);
    expect(controller.calls, contains('syncNow:peer-1'));
  });

  testWidgets('a sync cancelled by the user shows no sheet', (tester) async {
    final controller = _controller();
    await pumpLanSyncPage(tester, controller);
    controller.emit(
      _finished(
        const LanSyncSessionSummary(
          peerName: 'ThinkPad',
          duration: Duration(seconds: 5),
          failureReason: LanSyncFailureReason.cancelled,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncSummarySheet), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final width in <double>[320, 1280]) {
      testWidgets('summary sheet lays out without overflow '
          '(${brightness.name}, $width)', (tester) async {
        final controller = _controller();
        await pumpLanSyncPage(
          tester,
          controller,
          brightness: brightness,
          width: width,
        );
        controller.emit(
          _finished(
            const LanSyncSessionSummary(
              peerName: 'A very long device name that keeps going',
              duration: Duration(minutes: 3),
              received: LanSyncChangeCounts(
                added: 1200,
                updated: 340,
                deleted: 56,
                mediaCount: 789,
                mediaBytes: 1536 * 1024 * 1024,
              ),
              sent: LanSyncChangeCounts(added: 12, mediaCount: 3),
              conflictCopies: <LanSyncConflictCopy>[
                LanSyncConflictCopy(
                  diaryId: 'c',
                  title: '一篇标题特别特别特别特别特别特别长的日记',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LanSyncSummarySheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
