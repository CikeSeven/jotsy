import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/ai/pages/ai_chat_page.dart';
import 'package:node_diary/ui/ai/providers/ai_chat_return_provider.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';
import '../notebooks/notebook_test_support.dart';

/// 回到对话：AI 卡片把用户带回首页（日记页的某本日记本）后，返回键重新
/// 打开那段对话——子本里也先回对话，而不是上一级本子或退出应用；回到对话
/// 后登记撤销，返回键恢复原来的行为。
void main() {
  late AiProviderStore store;

  Future<DiaryDraftsHarness> pumpDiaries(
    WidgetTester tester, {
    Future<void> Function(DiaryDraftsHarness h)? seed,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    await seed?.call(h);
    store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    await tester.runAsync(() => seedFakeAiProvider(store));
    final overrides = <Override>[
      deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
      aiProviderStoreProvider.overrideWith((ref) async => store),
      aiServiceProvider.overrideWith(
        (ref) async => fakeAiService(store, reply: (_) => 'ok'),
      ),
    ];
    await h.pump(const DiariesPage(), overrides: overrides);
    await h.settleAll();
    return h;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(DiariesPage, skipOffstage: false)),
      );

  testWidgets('back reopens the chat the AI card came from', (tester) async {
    final h = await pumpDiaries(tester);
    final id = (await tester.runAsync(
      () => h.database.createAiConversation(title: '旅行计划'),
    ))!;
    containerOf(tester).read(aiChatReturnProvider.notifier).arm(id);
    await h.settleAll();

    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(find.byType(AiChatPage), findsOneWidget);
    expect(find.text('旅行计划'), findsWidgets);
    expect(containerOf(tester).read(aiChatReturnProvider), isNull);

    // 再从对话返回：回到日记页，之后返回照常离开应用。
    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(find.byType(AiChatPage), findsNothing);
    expect(await systemBackLeavesApp(tester), isTrue);
    await h.unmount();
  });

  testWidgets('in a child notebook the chat comes before the parent', (
    tester,
  ) async {
    late String child;
    late String chat;
    final h = await pumpDiaries(
      tester,
      seed: (h) async {
        final parent = await h.notebook('旅行');
        child = await h.notebook('东京', parentId: parent);
        chat = (await tester.runAsync(
          () => h.database.createAiConversation(title: '东京行程'),
        ))!;
      },
    );
    final container = containerOf(tester);
    container.read(homeNotebookScopeProvider.notifier).enter(child);
    await h.settleAll();
    expect(container.read(homeNotebookScopeProvider).notebookId, child);
    container.read(aiChatReturnProvider.notifier).arm(chat);
    await h.settleAll();

    await tester.binding.handlePopRoute();
    await h.settleAll();
    expect(find.byType(AiChatPage), findsOneWidget);
    expect(container.read(homeNotebookScopeProvider).notebookId, child);
    await h.unmount();
  });
}
