import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/export/diary_export_book.dart';
import 'package:node_diary/ui/notebooks/controllers/notebook_book_export_flow.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 导出成书的素材：日记本 → 书的结构（章节、未分章、归档、排序）与按书序
/// 读出的日记详情。
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary(
    String title, {
    required DateTime createdAt,
    List<String>? notebookIds,
    DateTime? capsuleUnlockAt,
  }) {
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
      createdAtOverride: createdAt,
      notebookIds: notebookIds,
      capsuleLockedAt: capsuleUnlockAt == null ? null : createdAt,
      capsuleUnlockAt: capsuleUnlockAt,
    );
  }

  Future<NotebookView> view(String id) async =>
      NotebookView((await db.getNotebook(id))!);

  /// 每章一行：“章节名: 日记标题…”，未分章写作“-”。
  List<String> chaptersOf(DiaryExportBook book, Map<String, String> titles) =>
      <String>[
        for (final chapter in book.chapters)
          '${chapter.title ?? '-'}:'
              '${chapter.diaryIds.map((id) => ' ${titles[id]}').join()}',
      ];

  NotebookPayload chaptered({NotebookSort sort = NotebookSort.book}) =>
      NotebookPayload(
        description: '  走过的路  ',
        coverPath: '/covers/trip.jpg',
        sort: sort,
        chapters: <NotebookChapter>[
          NotebookChapter(id: 'c1', title: '第一章'),
          NotebookChapter(id: 'c2', title: '第二章'),
          NotebookChapter(id: 'c3', title: '空章'),
        ],
      );

  /// a(5/3) 与 b(5/1) 在第一章（a 先加入），c(5/2) 未分章，d(5/4) 在第二章
  /// 且已归档，e 在第一章但已进回收站，s 是第一章里未解封的胶囊。
  Future<(String, Map<String, String>)> seedManual(
    NotebookPayload payload,
  ) async {
    final id = await db.createNotebook(name: '旅行日记', payload: payload);
    final titles = <String, String>{};
    Future<String> add(
      String title,
      DateTime createdAt, {
      DateTime? unlock,
    }) async {
      final diaryId = await diary(
        title,
        createdAt: createdAt,
        notebookIds: <String>[id],
        capsuleUnlockAt: unlock,
      );
      titles[diaryId] = title;
      return diaryId;
    }

    final a = await add('a', DateTime(2026, 5, 3));
    final b = await add('b', DateTime(2026, 5, 1));
    await add('c', DateTime(2026, 5, 2));
    final d = await add('d', DateTime(2026, 5, 4));
    final e = await add('e', DateTime(2026, 5, 5));
    final s = await add('s', DateTime(2026, 5, 6), unlock: DateTime(2099));
    await db.setNotebookEntriesChapter(id, <String>[a, b, e, s], 'c1');
    await db.setNotebookEntriesChapter(id, <String>[d], 'c2');
    await db.archiveDiary(d);
    await db.softDeleteDiary(e);
    return (id, titles);
  }

  test('a manual notebook in book order keeps chapters, positions and '
      'archived entries, and leaves out the recycle bin', () async {
    final (id, titles) = await seedManual(chaptered());
    final source = await loadNotebookBookExport(db, await view(id));
    final book = source.book;

    expect(book.title, '旅行日记');
    expect(book.description, '走过的路');
    expect(book.coverPath, '/covers/trip.jpg');
    expect(chaptersOf(book, titles), <String>[
      '第一章: a b s',
      '第二章: d',
      '空章:',
      '-: c',
    ]);
    // 详情按书序；胶囊照样读出，由导出链路跳过并计数。
    expect(source.diaries.map((d) => d.diary.title), <String>[
      'a',
      'b',
      's',
      'd',
      'c',
    ]);
  });

  test('other sorts still group by chapter but read oldest first', () async {
    final (id, titles) = await seedManual(
      chaptered(sort: NotebookSort.createdDesc),
    );
    final book = (await loadNotebookBookExport(db, await view(id))).book;
    expect(chaptersOf(book, titles), <String>[
      '第一章: b a s',
      '第二章: d',
      '空章:',
      '-: c',
    ]);
  });

  test(
    'a smart notebook is one group, oldest first, archived included',
    () async {
      final id = await db.createNotebook(
        name: '置顶的',
        kind: NotebookKind.smart,
        payload: NotebookPayload(
          rules: NotebookRuleSet(
            rules: const <NotebookRule>[
              NotebookFlagRule(NotebookFlagKind.pinned),
            ],
          ).encode(),
        ),
      );
      final later = await diary('later', createdAt: DateTime(2026, 5, 2));
      final earlier = await diary('earlier', createdAt: DateTime(2026, 5, 1));
      final archived = await diary('archived', createdAt: DateTime(2026, 5, 3));
      await diary('not pinned', createdAt: DateTime(2026, 4, 1));
      for (final diaryId in <String>[later, earlier, archived]) {
        await db.pinDiary(diaryId);
      }
      await db.archiveDiary(archived);

      final source = await loadNotebookBookExport(db, await view(id));
      expect(source.book.chapters, hasLength(1));
      expect(source.book.chapters.single.title, isNull);
      expect(source.diaries.map((d) => d.diary.title), <String>[
        'earlier',
        'later',
        'archived',
      ]);
    },
  );

  testWidgets('the entry point opens the export sheet in book mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final (id, _) = (await tester.runAsync(() => seedManual(chaptered())))!;
    final notebook = (await tester.runAsync(() => view(id)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (BuildContext context, WidgetRef ref, _) => TextButton(
                onPressed: () => exportNotebookAsBook(context, ref, notebook),
                child: const Text('export'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();

    // a、b、s、d、c：含归档与胶囊（胶囊在生成时跳过），不含回收站。
    expect(find.text('共 5 篇'), findsOneWidget);
    expect(find.text('书籍结构'), findsOneWidget);
    expect(find.text('从旧到新'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
