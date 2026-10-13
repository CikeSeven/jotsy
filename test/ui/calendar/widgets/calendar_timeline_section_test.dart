import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_timeline_section.dart';

void main() {
  testWidgets('calendar timeline hides locked capsule content', (tester) async {
    final now = DateTime.now();
    final diary = DiaryWithTags(
      diary: Diary(
        id: 1,
        diaryId: 'capsule-calendar-1',
        title: 'Future letter',
        content: '[{"insert":"secret capsule words\\n"}]',
        contentText: 'secret capsule words',
        metadata: '{}',
        createdAt: now.add(const Duration(days: 30)),
        updatedAt: now,
        isArchived: false,
        isPinned: false,
        capsuleLockedAt: now,
        capsuleUnlockAt: now.add(const Duration(days: 30)),
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CalendarTimelineSection(
            selectedDay: diary.diary.createdAt,
            diaries: <DiaryWithTags>[diary],
            onOpenDiary: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('secret capsule words'), findsNothing);
    expect(find.text('30 天后解封'), findsOneWidget);
  });

  testWidgets(
    'calendar timeline cover thumbnail keeps source aspect ratio on decode',
    (tester) async {
      final now = DateTime(2026, 10, 5, 9);
      final diary = DiaryWithTags(
        diary: Diary(
          id: 2,
          diaryId: 'calendar-cover-1',
          title: 'With cover',
          content: '[{"insert":"body\\n"}]',
          contentText: 'body',
          metadata: '{}',
          createdAt: now,
          updatedAt: now,
          isArchived: false,
          isPinned: false,
          isDeleted: false,
          cover: '/calendar-cover.jpg',
        ),
        tags: const <Tag>[],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarTimelineSection(
              selectedDay: now,
              diaries: <DiaryWithTags>[diary],
              onOpenDiary: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 同时限定宽高会按 ResizeImagePolicy.exact 把非方形图压成正方形。
      final image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;
      expect(resized.width, isNotNull);
      expect(resized.height, isNull);
    },
  );
}
