import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/models/ai_privacy_options.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 日记本章节工具：编辑章节（新增、改名、排序）、删除章节（确认预览 + 无损
/// 撤销）、调整日记所属章节，以及 `add_to_notebook` / `create_diary` /
/// `create_diary_from_template` 的章节联动、隐私排除与撤销冲突。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SettingsService settings;
  late ProviderContainer container;
  final zh = lookupAppLocalizations(const Locale('zh'));
  const everything = AppFeatures(
    todos: true,
    anniversaries: true,
    comments: true,
    ai: true,
  );

  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
    await container.read(settingsServiceProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  AiToolContext context({
    AppFeatures features = everything,
    AiPreferences prefs = AiPreferences.defaults,
  }) => AiToolContext(
    container: container,
    l10n: zh,
    kit: AiPromptKit.resolve(prefs: prefs, appLocale: const Locale('zh')),
    env: AiToolEnv(features: features, prefs: prefs),
    citations: AiCitationBook(),
    allowance: AiWordAllowance(100000),
    token: HttpCancelToken(),
    now: DateTime(2026, 11, 8, 10),
  );

  Future<AiToolOutcome> run(
    String name,
    Map<String, Object?> args, {
    AiToolContext? with_,
  }) async {
    final tool = aiToolByName(name)!;
    final ctx = with_ ?? context();
    final validated = ctx.citations.resolveDiaryArgs(
      tool.schema.validate(args),
      tool.diaryIdArgs,
    );
    final outcome = await tool.run(ctx, validated);
    expect(outcome.subjects, isNotEmpty, reason: '$name names no subject');
    return outcome;
  }

  Future<AiToolPreview?> preview(
    String name,
    Map<String, Object?> args, {
    AiToolContext? with_,
  }) {
    final tool = aiToolByName(name)!;
    final ctx = with_ ?? context();
    final validated = ctx.citations.resolveDiaryArgs(
      tool.schema.validate(args),
      tool.diaryIdArgs,
    );
    return tool.preview(ctx, validated);
  }

  Future<void> undo(String name, AiToolOutcome outcome, {bool force = false}) =>
      aiToolByName(name)!.undo(container, outcome.undo!, force: force);

  Future<String> diary(String title) => db.createDiary(
    title: title,
    contentDocJson: '',
    contentText: '$title 的正文',
    metadataJson: '{}',
    createdAtOverride: DateTime(2026, 11, 1, 9),
  );

  Future<List<NotebookChapter>> chaptersOf(String notebookId) async =>
      (await db.getNotebook(notebookId))!.parsedPayload.chapters;

  group('edit_notebook_chapters', () {
    test(
      'adds, renames and reorders chapters in one call and undoes',
      () async {
        final nb = await db.createNotebook(
          name: '旅行手记',
          payload: NotebookPayload(description: '保留这段简介'),
        );

        final added = await run('edit_notebook_chapters', {
          'notebook_id': nb,
          'add': ['行前', '行程'],
        });
        final initialChapters = await chaptersOf(nb);
        expect(initialChapters.map((c) => c.title), ['行前', '行程']);
        final prepId = initialChapters[0].id;
        final tripId = initialChapters[1].id;
        expect(((added.data! as Map)['added'] as List), hasLength(2));
        expect(
          aiToolByName(
            'edit_notebook_chapters',
          )!.labelWith(zh, {'notebook_id': nb}, added.subjects),
          zh.aiToolEditNotebookChaptersOf('旅行手记'),
        );

        // 一次组合：改名 + 新增 + 重排（引用改名后的新标题与刚新增的标题）。
        final comboArgs = <String, Object?>{
          'notebook_id': nb,
          'rename': [
            {'chapter': prepId, 'title': '行前准备'},
          ],
          'add': ['序言'],
          'order': ['序言', tripId, '行前准备'],
        };
        final confirm = await preview('edit_notebook_chapters', comboArgs);
        expect(confirm!.title, zh.aiToolEditNotebookChaptersOf('旅行手记'));
        expect(confirm.lines, contains(zh.aiToolEditReplace('行前', '行前准备')));
        expect(confirm.lines, contains(zh.aiToolReorderChaptersPreview));

        final combo = await run('edit_notebook_chapters', comboArgs);
        final afterCombo = await chaptersOf(nb);
        expect(afterCombo.map((c) => c.title), ['序言', '行程', '行前准备']);
        // 本子的其他 payload 字段不受影响。
        expect((await db.getNotebook(nb))!.parsedPayload.description, '保留这段简介');

        // 撤销组合编辑：回到 ['行前', '行程']。
        await undo('edit_notebook_chapters', combo);
        expect((await chaptersOf(nb)).map((c) => c.title), ['行前', '行程']);

        // 撤销最初的新增章节。
        await undo('edit_notebook_chapters', added);
        expect(await chaptersOf(nb), isEmpty);
      },
    );

    test('undo reports conflict when chapters changed later or added chapters '
        'already hold entries', () async {
      final nb = await db.createNotebook(name: '旅行手记');
      final added = await run('edit_notebook_chapters', {
        'notebook_id': nb,
        'add': ['行前'],
      });
      final chapterId = (await chaptersOf(nb)).single.id;

      // 新建章节里已经放进日记：撤销会删掉该章，先报冲突。
      final entry = await diary('买机票');
      await db.addDiariesToNotebook(nb, [entry], chapterId: chapterId);
      await expectLater(
        () => undo('edit_notebook_chapters', added),
        throwsA(isA<AiUndoConflict>()),
      );
      await undo('edit_notebook_chapters', added, force: true);
      expect(await chaptersOf(nb), isEmpty);
      expect((await db.getNotebookEntryChapters(nb, [entry]))[entry], isNull);

      // 章节列表之后又在别处被改动：撤销报冲突，强制才覆盖。
      final c1 = NotebookChapter(id: 'ch000001', title: '第一章');
      await db.updateNotebook(nb, payload: NotebookPayload(chapters: [c1]));
      final renamed = await run('edit_notebook_chapters', {
        'notebook_id': nb,
        'rename': [
          {'chapter': '第一章', 'title': '开篇'},
        ],
      });
      await db.updateNotebook(
        nb,
        payload: NotebookPayload(
          chapters: [c1.withTitle('开篇'), NotebookChapter.create('用户手加')],
        ),
      );
      await expectLater(
        () => undo('edit_notebook_chapters', renamed),
        throwsA(isA<AiUndoConflict>()),
      );
      await undo('edit_notebook_chapters', renamed, force: true);
      expect((await chaptersOf(nb)).map((c) => c.title), ['第一章']);
    });

    test('rejects ambiguous titles, no-op, smart/private/excluded notebooks '
        'and invalid arguments', () async {
      final c1 = NotebookChapter(id: 'ch000001', title: '重复');
      final c2 = NotebookChapter(id: 'ch000002', title: '重复');
      final nb = await db.createNotebook(
        name: '旅行手记',
        payload: NotebookPayload(chapters: [c1, c2]),
      );
      // 重名章节按标题引用报错，提示改用 id。
      await expectLater(
        () => run('edit_notebook_chapters', {
          'notebook_id': nb,
          'rename': [
            {'chapter': '重复', 'title': '唯一'},
          ],
        }),
        throwsA(
          isA<AiToolFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains(c1.id), contains(c2.id)),
          ),
        ),
      );
      // 按 id 改名则正常通过。
      await run('edit_notebook_chapters', {
        'notebook_id': nb,
        'rename': [
          {'chapter': c2.id, 'title': '第二段'},
        ],
      });
      expect((await chaptersOf(nb)).map((c) => c.title), ['重复', '第二段']);

      // 空操作 / 重复 order / 重复改名同一章。
      expect(
        () => run('edit_notebook_chapters', {'notebook_id': nb}),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('edit_notebook_chapters', {
          'notebook_id': nb,
          'order': [c1.id, c2.id],
        }),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('edit_notebook_chapters', {
          'notebook_id': nb,
          'order': [c1.id, c1.id],
        }),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('edit_notebook_chapters', {
          'notebook_id': nb,
          'rename': [
            {'chapter': c1.id, 'title': 'A'},
            {'chapter': c1.id, 'title': 'B'},
          ],
        }),
        throwsA(isA<AiToolFailure>()),
      );

      // 智能本、私密本、AI 排除本一律拒绝。
      final smart = await db.createNotebook(
        name: '智能本',
        kind: NotebookKind.smart,
      );
      final hidden = await db.createNotebook(
        name: '私密本',
        visibility: NotebookVisibility.hidden,
      );
      expect(
        () => run('edit_notebook_chapters', {
          'notebook_id': smart,
          'add': ['甲'],
        }),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('edit_notebook_chapters', {
          'notebook_id': hidden,
          'add': ['甲'],
        }),
        throwsA(isA<AiToolFailure>()),
      );
      final excludedPrefs = AiPreferences(
        privacy: AiPrivacyOptions(excludedNotebookIds: {nb}),
      );
      expect(
        () => run('edit_notebook_chapters', {
          'notebook_id': nb,
          'add': ['甲'],
        }, with_: context(prefs: excludedPrefs)),
        throwsA(isA<AiToolFailure>()),
      );
    });
  });

  group('delete_notebook_chapters', () {
    test('previews count, deletes chapters, unassigns entries and restores '
        'all assignments on undo', () async {
      final c1 = NotebookChapter(id: 'ch000001', title: '行前');
      final c2 = NotebookChapter(id: 'ch000002', title: '行程');
      final c3 = NotebookChapter(id: 'ch000003', title: '复盘');
      final nb = await db.createNotebook(
        name: '旅行手记',
        payload: NotebookPayload(chapters: [c1, c2, c3]),
      );
      final d1 = await diary('打包');
      final d2 = await diary('归档旧篇');
      final d3 = await diary('回程');
      final d4 = await diary('留在行程');
      await db.archiveDiary(d2, touchUpdatedAt: false);
      await db.addDiariesToNotebook(nb, [d1, d2], chapterId: c1.id);
      await db.addDiariesToNotebook(nb, [d3], chapterId: c3.id);
      await db.addDiariesToNotebook(nb, [d4], chapterId: c2.id);

      // 单章确认预览。
      final singlePreview = await preview('delete_notebook_chapters', {
        'notebook_id': nb,
        'chapters': ['行前'],
      });
      expect(
        singlePreview!.title,
        zh.aiToolDeleteNotebookChapterNamed('旅行手记', '行前'),
      );
      expect(singlePreview.lines, [zh.aiToolDeleteNotebookChaptersUnassign(2)]);

      // 一次删除两章（按标题与 id 混传）。
      final multiPreview = await preview('delete_notebook_chapters', {
        'notebook_id': nb,
        'chapters': ['行前', c3.id],
      });
      expect(
        multiPreview!.title,
        zh.aiToolDeleteNotebookChaptersNamed('旅行手记', 2),
      );
      expect(multiPreview.lines, containsAll(['行前', '复盘']));
      expect(
        multiPreview.lines,
        contains(zh.aiToolDeleteNotebookChaptersUnassign(3)),
      );

      final deleted = await run('delete_notebook_chapters', {
        'notebook_id': nb,
        'chapters': ['行前', c3.id],
      });
      final data = deleted.data! as Map;
      expect(data['deleted'], 2);
      expect(data['entries_unassigned'], 3);
      expect((await chaptersOf(nb)).map((c) => c.id), [c2.id]);
      // 被删章的日记回到未分章（仍在本子里），未删章的日记不动。
      expect(await db.getNotebookEntryChapters(nb, [d1, d2, d3, d4]), {
        d1: null,
        d2: null,
        d3: null,
        d4: c2.id,
      });

      // 撤销：章节恢复原位置，原属日记（含归档日记）回到各自原来的章节。
      await undo('delete_notebook_chapters', deleted);
      expect((await chaptersOf(nb)).map((c) => c.id), [c1.id, c2.id, c3.id]);
      expect(await db.getNotebookEntryChapters(nb, [d1, d2, d3, d4]), {
        d1: c1.id,
        d2: c1.id,
        d3: c3.id,
        d4: c2.id,
      });
    });

    test('undo detects later chapter changes and keeps reassigned entries '
        'unless forced', () async {
      final c1 = NotebookChapter(id: 'ch000001', title: '甲');
      final c2 = NotebookChapter(id: 'ch000002', title: '乙');
      final nb = await db.createNotebook(
        name: '日记本',
        payload: NotebookPayload(chapters: [c1, c2]),
      );
      final d1 = await diary('第一篇');
      final d2 = await diary('第二篇');
      await db.addDiariesToNotebook(nb, [d1, d2], chapterId: c1.id);

      final deleted = await run('delete_notebook_chapters', {
        'notebook_id': nb,
        'chapters': [c1.id],
      });
      // 删除之后用户把 d2 手动分到了乙章：非强制撤销不覆盖 d2 的新归属。
      await db.setNotebookEntriesChapter(nb, [d2], c2.id);
      await undo('delete_notebook_chapters', deleted);
      expect(await db.getNotebookEntryChapters(nb, [d1, d2]), {
        d1: c1.id,
        d2: c2.id,
      });

      // 再次删除，并在之后手动新建一个章节：撤销报冲突，force 才强行恢复。
      final deletedAgain = await run('delete_notebook_chapters', {
        'notebook_id': nb,
        'chapters': [c1.id],
      });
      await db.updateNotebook(
        nb,
        payload: NotebookPayload(chapters: [c2, NotebookChapter.create('丙')]),
      );
      await expectLater(
        () => undo('delete_notebook_chapters', deletedAgain),
        throwsA(isA<AiUndoConflict>()),
      );
      await undo('delete_notebook_chapters', deletedAgain, force: true);
      expect((await chaptersOf(nb)).map((c) => c.id), [c1.id, c2.id]);
      expect((await db.getNotebookEntryChapters(nb, [d1]))[d1], c1.id);
    });
  });

  group('move_to_notebook_chapter and linkages', () {
    test('move_to_notebook_chapter moves entries by id or ref and undoes '
        'each entry to its previous chapter', () async {
      final c1 = NotebookChapter(id: 'ch000001', title: '行前');
      final c2 = NotebookChapter(id: 'ch000002', title: '行程');
      final nb = await db.createNotebook(
        name: '旅行手记',
        payload: NotebookPayload(chapters: [c1, c2]),
      );
      final a = await diary('准备');
      final b = await diary('出发');
      final outside = await diary('不在本子里');
      await db.addDiariesToNotebook(nb, [a], chapterId: c1.id);
      await db.addDiariesToNotebook(nb, [b]);

      // 不在本子里的日记整批拒绝，不留半截改动。
      await expectLater(
        () => run('move_to_notebook_chapter', {
          'notebook_id': nb,
          'ids': [a, outside],
          'chapter_id': c2.id,
        }),
        throwsA(isA<AiToolFailure>()),
      );
      expect((await db.getNotebookEntryChapters(nb, [a]))[a], c1.id);

      // 支持通过 D1 / D2 编号引用日记。
      final ctx = context();
      await run('search_diaries', {'notebook_id': nb}, with_: ctx);
      final refA = ctx.citations.refFor(
        a,
        title: '准备',
        date: DateTime(2026, 11, 1),
      );
      final refB = ctx.citations.refFor(
        b,
        title: '出发',
        date: DateTime(2026, 11, 1),
      );

      final movePreview = await preview('move_to_notebook_chapter', {
        'notebook_id': nb,
        'ids': [refA, refB],
        'chapter_id': '行程',
      }, with_: ctx);
      expect(movePreview!.title, zh.aiToolMoveToChapterIn(2, '旅行手记'));

      final moved = await run('move_to_notebook_chapter', {
        'notebook_id': nb,
        'ids': [refA, refB],
        'chapter_id': '行程',
      }, with_: ctx);
      expect((moved.data! as Map)['moved'], 2);
      expect(await db.getNotebookEntryChapters(nb, [a, b]), {
        a: c2.id,
        b: c2.id,
      });

      // 移回未分章（传空串 ""）。
      final cleared = await run('move_to_notebook_chapter', {
        'notebook_id': nb,
        'ids': [a],
        'chapter_id': '',
      });
      expect(await db.getNotebookEntryChapters(nb, [a, b]), {
        a: null,
        b: c2.id,
      });
      await undo('move_to_notebook_chapter', cleared);
      expect(await db.getNotebookEntryChapters(nb, [a, b]), {
        a: c2.id,
        b: c2.id,
      });

      // 撤销第一次移章：a 回到行前、b 回到未分章。
      await undo('move_to_notebook_chapter', moved);
      expect(await db.getNotebookEntryChapters(nb, [a, b]), {
        a: c1.id,
        b: null,
      });
    });

    test(
      'add_to_notebook accepts optional chapter_id and undoes cleanly',
      () async {
        final c1 = NotebookChapter(id: 'ch000001', title: '行前');
        final c2 = NotebookChapter(id: 'ch000002', title: '行程');
        final nb = await db.createNotebook(
          name: '旅行手记',
          payload: NotebookPayload(chapters: [c1, c2]),
        );
        final fresh = await diary('新篇');
        final existing = await diary('已有篇');
        await db.addDiariesToNotebook(nb, [existing], chapterId: c1.id);

        // 章节不存在时整批不写。
        await expectLater(
          () => run('add_to_notebook', {
            'notebook_id': nb,
            'ids': [fresh],
            'chapter_id': '不存在',
          }),
          throwsA(isA<AiToolFailure>()),
        );
        expect(await db.getDiaryNotebookIds(fresh), isEmpty);

        // fresh 收进 c2，已在本子里的 existing 也从 c1 移到 c2。
        final added = await run('add_to_notebook', {
          'notebook_id': nb,
          'ids': [fresh, existing],
          'chapter_id': '行程',
        });
        final data = added.data! as Map;
        expect(data['added'], 1);
        expect(data['moved_to_chapter'], 1);
        expect(data['chapter_id'], c2.id);
        expect(await db.getNotebookEntryChapters(nb, [fresh, existing]), {
          fresh: c2.id,
          existing: c2.id,
        });

        // 撤销：fresh 移出本子，existing 回到 c1。
        await undo('add_to_notebook', added);
        expect(await db.getNotebookEntryChapters(nb, [fresh, existing]), {
          existing: c1.id,
        });
      },
    );

    test('create_diary and create_diary_from_template place new entries in '
        'the chosen chapter', () async {
      final c1 = NotebookChapter(id: 'ch000001', title: '行程');
      final nb = await db.createNotebook(
        name: '旅行手记',
        payload: NotebookPayload(chapters: [c1]),
      );

      // 给了 chapter_id 没给 notebook_id 时拒绝。
      expect(
        () => run('create_diary', {'body': '正文', 'chapter_id': c1.id}),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('create_diary', {
          'body': '正文',
          'notebook_id': nb,
          'chapter_id': '不存在',
        }),
        throwsA(isA<AiToolFailure>()),
      );

      final created = await run('create_diary', {
        'title': '第一天',
        'body': '坐新干线出发。',
        'notebook_id': nb,
        'chapter_id': '行程',
      });
      final diaryId = (created.data! as Map)['id']! as String;
      expect((created.data! as Map)['chapter_id'], c1.id);
      expect(await db.getNotebookEntryChapters(nb, [diaryId]), {
        diaryId: c1.id,
      });
      await undo('create_diary', created);
      expect(
        (await db.getDiaryWithTagsByDiaryId(diaryId))!.diary.isDeleted,
        isTrue,
      );

      final tpl = await run('create_template', {
        'name': '行程记录',
        'body': '今日行程：',
      });
      final templateId = (tpl.data! as Map)['id']! as String;
      expect(
        () => run('create_diary_from_template', {
          'template_id': templateId,
          'body': '今天一切顺利。',
          'chapter_id': c1.id,
        }),
        throwsA(isA<AiToolFailure>()),
      );
      final fromTpl = await run('create_diary_from_template', {
        'template_id': templateId,
        'body': '今天一切顺利。',
        'notebook_id': nb,
        'chapter_id': c1.id,
      });
      final tplDiaryId = (fromTpl.data! as Map)['id']! as String;
      expect(await db.getNotebookEntryChapters(nb, [tplDiaryId]), {
        tplDiaryId: c1.id,
      });
      await undo('create_diary_from_template', fromTpl);
      expect(
        (await db.getDiaryWithTagsByDiaryId(tplDiaryId))!.diary.isDeleted,
        isTrue,
      );
    });
  });
}
