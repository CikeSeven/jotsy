import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/core/services/storage/media_compressor.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';
import 'package:node_diary/core/services/video_poster_cache.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_embedded_image.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_player.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_scroll_range.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_tiles_view.dart';
import 'package:path/path.dart' as p;

import '../../../support/diary_content_test_helpers.dart';
import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_media_compressor.dart';
import '../../../support/fake_video_player.dart';

class _TrackingVideoPlayer extends FakeVideoPlayer {
  _TrackingVideoPlayer(this.source, {this.disposeGate, this.onDisposed});

  final String source;
  final Completer<void>? disposeGate;
  final VoidCallback? onDisposed;

  @override
  Future<void> dispose() async {
    await disposeGate?.future;
    await super.dispose();
    onDisposed?.call();
  }
}

class _TrackingPlayers {
  final List<_TrackingVideoPlayer> created = <_TrackingVideoPlayer>[];
  final List<String> events = <String>[];
  bool failNext = false;
  Completer<void>? nextDisposeGate;

  int get liveCount => created.where((p) => !p.wasDisposed).length;

  _TrackingVideoPlayer call(String source) {
    final gate = nextDisposeGate;
    nextDisposeGate = null;
    events.add('create:$source');
    final player = _TrackingVideoPlayer(
      source,
      disposeGate: gate,
      onDisposed: () => events.add('disposed:$source'),
    );
    if (failNext) {
      failNext = false;
      player.failInitialization = true;
    }
    created.add(player);
    return player;
  }
}

class _PosterCompressor extends FakeMediaCompressor {
  _PosterCompressor(this.infoByPath);

  final Map<String, StorageVideoInfo> infoByPath;

  @override
  Future<Map<String, StorageVideoInfo>> probeVideos(List<String> paths) async =>
      <String, StorageVideoInfo>{
        for (final path in paths)
          if (infoByPath[path] case final info?) path: info,
      };

  @override
  Future<bool> videoThumbnail(
    String source, {
    required String target,
    int maxSide = 320,
  }) async {
    await File(target).create(recursive: true);
    await File(target).writeAsBytes(const <int>[0xFF, 0xD8, 0xFF]);
    return true;
  }
}

Future<String> _writePng(
  Directory dir,
  String name,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file.path;
}

DiaryEditorController _controllerWithBlocks(
  List<Map<String, Object?>> blocks, {
  bool readOnly = false,
}) {
  return DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
    readOnly: readOnly,
  );
}

