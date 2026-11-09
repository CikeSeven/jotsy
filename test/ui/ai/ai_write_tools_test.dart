import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/models/ai_tool_subject.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/diaries/models/diary_create_prefs.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/providers/todo_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 改动数据的工具：每个都执行一次、再撤销，数据回到原样；私密日记不写；
/// 撤销前发现之后又被改过时先报冲突。新写工具必须加进 [_covered] 并在
/// 这里补往返测试。
const Set<String> _covered = <String>{
  'create_diary',
  'append_to_diary',
  'update_diary',
  'tag_diaries',
  'pin_diaries',
  'archive_diaries',
  'trash_diaries',
  'add_comment',
  'create_tag',
  'rename_tag',
  'merge_tags',
  'delete_tag',
  'create_notebook',
  'rename_notebook',
  'add_to_notebook',
  'remove_from_notebook',
  'create_todo',
  'update_todos',
  'complete_todos',
  'reopen_todos',
  'edit_todo_steps',
  'delete_todos',
  'create_todo_list',
  'rename_todo_list',
  'delete_todo_list',
  'create_anniversary',
  'delete_anniversary',
  'set_day_mood',
  'set_theme',
  'set_app_language',
  'set_font_scale',
  'set_feature_enabled',
  'change_settings',
};

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
    // 让 provider 先读到设置（功能开关、日记本树）。
    await container.read(settingsServiceProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  AiToolContext context({AppFeatures features = everything}) => AiToolContext(
    container: container,
    l10n: zh,
    kit: AiPromptKit.resolve(
      prefs: AiPreferences.defaults,
      appLocale: const Locale('zh'),
    ),
    env: AiToolEnv(features: features, prefs: AiPreferences.defaults),
    citations: AiCitationBook(),
    allowance: AiWordAllowance(100000),
    token: HttpCancelToken(),
    now: DateTime(2026, 11, 8, 10),
  );

  Future<AiToolOutcome> run(
    String name,
    Map<String, Object?> args, {
    AppFeatures features = everything,
  }) async {
    final tool = aiToolByName(name)!;
    final outcome = await tool.run(
      context(features: features),
      tool.schema.validate(args),
    );
    // 改动类工具都要说清改了谁（卡片标题与对象胶囊靠它），设置类除外。
    if (tool.group != AiToolGroup.settings) {
      expect(outcome.subjects, isNotEmpty, reason: '$name names no subject');
    }
    return outcome;
  }

  Future<void> undo(String name, AiToolOutcome outcome, {bool force = false}) =>
      aiToolByName(name)!.undo(container, outcome.undo!, force: force);

  Future<String> diary(
    String title, {
    List<int> tagIds = const <int>[],
    DateTime? at,
  }) => db.createDiary(
    title: title,
    contentDocJson: '',
    contentText: '$title 的正文',
    metadataJson: '{}',
    tagIds: tagIds,
    createdAtOverride: at ?? DateTime(2026, 11, 1, 9),
  );

  Future<Diary> row(String id) async =>
      (await db.getDiaryWithTagsByDiaryId(id))!.diary;

  Future<Set<String>> tagsOf(String id) async =>
      (await db.getDiaryWithTagsByDiaryId(id))!.tags.map((t) => t.name).toSet();

  Future<String> privateNotebook() =>
      db.createNotebook(name: '私密', visibility: NotebookVisibility.hidden);

  test('every tool that changes data is covered here and can be undone', () {
    final changing = {
      for (final tool in aiTools)
        if (aiToolChangesData(tool)) tool.name,
    };
    expect(changing, _covered);
  });

  group('diaries', () {
    test('create_diary writes the entry and undo trashes it', () async {
      final existing = await db.createTag(name: '旅行', color: 1);
      final mood = settings.moodOptions.first;
      final outcome = await run('create_diary', {
        'title': '海边',
        'body': '# 今天\n\n去了**海边**。',
        'date': '2026-11-05',
        'time': '18:30',
        'tags': ['旅行', '海'],
        'mood': mood,
        'weather': '晴',
      });
      final id = (outcome.data! as Map)['id']! as String;
      final created = await row(id);
      expect(created.title, '海边');
      expect(created.createdAt, DateTime(2026, 11, 5, 18, 30));
      expect(created.contentText, contains('去了海边'));
      expect(await tagsOf(id), {'旅行', '海'});
      final meta = PublishMetadataComposer.parse(created.metadata);
      expect(meta.moodEmoji, mood);
      expect(meta.weather, '晴');

      await undo('create_diary', outcome);
      expect((await row(id)).isDeleted, isTrue);
      // 新建的“海”跟着删掉，原有的“旅行”留着。
      final names = (await db.watchAllTags().first).map((t) => t.id);
      expect(names, [existing]);
    });

    test(
      'create_diary rejects moods outside the options and private notebooks',
      () async {
        expect(
          () => run('create_diary', {'body': 'x', 'mood': '🦄🦄'}),
          throwsA(isA<AiToolFailure>()),
        );
        final notebook = await privateNotebook();
        expect(
          () => run('create_diary', {'body': 'x', 'notebook_id': notebook}),
          throwsA(isA<AiToolFailure>()),
        );
      },
    );

    test(
      'append_to_diary adds text; undo restores, or reports a later edit',
      () async {
        final id = await diary('周末');
        final outcome = await run('append_to_diary', {
          'id': id,
          'text': '补一句：晚上看了电影。',
        });
        expect((await row(id)).contentText, contains('晚上看了电影'));
        await undo('append_to_diary', outcome);
        expect((await row(id)).contentText, isNot(contains('晚上看了电影')));

        final again = await run('append_to_diary', {'id': id, 'text': '再补一句'});
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await db.updateDiaryContent(
          diaryId: id,
          contentDocJson: '',
          contentText: '用户自己又改了',
        );
        expect(
          () => undo('append_to_diary', again),
          throwsA(isA<AiUndoConflict>()),
        );
        await undo('append_to_diary', again, force: true);
        expect((await row(id)).contentText, isNot(contains('再补一句')));
      },
    );

    test('update_diary changes details but keeps the archive state', () async {
      final id = await diary('旧');
      await db.archiveDiary(id, touchUpdatedAt: false);
      final mood = settings.moodOptions[1];
      final outcome = await run('update_diary', {
        'id': id,
        'title': '新',
        'mood': mood,
        'date': '2026-10-31',
      });
      var changed = await row(id);
      expect(changed.title, '新');
      expect(changed.isArchived, isTrue);
      expect(changed.createdAt, DateTime(2026, 10, 31, 9));
      expect(PublishMetadataComposer.parse(changed.metadata).moodEmoji, mood);

      await undo('update_diary', outcome);
      changed = await row(id);
      expect(changed.title, '旧');
      expect(changed.createdAt, DateTime(2026, 11, 1, 9));
      expect(PublishMetadataComposer.parse(changed.metadata).moodEmoji, isNull);
      expect(
        () => run('update_diary', {'id': id, 'date': '2027-01-01'}),
        throwsA(isA<AiToolFailure>()),
      );
    });

    test('private entries are never written', () async {
      final id = await diary('秘密');
      await db.addDiariesToNotebook(await privateNotebook(), [id]);
      expect(
        () => run('append_to_diary', {'id': id, 'text': 'x'}),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('pin_diaries', {
          'ids': [id],
          'pinned': true,
        }),
        throwsA(isA<AiToolFailure>()),
      );
    });

    test(
      'tag_diaries, pin, archive and trash undo to each previous state',
      () async {
        final keep = await db.createTag(name: '保留', color: 1);
        final a = await diary('a', tagIds: [keep]);
        final b = await diary('b');
        await db.pinDiary(b);

        final tagged = await run('tag_diaries', {
          'ids': [a, b],
          'add': ['新'],
          'remove': ['保留'],
        });
        expect(await tagsOf(a), {'新'});
        await undo('tag_diaries', tagged);
        expect(await tagsOf(a), {'保留'});
        expect(await tagsOf(b), isEmpty);

        final pinned = await run('pin_diaries', {
          'ids': [a, b],
          'pinned': true,
        });
        expect((await row(a)).isPinned, isTrue);
        await undo('pin_diaries', pinned);
        expect((await row(a)).isPinned, isFalse);
        expect((await row(b)).isPinned, isTrue);

        final archived = await run('archive_diaries', {
          'ids': [a],
          'archived': true,
        });
        expect((await row(a)).isArchived, isTrue);
        await undo('archive_diaries', archived);
        expect((await row(a)).isArchived, isFalse);

        final trashed = await run('trash_diaries', {
          'ids': [a, b],
        });
        expect((await row(a)).isDeleted, isTrue);
        await undo('trash_diaries', trashed);
        expect((await row(a)).isDeleted, isFalse);
        expect((await row(b)).isDeleted, isFalse);
      },
    );

    test('add_comment writes a comment and undo removes it', () async {
      final id = await diary('a');
      final outcome = await run('add_comment', {'id': id, 'text': '真好'});
      expect((await db.watchDiaryComments(id).first).single.content, '真好');
      await undo('add_comment', outcome);
      expect(await db.watchDiaryComments(id).first, isEmpty);
    });
  });

  group('tags and notebooks', () {
    test('create, rename, merge and delete tags all undo', () async {
      final created = await run('create_tag', {
        'name': '读书',
        'color': '#336699',
      });
      expect(
        (await db.watchAllTags().first).single.color,
        const Color(0xFF336699).toARGB32(),
      );
      expect(
        () => run('create_tag', {'name': '读书'}),
        throwsA(isA<AiToolFailure>()),
      );
      final renamed = await run('rename_tag', {'name': '读书', 'new_name': '阅读'});
      expect((await db.watchAllTags().first).single.name, '阅读');
      await undo('rename_tag', renamed);
      expect((await db.watchAllTags().first).single.name, '读书');
      await undo('create_tag', created);
      expect(await db.watchAllTags().first, isEmpty);

      final trip = await db.createTag(name: '出行', color: 1);
      final travel = await db.createTag(name: '旅行', color: 2);
      final id = await diary('a', tagIds: [trip]);
      final merged = await run('merge_tags', {
        'from': ['出行'],
        'into': '旅行',
      });
      expect(await tagsOf(id), {'旅行'});
      await undo('merge_tags', merged);
      expect(await tagsOf(id), {'出行'});

      final deleted = await run('delete_tag', {'name': '出行'});
      expect(await tagsOf(id), isEmpty);
      await undo('delete_tag', deleted);
      expect(await tagsOf(id), {'出行'});
      expect(travel, isNot(trip));
    });

    test('notebooks: create, rename, add and remove all undo', () async {
      final created = await run('create_notebook', {'name': '旅行'});
      final notebook = (created.data! as Map)['id']! as String;
      final renamed = await run('rename_notebook', {
        'notebook_id': notebook,
        'name': '远方',
      });
      expect((await db.getNotebook(notebook))!.name, '远方');
      await undo('rename_notebook', renamed);
      expect((await db.getNotebook(notebook))!.name, '旅行');

      final a = await diary('a');
      final b = await diary('b');
      await db.addDiariesToNotebook(notebook, [b]);
      final added = await run('add_to_notebook', {
        'notebook_id': notebook,
        'ids': [a, b],
      });
      expect((added.data! as Map)['added'], 1);
      expect(await db.getDiaryNotebookIds(a), {notebook});
      await undo('add_to_notebook', added);
      expect(await db.getDiaryNotebookIds(a), isEmpty);
      // 本来就在里面的那篇不受撤销影响。
      expect(await db.getDiaryNotebookIds(b), {notebook});

      final removed = await run('remove_from_notebook', {
        'notebook_id': notebook,
        'ids': [b],
      });
      expect(await db.getDiaryNotebookIds(b), isEmpty);
      await undo('remove_from_notebook', removed);
      expect(await db.getDiaryNotebookIds(b), {notebook});

      // 本子里已经有日记：撤销新建会丢掉归属，先报冲突。
      expect(
        () => undo('create_notebook', created),
        throwsA(isA<AiUndoConflict>()),
      );
      await undo('create_notebook', created, force: true);
      expect(await db.getNotebook(notebook), isNull);
    });

    test('private notebooks cannot take entries', () async {
      final notebook = await privateNotebook();
      final a = await diary('a');
      expect(
        () => run('add_to_notebook', {
          'notebook_id': notebook,
          'ids': [a],
        }),
        throwsA(isA<AiToolFailure>()),
      );
    });
  });

  group('calendar', () {
    test('to-dos: create, update, complete and delete all undo', () async {
      final list = await db.createTodoList(name: '工作');
      final created = await run('create_todo', {
        'title': '交报告',
        'date': '2026-11-09',
        'time': '09:00',
        'list': '工作',
        'priority': 'high',
      });
      final id = (created.data! as Map)['id']! as String;
      var todo = (await db.getTodo(id))!;
      expect(todo.listId, list);
      expect(todo.dueDate, '2026-11-09');
      expect(todo.dueMinute, 9 * 60);
      expect(
        () => run('create_todo', {'title': 'x', 'list': '不存在'}),
        throwsA(isA<AiToolFailure>()),
      );

      final updated = await run('update_todos', {
        'ids': [id],
        'date': '2026-11-10',
        'priority': 'low',
        'title': '交周报',
      });
      todo = (await db.getTodo(id))!;
      expect(todo.dueDate, '2026-11-10');
      expect(todo.title, '交周报');
      await undo('update_todos', updated);
      todo = (await db.getTodo(id))!;
      expect(todo.dueDate, '2026-11-09');
      expect(todo.title, '交报告');
      expect(todo.priority, 3);

      final completed = await run('complete_todos', {
        'ids': [id],
      });
      expect((await db.getTodo(id))!.completedAt, isNotNull);
      await undo('complete_todos', completed);
      expect((await db.getTodo(id))!.completedAt, isNull);

      final deleted = await run('delete_todos', {
        'ids': [id],
      });
      expect(await db.getTodo(id), isNull);
      await undo('delete_todos', deleted);
      expect((await db.getTodo(id))!.title, '交报告');

      await undo('create_todo', created);
      expect(await db.getTodo(id), isNull);
    });

    test(
      'create_todo takes steps, reminders, repeat and the default list',
      () async {
        final work = await db.createTodoList(name: '工作');
        await saveTodoSettings(
          settings,
          TodoSettings.defaults.copyWith(defaultListId: work),
        );
        final created = await run('create_todo', {
          'title': '浇花',
          'steps': ['接水', '浇水'],
          'repeat': {
            'frequency': 'daily',
            'interval': 3,
            'from_completion': true,
          },
          'reminders': [
            {'time': '20:00', 'days_before': 1},
          ],
        });
        final data = created.data! as Map;
        final id = data['id']! as String;
        final todo = (await db.getTodo(id))!;
        // 没给清单进默认清单；设了重复没给日期，截止日定为今天。
        expect(todo.listId, work);
        expect(todo.dueDate, '2026-11-08');
        expect(data['due_date'], '2026-11-08');
        expect(decodeTodoSteps(todo.steps).map((s) => s.title), ['接水', '浇水']);
        final rule = decodeTodoRepeat(todo.repeat)!;
        expect(rule.frequency, TodoRepeatFrequency.daily);
        expect(rule.interval, 3);
        expect(rule.basis, TodoRepeatBasis.completion);
        expect(rule.anchor, DateTime(2026, 11, 8));
        expect(decodeTodoReminders(todo.reminders), [
          const TodoReminder.onDay(days: -1, minute: 20 * 60),
        ]);

        final inbox = await run('create_todo', {'title': '随手记', 'list': ''});
        expect(
          (await db.getTodo((inbox.data! as Map)['id']! as String))!.listId,
          isNull,
        );
        // 全天待办到不了“截止前若干分钟”。
        expect(
          () => run('create_todo', {
            'title': 'x',
            'date': '2026-11-09',
            'reminders': [
              {'minutes_before': 10},
            ],
          }),
          throwsA(isA<AiToolFailure>()),
        );
        await undo('create_todo', created);
        expect(await db.getTodo(id), isNull);
      },
    );

    test('update_todos keeps each time, sets reminders, repeat and a link, '
        'and undo puts everything back', () async {
      final a = await db.createTodo(
        TodoInput(
          title: 'a',
          dueDate: DateTime(2026, 11, 9),
          dueMinute: 9 * 60,
          reminders: const [TodoReminder.beforeDue(15)],
        ),
      );
      final b = await db.createTodo(
        TodoInput(title: 'b', dueDate: DateTime(2026, 11, 9)),
      );

      // 只给日期：各自保留时刻（与多选改日期同一口径）。
      final moved = await run('update_todos', {
        'ids': [a, b],
        'date': '2026-11-12',
      });
      var rowA = (await db.getTodo(a))!;
      expect(rowA.dueDate, '2026-11-12');
      expect(rowA.dueMinute, 9 * 60);
      expect((await db.getTodo(b))!.dueMinute, isNull);
      await undo('update_todos', moved);
      expect((await db.getTodo(a))!.dueDate, '2026-11-09');
      expect((await db.getTodo(b))!.dueDate, '2026-11-09');

      // 改为全天：去掉“截止前”提醒；撤销连提醒一起放回。
      final allDay = await run('update_todos', {
        'ids': [a],
        'all_day': true,
      });
      rowA = (await db.getTodo(a))!;
      expect(rowA.dueMinute, isNull);
      expect(decodeTodoReminders(rowA.reminders), isEmpty);
      await undo('update_todos', allDay);
      rowA = (await db.getTodo(a))!;
      expect(rowA.dueMinute, 9 * 60);
      expect(decodeTodoReminders(rowA.reminders), [
        const TodoReminder.beforeDue(15),
      ]);

      final entry = await diary('周报');
      final changed = await run('update_todos', {
        'ids': [b],
        'reminders': [
          {'time': '08:30'},
        ],
        'repeat': {
          'frequency': 'weekly',
          'weekdays': [1, 3],
        },
        'diary_id': entry,
      });
      var rowB = (await db.getTodo(b))!;
      expect(decodeTodoReminders(rowB.reminders), [
        const TodoReminder.onDay(days: 0, minute: 8 * 60 + 30),
      ]);
      expect(decodeTodoRepeat(rowB.repeat)!.weekdays, [1, 3]);
      expect(rowB.linkedDiaryId, entry);
      expect(
        changed.subjects.map((s) => s.kind),
        containsAll([AiSubjectKind.todo, AiSubjectKind.diary]),
      );
      await undo('update_todos', changed);
      rowB = (await db.getTodo(b))!;
      expect(decodeTodoReminders(rowB.reminders), isEmpty);
      expect(rowB.repeat, isNull);
      expect(rowB.linkedDiaryId, isNull);

      // 校验都在写库之前：有一条不合规就整批不做。
      final c = await db.createTodo(const TodoInput(title: 'c'));
      await expectLater(
        () => run('update_todos', {
          'ids': [a, c],
          'time': '10:00',
        }),
        throwsA(isA<AiToolFailure>()),
      );
      expect((await db.getTodo(a))!.dueMinute, 9 * 60);
      expect(
        () => run('update_todos', {
          'ids': [b],
          'reminders': [
            {'minutes_before': 5},
          ],
        }),
        throwsA(isA<AiToolFailure>()),
      );
    });

    test('reopen_todos and edit_todo_steps undo', () async {
      final id = await db.createTodo(
        const TodoInput(
          title: '买菜',
          steps: [TodoStep(id: 's0', title: '牛奶')],
        ),
      );
      await db.completeTodo(id);
      final reopened = await run('reopen_todos', {
        'ids': [id],
      });
      expect((await db.getTodo(id))!.completedAt, isNull);
      await undo('reopen_todos', reopened);
      expect((await db.getTodo(id))!.completedAt, isNotNull);
      final open = await db.createTodo(const TodoInput(title: '没完成'));
      expect(
        () => run('reopen_todos', {
          'ids': [open],
        }),
        throwsA(isA<AiToolFailure>()),
      );

      final edited = await run('edit_todo_steps', {
        'id': id,
        'add_steps': ['鸡蛋'],
        'check_steps': ['牛奶'],
      });
      expect(decodeTodoSteps((await db.getTodo(id))!.steps), const [
        TodoStep(id: 's0', title: '牛奶', done: true),
        TodoStep(id: 's1', title: '鸡蛋'),
      ]);
      expect(
        () => run('edit_todo_steps', {
          'id': id,
          'remove_steps': ['不存在'],
        }),
        throwsA(isA<AiToolFailure>()),
      );
      await undo('edit_todo_steps', edited);
      expect(decodeTodoSteps((await db.getTodo(id))!.steps), const [
        TodoStep(id: 's0', title: '牛奶'),
      ]);
    });

    test('to-do lists: create, rename and delete all undo', () async {
      final created = await run('create_todo_list', {'name': '旅行'});
      expect(
        () => run('create_todo_list', {'name': '旅行'}),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('create_todo_list', {'name': 'Inbox'}),
        throwsA(isA<AiToolFailure>()),
      );
      final listId = (await db.getTodoLists()).single.listId;
      final renamed = await run('rename_todo_list', {
        'name': '旅行',
        'new_name': '出行',
      });
      expect((await db.getTodoList(listId))!.name, '出行');
      await undo('rename_todo_list', renamed);
      expect((await db.getTodoList(listId))!.name, '旅行');

      final todo = await db.createTodo(TodoInput(title: '订票', listId: listId));
      final tool = aiToolByName('delete_todo_list')!;
      final preview = await tool.preview(
        context(),
        tool.schema.validate({'name': '旅行'}),
      );
      expect(preview!.lines, [zh.aiToolDeleteTodoListCount(1)]);
      final deleted = await run('delete_todo_list', {'name': '旅行'});
      expect(await db.getTodoLists(), isEmpty);
      expect(await db.getTodo(todo), isNull);
      await undo('delete_todo_list', deleted);
      expect((await db.getTodo(todo))!.listId, listId);

      // 撤销新建：清单里已经有待办时先报冲突，仍要撤销就把待办移回收集箱。
      await expectLater(
        () => undo('create_todo_list', created),
        throwsA(isA<AiUndoConflict>()),
      );
      await undo('create_todo_list', created, force: true);
      expect(await db.getTodoLists(), isEmpty);
      expect((await db.getTodo(todo))!.listId, isNull);
    });

    test('anniversaries and the day mood undo', () async {
      final created = await run('create_anniversary', {
        'title': '生日',
        'date': '1990-05-20',
        'repeat': 'yearly',
      });
      final id = (created.data! as Map)['id']! as String;
      expect((await db.watchAnniversaries().first).single.title, '生日');
      final deleted = await run('delete_anniversary', {'id': id});
      expect(await db.watchAnniversaries().first, isEmpty);
      await undo('delete_anniversary', deleted);
      expect((await db.watchAnniversaries().first).single.anniversaryId, id);
      await undo('create_anniversary', created);
      expect(await db.watchAnniversaries().first, isEmpty);

      final first = await run('set_day_mood', {
        'date': '2026-11-08',
        'mood': 'good',
      });
      final second = await run('set_day_mood', {
        'date': '2026-11-08',
        'mood': 'bad',
      });
      expect((await db.watchDayMoods().first).single.mood, 'bad');
      await undo('set_day_mood', second);
      expect((await db.watchDayMoods().first).single.mood, 'good');
      await undo('set_day_mood', first);
      expect(await db.watchDayMoods().first, isEmpty);
    });
  });

  group('settings', () {
    test('theme, language and text size go back on undo', () async {
      final theme = await run('set_theme', {
        'mode': 'dark',
        'color': '#AA3300',
      });
      expect(settings.themeModeNotifier.value, ThemeMode.dark);
      await undo('set_theme', theme);
      expect(settings.themeModeNotifier.value, isNot(ThemeMode.dark));

      final before = settings.appLocaleCode;
      final language = await run('set_app_language', {'language': 'ja'});
      expect(settings.appLocaleCode, 'ja');
      await undo('set_app_language', language);
      expect(settings.appLocaleCode, before);

      final scale = settings.fontScaleValue;
      final size = await run('set_font_scale', {'scale': 1.2});
      expect(settings.fontScaleValue, isNot(scale));
      await undo('set_font_scale', size);
      expect(settings.fontScaleValue, scale);
    });

    test(
      'change_settings changes several settings and undo restores only them',
      () async {
        final work = await db.createTodoList(name: '工作');
        final outcome = await run('change_settings', {
          'todo_show_completed': false,
          'todo_sort': 'due',
          'todo_default_list': '工作',
          'todo_all_day_reminder_time': '08:00',
          'calendar_week_start': 'monday',
          'calendar_lunar': 'hide',
          'open_diary_in_editor': true,
          'publish_on_leave': true,
        });
        TodoSettings todos() =>
            TodoSettings.decode(settings.todoSettingsRawNotifier.value);
        CalendarDisplayOptions calendar() => CalendarDisplayOptions.decode(
          settings.calendarDisplayOptionsRawNotifier.value,
        );
        expect(todos().showCompleted, isFalse);
        expect(todos().sort, TodoSortMode.due);
        expect(todos().defaultListId, work);
        expect(todos().allDayReminderMinute, 8 * 60);
        expect(calendar().weekStart, CalendarWeekStart.monday);
        expect(calendar().lunarMode, CalendarLunarMode.never);
        expect(
          DiaryPreviewSettings.decode(
            settings.diaryPreviewStyleRawNotifier.value,
          ).behavior.openInEditor,
          isTrue,
        );
        expect(
          DiaryCreatePrefs.decode(
            settings.diaryCreatePrefsRawNotifier.value,
          ).publishOnLeave,
          isTrue,
        );

        // 用户之后在同一页改了别的设置：撤销只写回 AI 改过的那几项。
        await saveTodoSettings(settings, todos().copyWith(smartParse: false));
        await undo('change_settings', outcome);
        expect(todos().showCompleted, isTrue);
        expect(todos().sort, TodoSortMode.manual);
        expect(todos().defaultListId, isNull);
        expect(todos().allDayReminderMinute, 9 * 60);
        expect(todos().smartParse, isFalse);
        expect(calendar(), const CalendarDisplayOptions());
        expect(
          DiaryPreviewSettings.decode(
            settings.diaryPreviewStyleRawNotifier.value,
          ).behavior.openInEditor,
          isFalse,
        );
        expect(
          DiaryCreatePrefs.decode(
            settings.diaryCreatePrefsRawNotifier.value,
          ).publishOnLeave,
          isFalse,
        );
      },
    );

    test('change_settings checks features and values before writing', () async {
      // 待办功能关着：整次不做，同一次里的日历设置也不写。
      await expectLater(
        () => run('change_settings', {
          'calendar_week_numbers': true,
          'todo_sort': 'due',
        }, features: AppFeatures.defaults),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        CalendarDisplayOptions.decode(
          settings.calendarDisplayOptionsRawNotifier.value,
        ).showWeekNumbers,
        isFalse,
      );
      expect(
        () => run('change_settings', {'todo_snooze_minutes': 7}),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('change_settings', {'todo_default_list': '不存在'}),
        throwsA(isA<AiToolFailure>()),
      );
      expect(() => run('change_settings', {}), throwsA(isA<AiToolFailure>()));
      final same = await run('change_settings', {'todo_show_completed': true});
      expect((same.data! as Map)['already_set'], ['todo_show_completed']);
      expect(same.undo, {'previous': <String, Object?>{}});
    });

    test(
      'features toggle and undo; notebooks with private ones stay on',
      () async {
        final toggled = await run('set_feature_enabled', {
          'feature': 'todos',
          'enabled': true,
        });
        expect(container.read(appFeaturesProvider).todos, isTrue);
        await undo('set_feature_enabled', toggled);
        expect(container.read(appFeaturesProvider).todos, isFalse);

        await privateNotebook();
        expect(
          () => run('set_feature_enabled', {
            'feature': 'notebooks',
            'enabled': false,
          }),
          throwsA(isA<AiToolFailure>()),
        );
      },
    );
  });
}
