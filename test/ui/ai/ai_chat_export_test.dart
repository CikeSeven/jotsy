import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/models/ai_agent_steps.dart';
import 'package:node_diary/ui/ai/models/ai_tool_subject.dart';
import 'package:node_diary/ui/ai/pages/ai_chat_export_page.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_chat_export.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_task_prompts.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';

/// 导出对话：完整写出问题、回答、可选的思考与操作、参考的日记；可以只导出
/// 勾选的消息。
void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh');
  });

  final zh = lookupAppLocalizations(const Locale('zh'));

  AiMessageRow row(
    String id,
    String role,
    String content, {
    String reasoning = '',
    String steps = '[]',
    String citations = '[]',
    String status = AiMessageStatus.done,
  }) => AiMessageRow(
    id: id.hashCode & 0xffff,
    messageId: id,
    conversationId: 'c',
    role: role,
    content: content,
    reasoning: reasoning,
    citations: citations,
    meta: '{}',
    status: status,
    steps: steps,
    createdAt: DateTime(2026, 11, 8, 21, 5),
  );

  final messages = [
    row('q', AiMessageRole.user, '十月去过海边吗？'),
    row(
      'a',
      AiMessageRole.assistant,
      '去过，**周末去海边** [D1] 那次风很大。',
      reasoning: '先确认日期范围',
      citations: AiCitation.encodeList([
        AiCitation(
          ref: 'D1',
          diaryId: 'd1',
          title: '周末去海边',
          date: DateTime(2026, 10, 18, 9),
        ),
      ]),
      steps: AiAgentStepRecord.encodeList([
        AiAgentStepRecord(
          text: '我先查一下。',
          calls: [
            AiAgentCallRecord(
              id: 's1',
              tool: 'search_diaries',
              args: const {'query': '海边'},
              status: AiToolCallStatus.succeeded,
              summary: '找到 1 篇',
              subjects: [
                AiToolSubject.diary(
                  'd1',
                  title: '周末去海边',
                  date: DateTime(2026, 10, 18),
                ),
              ],
            ),
          ],
        ),
      ]),
    ),
  ];

  test('markdown keeps the whole exchange with steps and references', () {
    final text = aiChatExportText(
      l10n: zh,
      title: '海边',
      messages: messages,
      assistantName: '日记助手',
      options: const AiChatExportOptions(),
      now: DateTime(2026, 11, 9, 8),
    );
    expect(text, startsWith('# 海边\n'));
    expect(text, contains('### 你 · '));
    expect(text, contains('十月去过海边吗？'));
    expect(text, contains('### 日记助手 · '));
    expect(text, contains('**${zh.aiChatExportSteps}**'));
    expect(text, contains('- 我先查一下。'));
    expect(
      text,
      contains('- ${zh.aiToolSearchDiariesFor('海边')} —— 找到 1 篇：周末去海边'),
    );
    expect(text, contains('去过，**周末去海边** [D1] 那次风很大。'));
    expect(text, contains('- [D1] 周末去海边'));
    // 思考过程默认不带。
    expect(text, isNot(contains('先确认日期范围')));
  });

  test('plain text drops markdown and can include thinking', () {
    final text = aiChatExportText(
      l10n: zh,
      title: '海边',
      messages: messages,
      assistantName: '日记助手',
      options: const AiChatExportOptions(
        format: AiChatExportFormat.text,
        reasoning: true,
        steps: false,
      ),
      now: DateTime(2026, 11, 9, 8),
    );
    expect(text, contains('【你 · '));
    expect(text, contains('先确认日期范围'));
    expect(text, contains('去过，周末去海边 那次风很大。'));
    expect(text, isNot(contains('**')));
    expect(text, isNot(contains('[D1]')));
    expect(text, isNot(contains('我先查一下')));
  });

  test('file names drop characters that file systems reject', () {
    expect(
      aiChatExportFileName(
        'a/b:c?',
        DateTime(2026, 11, 9),
        AiChatExportFormat.text,
      ),
      'a b c 2026-11-09.txt',
    );
  });

  testWidgets('the page exports only the ticked messages', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(600, 1400);
    final store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    await tester.runAsync(() => seedFakeAiProvider(store));
    final id = (await tester.runAsync(() async {
      final id = await h.database.createAiConversation(title: '海边');
      await h.database.addAiMessage(
        conversationId: id,
        role: AiMessageRole.user,
        content: '第一个问题',
      );
      await h.database.addAiMessage(
        conversationId: id,
        role: AiMessageRole.assistant,
        content: '第一个回答',
      );
      await h.database.addAiMessage(
        conversationId: id,
        role: AiMessageRole.user,
        content: '第二个问题',
      );
      return id;
    }))!;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await h.pump(
      AiChatExportPage(conversationId: id),
      overrides: <Override>[
        aiProviderStoreProvider.overrideWith((ref) async => store),
      ],
    );
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.text(zh.aiChatExportSelected(3, 3)), findsOneWidget);

    await tester.tap(find.text('第二个问题'));
    await tester.pumpAndSettle();
    expect(find.text(zh.aiChatExportSelected(2, 3)), findsOneWidget);

    await tester.tap(find.text(zh.aiPanelCopy));
    await h.settle();
    expect(copied, contains('第一个问题'));
    expect(copied, contains('第一个回答'));
    expect(copied, isNot(contains('第二个问题')));
    await h.unmount();
  });
}
