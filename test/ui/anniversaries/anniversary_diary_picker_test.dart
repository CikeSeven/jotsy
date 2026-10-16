import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/anniversaries/widgets/anniversary_diary_picker.dart';

import '../../support/calendar_test_harness.dart';
import '../../support/expressive_test_theme.dart';

void main() {
  final date = DateTime(2026, 10, 1);

  Future<List<AnniversaryDiaryPick?>> pumpPicker(
    WidgetTester tester,
    List<DiaryWithTags> candidates, {
    String? selected,
  }) async {
    final picks = <AnniversaryDiaryPick?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anniversaryDiaryCandidatesProvider.overrideWith(
            (ref, day) => Stream.value(candidates),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async => picks.add(
                  await showAnniversaryDiaryPicker(
                    context,
                    date: date,
                    selectedDiaryId: selected,
                  ),
                ),
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    return picks;
  }

  testWidgets('lists nearby diaries without sealed capsules', (tester) async {
    final picks = await pumpPicker(tester, <DiaryWithTags>[
      calendarTestDiary('trip', DateTime(2026, 10, 2, 9), title: '出发'),
      calendarTestDiary(
        'capsule',
        DateTime(2026, 9, 30, 9),
        title: '秘密',
        capsuleUnlockAt: DateTime(2030),
      ),
    ]);
    expect(find.text('出发'), findsOneWidget);
    expect(find.text('秘密'), findsNothing);
    await tester.tap(find.text('出发'));
    await tester.pumpAndSettle();
    expect(picks.single?.diaryId, 'trip');
  });

  testWidgets('“none” clears the link and dismissing keeps it', (tester) async {
    final picks = await pumpPicker(
      tester,
      const <DiaryWithTags>[],
      selected: 'trip',
    );
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    expect(find.text(l10n.anniversaryPickerEmpty), findsOneWidget);
    await tester.tap(find.text(l10n.anniversaryLinkNone));
    await tester.pumpAndSettle();
    expect(picks.single, isNotNull);
    expect(picks.single!.diaryId, isNull);

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(picks.last, isNull);
  });
}
