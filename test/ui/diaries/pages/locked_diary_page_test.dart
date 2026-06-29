import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/locked_diary_page.dart';

void main() {
  testWidgets('locked capsule delete asks for confirmation before deleting', (
    tester,
  ) async {
    final now = DateTime(2026, 6, 29, 9);
    final diaryId = 'locked-capsule-1';
    final db = _RecordingAppDatabase(
      DiaryWithTags(
        diary: Diary(
          id: 1,
          diaryId: diaryId,
          title: 'Future letter',
          content: '[{"insert":"secret words\\n"}]',
          contentText: 'secret words',
          metadata: '{}',
          createdAt: now,
          updatedAt: now,
          isArchived: false,
          isPinned: false,
          capsuleLockedAt: now,
          capsuleUnlockAt: now.add(const Duration(days: 30)),
          isDeleted: false,
        ),
        tags: const <Tag>[],
      ),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LockedDiaryPage(diaryId: diaryId),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Future letter'));

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await _pumpUntilFound(tester, find.text('删除日记'));

    expect(find.text('确认删除这条日记吗？'), findsOneWidget);
    expect(db.softDeleteCalls, 0);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await _pumpUntilNotFound(tester, find.text('删除日记'));

    expect(db.softDeleteCalls, 0);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await _pumpUntilFound(tester, find.text('删除日记'));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '删除'),
      ),
    );
    await _pumpUntil(tester, () => db.softDeleteCalls == 1);

    expect(db.deletedDiaryIds, <String>[diaryId]);
    expect(db.deletedWithoutTouchingUpdatedAt, isTrue);

    await tester.pump(const Duration(seconds: 4));
  });
}

class _RecordingAppDatabase extends AppDatabase {
  _RecordingAppDatabase(this.detail)
    : super.forTesting(NativeDatabase.memory());

  final DiaryWithTags detail;
  final List<String> deletedDiaryIds = <String>[];
  bool deletedWithoutTouchingUpdatedAt = false;

  int get softDeleteCalls => deletedDiaryIds.length;

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) async {
    if (diaryId == detail.diary.diaryId) {
      return detail;
    }
    return null;
  }

  @override
  Future<void> softDeleteDiary(
    String diaryId, {
    bool touchUpdatedAt = true,
  }) async {
    deletedDiaryIds.add(diaryId);
    deletedWithoutTouchingUpdatedAt = !touchUpdatedAt;
  }

  @override
  Future<void> restoreDiary(
    String diaryId, {
    bool touchUpdatedAt = true,
  }) async {
    deletedDiaryIds.remove(diaryId);
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  await _pumpUntil(tester, () => finder.evaluate().isNotEmpty);
}

Future<void> _pumpUntilNotFound(WidgetTester tester, Finder finder) async {
  await _pumpUntil(tester, () => finder.evaluate().isEmpty);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) {
      return;
    }
  }
  fail('等待测试条件满足超时');
}
