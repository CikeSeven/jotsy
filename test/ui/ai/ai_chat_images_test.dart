import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/controllers/ai_agent_images.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_agent_history.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_agent_image_slots.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_agent_prompts.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_images.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';

/// 对话附图的编号、请求里图片的加载与分段淘汰、历史回放把图片插回原位。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));

  setUpAll(() => initializeDateFormatting('zh'));

  AiMessageRow row(
    String id, {
    String role = AiMessageRole.user,
    String content = '',
    List<String> images = const <String>[],
    Map<String, Object?> meta = const <String, Object?>{},
    int minute = 0,
  }) => AiMessageRow(
    id: id.hashCode,
    messageId: id,
    conversationId: 'c',
    role: role,
    content: content,
    reasoning: '',
    citations: '[]',
    meta: jsonEncode(meta),
    status: AiMessageStatus.done,
    steps: '[]',
    images: encodeAiMessageImages(images),
    createdAt: DateTime(2026, 11, 10, 9, minute),
  );

  group('numbers', () {
    test('stored numbers win and survive deleted messages', () {
      final rows = [
        row(
          'm2',
          images: ['/a', '/b'],
          meta: {
            'imageRefs': ['P3', 'P4'],
          },
        ),
        row(
          'm3',
          images: ['/c'],
          meta: {
            'imageRefs': ['P5'],
          },
        ),
      ];
      // m1（P1、P2）已删：其余编号不变，新图接着最大的编号。
      expect([for (final i in aiChatImages(rows)) i.ref], ['P3', 'P4', 'P5']);
      expect(aiNextImageRefs(rows, 2), ['P6', 'P7']);
      expect(aiChatImageByRef(aiChatImages(rows), '[p4]')?.path, '/b');
      expect(aiChatImageByRef(aiChatImages(rows), 'P9'), isNull);
    });

    test('missing or broken numbers are filled in after the highest', () {
      final rows = [
        row(
          'm1',
          images: ['/a'],
          meta: {
            'imageRefs': ['P2'],
          },
        ),
        // 张数对不上：按位置补。
        row(
          'm2',
          images: ['/b', '/c'],
          meta: {
            'imageRefs': ['P9'],
          },
        ),
        row('m3', images: ['/d']),
        row('a1', role: AiMessageRole.assistant, content: '好'),
      ];
      expect(
        [for (final i in aiChatImages(rows)) i.ref],
        ['P2', 'P3', 'P4', 'P5'],
      );
    });

    test('tombstones keep their number', () {
      final rows = [
        row(
          'm1',
          images: ['/a', '', '/c'],
          meta: {
            'imageRefs': ['P1', 'P2', 'P3'],
          },
        ),
      ];
      final images = aiChatImages(rows);
      expect(images[1].removed, isTrue);
      expect(images[2].ref, 'P3');
      expect(aiImageRefsMeta(const <String>[]), isEmpty);
    });
  });

  group('resolving slots', () {
    AiImageSlot slot(String key, {String source = '/x.jpg', String? diary}) =>
        AiImageSlot(key: key, label: key, source: source, diaryId: diary);

    Future<AiImagePart?> fakeLoad(String source, int maxSide) async =>
        source.contains('broken')
        ? null
        : AiImagePart(Uint8List(source.length * 100), 'image/jpeg');

    String textOf(AiPart? part) => (part! as AiTextPart).text;

    test('placeholders say why an image is not there', () async {
      final resolved = await resolveAiImageSlots(
        [
          slot('removed', source: ''),
          slot('broken', source: '/broken.jpg'),
          slot('private', diary: 'secret'),
          slot('ok'),
        ],
        vision: true,
        maxSide: 1024,
        l10n: zh,
        diaryAllowed: (id) async => id != 'secret',
        loader: fakeLoad,
      );
      expect(
        textOf(resolved.parts['removed']),
        zh.aiPromptImageRemoved('removed'),
      );
      expect(
        textOf(resolved.parts['broken']),
        zh.aiPromptImageUnavailable('broken'),
      );
      expect(
        textOf(resolved.parts['private']),
        zh.aiPromptImageUnavailable('private'),
      );
      expect(resolved.parts['ok'], isA<AiImagePart>());
      expect(resolved.budget.count, 1);
    });

    test('without vision nothing is loaded', () async {
      var loads = 0;
      final resolved = await resolveAiImageSlots(
        [slot('a')],
        vision: false,
        maxSide: 1024,
        l10n: zh,
        loader: (source, side) async {
          loads++;
          return null;
        },
      );
      expect(loads, 0);
      expect(textOf(resolved.parts['a']), zh.aiPromptImageNotSent('a'));
    });

    test('over the limit the oldest go in one step, down to half', () async {
      final slots = [for (var i = 1; i <= 5; i++) slot('s$i')];
      final resolved = await resolveAiImageSlots(
        slots,
        vision: true,
        maxSide: 1024,
        l10n: zh,
        maxCount: 4,
        loader: fakeLoad,
      );
      // 第 5 张越过上限：一次换掉最旧的 3 张，剩 2 张（不超过一半）。
      expect(
        [for (final s in slots) resolved.parts[s.key] is AiImagePart],
        [false, false, false, true, true],
      );
      expect(textOf(resolved.parts['s1']), zh.aiPromptImageOmitted('s1'));
      expect(resolved.budget.count, 2);

      // 同样的槽位每次得到同样的结果；少一张时较早的决定不变。
      final again = await resolveAiImageSlots(
        slots.take(4).toList(),
        vision: true,
        maxSide: 1024,
        l10n: zh,
        maxCount: 4,
        loader: fakeLoad,
      );
      expect(again.parts.values.every((part) => part is AiImagePart), isTrue);
    });
  });

  test('history puts each image back in front of its question', () {
    const config = AiProviderConfig(
      id: 'p',
      name: 'P',
      protocol: AiProtocol.openAi,
      baseUrl: 'http://localhost',
      models: [AiModelConfig(id: 'm')],
    );
    final target = AiResolvedModel(config, config.models.single);
    final rows = [
      row(
        'm1',
        images: ['/a.jpg'],
        meta: {
          'prompt': '问题一',
          'imageRefs': ['P1'],
        },
      ),
      row('a1', role: AiMessageRole.assistant, content: '回答一', minute: 1),
    ];
    final slots = aiAgentHistoryImageSlots(rows, l10n: zh, target: target);
    expect(slots.single.key, aiQuestionImageKey('m1', 0));
    expect(slots.single.label, 'P1');
    final image = AiImagePart(Uint8List.fromList([1, 2, 3]), 'image/jpeg');
    final history = aiAgentHistory(
      rows,
      l10n: zh,
      target: target,
      images: {slots.single.key: image},
    );
    final question = history.messages.first;
    expect(question.parts.first, same(image));
    expect((question.parts.last as AiTextPart).text, '问题一');

    // 这一轮的附图同样放在问题文字之前，提问里写着编号。
    final prompt = aiAgentPrompt(
      AiPromptKit.resolve(
        prefs: AiPreferences.defaults,
        appLocale: const Locale('zh'),
      ),
      question: '',
      now: DateTime(2026, 11, 10, 9),
      imageRefs: const ['P2'],
    );
    expect(prompt, contains(zh.aiPromptAgentImagesAttached('P2')));
  });
}
