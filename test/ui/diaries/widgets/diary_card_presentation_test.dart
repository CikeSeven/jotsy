import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

void main() {
  DiaryWithTags createMockDiary({
    required String id,
    required String title,
    required bool isPinned,
    DateTime? createdAt,
    String? cover,
  }) {
    final now = createdAt ?? DateTime(2026, 10, 5, 14, 30);
    return DiaryWithTags(
      diary: Diary(
        id: 1,
        diaryId: id,
        title: title,
        content: '{"ops":[{"insert":"Hello World\\n"}]}',
        contentText: 'Hello World, today was a wonderful day.',
        // 与 PublishMetadataComposer 写入的 context 键名保持一致。
        metadata: '{"context":{"moodEmoji":"😊","weatherIconCode":"100"}}',
        createdAt: now,
        updatedAt: now,
        isArchived: false,
        isPinned: isPinned,
        isDeleted: false,
        cover: cover,
      ),
      tags: [
        const Tag(id: 1, name: '生活', color: 0xFF4CAF50),
        const Tag(id: 2, name: '日常', color: 0xFF2196F3),
      ],
    );
  }

  Widget buildApp({
    required List<DiaryWithTags> diaries,
    required DiaryLayoutMode layoutMode,
    Brightness brightness = Brightness.light,
    Set<String> selectedDiaryIds = const {},
    bool isSelectionMode = false,
  }) {
    final themeData = brightness == Brightness.light
        ? const MaterialTheme(TextTheme()).light()
        : const MaterialTheme(TextTheme()).dark();

    return MaterialApp(
      theme: themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            DiariesListSection(
              diaries: diaries,
              layoutMode: layoutMode,
              selectedDiaryIds: selectedDiaryIds,
              isSelectionMode: isSelectionMode,
              maxVisibleTags: 3,
              onCreate: () {},
              onOpenEditor: (_, _) {},
              onToggleSelection: (_, __) {},
            ),
          ],
        ),
      ),
    );
  }

  testWidgets(
    'diaries list card displays eyebrow date and pinned badge when pinned',
    (tester) async {
      final pinnedDiary = createMockDiary(
        id: 'd1',
        title: '置顶日记测试',
        isPinned: true,
      );
      final normalDiary = createMockDiary(
        id: 'd2',
        title: '普通日记测试',
        isPinned: false,
      );

      await tester.pumpWidget(
        buildApp(
          diaries: [pinnedDiary, normalDiary],
          layoutMode: DiaryLayoutMode.list,
        ),
      );
      await tester.pumpAndSettle();

      // Eyebrow date（底部更新时间也会显示“10月5日”，需精确匹配眉线文本）
      expect(find.text('10月5日 · 周一'), findsNWidgets(2));
      // Pinned badge text (only on pinned diary)
      expect(find.text('置顶'), findsOneWidget);
      // Titles
      expect(find.text('置顶日记测试'), findsOneWidget);
      expect(find.text('普通日记测试'), findsOneWidget);
      // Mood emoji
      expect(find.text('😊'), findsNWidgets(2));
    },
  );

  testWidgets(
    'diaries waterfall card displays eyebrow date and pinned indicator',
    (tester) async {
      final pinnedDiary = createMockDiary(
        id: 'd1',
        title: '瀑布流置顶',
        isPinned: true,
      );

      await tester.pumpWidget(
        buildApp(diaries: [pinnedDiary], layoutMode: DiaryLayoutMode.waterfall),
      );
      await tester.pumpAndSettle();

      expect(find.text('10月5日 · 周一'), findsOneWidget);
      expect(find.text('瀑布流置顶'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
    },
  );

  testWidgets(
    'renders correctly under dark theme without overflow or missing contrast',
    (tester) async {
      final pinnedDiary = createMockDiary(
        id: 'd1',
        title: '暗黑模式日记',
        isPinned: true,
      );

      await tester.pumpWidget(
        buildApp(
          diaries: [pinnedDiary],
          layoutMode: DiaryLayoutMode.list,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('暗黑模式日记'), findsOneWidget);
      expect(find.text('置顶'), findsOneWidget);
    },
  );

  testWidgets(
    'list card eyebrow truncates instead of overflowing on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final crowdedDiary = createMockDiary(
        id: 'narrow_diary',
        title: '窄屏眉线',
        isPinned: true,
        createdAt: DateTime(2025, 12, 28, 9, 0),
        cover: '/test-cover.jpg',
      );

      await tester.pumpWidget(
        buildApp(diaries: [crowdedDiary], layoutMode: DiaryLayoutMode.list),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('置顶'), findsOneWidget);
    },
  );

  testWidgets(
    'diaries list card displays cover preview on the left when diary has cover',
    (tester) async {
      final diaryWithCover = createMockDiary(
        id: 'cover_diary_100',
        title: '带封面日记',
        isPinned: false,
        cover: '/test-cover.jpg',
      );

      await tester.pumpWidget(
        buildApp(diaries: [diaryWithCover], layoutMode: DiaryLayoutMode.list),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('带封面日记'), findsOneWidget);
      // Cover image should be present on the left
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      final resizedImage = image.image as ResizeImage;
      expect(image.fit, BoxFit.cover);
      expect(resizedImage.width, isNotNull);
      expect(resizedImage.height, isNull);
    },
  );

  testWidgets(
    'diaries list card shows selection checkmark in title row when selected',
    (tester) async {
      final diary = createMockDiary(id: 'd1', title: '被选中的日记', isPinned: false);

      await tester.pumpWidget(
        buildApp(
          diaries: [diary],
          layoutMode: DiaryLayoutMode.list,
          selectedDiaryIds: {'d1'},
          isSelectionMode: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('被选中的日记'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FaIcon &&
              widget.icon?.codePoint ==
                  FontAwesomeIcons.solidCircleCheck.codePoint,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'diary card in resting list and waterfall mode does not have hard-edge ClipRect clipping shadow',
    (tester) async {
      final diary = createMockDiary(id: 'd1', title: '阴影测试日记', isPinned: false);

      // 1. List mode
      await tester.pumpWidget(
        buildApp(diaries: [diary], layoutMode: DiaryLayoutMode.list),
      );
      await tester.pumpAndSettle();

      final surface = find.byKey(
        const ValueKey<String>('diary_selection_surface_d1'),
      );
      expect(surface, findsOneWidget);

      final listClipRects = find.ancestor(
        of: surface,
        matching: find.byWidgetPredicate(
          (widget) => widget is ClipRect && widget.clipBehavior != Clip.none,
        ),
      );
      expect(
        listClipRects,
        findsNothing,
        reason: 'List mode card should not be clipped by hard-edge ClipRect',
      );

      // 2. Waterfall mode
      await tester.pumpWidget(
        buildApp(diaries: [diary], layoutMode: DiaryLayoutMode.waterfall),
      );
      await tester.pumpAndSettle();

      final waterfallSurface = find.byKey(
        const ValueKey<String>('diary_selection_surface_d1'),
      );
      expect(waterfallSurface, findsOneWidget);

      final waterfallClipRects = find.ancestor(
        of: waterfallSurface,
        matching: find.byWidgetPredicate(
          (widget) => widget is ClipRect && widget.clipBehavior != Clip.none,
        ),
      );
      expect(
        waterfallClipRects,
        findsNothing,
        reason:
            'Waterfall mode card should not be clipped by hard-edge ClipRect',
      );
    },
  );

  for (final layoutMode in DiaryLayoutMode.values) {
    testWidgets('card press ink sits above the cover image in $layoutMode', (
      tester,
    ) async {
      // 卡片展示数据按 (id, updatedAt) 全局缓存，用独立 id 避免复用无封面的缓存。
      final diary = createMockDiary(
        id: 'ink_cover_${layoutMode.name}',
        title: '按压反馈',
        isPinned: false,
        cover: '/missing-cover.png',
      );
      await tester.pumpWidget(
        buildApp(diaries: [diary], layoutMode: layoutMode),
      );
      await tester.pumpAndSettle();

      // 前景墨水层先于封面图被命中，说明它画在图片之上，按压高亮不会被盖住。
      final result = HitTestResult();
      tester.binding.hitTestInView(
        result,
        tester.getCenter(find.byType(Image)),
        tester.view.viewId,
      );
      final hitInk = result.path.any(
        (entry) =>
            entry.target ==
            tester.renderObject(
              find
                  .descendant(
                    of: find.byType(InkWell),
                    matching: find.byType(MouseRegion),
                  )
                  .first,
            ),
      );
      final hitImage = result.path.any(
        (entry) => entry.target == tester.renderObject(find.byType(RawImage)),
      );
      expect(hitInk, isTrue);
      expect(hitImage, isFalse);
    });
  }

  testWidgets('toggling selection swaps the mark without reflowing the title', (
    tester,
  ) async {
    final diary = createMockDiary(
      id: 'd1',
      title: '一个足够长的标题，用来确认选中时不会被勾选图标挤得重新折行',
      isPinned: false,
    );
    Finder mark(FaIconData icon) => find.byWidgetPredicate(
      (widget) => widget is FaIcon && widget.icon?.codePoint == icon.codePoint,
    );

    await tester.pumpWidget(
      buildApp(
        diaries: [diary],
        layoutMode: DiaryLayoutMode.list,
        isSelectionMode: true,
      ),
    );
    await tester.pumpAndSettle();
    final titleFinder = find.textContaining('一个足够长的标题');
    final unselectedSize = tester.getSize(titleFinder);
    expect(mark(FontAwesomeIcons.circle), findsOneWidget);

    await tester.pumpWidget(
      buildApp(
        diaries: [diary],
        layoutMode: DiaryLayoutMode.list,
        selectedDiaryIds: {'d1'},
        isSelectionMode: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(mark(FontAwesomeIcons.solidCircleCheck), findsOneWidget);
    expect(tester.getSize(titleFinder), unselectedSize);
  });

  testWidgets('selection marks expand in smoothly when entering selection', (
    tester,
  ) async {
    final diary = createMockDiary(id: 'd1', title: '进入多选', isPinned: false);
    await tester.pumpWidget(
      buildApp(diaries: [diary], layoutMode: DiaryLayoutMode.list),
    );
    await tester.pumpAndSettle();
    final restingWidth = tester.getSize(find.text('进入多选')).width;

    await tester.pumpWidget(
      buildApp(
        diaries: [diary],
        layoutMode: DiaryLayoutMode.list,
        isSelectionMode: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midWidth = tester.getSize(find.text('进入多选')).width;
    await tester.pumpAndSettle();
    final selectionWidth = tester.getSize(find.text('进入多选')).width;

    expect(selectionWidth, lessThan(restingWidth));
    expect(midWidth, inExclusiveRange(selectionWidth, restingWidth));
  });
}
