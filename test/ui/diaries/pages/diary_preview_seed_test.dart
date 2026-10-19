import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillEditor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/locked_diary_page.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../../support/expressive_test_theme.dart';

DiaryWithTags _diary({DateTime? unlockAt}) {
  final now = DateTime(2026, 10, 14, 9);
  return DiaryWithTags(
    diary: Diary(
      id: 1,
      diaryId: 'seeded-1',
      title: '海边日落',
      content: '[{"insert":"晚霞把整片海都染成了橘色\\n"}]',
      contentText: '晚霞把整片海都染成了橘色',
      metadata: '{}',
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
      capsuleLockedAt: unlockAt == null ? null : now,
      capsuleUnlockAt: unlockAt,
    ),
    tags: const <Tag>[],
  );
}

/// 详情查询由测试控制何时返回，用来观察“查询返回前”的首帧。
class _PendingDetailDatabase extends AppDatabase {
  _PendingDetailDatabase() : super.forTesting(NativeDatabase.memory());

  final Completer<DiaryWithTags?> pending = Completer<DiaryWithTags?>();

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) =>
      pending.future;
}

Future<_PendingDetailDatabase> _pumpPage(
  WidgetTester tester,
  Widget page,
) async {
  final database = _PendingDetailDatabase();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ),
  );
  return database;
}

void main() {
  testWidgets('preview renders the entry data before the detail query lands', (
    tester,
  ) async {
    final seeded = _diary();
    final database = await _pumpPage(
      tester,
      DiaryPreviewPage(diaryId: 'seeded-1', initialDetail: seeded),
    );

    // 首帧即是完整内容（标题 + 正文编辑器），不是空壳，也没有首屏等待。
    expect(find.text('海边日落'), findsOneWidget);
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.byType(DelayedLoadingIndicator), findsNothing);

    database.pending.complete(seeded);
    await tester.pump();
    await tester.pump();
    expect(find.text('海边日落'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('locked capsule renders the entry data before the query lands', (
    tester,
  ) async {
    final seeded = _diary(
      unlockAt: DateTime.now().add(const Duration(days: 30)),
    );
    final database = await _pumpPage(
      tester,
      LockedDiaryPage(diaryId: 'seeded-1', initialDetail: seeded),
    );

    expect(find.text('海边日落'), findsOneWidget);
    expect(find.byType(DelayedLoadingIndicator), findsNothing);

    database.pending.complete(seeded);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('without entry data a fast query never flashes a spinner', (
    tester,
  ) async {
    final database = await _pumpPage(
      tester,
      const DiaryPreviewPage(diaryId: 'seeded-1'),
    );
    expect(find.text('海边日落'), findsNothing);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.descendant(
        of: find.byType(DelayedLoadingIndicator),
        matching: find.byType(ExpressiveLoadingIndicator),
      ),
      findsNothing,
    );

    database.pending.complete(_diary());
    await tester.pump();
    await tester.pump();
    expect(find.text('海边日落'), findsOneWidget);
    expect(find.byType(DelayedLoadingIndicator), findsNothing);
    await _unmount(tester);
  });
}

/// 卸载后再走一帧：预览页读取所在日记本的查询在 drift 里留下 0 时长计时器。
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
