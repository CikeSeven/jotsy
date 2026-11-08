import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/ui/ai/pages/ai_chat_page.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';

/// 回到对话时恢复离开前的样子：往上翻过的位置与跟随状态（从别处打开仍从
/// 底部开始）。
void main() {
  late AiProviderStore store;

  Future<(DiaryDraftsHarness, String)> setUpChat(WidgetTester tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(600, 1200);
    store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    await tester.runAsync(() => seedFakeAiProvider(store));
    final id = (await tester.runAsync(() async {
      final id = await h.database.createAiConversation(title: '很长的对话');
      for (var i = 0; i < 20; i++) {
        await h.database.addAiMessage(
          conversationId: id,
          role: AiMessageRole.user,
          content: '第 $i 个问题',
        );
        await h.database.addAiMessage(
          conversationId: id,
          role: AiMessageRole.assistant,
          content: '第 $i 个回答。${'很长的一段话，' * 30}',
        );
      }
      return id;
    }))!;
    return (h, id);
  }

  List<Override> overrides() => [
    aiProviderStoreProvider.overrideWith((ref) async => store),
    aiServiceProvider.overrideWith(
      (ref) async => fakeAiService(store, reply: (_) => 'ok'),
    ),
  ];

  Future<void> settle(DiaryDraftsHarness h) async {
    for (var i = 0; i < 4; i++) {
      await h.settle();
    }
    await h.tester.pumpAndSettle();
  }

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  testWidgets('reopening to return restores where the user had scrolled', (
    tester,
  ) async {
    final (h, id) = await setUpChat(tester);
    late NavigatorState navigator;
    await h.pump(
      Builder(
        builder: (context) {
          navigator = Navigator.of(context);
          return const SizedBox.shrink();
        },
      ),
      overrides: overrides(),
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => AiChatPage(conversationId: id)),
      ),
    );
    await settle(h);
    final bottom = position(tester).maxScrollExtent;
    expect(position(tester).pixels, closeTo(bottom, 1));

    // 往上翻一大段，停下后记下位置。
    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await settle(h);
    final scrolled = position(tester).pixels;
    expect(scrolled, lessThan(bottom - 400));

    navigator.pop();
    await settle(h);

    // 回到对话：停在刚才的位置，不跳到底部。
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => AiChatPage(conversationId: id, restoreView: true),
        ),
      ),
    );
    await settle(h);
    expect(position(tester).pixels, closeTo(scrolled, 2));

    navigator.pop();
    await settle(h);

    // 从历史或入口打开：照常从底部开始。
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => AiChatPage(conversationId: id)),
      ),
    );
    await settle(h);
    expect(
      position(tester).pixels,
      closeTo(position(tester).maxScrollExtent, 1),
    );
    await h.unmount();
  });
}
