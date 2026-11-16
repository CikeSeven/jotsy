import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/providers/calendar_display_options_provider.dart';
import 'package:node_diary/ui/explore/pages/explore_media_gallery_page.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';
import 'package:node_diary/ui/explore/widgets/gallery_group_header.dart';
import 'package:node_diary/ui/explore/widgets/gallery_time_range_cells.dart';
import 'package:node_diary/ui/explore/widgets/gallery_time_range_picker.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';

import '../../../support/expressive_test_theme.dart';

/// 媒体画廊顶栏 ⋮ 菜单与分组标题。
void main() {
  Future<(AppDatabase, AppLocalizations)> pump(
    WidgetTester tester, {
    AppFeatures features = AppFeatures.defaults,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final open = await db.createNotebook(name: 'Open book');
    final locked = await db.createNotebook(
      name: 'Locked book',
      visibility: NotebookVisibility.locked,
    );
    final now = DateTime.now();
    for (final (title, created, books) in <(String, DateTime, List<String>)>[
      ('today', now, <String>[open]),
      ('old', DateTime(now.year - 1, 3, 5), const <String>[]),
      ('secret', now, <String>[locked]),
    ]) {
      await db.createDiary(
        title: title,
        contentDocJson: '[{"insert":{"image":"/$title.jpg"}},{"insert":"\\n"}]',
        contentText: title,
        metadataJson: '{}',
        notebookIds: books,
        createdAtOverride: created,
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appFeaturesProvider.overrideWith(() => _FixedFeatures(features)),
          calendarDisplayOptionsProvider.overrideWith(
            (ref) => Stream.value(const CalendarDisplayOptions()),
          ),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExploreMediaGalleryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(ExploreMediaGalleryPage)).l10n;
    return (db, l10n);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(ExpressiveMenuButton));
    await tester.pumpAndSettle();
  }

  List<String> sources(WidgetTester tester) => tester
      .widgetList<ExploreMediaThumb>(find.byType(ExploreMediaThumb))
      .map((thumb) => thumb.source)
      .toList();

  testWidgets('photos are grouped by day with today on top; private ones '
      'stay out', (tester) async {
    final (_, l10n) = await pump(tester);
    expect(sources(tester), <String>['/today.jpg', '/old.jpg']);
    expect(
      find.widgetWithText(GalleryGroupHeader, l10n.calendarRelativeToday),
      findsOneWidget,
    );
    expect(find.byType(GalleryGroupHeader), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('pinching and Ctrl + wheel step through the zoom levels', (
    tester,
  ) async {
    // 手机宽度：各档就是它们的基本列数。
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (_, l10n) = await pump(tester);
    int columns() =>
        (tester.widget<SliverGrid>(find.byType(SliverGrid).first).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;
    expect(columns(), 3);

    // 两指捏近：缩小一档（4 列，仍按天）。
    final center = tester.getCenter(find.byType(CustomScrollView));
    final a = await tester.startGesture(center - const Offset(60, 0));
    final b = await tester.startGesture(center + const Offset(60, 0));
    await a.moveBy(const Offset(8, 0));
    await b.moveBy(const Offset(-8, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(columns(), 4);

    // 按住 Ctrl 向下滚：再缩小一档，按月分组。
    final mouse = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(mouse.hover(center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(columns(), 8);
    expect(find.text(l10n.calendarRelativeToday), findsNothing);
    await unmount(tester);
  });

  testWidgets('the menu offers notebook, date range and sort; locked '
      'notebooks are not listed', (tester) async {
    final (_, l10n) = await pump(tester);
    await openMenu(tester);
    expect(find.byType(ExpressiveSubmenuItem), findsNWidgets(3));

    await tester.tap(find.text(l10n.exploreGalleryNotebookFilter));
    await tester.pumpAndSettle();
    expect(find.text('Open book'), findsOneWidget);
    expect(find.text('Locked book'), findsNothing);

    // 只看未收录：今天那张在日记本里，不再出现。
    await tester.tap(find.text(l10n.exploreGalleryNotebookUnfiled));
    await tester.pumpAndSettle();
    expect(sources(tester), <String>['/old.jpg']);
    await unmount(tester);
  });

  testWidgets('without the notebooks feature the notebook filter is gone', (
    tester,
  ) async {
    final (_, l10n) = await pump(
      tester,
      features: const AppFeatures(notebooks: false),
    );
    await openMenu(tester);
    expect(find.byType(ExpressiveSubmenuItem), findsNWidgets(2));
    expect(find.text(l10n.exploreGalleryNotebookFilter), findsNothing);
    await unmount(tester);
  });

  testWidgets('oldest first flips the groups', (tester) async {
    final (_, l10n) = await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text(l10n.exploreGallerySort));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.exploreGallerySortOldest));
    await tester.pumpAndSettle();
    expect(sources(tester), <String>['/old.jpg', '/today.jpg']);
    await unmount(tester);
  });

  testWidgets('back from the month layer returns to the days, then closes '
      'the submenu', (tester) async {
    final (_, l10n) = await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text(l10n.exploreGalleryTimeRange));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTimeRangePicker), findsOneWidget);

    // 点“月”胶囊打开选月层，系统返回先退回日期页，菜单还在。
    await tester.tap(find.byType(GalleryTimeHeaderChip).first);
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTimeRangePicker), findsOneWidget);

    // 再按一次才收回二级菜单。
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTimeRangePicker), findsNothing);
    expect(find.byType(ExploreMediaGalleryPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('applying a day keeps only that day', (tester) async {
    final (_, l10n) = await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text(l10n.exploreGalleryTimeRange));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(GalleryTimeRangePicker),
            matching: find.text('${DateTime.now().day}'),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTimeRangePicker), findsNothing);
    expect(sources(tester), <String>['/today.jpg']);
    await unmount(tester);
  });
}

class _FixedFeatures extends AppFeaturesNotifier {
  _FixedFeatures(this.features);

  final AppFeatures features;

  @override
  AppFeatures build() => features;
}
