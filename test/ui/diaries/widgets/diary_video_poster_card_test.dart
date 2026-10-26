import '../../../support/diary_content_test_helpers.dart';
import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_player.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_poster_card.dart';
import 'package:video_player/video_player.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_video_player.dart';

/// 只记录打开请求，不碰文件系统与系统应用。
class _RecordingOpenService extends FileOpenService {
  _RecordingOpenService();

  final List<String> opened = <String>[];

  @override
  Future<FileOpenFailure?> open(String source) async {
    opened.add(source);
    return null;
  }
}

Widget _app(Brightness brightness, Widget child) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  locale: const Locale('zh'),
  localizationsDelegates: const [
    ...AppLocalizations.localizationsDelegates,
    af.AppFlowyEditorLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

void main() {
  const video = DiaryFileAttachment(
    path: '/data/diary_videos/trip.mp4',
    sizeBytes: 2048,
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness Linux video block shows a poster and never creates a player',
      (tester) async {
        var factoryCalls = 0;
        final openService = _RecordingOpenService();
        final controller = DiaryEditorController(
          document: decodeDiaryContentToDocument(
            jsonEncode([
              {
                'insert': {'video': video.path},
              },
              {'insert': '\n'},
            ]),
          ),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            brightness,
            nativeTestEditor(
              controller: controller,
              shrinkWrap: true,
              videoPlayerFactory: (String _) {
                factoryCalls++;
                return FakeVideoPlayer();
              },
              fileOpenService: openService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DiaryVideoPosterCard), findsOneWidget);
        expect(find.byType(DiaryVideoPlayer), findsNothing);
        expect(find.byType(VideoPlayer), findsNothing);
        expect(factoryCalls, 0);
        expect(find.text('trip.mp4'), findsOneWidget);

        await tester.tap(find.byType(IconButton).first);
        await tester.pumpAndSettle();
        expect(openService.opened, <String>[video.path]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  testWidgets('poster card has the same size as the inline player card', (
    tester,
  ) async {
    // 初始化前的内嵌播放器同样是 16:9 画面区 + 两行控件。
    final gate = Completer<void>();
    final player = FakeVideoPlayer()..initializationGate = gate;
    await tester.pumpWidget(
      _app(Brightness.light, DiaryVideoPlayer(video: video, player: player)),
    );
    await tester.pump();
    final playerSize = tester.getSize(find.byType(DiaryVideoPlayer));

    await tester.pumpWidget(
      _app(
        Brightness.light,
        DiaryVideoPosterCard(
          video: video,
          openService: _RecordingOpenService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(DiaryVideoPosterCard)), playerSize);
    expect(find.textContaining('点按用系统播放器打开'), findsOneWidget);
    expect(find.textContaining('MP4'), findsOneWidget);
    gate.complete();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
