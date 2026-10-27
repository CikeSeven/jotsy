import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_cover_photos_provider.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_cover_photo_sheet.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_cover/notebook_cover_crop_viewport.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 编辑页的封面分组：切版式与纹理写进表单并随保存写入、“调整取景”只在有
/// 封面图时出现并写回取景、“从日记中选”只对已保存的本子，列出本子（含子本）
/// 日记里的图片并拷贝成封面，没有图片时为空状态。
void main() {
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('notebook_cover_ui_test_');
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    await temp.delete(recursive: true);
  });

  /// 封面私有目录落在临时目录里（手机分支经文档目录）。
  void mockDocuments() {
    final documents = Directory('${temp.path}/documents')..createSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProvider,
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? documents.path
              : temp.path,
        );
  }

  /// 写一张小 PNG，返回路径。
  Future<String> writeImage(WidgetTester tester, String name) async {
    final path = '${temp.path}/$name.png';
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 40, 30),
        Paint()..color = const Color(0xFF884422),
      );
      final image = await recorder.endRecording().toImage(40, 30);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    });
    return path;
  }

  Future<String> imageDiary(
    DiaryDraftsHarness h,
    String title, {
    String? cover,
    String? image,
    List<String>? notebookIds,
    DateTime? createdAt,
  }) async {
    final content = image == null
        ? '[{"insert":"正文\\n"}]'
        : '[{"insert":{"image":"$image"}},{"insert":"\\n"}]';
    return (await h.tester.runAsync(
      () => h.database.createDiary(
        title: title,
        contentDocJson: content,
        contentText: '正文',
        metadataJson: '{}',
        cover: cover,
        notebookIds: notebookIds,
        createdAtOverride: createdAt,
      ),
    ))!;
  }

  Future<(DiaryDraftsHarness, List<String?>)> open(
    WidgetTester tester, {
    Future<String?> Function(DiaryDraftsHarness h)? seed,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    final notebookId = await seed?.call(h);
    final results = <String?>[];
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.of(
                context,
              ).push(NotebookEditorPage.route(notebookId: notebookId)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    return (h, results);
  }

  Finder page() => find.byType(Scrollable).first;

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: page());
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<NotebookPayload> savedPayload(DiaryDraftsHarness h) async =>
      (await h.shelf()).single.parsedPayload;

  testWidgets('new notebooks save the chosen layout and texture', (
    tester,
  ) async {
    final (h, results) = await open(tester);
    await tester.enterText(find.byType(TextField).first, '旅行');
    await tester.pump();
    await tapVisible(tester, find.text('满版'));
    await tapVisible(tester, find.text('方格'));
    // 新建时还没有日记，也没有封面图。
    expect(find.text('从日记中选'), findsNothing);
    expect(find.text('调整取景'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    expect(results.single, isNotNull);
    final style = (await savedPayload(h)).coverStyle;
    expect(style.layout, NotebookCoverLayout.fullBleed);
    expect(style.texture, NotebookCoverTexture.grid);
    await h.unmount();
  });

  testWidgets('switching the layout of an existing notebook marks it changed', (
    tester,
  ) async {
    final (h, _) = await open(tester, seed: (h) => h.notebook('旅行'));
    await tapVisible(tester, find.text('书脊'));
    await tapVisible(tester, find.text('斜纹'));
    expect(find.text('从日记中选'), findsOneWidget);

    // 有未保存改动：返回先确认。
    await tester.tap(find.byTooltip(h.l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.text(h.l10n.autoT0131), findsOneWidget);
    await tester.tap(find.text(h.l10n.commonCancel).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    final style = (await savedPayload(h)).coverStyle;
    expect(style.layout, NotebookCoverLayout.spine);
    expect(style.texture, NotebookCoverTexture.diagonal);
    await h.unmount();
  });

  testWidgets('adjust framing writes the new crop back to the form', (
    tester,
  ) async {
    late String cover;
    final (h, _) = await open(
      tester,
      seed: (h) async {
        cover = await writeImage(tester, 'cover');
        return h.notebook('旅行', payload: NotebookPayload(coverPath: cover));
      },
    );
    // 取景页解码图片期间有加载指示（不会 settle），点按后手动推进。
    await tester.scrollUntilVisible(find.text('调整取景'), 200, scrollable: page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('调整取景'));
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      if (find.byType(NotebookCoverCropViewport).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(NotebookCoverCropViewport),
      const Offset(-40, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    final payload = await savedPayload(h);
    expect(payload.coverPath, cover);
    expect(payload.coverStyle.focusX, greaterThan(0));
    expect(payload.coverStyle.zoom, 1);
    await h.unmount();
  });

  testWidgets('picks a cover from the images in the notebook diaries', (
    tester,
  ) async {
    mockDocuments();
    late String older;
    late String newer;
    final (h, _) = await open(
      tester,
      seed: (h) async {
        older = await writeImage(tester, 'older');
        newer = await writeImage(tester, 'newer');
        final outside = await writeImage(tester, 'outside');
        final id = await h.notebook('旅行');
        await imageDiary(
          h,
          '旧的',
          image: older,
          notebookIds: <String>[id],
          createdAt: DateTime(2024, 1, 1),
        );
        await imageDiary(
          h,
          '新的',
          cover: newer,
          // 正文里引用的文件已不存在：跳过。
          image: '${temp.path}/missing.png',
          notebookIds: <String>[id],
          createdAt: DateTime(2025, 1, 1),
        );
        await imageDiary(h, '别处', image: outside);
        return id;
      },
    );
    await tapVisible(tester, find.text('从日记中选'));
    await h.settleAll();
    final tiles = find.byType(NotebookCoverPhotoTile);
    expect(tiles, findsNWidgets(2));
    expect(
      tester.widget<NotebookCoverPhotoTile>(tiles.first).path,
      newer,
      reason: 'newest diary first',
    );

    await tester.tap(tiles.last);
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(NotebookCoverPhotoPicker), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    final saved = (await savedPayload(h)).coverPath!;
    // 拷贝进封面私有目录，不引用日记原图。
    expect(saved, isNot(older));
    expect(saved, startsWith('${temp.path}/documents/'));
    expect(
      await tester.runAsync(() => File(saved).readAsBytes()),
      await tester.runAsync(() => File(older).readAsBytes()),
    );
    await h.unmount();
  });

  testWidgets('shows an empty state when the diaries have no images', (
    tester,
  ) async {
    final (h, _) = await open(
      tester,
      seed: (h) async {
        final id = await h.notebook('旅行');
        await h.diary('只有文字', notebookIds: <String>[id]);
        return id;
      },
    );
    await tapVisible(tester, find.text('从日记中选'));
    await h.settleAll();
    expect(find.text('这本日记本的日记里还没有图片'), findsOneWidget);
    expect(find.byType(NotebookCoverPhotoTile), findsNothing);
    await h.unmount();
  });

  test('photo sources run newest first, deduplicated and local only', () {
    final rows = <DiaryMediaContent>[
      const DiaryMediaContent(
        diaryId: 'a',
        cover: '/img/a.png',
        content: '[{"insert":{"image":"/img/shared.png"}},{"insert":"\\n"}]',
      ),
      const DiaryMediaContent(
        diaryId: 'b',
        cover: 'asset:assets/img/sample.webp',
        content:
            '[{"insert":{"image":"https://example.com/x.png"}},'
            '{"insert":{"image":"/img/shared.png"}},'
            '{"insert":{"image":"/img/gone.png"}},{"insert":"\\n"}]',
      ),
    ];
    final sources = notebookCoverPhotoSources(
      rows,
      exists: (path) => path != '/img/gone.png',
    );
    expect(sources, <String>['/img/shared.png', '/img/a.png']);
  });
}
