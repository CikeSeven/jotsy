import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_ai_prompts.dart';

/// 导图 AI 的提示词与回复解析：请求带上主题、层数、风格、路径与整张导图，
/// 回复（含代码围栏、半截的流式文字）解析成主题。
void main() {
  final kit = AiPromptKit.resolve(
    prefs: AiPreferences.defaults,
    appLocale: const Locale('en'),
    sample: 'Trip',
  );
  final en = lookupAppLocalizations(const Locale('en'));

  String userText(AiRequest request) =>
      (request.messages.single.parts.single as AiTextPart).text;

  test('a generate request names the topic, depth, style and format', () {
    final request = mindMapAiGenerateRequest(
      kit,
      topic: '  Trip  ',
      depth: 3,
      style: MindMapAiStyle.study,
      extra: 'Keep it short',
    );
    final text = userText(request);
    expect(text, contains(en.aiPromptMindMapGenerate('Trip')));
    expect(text, contains(en.aiPromptMindMapDepth(3)));
    expect(text, contains(en.aiPromptMindMapStyleStudy));
    expect(text, contains(en.aiPromptMindMapExtra('Keep it short')));
    expect(text, contains(en.aiPromptMindMapFormat));
    expect(request.system, contains(en.aiPromptMindMapSystem));
  });

  test('an expand request carries the path and the whole map', () {
    final map = MindMapDocument.blank().copyWith(
      root: mindMapNodeFromOutline('Trip\n  Packing\n    Passport\n  Hotel')!,
    );
    final packing = map.root.children.first.id;
    final text = userText(
      mindMapAiExpandRequest(
        kit,
        document: map,
        nodeId: packing,
        untitled: 'Untitled',
      ),
    );
    expect(text, contains(en.aiPromptMindMapExpand('Packing')));
    expect(text, contains(en.aiPromptMindMapPath('Trip > Packing')));
    expect(text, contains('- Packing\n  - Passport\n- Hotel'));
    expect(text, contains(en.aiPromptMindMapExpandFormat));
  });

  test('a whole map reply reads through code fences and keeps the topic', () {
    const reply =
        '```markdown\n# Summer trip\n- Packing\n  - Passport\n- Hotel\n```';
    final parsed = mindMapAiParseMap(reply)!;
    expect(parsed.text, 'Summer trip');
    expect(parsed.children.map((node) => node.text), <String>[
      'Packing',
      'Hotel',
    ]);
    expect(parsed.children.first.children.single.text, 'Passport');
    expect(mindMapAiParseMap(reply, topic: 'Trip')!.text, 'Trip');
  });

  test('a half-streamed reply already shows the topics so far', () {
    final parsed = mindMapAiParseMap('```\n# Trip\n- Pack', topic: 'Trip')!;
    expect(parsed.children.single.text, 'Pack');
    expect(mindMapAiParseMap('', topic: ''), isNull);
    expect(mindMapAiParseMap('```'), isNull);
  });

  test('subtopic replies read as a list, with or without a heading', () {
    final branches = mindMapAiParseBranches('- Sunscreen\n  - SPF 50\n- Hat');
    expect(branches.map((node) => node.text), <String>['Sunscreen', 'Hat']);
    expect(branches.first.children.single.text, 'SPF 50');
    expect(
      mindMapAiParseBranches('# Packing\n- Sunscreen').map((node) => node.text),
      <String>['Sunscreen'],
    );
    expect(mindMapAiParseBranches('Sorry, I cannot help.'), isEmpty);
    expect(mindMapAiParseMap('Sorry, I cannot help.', topic: 'Trip'), isNull);
    expect(mindMapAiParseBranches(''), isEmpty);
  });
}
