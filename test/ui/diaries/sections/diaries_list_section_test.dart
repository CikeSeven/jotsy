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

  testWidgets('selected list card animates its highlight and press response', (
    tester,
  ) async {
    final diary = _createUnlockedDiaryWithTags();
    const surfaceKey = ValueKey<String>('diary_selection_surface_unlocked-1');
    const motionKey = ValueKey<String>('diary_selection_motion_unlocked-1');

    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 2,
        enableSwipeAction: true,
      ),
    );
    await tester.pumpAndSettle();

    final unselectedSurface = tester.widget<Container>(find.byKey(surfaceKey));
    final unselectedDecoration = unselectedSurface.decoration! as BoxDecoration;
    final unselectedColor = unselectedDecoration.color;
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.endToStart,
    );

    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 2,
        selectedDiaryIds: const <String>{'unlocked-1'},
        enableSwipeAction: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 90));

    final transitioningSurface = tester.widget<Container>(
      find.byKey(surfaceKey),
    );
    final transitioningDecoration =
        transitioningSurface.decoration! as BoxDecoration;
    final transitioningMotion = tester.widget<Transform>(find.byKey(motionKey));
    expect(transitioningDecoration.color, isNot(unselectedColor));
    expect(transitioningMotion.transform.storage[0], lessThan(1));
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.none,
    );

    await tester.pumpAndSettle();

    final selectedSurface = tester.widget<Container>(find.byKey(surfaceKey));
    final selectedDecoration = selectedSurface.decoration! as BoxDecoration;
    final selectedForeground =
        selectedSurface.foregroundDecoration! as BoxDecoration;
    final selectedBorder = selectedForeground.border! as Border;
    expect(selectedDecoration.color, isNot(unselectedColor));
    expect(selectedBorder.left.width, 4);
    expect(selectedBorder.left.color, isNot(Colors.transparent));
  });

  testWidgets(
    'selected waterfall card uses themed outline and shadow in dark mode',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          diary: _createUnlockedDiaryWithTags(),
          layoutMode: DiaryLayoutMode.waterfall,
          maxVisibleTags: 2,
          selectedDiaryIds: const <String>{'unlocked-1'},
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      final surface = tester.widget<Container>(
        find.byKey(
          const ValueKey<String>('diary_selection_surface_unlocked-1'),
        ),
      );
      final decoration = surface.decoration! as BoxDecoration;
      final foreground = surface.foregroundDecoration! as BoxDecoration;
      final border = foreground.border! as Border;
      final context = tester.element(find.byKey(const ValueKey('test-root')));
      final colorScheme = Theme.of(context).colorScheme;

      expect(decoration.color, isNot(colorScheme.surfaceContainerLow));
      expect(decoration.boxShadow, isNotEmpty);
      expect(border.top.width, 2);
      expect(border.top.color, colorScheme.primary.withValues(alpha: 0.82));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected locked capsule receives the shared card highlight', (
    tester,
  ) async {
    final now = DateTime.now();
    final diary = _createLockedDiaryWithTags(now);

    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 3,
        selectedDiaryIds: const <String>{'capsule-1'},
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey<String>('diary_selection_surface_capsule-1')),
    );
    final foreground = surface.foregroundDecoration! as BoxDecoration;
    final border = foreground.border! as Border;
    expect(border.left.width, 4);
    expect(border.left.color, isNot(Colors.transparent));
  });

  testWidgets(
    'locked capsule card does not overflow in narrow waterfall cell',
    (tester) async {
      final now = DateTime.now();
      final diary = _createLockedDiaryWithTags(now);

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

DiaryWithTags _createLockedDiaryWithTags(DateTime now) {
  return DiaryWithTags(
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
}

Widget _buildTestApp({
  required DiaryWithTags diary,
  required DiaryLayoutMode layoutMode,
  required int maxVisibleTags,
  Set<String> selectedDiaryIds = const <String>{},
  Brightness brightness = Brightness.light,
  bool enableSwipeAction = false,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF37618A),
        brightness: brightness,
      ),
    ),
    home: Scaffold(
      body: SizedBox(
        key: const ValueKey<String>('test-root'),
        width: 360,
        child: CustomScrollView(
          slivers: <Widget>[
            DiariesListSection(
              diaries: <DiaryWithTags>[diary],
              layoutMode: layoutMode,
              selectedDiaryIds: selectedDiaryIds,
              isSelectionMode: selectedDiaryIds.isNotEmpty,
              maxVisibleTags: maxVisibleTags,
              onCreate: () {},
              onOpenEditor: (_) {},
              onToggleSelection: (_, _) {},
              onArchiveDiary: enableSwipeAction ? (_) {} : null,
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
