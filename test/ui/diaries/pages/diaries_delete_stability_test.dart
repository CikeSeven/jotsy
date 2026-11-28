import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_comments_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/providers/diary_timeline_provider.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 日记首页删除与位置稳定性端到端回归测试：覆盖瀑布流与列表布局、明暗主题。
void main() {
  for (final brightness in Brightness.values) {
    for (final layout in DiaryLayoutMode.values) {
      testWidgets(
        '${layout.name} multi-select delete deep in the list keeps scroll '
        'position and does not remount surviving cards (${brightness.name})',
        (WidgetTester tester) async {
          final store = _ReactiveDiaryStore(List.generate(40, _diary));
          final db = _FakeDeleteDatabase(store);
          addTearDown(() async {
            await store.close();
            await db.close();
          });

          await _pumpDiariesPage(
            tester,
            store: store,
            db: db,
            brightness: brightness,
            layout: layout,
          );

          final position = _scrollPosition(tester);
          // 先加载两页并滚到列表下半段（远超 cacheExtent）。
          for (final step in <double>[600, 1200, 1800]) {
            position.jumpTo(step.clamp(0.0, position.maxScrollExtent));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          position.jumpTo(
            (position.maxScrollExtent - 350).clamp(
              0.0,
              position.maxScrollExtent,
            ),
          );
          await tester.pumpAndSettle();

          final offsetBefore = position.pixels;
          expect(offsetBefore, greaterThan(600));

          // 找出当前完全露在视口中的卡片，删掉中间一篇，验证前后存活卡片都不重挂。
          final visibleIds = _visibleDiaryIds(tester);
          expect(visibleIds.length, greaterThanOrEqualTo(3));
          final keepBeforeId = visibleIds.first;
          final deleteId = visibleIds[visibleIds.length ~/ 2];
          final keepAfterId = visibleIds.last;
          final keepBeforeEl = _cardElement(tester, keepBeforeId);
          final keepAfterEl = _cardElement(tester, keepAfterId);
          final keepBeforeTop = tester.getTopLeft(_cardFinder(keepBeforeId)).dy;

          // 长按进入多选 -> 点顶栏删除 -> 确认删除。
          await tester.longPress(_cardFinder(deleteId));
          await tester.pumpAndSettle();
          final l10n = tester.element(find.byType(DiariesPage)).l10n;
          await tester.tap(find.byTooltip(l10n.commonDelete));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.commonDelete).last);

          // 推进数据库即时写完后的首帧、退场中段、让位动画全过程。
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          // 数据流抢先删掉条目时，退场卡片仍在原位继续收起/淡出，不被 10ms 截断。
          expect(_cardFinder(deleteId), findsOneWidget);

          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 20));
            // 任何一帧都绝不能突然弹回上半部分。
            expect(
              position.pixels,
              greaterThan(offsetBefore - 260),
              reason: 'Must not jump toward top on frame $frame',
            );
          }
          await tester.pumpAndSettle();

          expect(_cardFinder(deleteId), findsNothing);
          expect(position.pixels, closeTo(offsetBefore, 40));
          expect(
            tester.getTopLeft(_cardFinder(keepBeforeId)).dy,
            closeTo(keepBeforeTop, 2.0),
          );
          // 存活卡片全程保持同一个 Element（不卸载重挂、不触发整表闪烁）。
          expect(_cardElement(tester, keepBeforeId), same(keepBeforeEl));
          expect(_cardElement(tester, keepAfterId), same(keepAfterEl));

          // 等 4 秒撤销提示关闭后再次核对元素与滚动位置不受影响。
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          expect(_cardElement(tester, keepBeforeId), same(keepBeforeEl));
          expect(_cardElement(tester, keepAfterId), same(keepAfterEl));
          expect(position.pixels, closeTo(offsetBefore, 40));

          // 滚回列表顶部：首篇紧贴顶部，无错位与异常。
          position.jumpTo(0);
          await tester.pumpAndSettle();
          expect(_cardFinder('diary-0'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${layout.name} off-screen delete and insert above viewport keep '
        'visible anchor stationary (${brightness.name})',
        (WidgetTester tester) async {
          final store = _ReactiveDiaryStore(List.generate(40, _diary));
          final db = _FakeDeleteDatabase(store);
          addTearDown(() async {
            await store.close();
            await db.close();
          });

          await _pumpDiariesPage(
            tester,
            store: store,
            db: db,
            brightness: brightness,
            layout: layout,
          );

          final position = _scrollPosition(tester);
          for (final step in <double>[600, 1200, 1800]) {
            position.jumpTo(step.clamp(0.0, position.maxScrollExtent));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(800));

          final visibleIds = _visibleDiaryIds(tester);
          expect(visibleIds, isNotEmpty);
          final anchorId = visibleIds.first;
          final anchorEl = _cardElement(tester, anchorId);
          final anchorY = tester.getTopLeft(_cardFinder(anchorId)).dy;

          // 删除视口上方看不见的第 0 篇日记（模拟同步/别处删除）。
          store.removeIds(<String>['diary-0']);
          await tester.pumpAndSettle();

          expect(
            tester.getTopLeft(_cardFinder(anchorId)).dy,
            closeTo(anchorY, 2.0),
          );
          expect(_cardElement(tester, anchorId), same(anchorEl));

          // 在视口上方索引 0 恢复第 0 篇日记：锚点依然纹丝不动。
          store.restoreIds(<String>['diary-0']);
          await tester.pumpAndSettle();

          expect(
            tester.getTopLeft(_cardFinder(anchorId)).dy,
            closeTo(anchorY, 2.0),
          );
          expect(_cardElement(tester, anchorId), same(anchorEl));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('toggling theme brightness preserves diaries scroll position', (
    WidgetTester tester,
  ) async {
    final store = _ReactiveDiaryStore(List.generate(40, _diary));
    final db = _FakeDeleteDatabase(store);
    addTearDown(() async {
      await store.close();
      await db.close();
    });

    final brightnessNotifier = ValueNotifier<Brightness>(Brightness.light);
    addTearDown(brightnessNotifier.dispose);

    await _pumpDiariesPage(
      tester,
      store: store,
      db: db,
      brightness: Brightness.light,
      layout: DiaryLayoutMode.waterfall,
      brightnessListenable: brightnessNotifier,
    );

    final position = _scrollPosition(tester);
    position.jumpTo(900);
    await tester.pumpAndSettle();
    final offsetBefore = position.pixels;
    expect(offsetBefore, greaterThan(700));

    brightnessNotifier.value = Brightness.dark;
    await tester.pumpAndSettle();

    expect(_scrollPosition(tester).pixels, closeTo(offsetBefore, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the only diary transitions cleanly to empty state', (
    WidgetTester tester,
  ) async {
    final store = _ReactiveDiaryStore(<DiaryWithTags>[_diary(0)]);
    final db = _FakeDeleteDatabase(store);
    addTearDown(() async {
      await store.close();
      await db.close();
    });

    await _pumpDiariesPage(
      tester,
      store: store,
      db: db,
      brightness: Brightness.light,
      layout: DiaryLayoutMode.waterfall,
    );

    await tester.longPress(_cardFinder('diary-0'));
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(DiariesPage)).l10n;
    await tester.tap(find.byTooltip(l10n.commonDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete).last);
    await tester.pumpAndSettle();

    expect(_cardFinder('diary-0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ReactiveDiaryStore {
  _ReactiveDiaryStore(List<DiaryWithTags> initial)
    : _all = List<DiaryWithTags>.of(initial);

  final List<DiaryWithTags> _all;
  final Set<String> _deletedIds = <String>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<DiaryWithTags> get active => <DiaryWithTags>[
    for (final item in _all)
      if (!_deletedIds.contains(item.diary.diaryId)) item,
  ];

  Stream<PagedDiariesResult> watchPage(DiaryPageQuery query) {
    PagedDiariesResult snapshot() {
      final list = active;
      final hasMore = list.length > query.limit;
      return PagedDiariesResult(
        items: hasMore ? list.take(query.limit).toList(growable: false) : list,
        limit: query.limit,
        hasMore: hasMore,
      );
    }

    late StreamController<PagedDiariesResult> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<PagedDiariesResult>(
      onListen: () {
        controller.add(snapshot());
        sub = _changes.stream.listen((_) => controller.add(snapshot()));
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  void removeIds(Iterable<String> ids) {
    _deletedIds.addAll(ids);
    _changes.add(null);
  }

  void restoreIds(Iterable<String> ids) {
    _deletedIds.removeAll(ids);
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}

class _FakeDeleteDatabase extends AppDatabase {
  _FakeDeleteDatabase(this.store) : super.forTesting(NativeDatabase.memory());

  final _ReactiveDiaryStore store;

  @override
  Future<void> softDeleteDiaries(Iterable<String> diaryIds) async {
    store.removeIds(diaryIds);
  }

  @override
  Future<void> restoreDiaries(Iterable<String> diaryIds) async {
    store.restoreIds(diaryIds);
  }
}

Future<void> _pumpDiariesPage(
  WidgetTester tester, {
  required _ReactiveDiaryStore store,
  required AppDatabase db,
  required Brightness brightness,
  required DiaryLayoutMode layout,
  ValueNotifier<Brightness>? brightnessListenable,
}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  await settings.setDiaryLayoutModeRaw(layout.name);

  Widget buildApp(Brightness activeBrightness) {
    final theme = expressiveTestTheme(
      activeBrightness,
    ).copyWith(platform: TargetPlatform.android);
    return MaterialApp(
      theme: theme,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiariesPage(pageBackgroundColor: theme.colorScheme.surface),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        diaryDraftCountProvider.overrideWith((ref) => Stream.value(0)),
        diaryCommentCountsProvider.overrideWith(
          (ref) => Stream.value(const <String, int>{}),
        ),
        notebooksProvider.overrideWith(
          (ref) => Stream.value(const <NotebookView>[]),
        ),
        settingsServiceProvider.overrideWith((ref) async => settings),
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
        diaryTimelineProvider.overrideWith(
          (ref, query) => Stream.value(const <DiaryTimelineEntry>[]),
        ),
        pagedDiariesProvider.overrideWith(
          (ref, query) => store.watchPage(query),
        ),
      ],
      child: brightnessListenable == null
          ? buildApp(brightness)
          : ValueListenableBuilder<Brightness>(
              valueListenable: brightnessListenable,
              builder: (BuildContext context, Brightness value, Widget? _) =>
                  buildApp(value),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _scrollPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Finder _cardFinder(String diaryId) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is DiaryCard && widget.diary.diary.diaryId == diaryId,
);

Element _cardElement(WidgetTester tester, String diaryId) =>
    tester.element(_cardFinder(diaryId));

List<String> _visibleDiaryIds(WidgetTester tester) {
  final result = <String>[];
  for (final element in find.byType(DiaryCard).evaluate()) {
    final card = element.widget as DiaryCard;
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    if (top >= 120 && bottom <= 760) {
      result.add(card.diary.diary.diaryId);
    }
  }
  return result;
}

DiaryWithTags _diary(int index) => DiaryWithTags(
  diary: Diary(
    id: index + 1,
    diaryId: 'diary-$index',
    title: 'Diary $index',
    content: '[{"insert":"Content\\n"}]',
    contentText: List.filled(
      index % 4 + 1,
      'Diary body line $index.',
    ).join(' '),
    metadata: '{}',
    createdAt: DateTime(2026, 10, 4).subtract(Duration(hours: index)),
    updatedAt: DateTime(2026, 10, 4).subtract(Duration(hours: index)),
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  ),
  tags: const <Tag>[],
);