Widget _wrapApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool tickerEnabled = true,
}) {
  return MaterialApp(
    theme: expressiveTestTheme(brightness),
    locale: const Locale('zh'),
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      af.AppFlowyEditorLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: TickerMode(
      enabled: tickerEnabled,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() async {
    ImageDimensions.debugReset();
    await DiaryVideoPlayerController.releaseInlineLease();
  });

  tearDown(() async {
    await DiaryVideoPlayerController.releaseInlineLease();
  });

  group('lazy inline video players and global lease', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$brightness mounting many videos creates zero native players until '
        'tapped, switches via sequential lease, and releases on offscreen / '
        'route cover',
        (tester) async {
          tester.view.physicalSize = const Size(400, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final players = _TrackingPlayers();
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          final controller = _controllerWithBlocks(<Map<String, Object?>>[
            for (var i = 0; i < 10; i++)
              {
                'type': 'video',
                'data': {'url': '/videos/v_$i.mp4'},
              },
          ], readOnly: true);
          addTearDown(controller.dispose);
          final posters = VideoPosterCache(
            compressor: const UnsupportedMediaCompressor(),
          );
          final ticker = ValueNotifier<bool>(true);
          addTearDown(ticker.dispose);

          await tester.pumpWidget(
            ValueListenableBuilder<bool>(
              valueListenable: ticker,
              builder: (context, enabled, _) => _wrapApp(
                SingleChildScrollView(
                  controller: scroll,
                  child: nativeTestEditor(
                    controller: controller,
                    shrinkWrap: true,
                    videoPlayerFactory: players.call,
                    videoPosters: posters,
                  ),
                ),
                brightness: brightness,
                tickerEnabled: enabled,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 10 段视频同在正文里，但点击播放前不会创建任何原生播放器。
          expect(find.byType(DiaryVideoPlayer), findsNWidgets(10));
          expect(players.created, isEmpty);

          // 点击第 1 段播放：创建并播放唯一一个原生播放器。
          final firstCard = find.byType(DiaryVideoPlayer).at(0);
          final secondCard = find.byType(DiaryVideoPlayer).at(1);
          final disposeGate = Completer<void>();
          players.nextDisposeGate = disposeGate;

          await tester.tap(
            find
                .descendant(of: firstCard, matching: find.byTooltip('播放视频'))
                .last,
          );
          await tester.pumpAndSettle();
          expect(players.created, hasLength(1));
          expect(players.liveCount, 1);
          expect(players.created.first.value.isPlaying, isTrue);

          // 拖动进度到 5 秒，再切去播第 2 段：第 2 段必须等第 1 段原生释放完成
          // 后才创建，确保同一时刻最多一个硬件解码器。
          await players.created.first.seekTo(const Duration(seconds: 5));
          await tester.pump();
          await tester.tap(
            find
                .descendant(of: secondCard, matching: find.byTooltip('播放视频'))
                .last,
          );
          await tester.pump();
          expect(players.created, hasLength(1));
          disposeGate.complete();
          await tester.pumpAndSettle();

          expect(players.created, hasLength(2));
          expect(players.liveCount, 1);
          expect(players.created[0].wasDisposed, isTrue);
          expect(players.created[1].value.isPlaying, isTrue);
          expect(players.events, <String>[
            'create:/videos/v_0.mp4',
            'disposed:/videos/v_0.mp4',
            'create:/videos/v_1.mp4',
          ]);

          // 滚到远离第 2 段的位置：自动释放原生播放器并回到封面态。
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(players.liveCount, 0);
          expect(players.created[1].wasDisposed, isTrue);

          // 滚回顶部并再次播放第 1 段：从记住的 5 秒位置续播。
          scroll.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .descendant(of: firstCard, matching: find.byTooltip('播放视频'))
                .last,
          );
          await tester.pumpAndSettle();
          expect(players.liveCount, 1);
          expect(
            players.created.last.value.position,
            const Duration(seconds: 5),
          );

          // 路由被遮挡 / 翻页器非当前页（TickerMode 关闭）：自动释放播放器。
          ticker.value = false;
          await tester.pumpAndSettle();
          expect(players.liveCount, 0);
          expect(players.created.last.wasDisposed, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      'failed lazy video disposes its player and shows attachment fallback',
      (tester) async {
        final players = _TrackingPlayers()..failNext = true;
        final controller = _controllerWithBlocks(<Map<String, Object?>>[
          {
            'type': 'video',
            'data': {'url': '/videos/broken.mp4'},
          },
        ], readOnly: true);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrapApp(
            SingleChildScrollView(
              child: nativeTestEditor(
                controller: controller,
                shrinkWrap: true,
                videoPlayerFactory: players.call,
                videoPosters: VideoPosterCache(
                  compressor: const UnsupportedMediaCompressor(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(players.created, isEmpty);

        await tester.tap(find.byTooltip('播放视频').last);
        await tester.pumpAndSettle();
        expect(players.created, hasLength(1));
        expect(players.created.single.wasDisposed, isTrue);
        expect(find.byType(DiaryAttachmentTile), findsOneWidget);
        expect(find.text('视频暂时无法播放，点击使用其他应用打开'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'lazy video card displays probed duration and aspect ratio without '
      'allocating a player',
      (tester) async {
        final tempDir = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('jotsy_video_card_info_'),
        ))!;
        addTearDown(
          () => tester.runAsync(() => tempDir.delete(recursive: true)),
        );
        final videoFile = File(p.join(tempDir.path, 'portrait.mp4'))
          ..writeAsBytesSync(const <int>[1, 2, 3]);
        final posters = VideoPosterCache(
          compressor: _PosterCompressor(<String, StorageVideoInfo>{
            videoFile.path: const StorageVideoInfo(
              width: 720,
              height: 1080,
              durationMs: 45000,
              bitrate: 1000000,
            ),
          }),
          temporaryDirectory: () async => tempDir,
        );
        final players = _TrackingPlayers();
        final controller = _controllerWithBlocks(<Map<String, Object?>>[
          {
            'type': 'video',
            'data': {'url': videoFile.path},
          },
        ], readOnly: true);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrapApp(
            Center(
              child: SizedBox(
                width: 360,
                child: nativeTestEditor(
                  controller: controller,
                  shrinkWrap: true,
                  videoPlayerFactory: players.call,
                  videoPosters: posters,
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();

        expect(players.created, isEmpty);
        expect(find.text('00:00 / 00:45'), findsOneWidget);
        final ratio = tester
            .widget<AspectRatio>(
              find
                  .descendant(
                    of: find.byType(DiaryVideoPlayer),
                    matching: find.byType(AspectRatio),
                  )
                  .first,
            )
            .aspectRatio;
        expect(ratio, closeTo(720 / 1080, 1e-4));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('image placeholder anti-collapse and viewport gating', () {
    testWidgets(
      'scrollable editor reserves non-zero height on frame 1 so 40 images do '
      'not mount all at once',
      (tester) async {
        tester.view.physicalSize = const Size(400, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final dir = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('jotsy_scroll_40_imgs_'),
        ))!;
        addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
        final paths = <String>[];
        for (var i = 0; i < 40; i++) {
          paths.add(
            (await tester.runAsync(
              () => _writePng(dir, 'p_$i.png', 400, 300),
            ))!,
          );
        }
        final controller = _controllerWithBlocks(<Map<String, Object?>>[
          for (final path in paths)
            {
              'type': 'image',
              'data': {'url': path},
            },
        ]);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrapApp(nativeTestEditor(controller: controller)),
        );

        // 首帧尺寸尚未读出时，每张图必须有非零占位高度，虚拟列表绝不一次
        // 挂载全部 40 张图。
        final mounted = find.byType(DiaryEmbeddedImage).evaluate().toList();
        expect(mounted.length, greaterThan(0));
        expect(mounted.length, lessThan(15));
        for (final element in mounted) {
          final box = element.renderObject! as RenderBox;
          expect(box.size.height, greaterThan(100));
        }

        // 等可见区域图片完成探测与解码。
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.byType(DiaryEmbeddedImage).evaluate().length, lessThan(15));
        expect(find.byType(Image).evaluate().length, lessThan(15));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'inline preview gates offscreen images and suspends all live images '
      'when TickerMode is disabled',
      (tester) async {
        tester.view.physicalSize = const Size(400, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final dir = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('jotsy_inline_30_imgs_'),
        ))!;
        addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
        final paths = <String>[];
        for (var i = 0; i < 30; i++) {
          paths.add(
            (await tester.runAsync(
              () => _writePng(dir, 'i_$i.png', 400, 300),
            ))!,
          );
        }
        final controller = _controllerWithBlocks(<Map<String, Object?>>[
          for (final path in paths)
            {
              'type': 'image',
              'data': {'url': path},
            },
        ], readOnly: true);
        addTearDown(controller.dispose);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final ticker = ValueNotifier<bool>(true);
        addTearDown(ticker.dispose);

        await tester.pumpWidget(
          ValueListenableBuilder<bool>(
            valueListenable: ticker,
            builder: (context, enabled, _) => _wrapApp(
              SingleChildScrollView(
                controller: scroll,
                child: nativeTestEditor(
                  controller: controller,
                  shrinkWrap: true,
                ),
              ),
              tickerEnabled: enabled,
            ),
          ),
        );
        for (var i = 0; i < 25; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }

        // 内联正文挂载了 30 个块，但只有视口附近几张真正挂载 Image 解码；
        // 远端图片既不解码也不探测文件头。
        expect(find.byType(DiaryEmbeddedImage), findsNWidgets(30));
        final activeImages = find.byType(Image).evaluate().length;
        expect(activeImages, greaterThan(0));
        expect(activeImages, lessThan(12));
        expect(ImageDimensions.isResolved(paths.last), isFalse);

        // 路由被遮挡或切到翻页器其他页：全部活着的 Image 立即卸载。
        ticker.value = false;
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);

        // 回到前台：视口内图片恢复挂载。
        ticker.value = true;
        await tester.pumpAndSettle();
        expect(find.byType(Image).evaluate().length, greaterThan(0));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('LongImageScrollRange offscreen & nested inline scroll', () {
    testWidgets(
      'skips NeverScrollableScrollPhysics and mounts zero tiles when offscreen',
      (tester) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final tiles = LongImageTiles(
          width: 1000,
          height: 5000,
          tiles: <LongImageTile>[
            for (var i = 0; i < 5; i++)
              LongImageTile(
                path: '/missing/tile_$i.png',
                top: i * 1000,
                height: 1002,
              ),
          ],
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                height: 400,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: SingleChildScrollView(
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 2000),
                        SizedBox(
                          width: 200,
                          height: 1000,
                          child: LongImageScrollRange(
                            builder: (context, start, end) =>
                                LongImageTilesView(
                                  tiles: tiles,
                                  decodeWidth: 200,
                                  visibleStart: start,
                                  visibleEnd: end,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        // 距离视口 1600dp，超出 1 屏（400dp）预留：0 块瓦片挂载。
        expect(find.byType(Image), findsNothing);

        // 滚到长图顶部附近：只挂载进入范围的瓦片，不是整张 5 块。
        scroll.jumpTo(1800);
        await tester.pump();
        await tester.pump();
        final visibleCount = find.byType(Image).evaluate().length;
        expect(visibleCount, greaterThan(0));
        expect(visibleCount, lessThan(5));
      },
    );
  });
}
