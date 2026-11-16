import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/models/gallery_level.dart';
import 'package:node_diary/ui/explore/pages/explore_media_gallery_page.dart';
import 'package:node_diary/ui/explore/widgets/gallery_cell.dart';
import 'package:node_diary/ui/explore/widgets/gallery_rows_sliver.dart';
import 'package:node_diary/ui/widgets/fast_scroller/fast_scroller.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../../support/expressive_test_theme.dart';
import '../explore_test_fixtures.dart';

void main() {
  _registerFirstFrameTest();
  _registerWideWindowTests();
  for (final brightness in Brightness.values) {
    testWidgets(
      'shows all diary images and opens the tapped image in $brightness',
      (tester) async {
        final database = _GalleryDatabase();
        addTearDown(database.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              theme: expressiveTestTheme(brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ExploreMediaGalleryPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final thumbs = find.byType(GalleryCell);
        expect(
          tester.widgetList<GalleryCell>(thumbs).map((item) => item.source),
          ['/cover.jpg', '/first.jpg', '/second.jpg'],
        );
        // 快速滚动条与日记列表同一个组件（内容不够长时不出现）。
        expect(find.byType(FastScroller), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(thumbs.at(2));
        await tester.pumpAndSettle();

        final viewer = tester.widget<ImageViewerPage>(
          find.byType(ImageViewerPage),
        );
        expect(viewer.items.map((item) => item.source), [
          '/cover.jpg',
          '/first.jpg',
          '/second.jpg',
        ]);
        expect(viewer.initialIndex, 2);
        // 每张图带上所在日记，看图页长按面板可以直接打开它。
        expect(viewer.items.map((item) => item.diaryId).toSet(), {'diary-1'});
        expect(viewer.onOpenDiary, isNotNull);
        // 页码数字单独滚动切换，可见文本拆成两段；读屏仍读整句页码。
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('3 / 3'), findsOneWidget);
        semantics.dispose();
        expect(tester.takeException(), isNull);

        await tester.tap(
          find
              .descendant(
                of: find.byType(ImageViewerPage),
                matching: find.byType(IconButton),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(GalleryCell), findsNWidgets(3));
        await _unmount(tester);
      },
    );
  }
}

void _registerFirstFrameTest() {
  testWidgets('opening the gallery never flashes the empty state', (
    tester,
  ) async {
    final database = _GalleryDatabase();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExploreMediaGalleryPage(),
        ),
      ),
    );
    final l10n = tester.element(find.byType(ExploreMediaGalleryPage)).l10n;
    // 首次加载在首帧之后才发起：这期间不能先露出“暂无媒体”。
    for (var frame = 0; frame < 6; frame++) {
      expect(find.text(l10n.autoT0055), findsNothing, reason: '$frame');
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCell), findsNWidgets(3));
    expect(find.text(l10n.autoT0055), findsNothing);
    await _unmount(tester);
  });
}

void _registerWideWindowTests() {
  test('gallery columns grow every 120 but never drop below four', () {
    expect(GalleryZoom.initial, GalleryZoom.day);
    expect(GalleryZoom.day.columnsFor(320), 4);
    expect(GalleryZoom.day.columnsFor(599), 4);
    expect(GalleryZoom.day.columnsFor(800), 6);
    expect(GalleryZoom.day.columnsFor(1280), 10);
  });

  test(
    'zoom levels are 4 / 5 / 8 / 16 columns, by day, day, month and year',
    () {
      expect(GalleryZoom.values.map((zoom) => zoom.columns), <int>[
        4,
        5,
        8,
        16,
      ]);
      expect(GalleryZoom.values.map((zoom) => zoom.level), <GalleryLevel>[
        GalleryLevel.day,
        GalleryLevel.day,
        GalleryLevel.month,
        GalleryLevel.year,
      ]);
      for (final zoom in GalleryZoom.values) {
        expect(zoom.columnsFor(360), zoom.columns, reason: '$zoom');
        expect(
          zoom.columnsFor(1280),
          greaterThan(zoom.columns),
          reason: '$zoom',
        );
      }
      expect(GalleryZoom.day.zoomedIn, isNull);
      expect(GalleryZoom.year.zoomedOut, isNull);
      expect(GalleryZoom.day.zoomedOut, GalleryZoom.dayDense);
      // 同一族的档位共用一份解码，族内换档不重新解码。
      expect(GalleryZoom.dayDense.decodeReference, GalleryZoom.day);
      expect(GalleryZoom.year.decodeReference, GalleryZoom.month);
    },
  );

  for (final (width, columns) in <(double, int)>[(400, 4), (1280, 10)]) {
    testWidgets('a $width wide window lays the gallery out in $columns '
        'columns', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final database = _GalleryDatabase();
      addTearDown(database.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ExploreMediaGalleryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = tester
          .widget<GalleryRowsSliver>(find.byType(GalleryRowsSliver))
          .grid;
      expect(grid.columns, columns);
      // 缩略图不随窗口变宽而放大成大图。
      final thumb = tester.getSize(find.byType(GalleryCell).first);
      expect(thumb.width, lessThanOrEqualTo(160));
      expect(thumb.width, closeTo(grid.cellExtent, 0.01));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
}

/// 页面订阅了日记本等 drift 流：卸载后再走一拍，让 drift 关流的计时器跑完。
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

class _GalleryDatabase extends AppDatabase {
  _GalleryDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<List<DiaryMediaContent>> getGalleryMediaPage({
    required int limit,
    required int offset,
    DiaryListScope scope = DiaryListScope.all,
    bool newestFirst = true,
    DateTime? from,
    DateTime? to,
  }) async => [
    createExploreTestMediaRow(
      cover: '/cover.jpg',
      content:
          '[{"insert":{"image":"/first.jpg"}},'
          '{"insert":{"image":"/cover.jpg"}},'
          '{"insert":{"image":"/second.jpg"}}]',
    ),
  ];
}
