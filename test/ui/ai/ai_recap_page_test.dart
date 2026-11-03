import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/ui/ai/controllers/ai_recap_controller.dart';
import 'package:node_diary/ui/ai/pages/ai_recap_page.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/explore/controllers/explore_module_actions.dart';
import 'package:node_diary/ui/explore/sections/explore_ai_insight_card.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';

class _RecordingActions extends ExploreModuleActions {
  final List<(String?, bool)> recaps = <(String?, bool)>[];
  int settings = 0;

  @override
  void openAiRecap({String? resultId, bool weekly = false}) =>
      recaps.add((resultId, weekly));

  @override
  void openAiSettings() => settings++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// AI 回顾：按范围读日记、流式生成、完成即保存；长的先分块总结；范围里
/// 没有日记时不发送。探索页 AI 卡片显示最近的回顾。
void main() {
  late AiProviderStore store;
  late List<AiRequest> requests;

  Future<DiaryDraftsHarness> setUpHarness(WidgetTester tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = const Size(600, 1600);
    store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    requests = <AiRequest>[];
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    // 只在首次确认：主机已确认过，多篇上下文也不再弹面板。
    await h.settings.setAiPrefsRaw(
      '{"privacy":{"confirm":"firstTime","budget":10000}}',
    );
    await tester.runAsync(() async {
      await seedFakeAiProvider(store);
      await store.acknowledgeHost(fakeAiProvider.host);
    });
    return h;
  }

  List<Override> overrides() => [
    aiProviderStoreProvider.overrideWith((ref) async => store),
    aiServiceProvider.overrideWith(
      (ref) async => fakeAiService(
        store,
        reply: (request) => '## 心情\n这周过得平稳 [D1]。',
        requests: requests,
      ),
    ),
  ];

  Future<void> seedDiary(DiaryDraftsHarness h, String text) async {
    await h.tester.runAsync(
      () => h.database.createDiary(
        title: '',
        contentDocJson: '',
        contentText: text,
        metadataJson: '{}',
      ),
    );
  }

  Future<void> tapGenerate(DiaryDraftsHarness h) async {
    final button = find.text(h.l10n.aiRecapGenerate);
    await h.tester.ensureVisible(button);
    await h.tester.pumpAndSettle();
    await h.tester.tap(button);
    for (var i = 0; i < 4; i++) {
      await h.settle();
    }
  }

  testWidgets('a recap streams, shows stats and is saved', (tester) async {
    final h = await setUpHarness(tester);
    await seedDiary(h, '去海边走了走');
    await seedDiary(h, '加班到很晚');
    await h.pump(const AiRecapPage(), overrides: overrides());
    await tapGenerate(h);

    expect(requests, hasLength(1));
    final prompt =
        (requests.single.messages.single.parts.single as AiTextPart).text;
    expect(prompt, contains('去海边走了走'));
    expect(prompt, contains('[D2]'));
    expect(find.textContaining('这周过得平稳'), findsWidgets);
    expect(find.text(h.l10n.aiRecapStats(2, 11)), findsOneWidget);

    final rows = (await tester.runAsync(
      () => h.database.watchAiRecaps().first,
    ))!;
    expect(rows.single.kind, AiResultKind.recap);
    final meta = AiRecapMeta.decode(rows.single.meta);
    expect(meta.citations.single.ref, 'D1');
    expect(meta.stats!.entries, 2);
    await h.unmount();
  });

  testWidgets('long periods are summarized in parts first', (tester) async {
    final h = await setUpHarness(tester);
    for (var i = 0; i < 3; i++) {
      await seedDiary(h, '字' * 3500);
    }
    await h.pump(const AiRecapPage(), overrides: overrides());
    await tapGenerate(h);

    // 1 万字的预算放不下 3 × 3500：两块分别总结，再汇总一次。
    expect(requests, hasLength(3));
    String text(AiRequest r) =>
        (r.messages.single.parts.single as AiTextPart).text;
    expect(text(requests[0]), contains(h.l10n.aiPromptRecapChunk));
    expect(text(requests[1]), contains(h.l10n.aiPromptRecapChunk));
    expect(text(requests[2]), contains(h.l10n.aiPromptRecapFromSummaries));
    expect(text(requests[2]), isNot(contains('字' * 100)));
    await h.unmount();
  });

  testWidgets('an empty period sends nothing', (tester) async {
    final h = await setUpHarness(tester);
    await h.pump(const AiRecapPage(), overrides: overrides());
    await tapGenerate(h);
    expect(requests, isEmpty);
    expect(find.text(h.l10n.aiRecapNoEntries), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the explore card shows the latest recap and opens it', (
    tester,
  ) async {
    final h = await setUpHarness(tester);
    final id = (await tester.runAsync(
      () => h.database.addAiResult(
        kind: AiResultKind.recap,
        content: '## 心情\n- **平稳** [D1]',
        title: '2026年11月2日 – 11月8日',
        scopeJson: '{"preset":"thisWeek"}',
      ),
    ))!;
    final actions = _RecordingActions();
    await h.pump(
      Scaffold(
        body: ExploreActionsScope(
          actions: actions,
          child: const SingleChildScrollView(child: ExploreAiInsightCard()),
        ),
      ),
      overrides: overrides(),
    );
    expect(find.text('心情 平稳'), findsOneWidget);
    await tester.tap(find.text('心情 平稳'));
    await tester.tap(find.text(h.l10n.aiExploreWeekly));
    expect(actions.recaps, [(id, false), (null, true)]);
    await h.unmount();
  });

  testWidgets('the explore card points to settings until AI is set up', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final empty = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(empty.dispose);
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    final actions = _RecordingActions();
    await h.pump(
      Scaffold(
        body: ExploreActionsScope(
          actions: actions,
          child: const ExploreAiInsightCard(),
        ),
      ),
      overrides: [aiProviderStoreProvider.overrideWith((ref) async => empty)],
    );
    expect(find.text(h.l10n.aiExploreNotConfigured), findsOneWidget);
    expect(find.text(h.l10n.aiExploreWeekly), findsNothing);
    await tester.tap(find.text(h.l10n.aiErrorOpenSettings));
    expect(actions.settings, 1);
    await h.unmount();
  });
}
