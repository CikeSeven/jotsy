import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/agent/ai_tool_schema.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_agent_options.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/models/ai_privacy_options.dart';
import 'package:node_diary/ui/ai/tools/ai_destinations.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 助手的工具：清单的一致性（名称、schema、标题、前往目标），以及几个
/// 只读工具对真实数据库的行为（私密排除、字数预算、统计、功能开关）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  AiToolContext context({
    AppFeatures features = AppFeatures.defaults,
    AiPreferences prefs = AiPreferences.defaults,
    int budget = 100000,
  }) => AiToolContext(
    container: container,
    l10n: zh,
    kit: AiPromptKit.resolve(prefs: prefs, appLocale: const Locale('zh')),
    env: AiToolEnv(features: features, prefs: prefs),
    citations: AiCitationBook(),
    allowance: AiWordAllowance(budget),
    token: HttpCancelToken(),
    now: DateTime(2026, 11, 8, 10),
  );

  Future<AiToolOutcome> run(
    String name,
    Map<String, Object?> args, {
    AiToolContext? with_,
  }) {
    final tool = aiToolByName(name)!;
    return tool.run(with_ ?? context(), tool.schema.validate(args));
  }

  Future<String> diary(
    String title,
    String text, {
    DateTime? at,
    List<int> tagIds = const <int>[],
  }) => db.createDiary(
    title: title,
    contentDocJson: '',
    contentText: text,
    metadataJson: '{}',
    tagIds: tagIds,
    createdAtOverride: at ?? DateTime(2026, 11, 1, 9),
  );

  /// 收进一本隐藏（私密）日记本，让这篇变成私密日记。
  Future<void> makePrivate(String diaryId) async {
    final notebook = await db.createNotebook(
      name: '私密',
      visibility: NotebookVisibility.hidden,
    );
    await db.addDiariesToNotebook(notebook, [diaryId]);
  }

  group('registry', () {
    test('names, schemas and labels are consistent', () {
      final names = <String>{};
      for (final tool in aiTools) {
        expect(names.add(tool.name), isTrue, reason: 'duplicate ${tool.name}');
        expect(RegExp(r'^[a-z][a-z0-9_]{2,63}$').hasMatch(tool.name), isTrue);
        expect(tool.description.trim(), isNotEmpty);
        final schema = tool.spec.parameters;
        expect(schema['type'], 'object', reason: tool.name);
        expect(schema['properties'], isA<Map>(), reason: tool.name);
        // 只用四家都认的子集。
        final text = jsonEncode(schema);
        for (final banned in ['additionalProperties', 'oneOf', 'anyOf']) {
          expect(text, isNot(contains(banned)), reason: tool.name);
        }
        for (final l10n in [zh, en]) {
          expect(tool.label(l10n, const {}).trim(), isNotEmpty);
        }
      }
    });

    test('every destination is reachable from open_page', () {
      final ids = [for (final d in aiDestinations) d.id];
      expect(ids.toSet(), hasLength(ids.length));
      final destination =
          (aiToolByName('open_page')!.spec.parameters['properties']!
                  as Map)['destination']
              as Map;
      expect(destination['enum'], ids);
      for (final d in aiDestinations) {
        expect(d.title(zh).trim(), isNotEmpty, reason: d.id);
        expect(d.title(en).trim(), isNotEmpty, reason: d.id);
      }
    });

    test('tools follow the feature switches', () {
      List<String> available(AppFeatures features) => [
        for (final tool in aiAvailableTools(
          AiToolEnv(features: features, prefs: AiPreferences.defaults),
        ))
          tool.name,
      ];
      final defaults = available(AppFeatures.defaults);
      expect(defaults, isNot(contains('list_todos')));
      expect(defaults, isNot(contains('list_anniversaries')));
      expect(defaults, contains('list_notebooks'));
      final more = available(
        AppFeatures.defaults.copyWith(
          todos: true,
          anniversaries: true,
          notebooks: false,
        ),
      );
      expect(more, containsAll(['list_todos', 'list_anniversaries']));
      expect(more, isNot(contains('list_notebooks')));
    });

    test('turning changes off leaves only lookups and open_page', () {
      final readOnly = aiAvailableTools(
        AiToolEnv(
          features: AppFeatures.defaults,
          prefs: AiPreferences.defaults.copyWith(
            agent: const AiAgentOptions(allowChanges: false),
          ),
        ),
      );
      expect(readOnly.any(aiToolChangesData), isFalse);
      expect(readOnly.map((t) => t.name), contains('open_page'));
      final all = aiAvailableTools(
        AiToolEnv(
          features: AppFeatures.defaults,
          prefs: AiPreferences.defaults,
        ),
      );
      expect(all.map((t) => t.name), contains('create_diary'));
    });
  });

  group('search_diaries', () {
    test('finds matching entries but never private ones', () async {
      final beach = await diary('周末', '傍晚去海边散步，风很大');
      final secret = await diary('秘密', '一个人去海边哭了一场');
      await diary('上班', '开了一整天的会');
      await makePrivate(secret);

      final ctx = context();
      final outcome = await run('search_diaries', {'query': '海边'}, with_: ctx);
      final data = outcome.data! as Map<String, Object?>;
      final diaries = (data['diaries']! as List).cast<Map>();
      expect(diaries.map((d) => d['id']), [beach]);
      expect(diaries.single['ref'], 'D1');
      expect(diaries.single['excerpt'], contains('海边'));
      expect(outcome.summary, zh.aiToolFoundEntries(1));
      expect(ctx.citations.all.single.diaryId, beach);
    });

    test('an unknown tag is reported so the model can fix it', () async {
      await diary('周末', '海边');
      expect(
        () => run('search_diaries', {
          'tags': ['不存在'],
        }),
        throwsA(isA<AiToolFailure>()),
      );
    });

    test('the date range is inclusive', () async {
      await diary('一号', 'a', at: DateTime(2026, 10, 1, 23));
      await diary('二号', 'b', at: DateTime(2026, 10, 2, 8));
      await diary('三号', 'c', at: DateTime(2026, 10, 3, 8));
      final outcome = await run('search_diaries', {
        'from': '2026-10-01',
        'to': '2026-10-02',
        'sort': 'oldest',
      });
      final diaries = ((outcome.data! as Map)['diaries'] as List).cast<Map>();
      expect(diaries.map((d) => d['title']), ['一号', '二号']);
    });
  });

  group('read_diaries', () {
    test(
      'reads full text, refuses private entries and keeps the budget',
      () async {
        final open = await diary('周末', '一二三四五六七八九十');
        final secret = await diary('秘密', '不能给 AI 看');
        await makePrivate(secret);

        final outcome = await run('read_diaries', {
          'ids': [open, secret, 'missing'],
        }, with_: context(budget: 6));
        final results = ((outcome.data! as Map)['diaries'] as List).cast<Map>();
        expect(results[0]['text'], contains('一二三'));
        // 预算只剩 6 字：正文被截断并注明。
        expect(results[0]['text'], contains(zh.aiPromptTruncated));
        expect(results[1]['error'], contains('private'));
        expect(results[1].containsKey('text'), isFalse);
        expect(results[2]['error'], contains('Not found'));
        expect(outcome.summary, zh.aiToolReadEntries(1));
      },
    );

    test('with the budget used up only the header is sent', () async {
      final id = await diary('周末', '正文内容');
      final ctx = context(budget: 1)..allowance.take(1);
      final outcome = await run('read_diaries', {
        'ids': [id],
      }, with_: ctx);
      final result = ((outcome.data! as Map)['diaries'] as List).single as Map;
      expect(result['title'], '周末');
      expect(result['error'], contains('budget'));
      expect(result.containsKey('text'), isFalse);
    });
  });

  test('diary_stats counts entries, words, days and groups', () async {
    await diary('a', '一二三', at: DateTime(2026, 10, 30, 9));
    await diary('b', '四五', at: DateTime(2026, 10, 31, 9));
    await diary('c', '六', at: DateTime(2026, 11, 2, 9));
    final secret = await diary('d', '私密不算', at: DateTime(2026, 11, 2, 10));
    await makePrivate(secret);
    final outcome = await run('diary_stats', {'group_by': 'month'});
    final data = outcome.data! as Map<String, Object?>;
    expect(data['entries'], 3);
    expect(data['words'], 6);
    expect(data['days_written'], 3);
    expect(data['longest_streak_days'], 2);
    expect(data['groups'], [
      {'period': '2026-10', 'entries': 2, 'words': 5},
      {'period': '2026-11', 'entries': 1, 'words': 1},
    ]);
  });

  test('list_tags hides tags excluded from AI', () async {
    final travel = await db.createTag(name: '旅行', color: 0xFF000000);
    final health = await db.createTag(name: '健康', color: 0xFF000000);
    await diary('a', 'x', tagIds: [travel, health]);
    await diary('b', 'y', tagIds: [travel]);
    const prefs = AiPreferences(
      privacy: AiPrivacyOptions(excludedTagNames: {'健康'}),
    );
    final outcome = await run('list_tags', {}, with_: context(prefs: prefs));
    expect((outcome.data! as Map)['tags'], [
      {'name': '旅行', 'entries': 2},
    ]);
  });

  group('open_page', () {
    test('returns a navigation for an available page', () async {
      final outcome = await run('open_page', {
        'destination': 'settings_tags',
        'now': true,
      });
      expect(outcome.navigation?.destination, 'settings_tags');
      expect(outcome.navigation?.now, isTrue);
    });

    test('refuses pages of features that are off', () async {
      expect(
        () => run('open_page', {'destination': 'tab_todos'}),
        throwsA(isA<AiToolFailure>()),
      );
    });

    test('asks for the id a page needs', () async {
      expect(
        () => run('open_page', {'destination': 'diary'}),
        throwsA(
          isA<AiToolFailure>().having(
            (f) => f.message,
            'message',
            contains('diary_id'),
          ),
        ),
      );
      expect(
        () => aiToolByName(
          'open_page',
        )!.schema.validate({'destination': 'nowhere'}),
        throwsA(isA<AiToolArgumentError>()),
      );
    });
  });

  test('get_app_context reports features and mood options', () async {
    final outcome = await run('get_app_context', {});
    final data = outcome.data! as Map<String, Object?>;
    expect(data['now'], '2026-11-08 10:00');
    expect(data['weekday'], 'Sunday');
    expect((data['features']! as Map)['todos'], isFalse);
    expect(data['mood_options'], isNotEmpty);
  });
}
