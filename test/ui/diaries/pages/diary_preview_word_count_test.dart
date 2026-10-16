import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_word_count_sheet.dart';

import '../../../support/expressive_test_theme.dart';

var _idSeed = 0;

DiaryWithTags _diary({required String content, required String text}) {
  final now = DateTime(2026, 10, 14, 9);
  return DiaryWithTags(
    diary: Diary(
      id: _idSeed,
      diaryId: 'word-count-${_idSeed++}',
      title: '海边',
      content: content,
      contentText: text,
      metadata: '{}',
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[],
  );
}

/// 详情查询不返回，页面始终按入口数据渲染，避免数据库计时器干扰。
class _PendingDetailDatabase extends AppDatabase {
  _PendingDetailDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) =>
      Completer<DiaryWithTags?>().future;
}

Future<void> _pump(WidgetTester tester, DiaryWithTags detail) async {
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
        home: DiaryPreviewPage(
          diaryId: detail.diary.diaryId,
          initialDetail: detail,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the meta line shows the word count and opens the details', (
    tester,
  ) async {
    // 今天去了海边。= 7 字，Walk by the sea. = 4 词。
    await _pump(
      tester,
      _diary(
        content:
            '[{"insert":"今天去了海边。Walk by the sea.\\n"},{"insert":{"image":"/a.png"}},{"insert":"\\n"}]',
        text: '今天去了海边。Walk by the sea.',
      ),
    );

    expect(find.text('11 字 · 约 1 分钟'), findsOneWidget);
    await tester.tap(find.text('11 字 · 约 1 分钟'));
    await tester.pumpAndSettle();

    final sheet = find.byType(DiaryWordCountSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('字数统计')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.textContaining('11', findRichText: true),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('中文字符')),
      findsOneWidget,
    );
    // 媒体数量只列出有的：一张图片，没有录音。
    expect(
      find.descendant(of: sheet, matching: find.text('图片')),
      findsOneWidget,
    );
    expect(find.descendant(of: sheet, matching: find.text('录音')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an entry without text shows no word count', (tester) async {
    await _pump(tester, _diary(content: '[{"insert":"\\n"}]', text: ''));
    expect(find.textContaining('字 · 约'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
