import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_config.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/ui/ai/models/ai_chat_scope.dart';
import 'package:node_diary/ui/ai/pages/ai_chat_page.dart';
import 'package:node_diary/ui/ai/pages/ai_recap_page.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_task_prompts.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';

/// 通过真实页面和确认面板记录请求，验证多阶段流程在授权前不会外发。
const _utility = AiProviderConfig(
  id: 'quick',
  name: 'Quick',
  protocol: AiProtocol.openAi,
  baseUrl: 'https://utility.test/v1',
  models: [AiModelConfig(id: 'quick-model')],
);

void main() {
  late AiProviderStore store;
  late List<AiRequest> requests;

  Future<DiaryDraftsHarness> setup(
    WidgetTester tester, {
    String mode = 'firstTime',
    bool autoTitle = false,
    String retrieval = 'smart',
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(600, 1400);
    store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    requests = [];
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    await h.settings.setAiPrefsRaw(
      jsonEncode({
        'autoTitle': autoTitle,
        'retrieval': retrieval,
        'aboutMe': '尚未授权的个人信息',
        'privacy': {'confirm': mode, 'budget': 10000},
      }),
    );
    await tester.runAsync(() => store.saveProvider(fakeAiProvider));
    return h;
  }

  List<Override> overrides() => [
    aiProviderStoreProvider.overrideWith((ref) async => store),
    aiServiceProvider.overrideWith(
      (ref) async => fakeAiService(
        store,
        requests: requests,
        reply: (request) {
          if (request.messages.last.text.contains(aiRetrievalPlanFormat)) {
            return '{"keywords":[],"from":null,"to":null}';
          }
          return request.model == 'quick-model' ? '新标题' : '回答 [D1]';
        },
      ),
    ),
  ];

  Future<void> addUtility(WidgetTester tester) async {
    await tester.runAsync(() async {
      await store.saveProvider(_utility);
      await store.update(
        (c) => c.copyWith(
          taskModels: {
            AiTaskKind.utility: const AiModelRef('quick', 'quick-model'),
          },
        ),
      );
    });
  }

  Future<void> settle(DiaryDraftsHarness h) async {
    for (var i = 0; i < 5; i++) {
      await h.settle();
    }
    await h.tester.pump(const Duration(seconds: 1));
  }

  Future<void> confirm(DiaryDraftsHarness h, {required bool send}) async {
    final finder = send
        ? find.widgetWithText(FilledButton, h.l10n.aiConfirmSendAction)
        : find.widgetWithText(TextButton, h.l10n.commonCancel);
    await h.tester.tap(finder.last);
    await settle(h);
  }

  Future<void> openChat(DiaryDraftsHarness h, AiChatPage page) async {
    // 与真实入口一致：先让应用级设置就绪，再导航进自动发问的页面。
    await h.pump(
      Consumer(
        builder: (context, ref, _) {
          ref.watch(aiPreferencesProvider);
          return Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('open chat'),
            ),
          );
        },
      ),
      overrides: overrides(),
    );
    await h.tester.tap(find.text('open chat'));
    await settle(h);
  }

  Future<void> startLongRecap(DiaryDraftsHarness h) async {
    for (var i = 0; i < 3; i++) {
      await h.tester.runAsync(
        () => h.database.createDiary(
          title: '',
          contentDocJson: '',
          contentText: '字' * 3500,
          metadataJson: '{}',
        ),
      );
    }
    await h.pump(const AiRecapPage(), overrides: overrides());
    await h.tester.tap(find.text(h.l10n.aiRecapGenerate));
    await settle(h);
  }

  for (final mode in ['firstTime', 'always']) {
    testWidgets(
      'smart retrieval sends nothing before $mode confirmation or after cancellation',
      (tester) async {
        final h = await setup(tester, mode: mode);
        if (mode == 'always') {
          await tester.runAsync(
            () => store.acknowledgeHost(fakeAiProvider.host),
          );
        }
        await openChat(h, const AiChatPage(initialQuestion: '我的秘密问题'));
        await settle(h);
        expect(
          find.text(h.l10n.aiConfirmSendTitle(fakeAiProvider.host)),
          findsOneWidget,
        );
        expect(requests, isEmpty);
        await confirm(h, send: false);
        expect(requests, isEmpty);
        await h.unmount();
      },
    );
  }

  testWidgets('retrieval confirms the actual utility host before using it', (
    tester,
  ) async {
    final h = await setup(tester);
    await addUtility(tester);
    await tester.runAsync(() => store.acknowledgeHost(fakeAiProvider.host));
    await openChat(h, const AiChatPage(initialQuestion: '问题'));
    await settle(h);
    expect(find.text(h.l10n.aiConfirmSendTitle(_utility.host)), findsOneWidget);
    expect(requests, isEmpty);
    await confirm(h, send: true);
    expect(requests.map((r) => r.model), ['quick-model', 'fake-model']);
    expect(requests.first.system, contains('尚未授权的个人信息'));
    await h.unmount();
  });

  for (final sendTitle in [false, true]) {
    testWidgets('auto title confirms its host and respects send=$sendTitle', (
      tester,
    ) async {
      final h = await setup(tester, autoTitle: true, retrieval: 'keyword');
      await addUtility(tester);
      await tester.runAsync(() => store.acknowledgeHost(fakeAiProvider.host));
      await openChat(h, const AiChatPage(initialQuestion: '原来的问题'));
      await settle(h);
      expect(requests.map((r) => r.model), ['fake-model']);
      expect(
        find.text(h.l10n.aiConfirmSendTitle(_utility.host)),
        findsOneWidget,
      );
      await confirm(h, send: sendTitle);
      expect(requests, hasLength(sendTitle ? 2 : 1));
      final rows = (await tester.runAsync(
        () => h.database.watchAiConversations().first,
      ))!;
      expect(rows.single.title, sendTitle ? '新标题' : '原来的问题');
      await h.unmount();
    });
  }

  testWidgets(
    'recap confirms each utility chunk and cancelling stops later stages',
    (tester) async {
      final h = await setup(tester);
      await addUtility(tester);
      await tester.runAsync(() => store.acknowledgeHost(fakeAiProvider.host));
      await startLongRecap(h);
      expect(
        find.text(h.l10n.aiConfirmSendTitle(_utility.host)),
        findsOneWidget,
      );
      expect(requests, isEmpty);
      await confirm(h, send: true);
      expect(requests.map((r) => r.model), ['quick-model']);
      expect(
        find.text(h.l10n.aiConfirmSendTitle(_utility.host)),
        findsOneWidget,
      );
      await confirm(h, send: false);
      expect(requests, hasLength(1));
      await h.unmount();
    },
  );

  testWidgets('utility consent does not authorize the final recap host', (
    tester,
  ) async {
    final h = await setup(tester);
    await addUtility(tester);
    await tester.runAsync(() => store.acknowledgeHost(_utility.host));
    await startLongRecap(h);
    expect(requests.map((r) => r.model), ['quick-model', 'quick-model']);
    expect(
      find.text(h.l10n.aiConfirmSendTitle(fakeAiProvider.host)),
      findsOneWidget,
    );
    await confirm(h, send: false);
    expect(requests, hasLength(2));
    await h.unmount();
  });

  testWidgets('reopening a fixed-entry chat rechecks a resealed capsule', (
    tester,
  ) async {
    final h = await setup(tester);
    await tester.runAsync(() => store.acknowledgeHost(fakeAiProvider.host));
    final diaryId = (await tester.runAsync(
      () => h.database.createDiary(
        title: '胶囊',
        contentDocJson: '',
        contentText: '不可提前发送的封存正文',
        metadataJson: '{}',
      ),
    ))!;
    final conversationId = (await tester.runAsync(
      () => h.database.createAiConversation(
        title: '旧对话',
        scopeJson: AiChatScope.diary(diaryId: diaryId).encode(),
      ),
    ))!;
    await tester.runAsync(
      () => h.database.updateDiary(
        diaryId: diaryId,
        title: '胶囊',
        contentDocJson: '',
        contentText: '不可提前发送的封存正文',
        metadataJson: '{}',
        capsule: (
          lockedAt: DateTime.now(),
          unlockAt: DateTime.now().add(const Duration(days: 10)),
        ),
      ),
    );
    await h.pump(
      AiChatPage(conversationId: conversationId),
      overrides: overrides(),
    );
    await settle(h);
    await tester.enterText(find.byType(TextField), '现在能告诉我什么？');
    await tester.tap(find.byTooltip(h.l10n.aiPanelSend));
    await settle(h);
    expect(requests, hasLength(1));
    expect(requests.single.messages.last.text, isNot(contains('不可提前发送的封存正文')));
    expect(requests.single.messages.last.text, isNot(contains('[D1]')));
    await h.unmount();
  });
}
