import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

const _threeTags = <Tag>[
  Tag(id: 1, name: 'Tag 1', color: 0xFF336699),
  Tag(id: 2, name: 'Tag 2', color: 0xFF669933),
  Tag(id: 3, name: 'Tag 3', color: 0xFF993366),
];

void main() {
  testWidgets('list layout applies the configured visible tag limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        diary: _createUnlockedDiaryWithTags(),
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 1,
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_tagLabel('Tag 1'), findsOneWidget);
    expect(_tagLabel('Tag 2'), findsNothing);
    expect(_tagLabel('Tag 3'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('waterfall layout applies a positive visible tag limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        diary: _createUnlockedDiaryWithTags(),
        layoutMode: DiaryLayoutMode.waterfall,
        maxVisibleTags: 1,
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Visible diary'), findsOneWidget);
    expect(_tagLabel('Tag 1'), findsOneWidget);
    expect(_tagLabel('Tag 2'), findsNothing);
    expect(_tagLabel('Tag 3'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('waterfall layout hides tags when the configured limit is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        diary: _createUnlockedDiaryWithTags(),
        layoutMode: DiaryLayoutMode.waterfall,
        maxVisibleTags: 0,
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_tagLabel('Tag 1'), findsNothing);
    expect(_tagLabel('Tag 2'), findsNothing);
    expect(_tagLabel('Tag 3'), findsNothing);
    expect(find.text('+3'), findsNothing);
  });

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
        tags: _threeTags,
      );

      await tester.pumpWidget(
        _buildTestApp(
          diary: diary,
          layoutMode: DiaryLayoutMode.waterfall,
          maxVisibleTags: 3,
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('365 天后解封'), findsOneWidget);
      expect(_tagLabel('Tag 1'), findsNothing);
    },
  );
}

DiaryWithTags _createUnlockedDiaryWithTags() {
  final now = DateTime.now();
  return DiaryWithTags(
    diary: Diary(
      id: 1,
      diaryId: 'unlocked-1',
      title: 'Visible diary',
      content: '[{"insert":"visible content\\n"}]',
      contentText: 'visible content',
      metadata: '{}',
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: _threeTags,
  );
}

Widget _buildTestApp({
  required DiaryWithTags diary,
  required DiaryLayoutMode layoutMode,
  required int maxVisibleTags,
}) {
  return MaterialApp(
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
              layoutMode: layoutMode,
              selectedDiaryIds: const <String>{},
              isSelectionMode: false,
              maxVisibleTags: maxVisibleTags,
              onCreate: () {},
              onOpenEditor: (_) {},
              onToggleSelection: (_, _) {},
            ),
          ],
        ),
      ),
    ),
  );
}

Finder _tagLabel(String label) {
  return find.textContaining(label, findRichText: true);
}
