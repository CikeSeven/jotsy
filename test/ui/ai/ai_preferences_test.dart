import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_agent_options.dart';
import 'package:node_diary/ui/ai/models/ai_built_ins.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/models/ai_privacy_options.dart';
import 'package:node_diary/ui/ai/models/ai_prompt_variables.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('AiPreferences', () {
    test('defaults encode to nothing so the settings key is removed', () {
      expect(AiPreferences.defaults.encode(), isNull);
      expect(AiPreferences.decode(null), AiPreferences.defaults);
      expect(AiPreferences.decode('{oops'), AiPreferences.defaults);
    });

    test('round-trips every customised field', () {
      final prefs = AiPreferences.defaults
          .withModule(AiModule.chat, false)
          .withModule(AiModule.vision, true)
          .copyWith(
            personas: const [
              AiPersona(id: 'p1', name: 'Mia', prompt: 'Be Mia', emoji: '🐱'),
            ],
            hiddenPersonas: {AiBuiltInPersona.roast.id},
            personaFor: const {AiPersonaUse.reply: 'p1'},
            actionOrder: const ['builtin.poem', 'builtin.polish'],
            hiddenActions: const {'builtin.translate'},
            actionPrompts: const {'builtin.polish': 'Polish gently'},
            customActions: const [
              AiCustomAction(
                id: 'a1',
                name: 'Haiku',
                prompt: 'Write a haiku about {{text}}',
                output: AiActionOutput.preview,
              ),
            ],
            aboutMe: 'A teacher',
            writingStyle: 'Short sentences',
            language: AiOutputLanguage.custom,
            customLanguage: '日本語',
            length: AiResponseLength.long,
            creativity: AiCreativity.creative,
            privacy: const AiPrivacyOptions(
              sendLocation: true,
              excludedNotebookIds: {'nb'},
              excludedTagNames: {'work'},
              contextBudget: 200000,
              includeArchived: false,
              confirm: AiConfirmMode.always,
              allowPrivate: true,
            ),
            visionMaxImages: 5,
            visionMaxSide: 1536,
            autoReply: true,
            promptsStrip: false,
            promptStyle: AiPromptInsertStyle.heading,
            promptsUseRecent: true,
            recapSections: const {AiRecapSection.quotes},
            recapNotebookId: 'nb2',
            retrieval: AiRetrievalMode.recent,
            recentDays: 90,
            maxCitations: 40,
            showReasoning: false,
            showTokens: true,
            autoTitle: false,
            titleButton: false,
            autoSuggestOnPublish: true,
          );
      final decoded = AiPreferences.decode(prefs.encode());
      expect(decoded, prefs);
      expect(decoded.isModuleEnabled(AiModule.chat), isFalse);
      expect(decoded.isModuleEnabled(AiModule.vision), isTrue);
      expect(decoded.privacy.excludedTagNames, {'work'});
    });

    test('photos per request accepts 1 to 20', () {
      AiPreferences decodeImages(Object? value) => AiPreferences.decode(
        jsonEncode(<String, Object?>{'visionImages': value}),
      );
      expect(AiPreferences.maxVisionImages, 20);
      expect(AiPreferences.visionMaxImagesChoices.first, 1);
      expect(AiPreferences.visionMaxImagesChoices.last, 20);
      expect(AiPreferences.visionMaxImagesChoices, hasLength(20));
      expect(decodeImages(20).visionMaxImages, 20);
      expect(decodeImages(1).visionMaxImages, 1);
      for (final bad in <Object?>[0, 21, 'many', 2.5]) {
        expect(
          decodeImages(bad).visionMaxImages,
          AiPreferences.defaultVisionMaxImages,
        );
      }
      final roundTrip = AiPreferences.decode(
        AiPreferences.defaults.copyWith(visionMaxImages: 20).encode(),
      );
      expect(roundTrip.visionMaxImages, 20);
    });

    test(
      'old budget choices map to the nearest new one, perDiary is dropped',
      () {
        AiPrivacyOptions decodePrivacy(Map<String, Object?> privacy) =>
            AiPreferences.decode(
              jsonEncode(<String, Object?>{'privacy': privacy}),
            ).privacy;
        expect(AiPrivacyOptions.defaultContextBudget, 100000);
        expect(AiPrivacyOptions.contextBudgetChoices.last, 1000000);
        const legacy = <int, int>{
          8000: 10000,
          16000: 20000,
          48000: 50000,
          96000: 100000,
        };
        legacy.forEach((old, now) {
          expect(
            decodePrivacy({'budget': old, 'perDiary': 4000}).contextBudget,
            now,
          );
        });
        for (final bad in <Object?>[1, 30000, -5, '100000']) {
          expect(
            decodePrivacy({'budget': bad}).contextBudget,
            AiPrivacyOptions.defaultContextBudget,
          );
        }
        // 旧版的“每篇最多”读取时忽略，再写出时不再出现。
        final old = decodePrivacy({'budget': 48000, 'perDiary': 500});
        expect(old.toJson(), {'budget': 50000});
      },
    );

    test('falls back per field on bad values', () {
      final prefs = AiPreferences.decode(
        jsonEncode(<String, Object?>{
          'off': ['writing', 'vision', 'nope'],
          'on': ['vision', 'chat'],
          'length': 'enormous',
          'visionImages': 99,
          'visionSide': 777,
          'recentDays': 3,
          'privacy': {'budget': 1, 'confirm': 'never', 'location': 'yes'},
          'personas': [
            {'id': 'x', 'name': '', 'prompt': 'p'},
            {'id': 'y', 'name': 'Y', 'prompt': 'p'},
            {'id': 'y', 'name': 'dup', 'prompt': 'p'},
          ],
          'recapSections': <String>[],
        }),
      );
      expect(prefs.isModuleEnabled(AiModule.writing), isFalse);
      // 模块现在都默认开启：'off' 关掉，'on' 里的名字不起作用。
      expect(prefs.isModuleEnabled(AiModule.vision), isFalse);
      expect(prefs.isModuleEnabled(AiModule.chat), isTrue);
      expect(prefs.length, AiResponseLength.medium);
      expect(prefs.visionMaxImages, AiPreferences.defaultVisionMaxImages);
      expect(prefs.visionMaxSide, AiPreferences.defaultVisionMaxSide);
      expect(prefs.recentDays, AiPreferences.defaultRecentDays);
      expect(prefs.privacy, AiPrivacyOptions.defaults);
      expect(prefs.personas.map((p) => p.id), ['y']);
      // 显式写了空章节就是“都不要”，不回到默认。
      expect(prefs.recapSections, isEmpty);
    });

    test('agent options are sparse and tolerate bad values', () {
      final changed = AiPreferences.defaults.copyWith(
        agent: const AiAgentOptions(enabled: false, maxSteps: 40),
      );
      expect(changed.toJson()['agent'], {'enabled': false, 'maxSteps': 40});
      expect(AiPreferences.decode(changed.encode()).agent, changed.agent);
      // 只改一项时只写那一项；与默认相同时整个字段都不写。
      expect(
        AiPreferences.defaults
            .copyWith(agent: const AiAgentOptions(maxSteps: 10))
            .toJson()['agent'],
        {'maxSteps': 10},
      );
      expect(AiPreferences.defaults.toJson().containsKey('agent'), isFalse);
      final bad = AiPreferences.decode(
        jsonEncode({
          'agent': {'enabled': 'no', 'maxSteps': 7},
        }),
      );
      expect(bad.agent, AiAgentOptions.defaults);
    });

    test('keeps prompt texts up to 100k chars and clips only beyond', () {
      const max = kAiPromptTextMaxLength;
      expect(max, 100000);
      expect(AiPersona.maxPromptLength, max);
      expect(AiCustomAction.maxPromptLength, max);
      expect(AiPreferences.maxAboutMeLength, max);
      expect(AiPreferences.maxWritingStyleLength, max);

      // 旧上限（人设与指令 2000、关于我 1000、文风 500）以上的长文字原样读回。
      final long = '设' * 50000;
      final kept = AiPreferences.decode(
        jsonEncode(<String, Object?>{
          'personas': [
            {'id': 'p', 'name': 'P', 'prompt': long},
          ],
          'actions': [
            {'id': 'a', 'name': 'A', 'prompt': long},
          ],
          'aboutMe': long,
          'style': long,
        }),
      );
      expect(kept.personas.single.prompt, long);
      expect(kept.customActions.single.prompt, long);
      expect(kept.aboutMe, long);
      expect(kept.writingStyle, long);

      // 超过上限的异常数据截到上限。
      final huge = 'x' * (max + 10);
      final clipped = AiPreferences.decode(
        jsonEncode(<String, Object?>{
          'personas': [
            {'id': 'p', 'name': 'P', 'prompt': huge},
          ],
          'aboutMe': huge,
        }),
      );
      expect(clipped.personas.single.prompt.length, max);
      expect(clipped.aboutMe.length, max);
    });

    test('keeps up to 50 personas and 50 custom actions', () {
      final prefs = AiPreferences.decode(
        jsonEncode(<String, Object?>{
          'personas': [
            for (var i = 0; i < 60; i++)
              {'id': 'p$i', 'name': 'P$i', 'prompt': 'p'},
          ],
          'actions': [
            for (var i = 0; i < 60; i++)
              {'id': 'a$i', 'name': 'A$i', 'prompt': 'a'},
          ],
        }),
      );
      expect(prefs.personas, hasLength(AiPreferences.maxPersonas));
      expect(prefs.customActions, hasLength(AiPreferences.maxCustomActions));
      expect(AiPreferences.maxPersonas, 50);
      expect(AiPreferences.maxCustomActions, 50);
    });
  });

  group('built-ins', () {
    test('every built-in persona and action has text in both languages', () {
      for (final l10n in [zh, en]) {
        for (final persona in AiBuiltInPersona.values) {
          expect(persona.label(l10n), isNotEmpty);
          expect(persona.prompt(l10n), isNotEmpty);
        }
        for (final action in AiWritingAction.values) {
          expect(action.label(l10n), isNotEmpty);
          expect(action.defaultPrompt(l10n), isNotEmpty);
        }
      }
    });

    test('actions follow the saved order, then the default order', () {
      final prefs = AiPreferences.defaults.copyWith(
        actionOrder: const ['a1', 'builtin.poem', 'gone'],
        hiddenActions: const {'builtin.polish'},
        actionPrompts: const {'builtin.expand': 'Mine'},
        customActions: const [
          AiCustomAction(id: 'a1', name: 'Mine', prompt: 'p'),
        ],
      );
      final actions = aiWritingActions(zh, zh, prefs);
      expect(actions.take(3).map((a) => a.id), [
        'a1',
        'builtin.poem',
        'builtin.continueWriting',
      ]);
      expect(actions.any((a) => a.id == 'builtin.polish'), isFalse);
      final expand = actions.firstWhere((a) => a.id == 'builtin.expand');
      expect(expand.prompt, 'Mine');
      expect(expand.customized, isTrue);
      expect(
        aiWritingActions(zh, zh, prefs, includeHidden: true).length,
        AiWritingAction.values.length + 1,
      );
    });

    test('persona lookup falls back to the default for the use', () {
      final prefs = AiPreferences.defaults.copyWith(
        personaFor: const {AiPersonaUse.chat: 'deleted'},
      );
      expect(
        aiPersonaFor(zh, prefs, AiPersonaUse.chat).id,
        AiBuiltInPersona.assistant.id,
      );
      expect(
        aiPersonaFor(zh, prefs, AiPersonaUse.reply).id,
        AiBuiltInPersona.listener.id,
      );
    });
  });

  group('prompt variables', () {
    test('fills both alias languages and keeps unknown ones', () {
      final filled = fillAiPromptVariables(
        'A {{文字}} B {{ text }} C {{日期}} D {{unknown}} E {{mood}}',
        {AiPromptVariable.text: 'X', AiPromptVariable.date: '5/1'},
      );
      expect(filled, 'A X B X C 5/1 D {{unknown}} E ');
      expect(aiPromptUses('see {{全文}}', AiPromptVariable.diary), isTrue);
      expect(aiPromptUses('see {{全文}}', AiPromptVariable.text), isFalse);
      expect(AiPromptVariable.title.token(zh: true), '{{标题}}');
      expect(AiPromptVariable.title.token(zh: false), '{{title}}');
    });
  });
}
