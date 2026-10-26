import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/pages/explore_media_gallery_page.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';
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

        final thumbs = find.byType(ExploreMediaThumb);
        expect(
          tester
              .widgetList<ExploreMediaThumb>(thumbs)
              .map((item) => item.source),
          ['/cover.jpg', '/first.jpg', '/second.jpg'],
        );
        expect(tester.takeException(), isNull);

        await tester.tap(
          find
              .descendant(
                of: find.byType(SliverGrid),
                matching: find.byType(InkWell),
              )
              .at(2),
        );
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
        expect(find.byType(ExploreMediaThumb), findsNWidgets(3));
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
    expect(find.byType(ExploreMediaThumb), findsNWidgets(3));
    expect(find.text(l10n.autoT0055), findsNothing);
  });
}

void _registerWideWindowTests() {
  test('gallery columns grow every 160 but never drop below three', () {
    expect(ExploreMediaGalleryPage.galleryColumns(320), 3);
    expect(ExploreMediaGalleryPage.galleryColumns(599), 3);
    expect(ExploreMediaGalleryPage.galleryColumns(800), 5);
    expect(ExploreMediaGalleryPage.galleryColumns(1280), 8);
  });

  for (final (width, columns) in <(double, int)>[(400, 3), (1280, 8)]) {
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

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, columns);
      // 缩略图不随窗口变宽而放大成大图。
      final thumb = tester.getSize(find.byType(ExploreMediaThumb).first);
      expect(thumb.width, lessThanOrEqualTo(160));
      expect(tester.takeException(), isNull);
    });
  }
}

class _GalleryDatabase extends AppDatabase {
  _GalleryDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<List<Diary>> getActiveDiariesPage({
    required int limit,
    required int offset,
  }) async => [
    createExploreTestDiary(
      cover: '/cover.jpg',
      content:
          '[{"insert":{"image":"/first.jpg"}},'
          '{"insert":{"image":"/cover.jpg"}},'
          '{"insert":{"image":"/second.jpg"}}]',
    ),
  ];
}
