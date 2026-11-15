import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/storage/media_compressor.dart';
import 'package:node_diary/core/services/video_poster_cache.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/diaries/models/diary_thumbnail_rows.dart';
import 'package:node_diary/ui/diaries/models/media_insertion.dart';
import 'package:node_diary/ui/diaries/pages/diary_video_fullscreen_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_menu.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_player.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_thumbnail.dart';

import '../../../support/diary_content_test_helpers.dart';
import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_video_player.dart';

/// 视频小图、视频菜单与调整宽度（#252）。
///
/// 取帧用不支持的压缩器：小图一直是占位方格 + 播放圆钮，不碰文件系统。

const _path = '/data/diary_videos/trip.mp4';

Map<String, Object?> _video({bool thumbnail = false, double? width}) => {
  'type': 'video',
  'data': {
    'url': _path,
    if (thumbnail) kDiaryImageThumbnailKey: true,
    if (width != null) kDiaryVideoWidthKey: width,
  },
};

Map<String, Object?> _image({bool thumbnail = true}) => {
  'type': 'image',
  'data': {
    'url': '/missing/a.jpg',
    if (thumbnail) kDiaryImageThumbnailKey: true,
  },
};

Map<String, Object?> _p() => {
  'type': 'paragraph',
  'data': {'delta': <Object?>[]},
};

DiaryEditorController _document(
  List<Map<String, Object?>> blocks, {
  bool readOnly = false,
}) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
    readOnly: readOnly,
  );
  addTearDown(controller.dispose);
  return controller;
}

af.Node _block(DiaryEditorController controller, int index) =>
    controller.document.root.children[index];

class _Players {
  final List<FakeVideoPlayer> created = <FakeVideoPlayer>[];

  FakeVideoPlayer call(String _) {
    final player = FakeVideoPlayer();
    created.add(player);
    return player;
  }
}

