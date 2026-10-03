import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';

import '../../../support/expressive_test_theme.dart';

/// Genuine Home-like page fixture; providers are mocked, but its nested
/// scrollables and platform gesture settings use the real Flutter pipeline.
final Finder tagBarFinder = find.byType(DiaryTagFilterBar);

double tagExpansionProgress(WidgetTester tester) =>
    tester.widget<DiaryTagFilterBar>(tagBarFinder).expansionProgress.value;

ScrollableState verticalDiaryScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
          )
          .first,
    );

Future<void> dragTagPanel(
  WidgetTester tester, {
  required Offset start,
  required Offset step,
  int steps = 10,
}) async {
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 40));
  for (var index = 0; index < steps; index++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.takeException(), isNull);
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> pumpTagPage(
  WidgetTester tester, {
  int tagCount = 3,
  Brightness brightness = Brightness.light,
  List<DiaryWithTags> diaries = const <DiaryWithTags>[],
  double? deviceTouchSlop,
}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = await SettingsService.create();
  final theme = expressiveTestTheme(
    brightness,
  ).copyWith(platform: TargetPlatform.android);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        tagListProvider.overrideWith(
          (ref) => Stream.value(<Tag>[
            for (var id = 1; id <= tagCount; id++)
              Tag(id: id, name: 'Tag $id', color: 0xff336699),
          ]),
        ),
        pagedDiariesProvider.overrideWith(
          (ref, query) => Stream.value(
            PagedDiariesResult(
              items: diaries,
              limit: query.limit,
              hasMore: false,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            gestureSettings: deviceTouchSlop == null
                ? null
                : DeviceGestureSettings(touchSlop: deviceTouchSlop),
          ),
          child: child!,
        ),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PageView(
          // Match Home's horizontal page recognizer as well as the real
          // DiariesPage slivers; a standalone Column misses both conflicts.
          physics: const PageScrollPhysics(),
          children: <Widget>[
            DiariesPage(pageBackgroundColor: theme.colorScheme.surface),
            ColoredBox(color: theme.colorScheme.surface),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tagBarFinder, findsOneWidget);
  expect(tester.takeException(), isNull);
}

List<DiaryWithTags> createGestureDiaries(int count) => <DiaryWithTags>[
  for (var index = 1; index <= count; index++)
    DiaryWithTags(
      diary: Diary(
        id: index,
        diaryId: 'diary-$index',
        title: 'Diary $index',
        content: '[{"insert":"Content\\n"}]',
        contentText: 'Content',
        metadata: '{}',
        createdAt: DateTime(2026, 10, 4),
        updatedAt: DateTime(2026, 10, 4),
        isArchived: false,
        isPinned: false,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    ),
];
