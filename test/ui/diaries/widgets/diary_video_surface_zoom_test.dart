import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_surface.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';

import '../../../support/fake_video_player.dart';

Future<DiaryVideoPlayerController> _pumpSurface(
  WidgetTester tester, {
  required bool zoomable,
  required FakeVideoPlayer player,
  ValueChanged<bool>? onZoomChanged,
}) async {
  final controller = DiaryVideoPlayerController(source: 'x', player: player);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 400,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => DiaryVideoSurface(
              controller: controller,
              zoomable: zoomable,
              onZoomChanged: onZoomChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await controller.initialize();
  await tester.pumpAndSettle();
  return controller;
}

double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

void main() {
  testWidgets('a zoomable video pinches in, taps still play at once and '
      'double tap restores', (tester) async {
    final player = FakeVideoPlayer();
    final zoomEvents = <bool>[];
    await _pumpSurface(
      tester,
      zoomable: true,
      player: player,
      onZoomChanged: zoomEvents.add,
    );

    // 未放大时没有双击判定：单击画面（避开中央的播放按钮）立即播放。
    await tester.tapAt(const Offset(60, 200));
    await tester.pump();
    expect(player.playCount, 1);

    final first = await tester.startGesture(
      const Offset(150, 200),
      pointer: 201,
    );
    final second = await tester.startGesture(
      const Offset(250, 200),
      pointer: 202,
    );
    for (var i = 0; i < 5; i++) {
      await second.moveBy(const Offset(10, 0));
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    // 跨度 50 → 75：放大到 1.5 倍；捏合不算点按，不会暂停。
    expect(_scale(tester), closeTo(1.5, 1e-6));
    expect(zoomEvents, <bool>[true]);
    expect(player.pauseCount, 0);

    // 放大后双击复原。
    await tester.tapAt(const Offset(60, 200));
    await tester.pump(kDoubleTapMinTime + const Duration(milliseconds: 10));
    await tester.tapAt(const Offset(60, 200));
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1, 1e-6));
    expect(zoomEvents, <bool>[true, false]);
  });

  testWidgets('the inline video card does not zoom', (tester) async {
    await _pumpSurface(tester, zoomable: false, player: FakeVideoPlayer());
    expect(find.byType(DoubleTapZoomViewer), findsNothing);
  });
}
