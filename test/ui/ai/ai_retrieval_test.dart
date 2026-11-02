import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/ui/ai/models/ai_built_ins.dart';
import 'package:node_diary/ui/ai/models/ai_chat_scope.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/models/ai_preferences.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_prompts.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_context_budget.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_prompt_builder.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_retrieval.dart';

AiContextDiary _diary(
  String id,
  DateTime date, {
  String title = '',
  String text = '',
  List<String> tags = const <String>[],
}) => AiContextDiary(
  diaryId: id,
  title: title,
  contentText: text,
  createdAt: date,
  isArchived: false,
  tags: tags,
);

AiMessageRow _message(String role, String content, {String status = 'done'}) =>
    AiMessageRow(
      id: 0,
      messageId: 'm${content.hashCode}',
      conversationId: 'c',
      role: role,
      content: content,
      reasoning: '',
      citations: '[]',
      meta: '{}',
      status: status,
      createdAt: DateTime(2026),
    );

void main() {
  setUpAll(() => initializeDateFormatting('zh'));

  group('keywords', () {
    test('question words are dropped, Chinese becomes words and bigrams', () {
      final keywords = aiQueryKeywords('我最近常为什么事烦恼？');
      expect(keywords, isNot(contains('什么')));
      expect(keywords, isNot(contains('最近')));
      expect(keywords, contains('烦恼'));
    });

    test('English keeps meaningful words only', () {
      final keywords = aiQueryKeywords('What did I do at the beach in July?');
      expect(keywords, containsAll(<String>['beach', 'july']));
      expect(keywords, isNot(contains('what')));
      expect(keywords, isNot(contains('the')));
    });
  });

  test('ranking prefers title and tag hits, then newer entries', () {
    final now = DateTime(2026, 11, 2);
    final ranked = aiRankDiaries(
      <AiContextDiary>[
        _diary('body', DateTime(2026, 10, 1), text: '今天去了海边'),
        _diary('title', DateTime(2026, 5, 1), title: '海边', text: '风很大'),
        _diary('none', DateTime(2026, 11, 1), text: '在家看书'),
      ],
      <String>['海边'],
      now: now,
    );
    expect([for (final d in ranked) d.diaryId], ['title', 'body', 'none']);
  });

  test('retrieval plans are parsed tolerantly', () {
    final plan = AiRetrievalPlan.parse(
      '```json\n{"keywords": ["跑步", "", "马拉松"], '
      '"from": "2026-03-31", "to": "2026-03-01"}\n```',
    )!;
    expect(plan.keywords, ['跑步', '马拉松']);
    // 颠倒的范围换回来。
    expect(plan.from, DateTime(2026, 3, 1));
    expect(plan.to, DateTime(2026, 3, 31));
    expect(AiRetrievalPlan.parse('no json here'), isNull);
    expect(
      AiRetrievalPlan.parse('{"keywords": [], "from": "bad"}')!.hasDates,
      isFalse,
    );
  });

  test('chat scopes round-trip and unknown ones fall back to auto', () {
    for (final scope in <AiChatScope>[
      const AiChatScope.auto(),
      const AiChatScope.recent(30),
      const AiChatScope.all(),
      AiChatScope.range(DateTime(2026, 1, 1), DateTime(2026, 1, 31)),
      const AiChatScope.diary(diaryId: 'd1', diaryTitle: '海边'),
    ]) {
      expect(AiChatScope.decode(scope.encode()), scope);
    }
    expect(AiChatScope.decode('{"kind":"later"}').kind, AiChatScopeKind.auto);
    expect(AiChatScope.decode('oops').kind, AiChatScopeKind.auto);
  });

  test('chat requests alternate roles and strip old citations', () {
    final kit = AiPromptKit.resolve(
      prefs: AiPreferences.defaults,
      appLocale: const Locale('zh'),
    );
    final l10n = kit.l10n;
    final request = aiChatRequest(
      kit,
      history: <AiMessageRow>[
        _message('assistant', '听起来很放松 [D1]'),
        _message('user', '那天还做了什么'),
        _message('assistant', '出错了', status: 'error'),
        _message('user', '再说说'),
      ],
      question: '我最近开心吗',
      diaries: <AiBudgetedDiary>[
        AiBudgetedDiary(
          diary: _diary('d9', DateTime(2026, 10, 30), text: '和朋友吃火锅'),
          ref: 'D1',
          maxWords: 100,
        ),
      ],
      today: DateTime(2026, 11, 2),
      persona: aiPersonaFor(l10n, AiPreferences.defaults, AiPersonaUse.chat),
    );
    final roles = [for (final m in request.messages) m.role];
    // 开头的回答前补了一句“请回应”；出错的回答不进历史；相邻的两个问题合并。
    expect(roles, [AiRole.user, AiRole.assistant, AiRole.user]);
    expect(request.messages[0].text, l10n.aiPromptReplyInstruction);
    expect(request.messages[1].text, '听起来很放松');
    expect(request.messages[2].text, contains('那天还做了什么'));
    expect(request.messages[2].text, contains('再说说'));
    expect(request.messages[2].text, contains('[D1]'));
    expect(request.messages[2].text, contains('和朋友吃火锅'));
    expect(request.messages[2].text, endsWith('我最近开心吗'));
    expect(request.system, contains(l10n.aiPromptChatSystem));
  });
}
