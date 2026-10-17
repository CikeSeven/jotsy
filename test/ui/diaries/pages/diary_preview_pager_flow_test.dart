import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/locked_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_pager_view.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_view.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

const String _todoContent =
    '[{"insert":"买菜"},{"insert":"\\n","attributes":{"list":"unchecked"}}]';

String _textContent(String text) => '[{"insert":"$text\\n"}]';

/// 按标题依次建日记（更新时间递减，按“最近更新”排序时就是这个顺序）。
Future<List<DiaryWithTags>> _seed(
  WidgetTester tester,
  AppDatabase database,
  List<String> titles, {
  Map<String, String> contents = const <String, String>{},
  Set<String> locked = const <String>{},
}) async {
  return (await tester.runAsync(() async {
    final base = DateTime(2026, 10, 1, 9);
    final result = <DiaryWithTags>[];
    for (var i = 0; i < titles.length; i++) {
      final title = titles[i];
      final id = await database.createDiary(
        title: title,
        contentDocJson: contents[title] ?? _textContent('$title 的正文'),
        contentText: '$title 的正文',
        metadataJson: '{}',
        createdAtOverride: base.subtract(Duration(days: i)),
        capsuleLockedAt: locked.contains(title) ? base : null,
        capsuleUnlockAt: locked.contains(title)
            ? DateTime.now().add(const Duration(days: 365))
            : null,
      );
      result.add((await database.getDiaryWithTagsByDiaryId(id))!);
    }
    return result;
  }))!;
}

class _Harness {
  _Harness(this.database, this.results);

  final AppDatabase database;
  final List<Object?> results;
}

/// 列表页替身：点“打开”推入预览页，记下返回结果。
Future<_Harness> _open(
  WidgetTester tester,
  AppDatabase database, {
  required String diaryId,
  DiaryPreviewSequence? sequence,
  DiaryWithTags? initialDetail,
  DiaryPreviewStyle style = DiaryPreviewStyle.defaults,
  DiaryPreviewBehavior behavior = DiaryPreviewBehavior.defaults,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.diary_preview_style': ?DiaryPreviewSettings(
      current: style,
      behavior: behavior,
    ).encode(),
  });
  final settings = await SettingsService.create();
  final results = <Object?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .push<DiaryPreviewResult?>(
                      MaterialPageRoute<DiaryPreviewResult?>(
                        builder: (BuildContext context) => DiaryPreviewPage(
                          diaryId: diaryId,
                          initialDetail: initialDetail,
                          sequence: sequence,
                        ),
                      ),
                    )
                    .then(results.add),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  return _Harness(database, results);
}

Future<void> _swipe(WidgetTester tester, {bool forward = true}) async {
  final gesture = await tester.startGesture(const Offset(200, 500));
  for (var i = 0; i < 30; i++) {
    await gesture.moveBy(Offset(forward ? -10 : 10, 0));
    await tester.pump(const Duration(milliseconds: 8));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).last));

