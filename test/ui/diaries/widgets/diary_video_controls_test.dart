import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_controls.dart';

import '../../../support/fake_video_player.dart';

class _CountingVideoPlayer extends FakeVideoPlayer {
  final List<Duration> seeks = <Duration>[];

  @override
  Future<void> seekTo(Duration position) {
    seeks.add(position);
    return super.seekTo(position);
  }
}

void main() {
  testWidgets('dragging the progress bar seeks once on release', (
    tester,
  ) async {
    final player = _CountingVideoPlayer();
    final controller = DiaryVideoPlayerController(
      source: '/video.mp4',
      player: player,
    );
    final exportController = DiaryVideoExportController();
    addTearDown(controller.dispose);
    addTearDown(exportController.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[controller, player]),
            builder: (context, _) => DiaryVideoControls(
              video: const DiaryFileAttachment(path: '/video.mp4'),
              controller: controller,
              exportController: exportController,
              onFullscreen: null,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    for (var step = 0; step < 8; step++) {
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 拖动过程中不向原生播放器发 seek。
    expect(player.seeks, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(player.seeks, hasLength(1));
    expect(player.value.position, player.seeks.single);
  });
}
