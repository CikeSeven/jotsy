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
        metadata: '{"context":{"mood":"😊","weather_icon_code":"100"}}',
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
              onOpenEditor: (_) {},
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

      // Eyebrow date
      expect(find.textContaining('10月5日'), findsNWidgets(2));
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

      expect(find.textContaining('10月5日'), findsOneWidget);
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
}