const DiaryPreviewStyle _positionTitle = DiaryPreviewStyle(
  page: DiaryPreviewPageStyle(topBarTitle: DiaryPreviewTopBarTitle.position),
);

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('swipes through the list order with a position title', (
    tester,
  ) async {
    final diaries = await _seed(tester, database, <String>['甲', '乙', '丙']);
    await _open(
      tester,
      database,
      diaryId: diaries[1].diary.diaryId,
      initialDetail: diaries[1],
      sequence: DiaryPreviewSequence.fromItems(diaries),
      style: _positionTitle,
    );
    expect(find.text('乙'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await _swipe(tester);
    expect(find.text('丙'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);

    await _swipe(tester, forward: false);
    await _swipe(tester, forward: false);
    expect(find.text('甲'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('single entries and one-item lists do not page', (tester) async {
    final diaries = await _seed(tester, database, <String>['甲']);
    await _open(
      tester,
      database,
      diaryId: diaries[0].diary.diaryId,
      sequence: DiaryPreviewSequence.fromItems(diaries),
      style: _positionTitle,
    );
    expect(find.byType(DiaryPagerView), findsNothing);
    // 单篇打开时“位置”标题退回“日记”。
    expect(find.text(_l10n(tester).autoT0120), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('deleting after a swipe returns the diary on screen', (
    tester,
  ) async {
    final diaries = await _seed(tester, database, <String>['甲', '乙']);
    final harness = await _open(
      tester,
      database,
      diaryId: diaries[0].diary.diaryId,
      sequence: DiaryPreviewSequence.fromItems(diaries),
    );
    await _swipe(tester);
    final l10n = _l10n(tester);
    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.commonDelete));
    await tester.pumpAndSettle();

    expect(harness.results, <Object?>[
      DiaryPreviewResult.deleted(diaries[1].diary.diaryId),
    ]);
    final deleted = await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaries[1].diary.diaryId),
    );
    expect(deleted?.diary.isDeleted, isTrue);
    await _unmount(tester);
  });

  testWidgets('the end of the page offers previous and next diaries', (
    tester,
  ) async {
    final diaries = await _seed(tester, database, <String>['甲', '乙', '丙']);
    await _open(
      tester,
      database,
      diaryId: diaries[1].diary.diaryId,
      sequence: DiaryPreviewSequence.fromItems(diaries),
      style: const DiaryPreviewStyle(
        navigation: DiaryPreviewNavigationStyle(neighborCards: true),
      ),
    );
    final l10n = _l10n(tester);
    final next = find.bySemanticsLabel('${l10n.diaryPreviewNext}: 丙');
    expect(
      find.bySemanticsLabel('${l10n.diaryPreviewPrevious}: 甲'),
      findsOneWidget,
    );
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('丙'), findsOneWidget);
    // 最后一篇只有“上一篇”。
    expect(
      find.bySemanticsLabel(RegExp('^${l10n.diaryPreviewNext}')),
      findsNothing,
    );
    await _unmount(tester);
  });

  testWidgets('a todo ticked right before paging away is saved and an '
      'archived diary stays archived', (tester) async {
    // 减少动画时“下一篇”直接跳页：整个过程只走几帧，远短于 260ms 的防抖，
    // 勾选只能靠页面被回收时的补写落库。
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final diaries = await _seed(
      tester,
      database,
      <String>['甲', '乙', '丙'],
      contents: <String, String>{'甲': _todoContent},
    );
    final archivedId = diaries[0].diary.diaryId;
    await tester.runAsync(() => database.archiveDiary(archivedId));
    await _open(
      tester,
      database,
      diaryId: archivedId,
      sequence: DiaryPreviewSequence.fromItems(diaries),
      style: const DiaryPreviewStyle(
        navigation: DiaryPreviewNavigationStyle(neighborCards: true),
      ),
    );
    final l10n = _l10n(tester);
    Finder checkboxPoint() => find.byWidgetPredicate(
      (Widget widget) => widget.runtimeType.toString() == 'QuillCheckboxPoint',
    );
    // 直接调用点按回调：真实点按的水波纹会让页面在动画期间保活
    // （InkWell 的 AutomaticKeepAlive），测试里就等不到回收。
    void press(Finder target) => tester
        .widget<InkWell>(
          find.descendant(of: target, matching: find.byType(InkWell)).first,
        )
        .onTap!();
    press(checkboxPoint());
    await tester.pump();
    for (final title in <String>['乙', '丙']) {
      final next = find.bySemanticsLabel(RegExp('^${l10n.diaryPreviewNext}'));
      await tester.ensureVisible(next);
      await tester.pump();
      press(next);
      await tester.pump();
      expect(find.text(title), findsOneWidget);
    }
    expect(
      find.byKey(
        PageStorageKey<String>('diary_preview_page_$archivedId'),
        skipOffstage: false,
      ),
      findsNothing,
      reason: 'the first page has been recycled',
    );

    final saved = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(archivedId),
    ))!;
    expect(saved.diary.content, contains('"checked"'));
    expect(saved.diary.isArchived, isTrue);
    expect(saved.diary.isDeleted, isFalse);

    // 翻回来看到的是保存后的勾选状态。
    await tester.pumpAndSettle();
    await _swipe(tester, forward: false);
    await _swipe(tester, forward: false);
    expect(find.text('甲'), findsOneWidget);
    expect((tester.widget(checkboxPoint()) as dynamic).value, isTrue);
    await _unmount(tester);
  });

  testWidgets('swiping past the loaded window continues with the rest', (
    tester,
  ) async {
    final diaries = await _seed(tester, database, <String>[
      '一',
      '二',
      '三',
      '四',
      '五',
    ]);
    final window = diaries.take(2).toList();
    await _open(
      tester,
      database,
      diaryId: window[0].diary.diaryId,
      sequence: DiaryPreviewSequence.fromItems(
        window,
        query: const DiaryPreviewListQuery(
          keyword: '',
          requiredTagIds: <int>[],
          sortMode: DiarySortMode.updatedDesc,
        ),
      ),
      style: _positionTitle,
    );
    // 入场结束后已接上剩下的部分。
    expect(find.text('1 / 5'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await _swipe(tester);
    }
    expect(find.text('五'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('the position title marks that more may still load', (
    tester,
  ) async {
    final diaries = await _seed(tester, database, <String>['一', '二']);
    final sequence = DiaryPreviewSequence.fromItems(
      diaries,
      query: const DiaryPreviewListQuery(
        keyword: '',
        requiredTagIds: <int>[],
        sortMode: DiarySortMode.updatedDesc,
      ),
    );
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_preview_style': DiaryPreviewSettings(
        current: _positionTitle,
      ).encode()!,
    });
    final settings = await SettingsService.create();
    // 设置先就绪，首帧即是“位置”标题；直接作为首页（没有入场动画）也会接上，
    // 接上之前标题带“+”。
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsServiceProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiaryPreviewPage(
            diaryId: diaries[0].diary.diaryId,
            initialDetail: diaries[0],
            sequence: sequence,
          ),
        ),
      ),
    );
    expect(find.text('1 / 2+'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a locked capsule in the list shows its sealed page', (
    tester,
  ) async {
    final diaries = await _seed(
      tester,
      database,
      <String>['甲', '胶囊'],
      locked: <String>{'胶囊'},
    );
    await _open(
      tester,
      database,
      diaryId: diaries[0].diary.diaryId,
      sequence: DiaryPreviewSequence.fromItems(diaries),
    );
    await _swipe(tester);
    expect(find.byType(LockedDiaryPage), findsOneWidget);
    expect(find.text('胶囊 的正文'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('only the first page flies back to the list card', (
    tester,
  ) async {
    final diaries = await _seed(tester, database, <String>['甲', '乙']);
    await _open(
      tester,
      database,
      diaryId: diaries[0].diary.diaryId,
      sequence: DiaryPreviewSequence.fromItems(diaries),
    );
    DiaryPreviewView current() =>
        tester.widget<DiaryPreviewView>(find.byType(DiaryPreviewView));
    expect(current().coverHeroTag, isNull);
    expect(current().ownsCoverHero, isFalse);
    await _swipe(tester);
    expect(
      current().coverHeroTag,
      ImageViewerHeroTag('diary_preview_pager_cover', diaries[1].diary.diaryId),
    );
    await _unmount(tester);
  });

  testWidgets('the iOS edge back swipe still closes the preview', (
    tester,
  ) async {
    final diaries = await _seed(tester, database, <String>['甲', '乙', '丙']);
    final harness = await _open(
      tester,
      database,
      diaryId: diaries[1].diary.diaryId,
      sequence: DiaryPreviewSequence.fromItems(diaries),
    );
    final gesture = await tester.startGesture(const Offset(6, 400));
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(DiaryPreviewPage), findsNothing);
    expect(harness.results, <Object?>[null]);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
