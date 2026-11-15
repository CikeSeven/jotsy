import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_video_fullscreen_page.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_video_player.dart';

/// 全屏播放页（#252 改版）：顶栏只有返回与导出，底栏一行播放控件，播放中
/// 上下栏自动隐藏、点按画面切换，暂停时一直显示。
void main() {
  const video = DiaryFileAttachment(path: '/data/diary_videos/trip.mp4');

  Future<FakeVideoPlayer> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final player = FakeVideoPlayer();
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openDiaryVideoFullscreen(
                  context,
                  video: video,
                  playerFactory: (_) => player,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return player;
  }

  Finder chrome(String tooltip) => find.byTooltip(tooltip).hitTestable();

  /// 画面上避开中央播放按钮与上下栏的一点。
  Offset pictureSpot(WidgetTester tester) {
    final rect = tester.getRect(find.byType(DiaryVideoFullscreenPage));
    return Offset(rect.center.dx, rect.top + rect.height * 0.3);
  }

  for (final brightness in Brightness.values) {
    testWidgets('$brightness page shows only back, export and one control '
        'row, and autoplays its own player', (tester) async {
      final player = await open(tester, brightness: brightness);
      expect(player.value.isPlaying, isTrue);
      expect(chrome('返回'), findsOneWidget);
      expect(chrome('导出视频'), findsOneWidget);
      expect(find.text('trip.mp4'), findsNothing);
      expect(find.byTooltip('退出全屏'), findsNothing);
      expect(find.byTooltip('全屏播放'), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(chrome('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryVideoFullscreenPage), findsNothing);
      expect(player.wasDisposed, isTrue);
    });
  }

  testWidgets('bars hide after three idle seconds while playing and come back '
      'on tap', (tester) async {
    final player = await open(tester);
    expect(player.value.isPlaying, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(chrome('返回'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(chrome('返回'), findsNothing);
    expect(chrome('暂停视频'), findsNothing);
    expect(player.value.isPlaying, isTrue);

    // 点按画面只切换上下栏，不暂停。
    await tester.tapAt(pictureSpot(tester));
    await tester.pumpAndSettle();
    expect(chrome('返回'), findsOneWidget);
    expect(player.value.isPlaying, isTrue);

    // 中央的暂停按钮暂停后上下栏一直显示。
    await tester.tap(chrome('暂停视频').first);
    await tester.pumpAndSettle();
    expect(player.value.isPlaying, isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(chrome('返回'), findsOneWidget);

    // 暂停时点按画面不收起上下栏。
    await tester.tapAt(pictureSpot(tester));
    await tester.pumpAndSettle();
    expect(chrome('返回'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('touching the control row restarts the hide countdown', (
    tester,
  ) async {
    await open(tester);
    await tester.pump(const Duration(seconds: 2));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(chrome('返回'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(chrome('返回'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
