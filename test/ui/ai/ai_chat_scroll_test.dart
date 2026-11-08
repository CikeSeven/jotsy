import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/ui/ai/pages/ai_chat_page.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/widgets/ai_chat_scroll_controller.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';

/// 对话列表的滚动：贴着底部时跟随内容与视口变化；手指一往上就放手、按住
/// 期间不被拉回；滚回底部附近重新跟随；不跟随时视口变矮让底边那一行留在
/// 原处。对话页：输入栏让开键盘，提示条停在输入栏上方，键盘升起时列表仍停在
/// 底部。
void main() {
  group('AiChatScrollController', () {
    late AiChatScrollController controller;
    late ValueNotifier<int> count;
    late ValueNotifier<double> height;

    // 每项 50 高；视口 600 高。
    Future<void> pumpList(WidgetTester tester, {int items = 40}) async {
      controller = AiChatScrollController();
      count = ValueNotifier<int>(items);
      height = ValueNotifier<double>(600);
      addTearDown(controller.dispose);
      addTearDown(count.dispose);
      addTearDown(height.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (context, h, _) => SizedBox(
                height: h,
                child: ValueListenableBuilder<int>(
                  valueListenable: count,
                  builder: (context, n, _) => ListView.builder(
                    controller: controller,
                    itemCount: n,
                    itemBuilder: (context, i) =>
                        SizedBox(height: 50, child: Text('item $i')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    ScrollPosition position() => controller.position;

    testWidgets('stays at the bottom as content grows and the viewport '
        'shrinks or grows', (tester) async {
      await pumpList(tester);
      // 首次排版就停在底部。
      expect(position().pixels, 1400);
      expect(controller.following, isTrue);

      count.value = 45;
      await tester.pump();
      expect(position().pixels, 2250 - 600);

      // 键盘升起：视口变矮，仍贴着底部。
      height.value = 300;
      await tester.pump();
      expect(position().pixels, 2250 - 300);

      height.value = 600;
      await tester.pump();
      expect(position().pixels, 2250 - 600);
    });

    testWidgets('lets go as soon as the finger moves up and is not pulled '
        'back while held', (tester) async {
      await pumpList(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      final held = position().pixels;
      expect(held, lessThan(1400));
      expect(controller.following, isFalse);

      // 按住期间内容不断变高（流式输出）：不被拉回底部。
      for (var i = 0; i < 5; i++) {
        count.value += 1;
        await tester.pump();
        expect(position().pixels, held);
      }

      await gesture.moveBy(const Offset(0, 120));
      await gesture.up();
      await tester.pumpAndSettle();
      final released = position().pixels;
      expect(
        position().maxScrollExtent - released,
        greaterThan(AiChatScrollController.resumeDistance),
      );
      expect(controller.following, isFalse);

      count.value += 5;
      await tester.pump();
      expect(position().pixels, released);
    });

    testWidgets('follows again after scrolling back near the bottom', (
      tester,
    ) async {
      await pumpList(tester);
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(controller.following, isFalse);

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(controller.following, isTrue);

      count.value += 3;
      await tester.pump();
      expect(position().pixels, position().maxScrollExtent);
    });

    testWidgets('keeps the bottom edge in place when not following', (
      tester,
    ) async {
      await pumpList(tester);
      controller.jumpTo(500);
      await tester.pump();
      expect(controller.following, isFalse);

      // 键盘升起 300：原来在视口底边的那一行仍在底边。
      height.value = 300;
      await tester.pump();
      expect(position().pixels, 800);

      height.value = 600;
      await tester.pump();
      expect(position().pixels, 500);

      // 内容变高不动位置。
      count.value += 5;
      await tester.pump();
      expect(position().pixels, 500);

      controller.jumpToBottom();
      await tester.pump();
      expect(controller.following, isTrue);
      expect(position().pixels, position().maxScrollExtent);
    });
  });

  group('chat page', () {
    late AiProviderStore store;

    List<Override> overrides() => [
      aiProviderStoreProvider.overrideWith((ref) async => store),
      aiServiceProvider.overrideWith(
        (ref) async => fakeAiService(store, reply: (_) => '好的'),
      ),
    ];

    Future<DiaryDraftsHarness> setUpHarness(WidgetTester tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      tester.view.physicalSize = const Size(600, 1400);
      store = (await tester.runAsync(AiProviderStore.create))!;
      addTearDown(store.dispose);
      await h.settings.setAppFeaturesRaw('{"ai":true}');
      await h.settings.setAiPrefsRaw('{"agent":{"enabled":false}}');
      await tester.runAsync(() async {
        await seedFakeAiProvider(store);
        await store.acknowledgeHost(fakeAiProvider.host);
      });
      return h;
    }

    /// 一段 20 轮的对话，足够滚动好几屏。
    Future<String> seedConversation(DiaryDraftsHarness h) async =>
        (await h.tester.runAsync(() async {
          final database = h.database;
          final id = await database.createAiConversation(title: '长对话');
          for (var i = 0; i < 20; i++) {
            await database.addAiMessage(
              conversationId: id,
              role: AiMessageRole.user,
              content: '问题 $i',
            );
            await database.addAiMessage(
              conversationId: id,
              role: AiMessageRole.assistant,
              content: List<String>.filled(6, '回答 $i 的一段文字。').join('\n\n'),
            );
          }
          return id;
        }))!;

    Future<void> settleMany(DiaryDraftsHarness h) async {
      for (var i = 0; i < 4; i++) {
        await h.settle();
      }
    }

    ScrollPosition listPosition(WidgetTester tester) => tester
        .state<ScrollableState>(
          // 第一个是列表自己的（回答里的代码块等也有横向滚动）。
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    testWidgets('opens at the bottom and stays there when the keyboard '
        'rises; the input bar clears the keyboard', (tester) async {
      final h = await setUpHarness(tester);
      final id = await seedConversation(h);
      await h.pump(AiChatPage(conversationId: id), overrides: overrides());
      await settleMany(h);

      final position = listPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, position.maxScrollExtent);

      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetViewInsets);
      await settleMany(h);

      expect(position.pixels, position.maxScrollExtent);
      expect(tester.getRect(find.byType(TextField)).bottom, lessThan(1000));
      await h.unmount();
    });

    testWidgets('snack bars float above the input bar', (tester) async {
      final h = await setUpHarness(tester);
      final id = await seedConversation(h);
      await h.pump(AiChatPage(conversationId: id), overrides: overrides());
      await settleMany(h);

      Future<void> expectAboveInput() async {
        final context = tester.element(find.byType(TextField));
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: const SnackBar(content: Text('已复制')),
        ).ignore();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.getRect(find.byType(SnackBar)).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(TextField)).top),
        );
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await tester.pump();
      }

      await expectAboveInput();
      // 键盘开着时同样停在输入栏上方。
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetViewInsets);
      await settleMany(h);
      await expectAboveInput();
      await h.unmount();
    });
  });
}
