import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/ui/ai/controllers/ai_stream_run.dart';
import 'package:node_diary/ui/ai/models/ai_built_ins.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/models/ai_privacy_options.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_context_budget.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_json_output.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_task_prompts.dart';
import 'package:node_diary/utils/text_stats.dart';

AiContextDiary _diary({
  String title = '周末',
  String text = '今天去了海边，风很大。',
  String? mood = '😊',
  String? location = '青岛',
  List<String> tags = const ['旅行'],
}) => AiContextDiary(
  diaryId: 'd1',
  title: title,
  contentText: text,
  createdAt: DateTime(2026, 5, 2, 10),
  isArchived: false,
  mood: mood,
  weather: '晴',
  location: location,
  tags: tags,
);

void main() {
  const zhLocale = Locale('zh');
  // 应用里由本地化代理初始化日期格式，纯函数测试自己初始化。
  setUpAll(initializeDateFormatting);

  group('AiPromptKit', () {
    test('follows the diary language and adds profile and persona', () {
      final prefs = AiPreferences.defaults.copyWith(
        aboutMe: '我是一名护士',
        writingStyle: '简洁',
      );
      final kit = AiPromptKit.resolve(
        prefs: prefs,
        appLocale: const Locale('en'),
        sample: '今天很累',
      );
      expect(kit.l10n.localeName, 'zh');
      final system = kit.system(
        task: 'TASK',
        withStyle: true,
        withLength: true,
        persona: const AiPersonaInfo(
          id: 'p',
          name: 'n',
          emoji: 'e',
          prompt: 'BE KIND',
        ),
      );
      expect(system, contains('TASK'));
      expect(system, contains('BE KIND'));
      expect(system, contains('我是一名护士'));
      expect(system, contains('简洁'));
      expect(system, contains(kit.l10n.aiPromptLengthMedium));
      expect(system, contains(kit.l10n.aiPromptRespondLikeDiary));

      final english = AiPromptKit.resolve(
        prefs: AiPreferences.defaults,
        appLocale: zhLocale,
        sample: 'A quiet day at home.',
      );
      expect(english.l10n.localeName, 'en');
    });

    test('custom language uses its own instruction', () {
      final kit = AiPromptKit.resolve(
        prefs: AiPreferences.defaults.copyWith(
          language: AiOutputLanguage.custom,
          customLanguage: '日本語',
        ),
        appLocale: const Locale('en'),
      );
      expect(kit.system(), contains('日本語'));
    });

    test('diary block respects the privacy switches', () {
      final open = AiPromptKit.resolve(
        prefs: AiPreferences.defaults,
        appLocale: zhLocale,
        sample: '中文',
      );
      final block = open.diary(_diary(), ref: '[D1]');
      expect(block, startsWith('[D1]'));
      expect(block, contains('😊'));
      expect(block, contains('旅行'));
      expect(block, contains('晴'));
      // 地点默认不发送。
      expect(block, isNot(contains('青岛')));

      final strict = AiPromptKit.resolve(
        prefs: AiPreferences.defaults.copyWith(
          privacy: const AiPrivacyOptions(
            sendDate: false,
            sendMood: false,
            sendTags: false,
            sendWeather: false,
            sendLocation: true,
          ),
        ),
        appLocale: zhLocale,
        sample: '中文',
      );
      final limited = strict.diary(_diary());
      expect(limited, isNot(contains('😊')));
      expect(limited, isNot(contains('旅行')));
      expect(limited, isNot(contains('晴')));
      expect(limited, contains('青岛'));
    });

    test('temperature follows creativity and task, within 0–1', () {
      final kit = AiPromptKit.resolve(
        prefs: AiPreferences.defaults.copyWith(
          creativity: AiCreativity.creative,
        ),
        appLocale: zhLocale,
      );
      expect(kit.temperature(AiTaskKind.suggest), 0.2);
      expect(kit.temperature(AiTaskKind.prompts), 1.0);
    });
  });

  group('requests', () {
    final kit = AiPromptKit.resolve(
      prefs: AiPreferences.defaults,
      appLocale: zhLocale,
      sample: '中文',
    );

    test('custom commands fill variables or append the text', () {
      const withVariable = AiActionInfo(
        id: 'a',
        label: 'x',
        emoji: 'x',
        prompt: '把「{{文字}}」写成标题为 {{title}} 的诗',
        output: AiActionOutput.replace,
      );
      final request = aiWritingRequest(
        kit,
        action: withVariable,
        targetText: '海风',
        diary: _diary(),
      );
      final user = request.messages.single.text;
      expect(user, contains('把「海风」写成标题为 周末 的诗'));
      expect(user, isNot(contains('<text>')));

      const plain = AiActionInfo(
        id: 'b',
        label: 'x',
        emoji: 'x',
        prompt: 'Do it',
        output: AiActionOutput.replace,
      );
      final appended = aiWritingRequest(
        kit,
        action: plain,
        targetText: '海风',
        diary: _diary(title: ''),
      ).messages.single.text;
      expect(appended, 'Do it\n\n<text>\n海风\n</text>');
    });

    test('free-form instructions are wrapped', () {
      final user = aiWritingRequest(
        kit,
        instruction: '更口语',
        targetText: '文字',
        diary: _diary(title: ''),
      ).messages.single.text;
      expect(user, contains(kit.l10n.aiPromptCustomInstruction('更口语')));
    });

    test('reply requests attach images before the text', () {
      final request = aiReplyRequest(
        kit,
        diary: _diary(),
        persona: aiPersonaFor(
          kit.l10n,
          AiPreferences.defaults,
          AiPersonaUse.reply,
        ),
        images: [
          AiImagePart(Uint8List.fromList(const [1]), 'image/png'),
        ],
      );
      final parts = request.messages.single.parts;
      expect(parts.first, isA<AiImagePart>());
      expect((parts.last as AiTextPart).text, contains('海边'));
      expect(request.system, contains(kit.l10n.aiPersonaListenerPrompt));
    });
  });

  group('budget', () {
    test('truncates by TextStats words and never splits surrogates', () {
      final text = '😀' * 10 + '一二三四五六七八九十';
      final cut = aiTruncateWords(text, 3);
      expect(TextStats.countWords(cut), lessThanOrEqualTo(3));
      expect(cut.runes.every((rune) => rune != 0xFFFD), isTrue);
      expect(aiTruncateWords('short', 10), 'short');
    });

    test('fills the budget in order with whole entries', () {
      final diaries = [
        for (var i = 0; i < 5; i++) _diary(title: '', text: '字' * 300),
      ];
      final picked = aiBudgetDiaries(diaries, budget: 700);
      expect(picked.map((d) => d.ref), ['D1', 'D2', 'D3']);
      // 前两篇整篇，第三篇截到剩下的 100 字，之后不再放。
      expect(picked.map((d) => d.maxWords), [300, 300, 100]);
    });

    test('a long entry is never cut by a per-entry cap', () {
      final picked = aiBudgetDiaries([
        _diary(title: '', text: '字' * 12000),
        _diary(title: '', text: '字' * 30),
      ], budget: AiPrivacyOptions.defaultContextBudget);
      expect(picked.map((d) => d.maxWords), [12000, 30]);
    });

    test('single-entry tasks send the whole entry up to the budget', () {
      final long = '一' * 9000 + '尾';
      final kit = AiPromptKit.resolve(
        prefs: AiPreferences.defaults,
        appLocale: zhLocale,
      );
      String text(AiRequest request) =>
          (request.messages.single.parts.last as AiTextPart).text;
      final persona = aiPersonaFor(
        kit.l10n,
        AiPreferences.defaults,
        AiPersonaUse.reply,
      );
      final reply = text(
        aiReplyRequest(
          kit,
          diary: _diary(text: long),
          persona: persona,
        ),
      );
      final suggest = text(
        aiSuggestRequest(
          kit,
          diary: _diary(text: long),
          tags: const [],
          moods: const [],
        ),
      );
      for (final user in [reply, suggest]) {
        expect(user, contains(long));
        expect(user, isNot(contains(kit.l10n.aiPromptTruncated)));
      }

      // 超过“最多发送”时才截断。
      final small = AiPromptKit.resolve(
        prefs: AiPreferences.defaults.copyWith(
          privacy: AiPreferences.defaults.privacy.copyWith(
            contextBudget: 10000,
          ),
        ),
        appLocale: zhLocale,
      );
      final cut = text(
        aiReplyRequest(
          small,
          diary: _diary(text: '字' * 15000),
          persona: persona,
        ),
      );
      expect(cut, contains(small.l10n.aiPromptTruncated));
      expect(cut, isNot(contains('字' * 10001)));
    });
  });

  group('parsing', () {
    test('suggestions keep only known tags and moods', () {
      final suggestion = AiSuggestion.parse(
        'Sure!\n```json\n{"title": "《海边的风》", "tags": ["#旅行", "工作"], '
        '"newTags": ["海边", "旅行"], "mood": "😊"}\n```',
        existingTags: ['旅行', '家'],
        moods: ['😊', '😢'],
      );
      expect(suggestion.title, '海边的风');
      expect(suggestion.tags, ['旅行']);
      expect(suggestion.newTags, ['工作', '海边']);
      expect(suggestion.mood, '😊');
      expect(
        AiSuggestion.parse('no json', existingTags: [], moods: []).isEmpty,
        isTrue,
      );
    });

    test('prompts are split into clean questions', () {
      expect(aiParsePrompts('1. 今天最开心的事？\n- 有什么遗憾？\n\n今天学到了什么？'), [
        '今天最开心的事？',
        '有什么遗憾？',
        '今天学到了什么？',
      ]);
    });

    test('output cleanup removes fences, tags and quotes', () {
      expect(aiCleanOutput('```markdown\nhello\n```'), 'hello');
      expect(aiCleanOutput('<text>\nhi\n</text>'), 'hi');
      expect(aiCleanOutput('“引号”'), '引号');
      expect(aiCleanOutput('“a” and “b”'), '“a” and “b”');
    });

    test('citations survive encoding', () {
      final list = [
        AiCitation(
          ref: 'D1',
          diaryId: 'x',
          title: 't',
          date: DateTime(2026, 1, 2),
        ),
      ];
      final decoded = AiCitation.decodeList(AiCitation.encodeList(list));
      expect(decoded.single.diaryId, 'x');
      expect(decoded.single.date, DateTime(2026, 1, 2));
      expect(AiCitation.decodeList('oops'), isEmpty);
    });
  });
}
