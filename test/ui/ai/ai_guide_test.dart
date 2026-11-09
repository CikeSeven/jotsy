import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/services/ai/agent/ai_tool_schema.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/http_cancel_token.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_built_ins.dart';
import 'package:node_diary/ui/ai/models/ai_guide.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/providers/ai_guide_provider.dart';
import 'package:node_diary/ui/ai/tools/ai_destinations.dart';
import 'package:node_diary/ui/ai/tools/ai_tool.dart';
import 'package:node_diary/ui/ai/tools/ai_tool_registry.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_agent_history.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_agent_prompts.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';

/// 使用指南：打包的文章中英两份一致、头信息合法、引用的页面都存在，并且
/// 覆盖每个功能开关与每个设置页（新增功能时补一篇，或在现有文章里加上它）。
/// 另测 read_guide 的分页与“关着 / 本平台没有”的提示，以及目录进系统提示词。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('zh'));

  const featureNames = <String>{
    'calendar',
    'todos',
    'explore',
    'notebooks',
    'anniversaries',
    'templates',
    'timeCapsules',
    'swipeArchive',
    'comments',
    'ai',
  };
  const platformNames = <String>{'android', 'ios', 'windows', 'linux', 'macos'};
  // 需要具体 id 的目标不能写进文章。
  const idDestinations = <String>{'diary', 'notebook', 'todo'};
  // 设置首页能进的各页：每个都要有文章讲到。
  const settingsDestinations = <String>{
    'settings_appearance',
    'settings_background',
    'settings_card_style',
    'settings_preview_style',
    'settings_nav_bar_style',
    'settings_explore_layout',
    'settings_features',
    'settings_editor',
    'settings_typography',
    'settings_code_block_style',
    'settings_templates',
    'settings_drafts',
    'settings_tags',
    'settings_moods',
    'settings_notebooks',
    'settings_todos',
    'recycle_bin',
    'data_management',
    'cloud_backup',
    'export_diaries',
    'storage',
    'lan_sync',
    'app_lock',
    'ai_settings',
    'about',
    'changelog',
    'app_update',
  };

  group('bundled articles', () {
    late AiGuideCatalog zh;
    late AiGuideCatalog en;
    late List<String> paths;

    setUpAll(() async {
      zh = await loadAiGuideCatalog(rootBundle, 'zh');
      en = await loadAiGuideCatalog(rootBundle, 'en');
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      paths = [
        for (final path in manifest.listAssets())
          if (path.startsWith(kAiGuideAssetDir)) path,
      ];
    });

    test('both languages have the same articles, all parseable', () {
      expect(zh.articles.length, greaterThanOrEqualTo(30));
      expect(
        en.articles.map((a) => a.id).toList(),
        zh.articles.map((a) => a.id).toList(),
      );
      // 每个文件都解析得出来，且 id 与文件名相同。
      expect(paths, hasLength(zh.articles.length + en.articles.length));
      for (final path in paths) {
        final language = path.split('/')[2];
        final id = path.split('/').last.replaceAll('.md', '');
        final catalog = language == 'zh' ? zh : en;
        expect(catalog.byId(id), isNotNull, reason: path);
      }
    });

    test('front matter is complete and refers to real things', () {
      final destinations = {for (final d in aiDestinations) d.id};
      for (final article in [...zh.articles, ...en.articles]) {
        final where = article.id;
        expect(RegExp(r'^[a-z][a-z0-9-]+$').hasMatch(article.id), isTrue);
        expect(article.title.trim(), isNotEmpty, reason: where);
        expect(article.summary.trim(), isNotEmpty, reason: where);
        expect(article.body.length, greaterThan(150), reason: where);
        expect(featureNames, containsAll(article.features), reason: where);
        expect(platformNames, containsAll(article.platforms), reason: where);
        for (final destination in article.destinations) {
          expect(destinations, contains(destination), reason: where);
          expect(idDestinations, isNot(contains(destination)), reason: where);
        }
      }
    });

    test('every feature switch and settings page is covered', () {
      final features = {for (final a in zh.articles) ...a.features};
      final pages = {for (final a in zh.articles) ...a.destinations};
      expect(features, containsAll(featureNames));
      expect(pages, containsAll(settingsDestinations));
    });

    test('the index stays small enough for every request', () {
      expect(zh.index.length, lessThan(6000));
      expect(en.index.length, lessThan(9000));
    });
  });

  test('parses front matter and tolerates missing fields', () {
    final article = AiGuideArticle.parse('''
---
id: demo
title: 示例
summary: 一句话
features: [todos, calendar]
platforms: []
destinations: [settings_todos]
---
## 在哪里

正文：设置 → 待办设置。
''')!;
    expect(article.features, ['todos', 'calendar']);
    expect(article.platforms, isEmpty);
    expect(article.destinations, ['settings_todos']);
    expect(article.keywords, isEmpty);
    expect(article.body, startsWith('## 在哪里'));
    expect(AiGuideArticle.parse('no front matter'), isNull);
    expect(AiGuideArticle.parse('---\ntitle: x\n---\nbody'), isNull);
  });

  test('Japanese and Russian read the English guide', () {
    expect(aiGuideLanguage('zh'), 'zh');
    expect(aiGuideLanguage('zh_Hans'), 'zh');
    expect(aiGuideLanguage('en'), 'en');
    expect(aiGuideLanguage('ja'), 'en');
    expect(aiGuideLanguage('ru'), 'en');
  });

  group('read_guide', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final guide = AiGuideCatalog([
      AiGuideArticle(
        id: 'todos',
        title: '待办',
        summary: '待办与提醒',
        body: 'x' * 9000,
        features: const ['todos'],
        destinations: const ['settings_todos', 'tab_todos'],
      ),
      const AiGuideArticle(
        id: 'lan-sync',
        title: '局域网同步',
        summary: '两台设备',
        body: '正文',
        platforms: ['ios'],
      ),
    ]);

    Future<Map<String, Object?>> read(
      Map<String, Object?> args, {
      AppFeatures features = AppFeatures.defaults,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tool = aiToolByName('read_guide')!;
      final outcome = await tool.run(
        AiToolContext(
          container: container,
          l10n: l10n,
          kit: AiPromptKit.resolve(
            prefs: AiPreferences.defaults,
            appLocale: const Locale('zh'),
          ),
          env: AiToolEnv(features: features, prefs: AiPreferences.defaults),
          citations: AiCitationBook(),
          allowance: AiWordAllowance(1000),
          token: HttpCancelToken(),
          guide: guide,
        ),
        tool.schema.validate(args),
      );
      return outcome.data! as Map<String, Object?>;
    }

    test('pages long articles and notes switched-off features', () async {
      final first =
          ((await read({
                        'ids': ['todos'],
                      }))['articles']!
                      as List)
                  .single
              as Map;
      expect((first['text']! as String).length, 8000);
      expect(first['next_offset'], 8000);
      expect(first['note_features_off'], contains('todos'));
      // 待办关着时对应的页面打不开，不列出。
      expect(first['open_pages'], isEmpty);

      final rest =
          ((await read(
                        {
                          'ids': ['todos'],
                          'offset': 8000,
                        },
                        features: AppFeatures.defaults.copyWith(todos: true),
                      ))['articles']!
                      as List)
                  .single
              as Map;
      expect((rest['text']! as String).length, 1000);
      expect(rest.containsKey('next_offset'), isFalse);
      expect(rest.containsKey('note_features_off'), isFalse);
      expect(rest['open_pages'], ['settings_todos', 'tab_todos']);
    });

    test('notes other platforms and unknown ids', () async {
      final articles =
          (await read({
                'ids': ['lan-sync', 'nope'],
              }))['articles']!
              as List;
      expect((articles.first as Map)['note_platform'], contains('ios'));
      expect((articles.last as Map)['error'], isNotNull);
      expect(
        () => aiToolByName('read_guide')!.schema.validate({
          'ids': ['a', 'b', 'c', 'd'],
        }),
        throwsA(isA<AiToolArgumentError>()),
      );
    });
  });

  test('the agent system prompt carries the guide index', () {
    final kit = AiPromptKit.resolve(
      prefs: AiPreferences.defaults,
      appLocale: const Locale('zh'),
    );
    final request = aiAgentRequest(
      kit,
      history: const AiAgentHistory(<AiMessage>[]),
      prompt: aiAgentPrompt(
        kit,
        question: '怎么备份？',
        now: DateTime(2026, 11, 8, 10),
      ),
      persona: aiPersonaById(
        kit.l10n,
        AiPreferences.defaults,
        null,
        use: AiPersonaUse.chat,
      ),
      tools: aiTools,
      guideIndex: '- cloud-backup: 网盘备份 — 备份到网盘',
    );
    expect(request.system, contains('read_guide'));
    expect(request.system, contains('- cloud-backup: 网盘备份'));
    expect(request.tools.map((t) => t.name), contains('read_guide'));
    expect(request.messages.single.role, AiRole.user);
  });
}
