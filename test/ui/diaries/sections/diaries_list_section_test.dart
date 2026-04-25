import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

void main() {
  testWidgets(
    'locked capsule card does not overflow in narrow waterfall cell',
    (tester) async {
      final now = DateTime.now();
      final diary = DiaryWithTags(
        diary: Diary(
          id: 1,
          diaryId: 'capsule-1',
          title: 'Future letter',
          content: '[{"insert":"hidden content\\n"}]',
          contentText: 'hidden content for future self',
          metadata: '{}',
          createdAt: now,
          updatedAt: now,
          isArchived: false,
          isPinned: false,
          capsuleLockedAt: now,
          capsuleUnlockAt: now.add(const Duration(days: 365)),
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
            body: SizedBox(
              width: 360,
              child: CustomScrollView(
                slivers: <Widget>[
                  DiariesListSection(
                    diaries: <DiaryWithTags>[diary],
                    layoutMode: DiaryLayoutMode.waterfall,
                    selectedDiaryIds: const <String>{},
                    isSelectionMode: false,
                    onCreate: () {},
                    onOpenEditor: (_) {},
                    onToggleSelection: (_, _) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('365 天后解封'), findsOneWidget);
    },
  );
}
