import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_player.dart';
import 'package:node_diary/ui/diaries/pages/diary_video_fullscreen_page.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_video_player.dart';

void main() {
  const video = DiaryFileAttachment(path: '/documents/diary_videos/trip.mp4');

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness video controls play pause and seek without overflow',
      (tester) async {
        final player = FakeVideoPlayer();
        await tester.pumpWidget(
          _app(brightness, DiaryVideoPlayer(video: video, player: player)),
        );
        await tester.pumpAndSettle();
        expect(find.text('trip.mp4'), findsOneWidget);
        expect(find.text('00:00 / 00:12'), findsOneWidget);
        expect(player.playCount, 0);
        await tester.tap(find.byTooltip('播放视频').last);
        await tester.pumpAndSettle();
        expect(player.value.isPlaying, isTrue);
        expect(find.byTooltip('暂停视频'), findsOneWidget);
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChanged!(4000);
        await tester.pumpAndSettle();
        expect(find.text('00:04 / 00:12'), findsOneWidget);
        await tester.tap(find.byTooltip('暂停视频'));
        await tester.pumpAndSettle();
        expect(player.value.isPlaying, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(player.wasDisposed, isTrue);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness export requires confirmation and cancellation writes nothing',
      (tester) async {
        final service = FakeVideoExportService();
        await tester.pumpWidget(
          _app(
            brightness,
            DiaryVideoPlayer(
              video: video,
              player: FakeVideoPlayer(),
              exportService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('导出视频'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('确认将“trip.mp4”保存到手机相册？'), findsOneWidget);
        expect(service.sources, isEmpty);
        await tester.tap(find.widgetWithText(TextButton, '取消'));
        await tester.pumpAndSettle();
        expect(service.sources, isEmpty);
        await tester.tap(find.byTooltip('导出视频'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '确认'));
        await tester.pumpAndSettle();
        expect(service.sources, [video.path]);
        expect(find.text('视频已保存到相册'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '$brightness fullscreen shares playback progress and return keeps pause state',
      (tester) async {
        final player = FakeVideoPlayer();
        final service = FakeVideoExportService();
        await tester.pumpWidget(
          _app(
            brightness,
            DiaryVideoPlayer(
              video: video,
              player: player,
              exportService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('播放视频').last);
        await tester.pumpAndSettle();
        tester.widget<Slider>(find.byType(Slider)).onChanged!(4000);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('全屏播放'));
        await tester.pumpAndSettle();
        expect(find.byType(DiaryVideoFullscreenPage), findsOneWidget);
        expect(find.text('00:04 / 00:12'), findsOneWidget);
        expect(player.value.isPlaying, isTrue);
        expect(player.wasDisposed, isFalse);
        tester.widget<Slider>(find.byType(Slider)).onChanged!(8000);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('暂停视频'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('导出视频'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, '取消'));
        await tester.pumpAndSettle();
        expect(service.sources, isEmpty);
        await tester.tap(find.byTooltip('退出全屏'));
        await tester.pumpAndSettle();
        expect(find.byType(DiaryVideoFullscreenPage), findsNothing);
        expect(find.text('00:08 / 00:12'), findsOneWidget);
        expect(player.value.isPlaying, isFalse);
        expect(player.wasDisposed, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(player.wasDisposed, isTrue);
      },
    );
  }

  testWidgets(
    'pending video export shows Expressive loading and prevents repeat export',
    (tester) async {
      final service = FakeVideoExportService()..completion = Completer<void>();
      await tester.pumpWidget(
        _app(
          Brightness.light,
          DiaryVideoPlayer(
            video: video,
            player: FakeVideoPlayer(),
            exportService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('导出视频'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '确认'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      expect(find.byTooltip('导出视频'), findsNothing);
      expect(service.sources, [video.path]);
      service.completion!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      expect(find.text('视频已保存到相册'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'export permission denial reports a localized error and stays retryable',
    (tester) async {
      final service = FakeVideoExportService()
        ..failure = VideoExportFailure.permissionDenied;
      await tester.pumpWidget(
        _app(
          Brightness.dark,
          DiaryVideoPlayer(
            video: video,
            player: FakeVideoPlayer(),
            exportService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('导出视频'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '确认'));
      await tester.pumpAndSettle();
      expect(find.text('未获得相册权限，无法导出视频'), findsOneWidget);
      expect(find.byTooltip('导出视频'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'video initialization uses Expressive loading and offers native open on failure',
    (tester) async {
      final gate = Completer<void>();
      final player = FakeVideoPlayer()
        ..initializationGate = gate
        ..failInitialization = true;
      await tester.pumpWidget(
        _app(Brightness.dark, DiaryVideoPlayer(video: video, player: player)),
      );
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DiaryAttachmentTile), findsOneWidget);
      expect(find.text('视频暂时无法播放，点击使用其他应用打开'), findsOneWidget);
      expect(find.byTooltip('打开附件'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Widget _app(Brightness brightness, Widget child) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

class FakeVideoExportService extends VideoExportService {
  final sources = <String>[];
  Completer<void>? completion;
  VideoExportFailure? failure;

  @override
  Future<void> saveToGallery(String source) async {
    sources.add(source);
    await completion?.future;
    if (failure != null) throw VideoExportException(failure!);
  }
}
