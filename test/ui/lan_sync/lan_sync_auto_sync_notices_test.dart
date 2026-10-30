import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/lan_sync/controllers/lan_sync_auto_sync_notices.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_summary.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/pages/lan_sync_page.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_providers.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_lan_sync_controller.dart';

/// 模拟首页：initState 订阅、dispose 取消。
class _Host extends StatefulWidget {
  const _Host({required this.controller});

  final FakeLanSyncController controller;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final LanSyncAutoSyncNotices _notices;

  @override
  void initState() {
    super.initState();
    _notices = LanSyncAutoSyncNotices(
      widget.controller.events,
      () => mounted ? context : null,
    );
  }

  @override
  void dispose() {
    _notices.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

Future<FakeLanSyncController> _pump(WidgetTester tester) async {
  final controller = FakeLanSyncController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [lanSyncControllerProvider.overrideWithValue(controller)],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: _Host(controller: controller),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets(
    'an auto sync with changes shows a snack bar that opens the page',
    (tester) async {
      final controller = await _pump(tester);
      controller.emit(
        const LanSyncAutoSyncAppliedEvent(
          peerId: 'peer-1',
          peerName: 'ThinkPad',
          diaries: 3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已从「ThinkPad」同步 3 篇日记'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.persist, isFalse);

      await tester.tap(find.text('查看'));
      await tester.pumpAndSettle();
      expect(find.byType(LanSyncPage), findsOneWidget);
    },
  );

  testWidgets('an auto sync needing confirmation says so', (tester) async {
    final controller = await _pump(tester);
    controller.emit(
      const LanSyncAutoSyncNeedsAttentionEvent(
        peerId: 'peer-1',
        peerName: 'ThinkPad',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('与「ThinkPad」的同步需要你确认'), findsOneWidget);
    expect(find.text('查看'), findsOneWidget);
  });

  testWidgets('no-change auto syncs and other events show nothing', (
    tester,
  ) async {
    final controller = await _pump(tester);
    controller
      ..emit(
        const LanSyncAutoSyncAppliedEvent(
          peerId: 'peer-1',
          peerName: 'ThinkPad',
          diaries: 0,
        ),
      )
      ..emit(
        const LanSyncSessionFinishedEvent(
          peerId: 'peer-1',
          summary: LanSyncSessionSummary(
            peerName: 'ThinkPad',
            duration: Duration(seconds: 3),
          ),
        ),
      );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('events after the host is gone are ignored', (tester) async {
    final controller = await _pump(tester);
    await tester.pumpWidget(const SizedBox());
    controller.emit(
      const LanSyncAutoSyncAppliedEvent(
        peerId: 'peer-1',
        peerName: 'ThinkPad',
        diaries: 2,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
