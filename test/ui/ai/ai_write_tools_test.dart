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
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
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
  'delete_todos',
  'create_anniversary',
  'delete_anniversary',
  'set_day_mood',
  'set_theme',
  'set_app_language',
  'set_font_scale',
  'set_feature_enabled',
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

  Future<AiToolOutcome> run(String name, Map<String, Object?> args) {
    final tool = aiToolByName(name)!;
    return tool.run(context(), tool.schema.validate(args));
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
