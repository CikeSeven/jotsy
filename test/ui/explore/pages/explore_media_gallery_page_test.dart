import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/pages/explore_image_viewer_page.dart';
import 'package:node_diary/ui/explore/pages/explore_media_gallery_page.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';

import '../../../support/expressive_test_theme.dart';
import '../explore_test_fixtures.dart';

void main() {
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

        final viewer = tester.widget<ExploreImageViewerPage>(
          find.byType(ExploreImageViewerPage),
        );
        expect(viewer.mediaItems, hasLength(3));
        expect(viewer.initialIndex, 2);
        expect(find.text('3 / 3'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(
          find
              .descendant(
                of: find.byType(ExploreImageViewerPage),
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
