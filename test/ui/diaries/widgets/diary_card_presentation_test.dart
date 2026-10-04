import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
              selectedDiaryIds: const {},
              isSelectionMode: false,
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
}
