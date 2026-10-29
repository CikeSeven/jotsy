import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_platform.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_flow_lanes.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_session_panel.dart';
import 'package:node_diary/ui/settings/widgets/app_update_progress_bar.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../support/expressive_test_theme.dart';

Future<void> _pumpPanel(
  WidgetTester tester,
  LanSyncSessionView session, {
  Brightness brightness = Brightness.light,
  double width = 390,
  bool reduceMotion = true,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: LanSyncSessionPanel(
            session: session,
            localPlatform: LanSyncPlatform.android,
            peerPlatform: LanSyncPlatform.linux,
            peerName: 'ThinkPad',
          ),
        ),
      ),
    ),
  );
}

const List<String> _stepLabels = <String>['连接', '比对', '传输', '合并'];

/// 阶段条里已完成的对勾个数。
int _checks(WidgetTester tester) => tester
    .widgetList<FaIcon>(find.byType(FaIcon))
    .where((icon) => icon.icon?.codePoint == FontAwesomeIcons.check.codePoint)
    .length;

void main() {
  for (final stage in LanSyncSessionStage.values) {
    testWidgets('the stage bar marks ${stage.name} as current', (tester) async {
      await _pumpPanel(
        tester,
        LanSyncSessionView(peerId: 'peer-1', stage: stage),
      );
      await tester.pumpAndSettle();

      for (final label in _stepLabels) {
        expect(find.text(label), findsOneWidget);
      }
      // 当前阶段之前的都是已完成（对勾）。
      expect(_checks(tester), stage.index);
      // 当前阶段的标签为 primary（亮色下 onPrimaryContainer 在白卡片上看不清）。
      final current = tester.element(find.text(_stepLabels[stage.index]));
      expect(
        DefaultTextStyle.of(current).style.color,
        Theme.of(current).colorScheme.primary,
      );
      expect(find.text('本机'), findsOneWidget);
      expect(find.text('ThinkPad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without media the progress area shows the stage and an '
      'indeterminate indicator', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpPanel(
      tester,
      const LanSyncSessionView(
        peerId: 'peer-1',
        stage: LanSyncSessionStage.comparing,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('正在比对…'), findsOneWidget);
    expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
    expect(find.byType(AppUpdateProgressBar), findsNothing);
    expect(find.bySemanticsLabel('正在比对…'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('media transfer shows files, bytes, speed and the percentage '
      'for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpPanel(
      tester,
      const LanSyncSessionView(
        peerId: 'peer-1',
        stage: LanSyncSessionStage.transferring,
        sentDiaries: 3,
        receivedDiaries: 5,
        filesDone: 23,
        filesTotal: 48,
        bytesDone: 1024 * 1024,
        bytesTotal: 4 * 1024 * 1024,
        bytesPerSecond: 512 * 1024,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('正在传输图片与录音'), findsOneWidget);
    expect(find.text('23 / 48 个文件'), findsOneWidget);
    expect(find.text('1 MB / 4 MB · 512 KB/s'), findsOneWidget);
    expect(find.byType(AppUpdateProgressBar), findsOneWidget);
    expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    expect(find.text('↑ 发送 3 篇'), findsOneWidget);
    expect(find.text('↓ 接收 5 篇'), findsOneWidget);
    expect(find.bySemanticsLabel('正在传输…，已完成 25%'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('merging falls back to the indeterminate indicator even after '
      'media was transferred', (tester) async {
    await _pumpPanel(
      tester,
      const LanSyncSessionView(
        peerId: 'peer-1',
        stage: LanSyncSessionStage.merging,
        filesDone: 48,
        filesTotal: 48,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('正在合并…'), findsOneWidget);
    expect(find.byType(AppUpdateProgressBar), findsNothing);
  });

  test('lanes flow both ways before transfer and only with data after', () {
    expect(
      lanSyncLaneActivity(
        const LanSyncSessionView(
          peerId: 'p',
          stage: LanSyncSessionStage.connecting,
        ),
      ),
      (sending: true, receiving: true),
    );
    expect(
      lanSyncLaneActivity(
        const LanSyncSessionView(
          peerId: 'p',
          stage: LanSyncSessionStage.transferring,
          receivedDiaries: 2,
        ),
      ),
      (sending: false, receiving: true),
    );
  });

  testWidgets('lanes stay still under reduce motion', (tester) async {
    await _pumpPanel(
      tester,
      const LanSyncSessionView(
        peerId: 'peer-1',
        stage: LanSyncSessionStage.comparing,
      ),
    );
    // 循环没有启动：pumpAndSettle 能收尾，之后不再排帧。
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncFlowLanes), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('lanes keep flowing while animations are on', (tester) async {
    await _pumpPanel(
      tester,
      const LanSyncSessionView(
        peerId: 'peer-1',
        stage: LanSyncSessionStage.transferring,
        sentDiaries: 1,
      ),
      reduceMotion: false,
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.binding.hasScheduledFrame, isTrue);
    // 卸载后停表，不留下挂起的计时器。
    await tester.pumpWidget(const SizedBox());
  });

  for (final brightness in Brightness.values) {
    for (final width in <double>[320, 1280]) {
      testWidgets('panel lays out without overflow '
          '(${brightness.name}, $width)', (tester) async {
        await _pumpPanel(
          tester,
          const LanSyncSessionView(
            peerId: 'peer-1',
            stage: LanSyncSessionStage.transferring,
            sentDiaries: 1234,
            receivedDiaries: 5678,
            filesDone: 999,
            filesTotal: 1000,
            bytesDone: 900 * 1024 * 1024,
            bytesTotal: 1024 * 1024 * 1024,
            bytesPerSecond: 12 * 1024 * 1024,
          ),
          brightness: brightness,
          width: width,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
