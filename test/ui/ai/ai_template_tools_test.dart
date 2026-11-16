import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/models/ai_tool_subject.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_tool_facts.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_built_ins.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_json.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:node_diary/ui/diary_templates/providers/diary_template_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 的日记模板工具：查询、每个改动类工具执行再撤销、撤销冲突、功能开关。
/// 改动类工具同时登记在 `ai_write_tools_test.dart` 的清单里。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SettingsService settings;
  late ProviderContainer container;
  final zh = lookupAppLocalizations(const Locale('zh'));
  const everything = AppFeatures(timeCapsules: true, ai: true);
  final now = DateTime(2026, 11, 8, 10);

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
    now: now,
  );

  Future<AiToolOutcome> run(String name, Map<String, Object?> args) async {
    final tool = aiToolByName(name)!;
    final outcome = await tool.run(context(), tool.schema.validate(args));
    if (aiToolChangesData(tool) && tool.group != AiToolGroup.settings) {
      expect(outcome.subjects, isNotEmpty, reason: '$name names no subject');
    }
    return outcome;
  }

  Future<void> undo(String name, AiToolOutcome outcome, {bool force = false}) =>
      aiToolByName(name)!.undo(container, outcome.undo!, force: force);

  Map<String, Object?> data(AiToolOutcome outcome) =>
      (outcome.data! as Map).cast<String, Object?>();

  DiaryTemplatePrefs prefs() =>
      DiaryTemplatePrefs.decode(settings.diaryTemplatePrefsRaw);

  Future<String?> payloadOf(String id) async =>
      (await db.getDiaryTemplate(id))?.payload;

  const body =
      '<span style="color: orange">**书名**</span>：\n'
      '\n'
      '<callout icon="📚" tone="blue">读到哪儿了？</callout>\n'
      '- [ ] 摘抄\n'
      '  - 第一句\n'
      '| 章节 | 感想 |\n'
      '| --- | --- |\n'
      '|  |  |\n'
      '写于 {{日期}}';

  group('reading', () {
    test(
      'list_templates shows built-ins, settings and the variables',
      () async {
        await saveDiaryTemplatePrefs(
          settings,
          prefs().withHidden('builtin.reading', true).withAuto('builtin.daily'),
        );
        final result = data(await run('list_templates', const {}));
        final templates = (result['templates']! as List).cast<Map>();
        expect(templates.map((t) => t['id']), contains('builtin.morning'));
        expect(
          templates.map((t) => t['id']),
          isNot(contains('builtin.reading')),
        );
        expect((result['deleted_built_ins']! as List).single, {
          'id': 'builtin.reading',
          'name': '读书笔记',
        });
        expect(
          (result['auto_apply']! as Map)['default_template_id'],
          'builtin.daily',
        );
        expect(result['suggestions_on_new_entry'], isTrue);
        expect((result['variables']! as Map)['date'], '{{日期}}');
        expect((result['variables']! as Map)['solar_term'], '{{节气}}');
        // 正文只在 get_template 里给。
        expect(templates.first.containsKey('body'), isFalse);
      },
    );

    test('get_template gives the body in template Markdown', () async {
      final result = data(
        await run('get_template', {
          'ids': ['builtin.reading'],
        }),
      );
      final template = (result['templates']! as List).single as Map;
      expect(template['built_in'], isTrue);
      expect(template['body'], contains('<span style="color:'));
      expect(template['body'], contains('书名**'));
    });

    test('an unknown or deleted template is reported clearly', () async {
      await saveDiaryTemplatePrefs(
        settings,
        prefs().withHidden('builtin.reading', true),
      );
      expect(
        () => run('get_template', {
          'ids': ['builtin.reading'],
        }),
        throwsA(
          isA<AiToolFailure>().having(
            (e) => e.message,
            'message',
            contains('restore_templates'),
          ),
        ),
      );
      expect(
        () => run('get_template', {
          'ids': ['nope'],
        }),
        throwsA(isA<AiToolFailure>()),
      );
    });

    test('template tools disappear when templates are turned off', () {
      final names = [
        for (final tool in aiAvailableTools(
          AiToolEnv(
            features: everything.copyWith(templates: false),
            prefs: AiPreferences.defaults,
          ),
        ))
          tool.name,
      ];
      for (final name in [
        'list_templates',
        'get_template',
        'create_template',
        'update_template',
        'delete_template',
        'reset_template',
        'restore_templates',
        'reorder_templates',
        'set_template_auto_apply',
        'set_notebook_template',
        'create_diary_from_template',
      ]) {
        expect(names, isNot(contains(name)));
      }
      expect(
        aiToolByName('set_notebook_template')!.isAvailable(
          AiToolEnv(
            features: everything.copyWith(notebooks: false),
            prefs: AiPreferences.defaults,
          ),
        ),
        isFalse,
      );
    });
  });

  group('changing templates', () {
    test('create_template writes a template from Markdown and undo deletes '
        'it', () async {
      final mood = settings.moodOptions.first;
      final outcome = await run('create_template', {
        'name': '读书',
        'description': '记下一本书',
        'category': 'life',
        'icon': 'bookOpen',
        'color': '#FB8C00',
        'title': '读书 · {{日期}}',
        'body': body,
        'tags': ['读书'],
        'mood': mood,
        'energy': 4,
        'capsule': 'month',
        'recommend': {
          'times': ['evening'],
          'weekdays': [6, 7],
        },
      });
      final id = data(outcome)['id']! as String;
      final saved = DiaryTemplateJson.fromPayload(
        (await payloadOf(id))!,
        id: id,
      )!;
      expect(saved.name, '读书');
      expect(saved.accent, 0xFFFB8C00);
      expect(saved.tags.single.name, '读书');
      expect(saved.mood, mood);
      expect(saved.energy, 4);
      expect(saved.capsule?.name, 'month');
      expect(saved.recommend.weekdays, {6, 7});
      expect(saved.bodyJson, contains('"type":"callout"'));
      expect(saved.bodyJson, contains('"type":"table"'));
      // 读回来就是写进去的那份正文。
      final read = data(
        await run('get_template', {
          'ids': [id],
        }),
      );
      expect(((read['templates']! as List).single as Map)['body'], body);

      await undo('create_template', outcome);
      expect(await db.getDiaryTemplate(id), isNull);
    });

    test('create_template copies a template or an entry', () async {
      final copy = await run('create_template', {
        'from_template_id': 'builtin.morning',
      });
      final copyId = data(copy)['id']! as String;
      final copied = DiaryTemplateJson.fromPayload(
        (await payloadOf(copyId))!,
        id: copyId,
      )!;
      final morning = buildBuiltInDiaryTemplates(
        zh,
      ).firstWhere((t) => t.id == 'builtin.morning');
      expect(copied.name, '晨间日记 副本');
      expect(copied.bodyJson, morning.bodyJson);

      final tag = await db.createTag(name: '旅行', color: 0xFF112233);
      final diaryId = await db.createDiary(
        title: '海边的一天',
        contentDocJson: encodeDiaryBlocks(diaryBlocksFromPlainText('风很大')),
        contentText: '风很大',
        metadataJson: '{}',
        tagIds: [tag],
        createdAtOverride: DateTime(2026, 11, 1, 9),
      );
      final fromDiary = await run('create_template', {
        'from_diary_id': diaryId,
      });
      final entry = DiaryTemplateJson.fromPayload(
        (await payloadOf(data(fromDiary)['id']! as String))!,
        id: 'x',
      )!;
      expect(entry.name, '海边的一天');
      expect(entry.bodyJson, contains('风很大'));
      expect(entry.tags.single.color, 0xFF112233);

      // 私密日记不能拿来做模板。
      final hidden = await db.createNotebook(
        name: '私密',
        visibility: NotebookVisibility.hidden,
      );
      await db.addDiariesToNotebook(hidden, [diaryId]);
      expect(
        () => run('create_template', {'from_diary_id': diaryId}),
        throwsA(isA<AiToolFailure>()),
      );
    });

    test('update_template edits a built-in template and undo brings the '
        'default back', () async {
      final get = data(
        await run('get_template', {
          'ids': ['builtin.daily'],
        }),
      );
      final original = ((get['templates']! as List).single as Map)['body']!;
      // 原样交回正文：不算改动，内置模板不会变成“已修改”。
      final same = await run('update_template', {
        'id': 'builtin.daily',
        'body': original,
      });
      expect(data(same)['note'], 'Nothing changed.');
      expect(await db.getDiaryTemplate('builtin.daily'), isNull);

      final outcome = await run('update_template', {
        'id': '每日记录',
        'name': '我的每日',
        'body': '$original\n- [ ] 喝水',
        'energy': 3,
      });
      final edited = DiaryTemplateJson.fromPayload(
        (await payloadOf('builtin.daily'))!,
        id: 'builtin.daily',
      )!;
      expect(edited.name, '我的每日');
      expect(edited.energy, 3);
      expect(edited.bodyJson, contains('喝水'));

      await undo('update_template', outcome);
      expect(await db.getDiaryTemplate('builtin.daily'), isNull);
    });

    test('undoing an edit made stale by a later change asks first', () async {
      final created = await run('create_template', {'name': 'A', 'body': 'x'});
      final id = data(created)['id']! as String;
      final edit = await run('update_template', {
        'id': id,
        'description': '第一次',
        'tags': ['甲'],
      });
      // 用户之后在管理页又改了一次。
      await run('update_template', {'id': id, 'description': '第二次'});
      expect(
        () => undo('update_template', edit),
        throwsA(isA<AiUndoConflict>()),
      );
      await undo('update_template', edit, force: true);
      final restored = DiaryTemplateJson.fromPayload(
        (await payloadOf(id))!,
        id: id,
      )!;
      expect(restored.description, '');
      expect(restored.tags, isEmpty);
    });

    test('delete_template removes its auto-apply rules and undo puts them '
        'back', () async {
      final created = await run('create_template', {'name': '晚安', 'body': ''});
      final id = data(created)['id']! as String;
      await run('set_template_auto_apply', {
        'default_template_id': id,
        'add_rules': [
          {'from': '22:00', 'to': '02:00', 'template_id': id},
        ],
      });
      final tool = aiToolByName('delete_template')!;
      final preview = await tool.preview(
        context(),
        tool.schema.validate({'id': id}),
      );
      expect(preview!.title, contains('晚安'));
      expect(preview.lines, contains(zh.aiToolDeleteTemplateAuto));

      final outcome = await run('delete_template', {'id': id});
      expect(await db.getDiaryTemplate(id), isNull);
      expect(prefs().autoTemplateId, isNull);
      expect(prefs().autoRules, isEmpty);

      await undo('delete_template', outcome);
      expect(await db.getDiaryTemplate(id), isNotNull);
      expect(prefs().autoTemplateId, id);
      expect(prefs().autoRules.single.templateId, id);
    });

    test('built-in templates: delete, restore and reset all undo', () async {
      final deleted = await run('delete_template', {'id': 'builtin.weekly'});
      expect(prefs().hiddenBuiltIns, {'builtin.weekly'});
      await undo('delete_template', deleted);
      expect(prefs().hiddenBuiltIns, isEmpty);

      await run('delete_template', {'id': 'builtin.weekly'});
      final restored = await run('restore_templates', {
        'ids': ['builtin.weekly'],
      });
      expect(prefs().hiddenBuiltIns, isEmpty);
      await undo('restore_templates', restored);
      expect(prefs().hiddenBuiltIns, {'builtin.weekly'});

      expect(
        () => run('reset_template', {'id': 'builtin.morning'}),
        throwsA(isA<AiToolFailure>()),
      );
      await run('update_template', {'id': 'builtin.morning', 'name': '早'});
      final reset = await run('reset_template', {'id': 'builtin.morning'});
      expect(await db.getDiaryTemplate('builtin.morning'), isNull);
      await undo('reset_template', reset);
      expect(
        DiaryTemplateJson.fromPayload(
          (await payloadOf('builtin.morning'))!,
          id: 'builtin.morning',
        )!.name,
        '早',
      );
    });

    test('reorder_templates moves the user\'s templates and undo puts them '
        'back', () async {
      final ids = [
        for (final name in ['一', '二', '三'])
          data(await run('create_template', {'name': name}))['id']! as String,
      ];
      final outcome = await run('reorder_templates', {
        'ids': [ids[2], ids[0]],
      });
      Future<List<String>> order() async => [
        for (final row in await db.getDiaryTemplates()) row.templateId,
      ];
      expect(await order(), [ids[2], ids[0], ids[1]]);
      expect(
        () => run('reorder_templates', {
          'ids': ['builtin.daily'],
        }),
        throwsA(isA<AiToolFailure>()),
      );
      await undo('reorder_templates', outcome);
      expect(await order(), ids);
    });

    test('set_template_auto_apply adds, removes and clears rules; undo '
        'restores them', () async {
      final first = await run('set_template_auto_apply', {
        'default_template_id': 'builtin.daily',
        'add_rules': [
          {
            'from': '07:00',
            'to': '10:00',
            'weekdays': [1, 2, 3, 4, 5],
            'template_id': 'builtin.morning',
          },
          {'from': '21:00', 'to': '23:30', 'template_id': '晚间复盘'},
        ],
      });
      expect(prefs().autoTemplateId, 'builtin.daily');
      expect(prefs().autoRules, hasLength(2));
      expect(prefs().autoRules.last.templateId, 'builtin.evening');

      final second = await run('set_template_auto_apply', {
        'default_template_id': '',
        'remove_rules': [
          {'from': '21:00', 'to': '23:30', 'template_id': 'builtin.evening'},
        ],
      });
      expect(prefs().autoTemplateId, isNull);
      expect(prefs().autoRules.single.startMinute, 7 * 60);
      expect(
        () => run('set_template_auto_apply', {
          'remove_rules': [
            {'from': '01:00', 'to': '02:00', 'template_id': 'builtin.daily'},
          ],
        }),
        throwsA(isA<AiToolFailure>()),
      );
      expect(
        () => run('set_template_auto_apply', {
          'add_rules': [
            {'from': '08:00', 'to': '08:00', 'template_id': 'builtin.daily'},
          ],
        }),
        throwsA(isA<AiToolFailure>()),
      );

      await undo('set_template_auto_apply', second);
      expect(prefs().autoTemplateId, 'builtin.daily');
      expect(prefs().autoRules, hasLength(2));
      // 撤销只写回这两项：用户期间关掉的建议条保持关着。
      await saveDiaryTemplatePrefs(settings, prefs().withStrip(false));
      await undo('set_template_auto_apply', first);
      expect(prefs(), const DiaryTemplatePrefs(showStrip: false));
    });

    test('set_notebook_template sets and clears a notebook\'s template, '
        'never a private one', () async {
      final notebook = await db.createNotebook(name: '旅行');
      final outcome = await run('set_notebook_template', {
        'notebook_id': notebook,
        'template_id': 'builtin.reading',
      });
      Future<String?> templateOf() async =>
          (await db.getNotebook(notebook))!.parsedPayload.templateId;
      expect(await templateOf(), 'builtin.reading');
      final listed = data(await run('list_templates', const {}));
      expect((listed['notebook_defaults']! as List).single, {
        'notebook_id': notebook,
        'notebook': '旅行',
        'template_id': 'builtin.reading',
      });
      await undo('set_notebook_template', outcome);
      expect(await templateOf(), isNull);

      final hidden = await db.createNotebook(
        name: '私密',
        visibility: NotebookVisibility.hidden,
      );
      expect(
        () => run('set_notebook_template', {
          'notebook_id': hidden,
          'template_id': 'builtin.daily',
        }),
        throwsA(isA<AiToolFailure>()),
      );
    });

    test('create_diary_from_template fills variables and presets; undo '
        'trashes the entry', () async {
      final mood = settings.moodOptions[1];
      final created = await run('create_template', {
        'name': '旅行',
        'title': '旅行 · {{日期}}',
        'body': body,
        'tags': ['旅行'],
        'mood': mood,
        'energy': 4,
        'capsule': 'year',
      });
      final id = data(created)['id']! as String;
      final outcome = await run('create_diary_from_template', {
        'template_id': id,
        'body': body.replaceFirst('：', '：《小王子》'),
        'date': '2026-11-05',
        'tags': ['读书'],
      });
      final diaryId = data(outcome)['id']! as String;
      final found = (await db.getDiaryWithTagsByDiaryId(diaryId))!;
      expect(found.diary.title, '旅行 · 2026年11月5日');
      expect(found.diary.contentText, contains('《小王子》'));
      expect(found.diary.contentText, contains('写于 2026年11月5日'));
      expect(found.tags.map((t) => t.name).toSet(), {'旅行', '读书'});
      final meta = PublishMetadataComposer.parse(found.diary.metadata);
      expect(meta.moodEmoji, mood);
      expect(meta.energyLevel, 4);
      expect(found.diary.capsuleUnlockAt, isNotNull);
      expect(prefs().recent.first, id);

      await undo('create_diary_from_template', outcome);
      expect(
        (await db.getDiaryWithTagsByDiaryId(diaryId))!.diary.isDeleted,
        isTrue,
      );
    });

    test('open_page can open a template or a new entry with it', () async {
      final template = await run('open_page', {
        'destination': 'template',
        'template_id': '读书笔记',
      });
      expect(template.navigation!.params['template_id'], 'builtin.reading');
      expect(template.subjects.single.title, '读书笔记');
      final write = await run('open_page', {
        'destination': 'new_diary',
        'template_id': 'builtin.morning',
      });
      expect(write.navigation!.destination, 'new_diary');
      expect(write.subjects.single.id, 'builtin.morning');
      final blank = await run('open_page', {'destination': 'new_diary'});
      expect(blank.subjects, isEmpty);
    });
  });

  test(
    'template_suggestions is a setting change_settings can turn off',
    () async {
      final outcome = await run('change_settings', {
        'template_suggestions': false,
      });
      expect(prefs().showStrip, isFalse);
      await undo('change_settings', outcome);
      expect(prefs().showStrip, isTrue);
      expect(
        () => aiToolByName('change_settings')!.run(
          context(features: everything.copyWith(templates: false)),
          aiToolByName(
            'change_settings',
          )!.schema.validate({'template_suggestions': false}),
        ),
        throwsA(isA<AiToolFailure>()),
      );
    },
  );

  test('call details read as plain words, never markup or ids', () {
    Map<String, String> facts(
      String tool,
      Map<String, Object?> args, [
      List<AiToolSubject> subjects = const [],
    ]) => {
      for (final fact in aiToolFacts(
        zh,
        AiAgentCallRecord(
          id: 'c',
          tool: tool,
          args: args,
          status: AiToolCallStatus.succeeded,
          subjects: subjects,
        ),
      ))
        fact.label: fact.value,
    };

    final created = facts('create_template', {
      'name': '读书',
      'category': 'life',
      'icon': 'bookOpen',
      'body': body,
      'capsule': 'none',
    });
    expect(created['分类'], '生活');
    expect(created.containsKey('图标'), isFalse);
    expect(created['时间胶囊'], '不设');
    expect(created['正文'], startsWith('书名：'));
    expect(created['正文'], isNot(contains('<')));
    expect(created['正文'], isNot(contains('**')));

    final rules = facts(
      'set_template_auto_apply',
      {
        'default_template_id': 'builtin.daily',
        'add_rules': [
          {
            'from': '07:00',
            'to': '10:00',
            'weekdays': [1, 2, 3, 4, 5],
            'template_id': 'builtin.morning',
          },
        ],
      },
      [const AiToolSubject.template('builtin.daily', '每日记录')],
    );
    expect(rules['模板'], '每日记录');
    expect(rules['添加时间段'], '07:00 – 10:00 · 工作日');
    expect(rules.values.join(), isNot(contains('builtin.')));
  });

  test(
    'the snapshot the new-entry editor reads is refreshed after a write',
    () async {
      expect(
        await container.read(userDiaryTemplatesSnapshotProvider.future),
        isEmpty,
      );
      await run('create_template', {'name': '新的'});
      expect(
        (await container.read(
          userDiaryTemplatesSnapshotProvider.future,
        )).single.name,
        '新的',
      );
    },
  );
}
