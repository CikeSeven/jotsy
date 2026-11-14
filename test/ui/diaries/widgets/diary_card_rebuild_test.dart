import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_resolved_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_surface.dart';

import '../../../support/expressive_test_theme.dart';

DiaryWithTags _diary() => DiaryWithTags(
  diary: Diary(
    id: 1,
    diaryId: 'rebuild',
    title: 'Original title',
    content: '',
    contentText: 'Body',
    metadata: '{}',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  ),
  tags: const <Tag>[],
);

void main() {
  final theme = expressiveTestTheme(Brightness.light);
  final resolved = DiaryCardResolvedStyle.resolve(
    style: DiaryCardStyle.defaults,
    mode: DiaryCardMode.list,
    theme: theme,
    screenWidth: 400,
  );

  Widget host({
    required DiaryWithTags diary,
    DiaryOpenCallback? onOpen,
    void Function(String, bool)? onSelect,
    bool Function(DiaryWithTags)? intercept,
    bool selected = false,
    bool selectionMode = false,
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    theme: theme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: DiaryCard(
            diary: diary,
            resolved: resolved,
            selected: selected,
            isSelectionMode: selectionMode,
            maxVisibleTags: 3,
            enableCoverHero: false,
            onOpenEditor: onOpen ?? (_, _, _) {},
            onToggleSelection: onSelect ?? (_, _) {},
            onTapIntercept: intercept,
          ),
        ),
      ),
    ),
  );

  DiarySelectionSurface surface(WidgetTester tester) =>
      tester.widget<DiarySelectionSurface>(find.byType(DiarySelectionSurface));

  testWidgets('equal rows reuse the card while taps use the newest callbacks', (
    tester,
  ) async {
    final diary = _diary();
    var oldCalls = 0;
    DiaryWithTags? opened;
    DiaryWithTags? intercepted;
    await tester.pumpWidget(
      host(
        diary: diary,
        onOpen: (_, _, _) => oldCalls++,
        intercept: (_) => false,
      ),
    );
    final first = surface(tester);
    final fresh = _diary();
    await tester.pumpWidget(
      host(
        diary: fresh,
        onOpen: (value, _, _) => opened = value,
        intercept: (value) {
          intercepted = value;
          return false;
        },
      ),
    );
    expect(surface(tester), same(first));
    await tester.tap(find.byType(InkWell));
    expect(oldCalls, 0);
    expect(opened, same(fresh));
    expect(intercepted, same(fresh));
  });

  testWidgets(
    'selection updates rebuild and long press uses the new callback',
    (tester) async {
      final diary = _diary();
      var calls = 0;
      await tester.pumpWidget(host(diary: diary));
      final first = surface(tester);
      await tester.pumpWidget(
        host(
          diary: diary,
          selected: true,
          selectionMode: true,
          onSelect: (_, _) => calls++,
        ),
      );
      expect(surface(tester), isNot(same(first)));
      expect(surface(tester).selected, isTrue);
      await tester.tap(find.byType(InkWell));
      await tester.longPress(find.byType(InkWell));
      expect(calls, 2);
    },
  );

  testWidgets('row changes and inherited locale invalidate the cached card', (
    tester,
  ) async {
    final diary = _diary();
    await tester.pumpWidget(host(diary: diary));
    final first = surface(tester);
    final changed = DiaryWithTags(
      diary: diary.diary.copyWith(title: 'Updated title'),
      tags: const <Tag>[Tag(id: 1, name: 'New tag', color: 0xFF336699)],
    );
    await tester.pumpWidget(host(diary: changed));
    expect(find.text('Updated title'), findsOneWidget);
    expect(surface(tester), isNot(same(first)));
    final second = surface(tester);
    await tester.pumpWidget(host(diary: changed, locale: const Locale('zh')));
    await tester.pumpAndSettle();
    expect(surface(tester), isNot(same(second)));
    expect(tester.takeException(), isNull);
  });
}