Future<void> _pumpEditor(
  WidgetTester tester,
  DiaryEditorController controller,
  _Players players, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: const Locale('zh'),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        af.AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
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
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _cardWidth(WidgetTester tester) => tester
    .getSize(
      find
          .descendant(
            of: find.byType(DiaryVideoPlayer),
            matching: find.byType(Material),
          )
          .first,
    )
    .width;

void main() {
  group('rows', () {
    af.Node node(String type, {required bool thumbnail}) => af.Node(
      type: type,
      attributes: {'url': '/x', if (thumbnail) kDiaryImageThumbnailKey: true},
    );

    test('image and video thumbnails share one row', () {
      final rows = diaryThumbnailRows([
        node('image', thumbnail: true),
        node('video', thumbnail: true),
        node('image', thumbnail: true),
        node('video', thumbnail: true),
      ]);
      expect(rows.map((row) => (row.start, row.end)), [
        (0, 3),
        (0, 3),
        (0, 3),
        (3, 4),
      ]);
    });

    test('a full-size video or an attachment breaks the row', () {
      final rows = diaryThumbnailRows([
        node('image', thumbnail: true),
        node('video', thumbnail: false),
        node('video', thumbnail: true),
        node('attachment', thumbnail: true),
      ]);
      expect(rows.map((row) => (row.start, row.end)), [
        (0, 1),
        (1, 2),
        (2, 3),
        (3, 4),
      ]);
    });
  });

  test('videos inserted right after a thumbnail join its row, attachments do '
      'not', () {
    final controller = _document([_image(), _p()]);
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    insertDiaryMediaBlocks(
      controller: controller,
      embeds: [
        af.Node(type: 'video', attributes: {'url': _path}),
        af.Node(type: 'attachment', attributes: {'path': '/a.pdf'}),
      ],
    );
    final children = controller.document.root.children.toList();
    expect(children.map((node) => node.type).take(3), [
      'image',
      'video',
      'attachment',
    ]);
    expect(diaryImageIsThumbnail(children[1]), isTrue);
    expect(diaryImageIsThumbnail(children[2]), isFalse);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness thumbnail video draws a square tile without a player and '
      'its menu restores the full card',
      (tester) async {
        final players = _Players();
        final controller = _document([_video(thumbnail: true), _p()]);
        await _pumpEditor(tester, controller, players, brightness: brightness);

        expect(find.byType(DiaryVideoThumbnail), findsOneWidget);
        expect(find.byType(DiaryVideoPlayer), findsNothing);
        expect(players.created, isEmpty);
        final tile = tester.getSize(find.byType(DiaryVideoThumbnail));
        expect(tile.width, tile.height);
        expect(tile.width, diaryThumbnailExtentFor(tile.width * 3 + 16));

        await tester.tap(find.byType(DiaryVideoThumbnail));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.text('播放视频'), findsOneWidget);
        expect(find.text('恢复正常显示'), findsOneWidget);
        expect(find.text('保存到相册'), findsOneWidget);
        expect(find.text('删除'), findsOneWidget);
        // 小图尺寸固定，菜单里没有“调整大小”。
        expect(find.text('调整大小'), findsNothing);

        await tester.tap(find.text('恢复正常显示'));
        await tester.pumpAndSettle();
        expect(diaryImageIsThumbnail(_block(controller, 0)), isFalse);
        expect(find.byType(DiaryVideoThumbnail), findsNothing);
        expect(find.byType(DiaryVideoPlayer), findsOneWidget);
        expect(players.created, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('the card menu shows the video as a thumbnail without raising '
      'the keyboard', (tester) async {
    final players = _Players();
    final controller = _document([_video(), _p()]);
    await _pumpEditor(tester, controller, players);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('显示为小图'), findsOneWidget);
    expect(find.text('调整大小'), findsOneWidget);
    await tester.tap(find.text('显示为小图'));
    await tester.pumpAndSettle();

    expect(diaryImageIsThumbnail(_block(controller, 0)), isTrue);
    expect(find.byType(DiaryVideoThumbnail), findsOneWidget);
    // 卡片的播放器随卡片卸载释放，小图不再创建新的。
    expect(players.created.single.wasDisposed, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resizing previews the width live, saves on confirm and keeps '
      'the saved width when dismissed', (tester) async {
    final players = _Players();
    final controller = _document([_video(), _p()]);
    await _pumpEditor(tester, controller, players);
    final full = _cardWidth(tester);

    Future<Slider> openResizer() async {
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('调整大小'));
      await tester.pumpAndSettle();
      expect(find.text('视频宽度'), findsOneWidget);
      return tester.widget<Slider>(
        find.byWidgetPredicate(
          (widget) => widget is Slider && widget.min == kDiaryVideoMinWidth,
        ),
      );
    }

    var slider = await openResizer();
    expect(slider.value, closeTo(full, 1));
    slider.onChanged!(280);
    await tester.pump();
    expect(_cardWidth(tester), 280);
    // 预览不写正文。
    expect(_block(controller, 0).attributes[kDiaryVideoWidthKey], isNull);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(_block(controller, 0).attributes[kDiaryVideoWidthKey], 280);
    expect(_cardWidth(tester), 280);

    // 拖动后直接关闭面板：回到已保存的宽度，正文不变。
    slider = await openResizer();
    expect(slider.value, 280);
    slider.onChanged!(250);
    await tester.pump();
    expect(_cardWidth(tester), 250);
    Navigator.of(tester.element(find.text('视频宽度'))).pop();
    await tester.pumpAndSettle();
    expect(_block(controller, 0).attributes[kDiaryVideoWidthKey], 280);
    expect(_cardWidth(tester), 280);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a narrow card drops the time text but keeps every button', (
    tester,
  ) async {
    final players = _Players();
    final controller = _document([_video(width: kDiaryVideoMinWidth), _p()]);
    await _pumpEditor(tester, controller, players);
    expect(_cardWidth(tester), kDiaryVideoMinWidth);
    expect(find.text('00:00 / 00:12'), findsNothing);
    expect(find.byTooltip('播放视频'), findsWidgets);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byTooltip('全屏播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('read-only thumbnail plays fullscreen on tap and releases its '
      'player on return', (tester) async {
    final players = _Players();
    final controller = _document([
      _video(thumbnail: true),
      _p(),
    ], readOnly: true);
    await _pumpEditor(tester, controller, players);
    expect(players.created, isEmpty);

    await tester.tap(find.byType(DiaryVideoThumbnail));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryVideoFullscreenPage), findsOneWidget);
    // 没有菜单：直接自建播放器并开始播放。
    expect(find.text('恢复正常显示'), findsNothing);
    final player = players.created.single;
    expect(player.value.isPlaying, isTrue);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryVideoFullscreenPage), findsNothing);
    expect(player.wasDisposed, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
