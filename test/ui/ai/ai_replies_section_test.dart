import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/core/services/ai/ai_provider_store.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/controllers/ai_reply_flow.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/sections/ai_replies_section.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/fake_ai.dart';

/// 预览页的 AI 回应：选人设后流式生成、完成即保存；删除可撤销；自动回应
/// 只在服务商确认过时发送。
void main() {
  late AiProviderStore store;
  late List<AiRequest> requests;

  Future<String> seedDiary(DiaryDraftsHarness h) async =>
      (await h.tester.runAsync(
        () => h.database.createDiary(
          title: '海边',
          contentDocJson: '[{"insert":"今天去了海边\\n"}]',
          contentText: '今天去了海边',
          metadataJson: '{}',
        ),
      ))!;

  Future<DiaryDraftsHarness> setUpHarness(WidgetTester tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    store = (await tester.runAsync(AiProviderStore.create))!;
    addTearDown(store.dispose);
    requests = <AiRequest>[];
    await h.settings.setAppFeaturesRaw('{"ai":true}');
    return h;
  }

  List<Override> overrides() => [
    aiProviderStoreProvider.overrideWith((ref) async => store),
    aiServiceProvider.overrideWith(
      (ref) async =>
          fakeAiService(store, reply: (_) => '听起来是很放松的一天。', requests: requests),
    ),
  ];

  testWidgets('asking for a reflection streams and saves it', (tester) async {
    final h = await setUpHarness(tester);
    await tester.runAsync(() => seedFakeAiProvider(store));
    final diaryId = await seedDiary(h);
    await h.pump(
      Scaffold(
        body: SingleChildScrollView(
          child: AiRepliesSection(diaryId: diaryId, textColor: Colors.black87),
        ),
      ),
      overrides: overrides(),
    );
    final l10n = h.l10n;
    await tester.tap(find.text(l10n.aiReplyAsk));
    await h.settle();
    await tester.pumpAndSettle();
    // 人设面板：选“知心朋友”。
    await tester.tap(find.text(l10n.aiPersonaFriendName));
    await h.settle();
    await h.settle();

    expect(requests, hasLength(1));
    expect(requests.single.system, contains(l10n.aiPersonaFriendPrompt));
    expect(find.text('听起来是很放松的一天。'), findsOneWidget);
    expect(find.text(l10n.aiRepliesHeading(1)), findsOneWidget);
    final rows = await tester.runAsync(
      () => h.database.watchAiRepliesForDiary(diaryId).first,
    );
    expect(rows!.single.content, '听起来是很放松的一天。');
    await h.unmount();
  });

  testWidgets('deleting a reflection can be undone', (tester) async {
    final h = await setUpHarness(tester);
    await tester.runAsync(() => seedFakeAiProvider(store));
    final diaryId = await seedDiary(h);
    await tester.runAsync(
      () => h.database.addAiResult(
        kind: AiResultKind.reply,
        diaryId: diaryId,
        content: '一条回应',
        metaJson: '{"personaName":"倾听者","personaEmoji":"🫶"}',
      ),
    );
    await h.pump(
      Scaffold(
        body: SingleChildScrollView(
          child: AiRepliesSection(diaryId: diaryId, textColor: Colors.black87),
        ),
      ),
      overrides: overrides(),
    );
    expect(find.text('一条回应'), findsOneWidget);
    expect(find.text('倾听者'), findsOneWidget);

    // 回应从数据流读进来后回应区随高度展开，先等展开动画结束再点。
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('倾听者'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(h.l10n.commonDelete));
    await h.settle();
    expect(find.text('一条回应'), findsNothing);
    await tester.pumpAndSettle();
    await tester.tap(find.text(h.l10n.commonUndo));
    await h.settle();
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.text('一条回应'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('auto reflection waits for a confirmed provider', (tester) async {
    final h = await setUpHarness(tester);
    await tester.runAsync(() => store.saveProvider(fakeAiProvider));
    await h.settings.setAiPrefsRaw('{"autoReply":true}');
    final diaryId = await seedDiary(h);
    late WidgetRef capturedRef;
    await h.pump(
      Consumer(
        builder: (context, ref, _) {
          capturedRef = ref;
          return const SizedBox();
        },
      ),
      overrides: overrides(),
    );
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await tester.runAsync(
      () => startAutoAiReply(
        capturedRef,
        diaryId: diaryId,
        locale: const Locale('zh'),
        l10n: l10n,
      ),
    );
    expect(requests, isEmpty);

    await tester.runAsync(() => store.acknowledgeHost(fakeAiProvider.host));
    await h.settle();
    await tester.runAsync(
      () => startAutoAiReply(
        capturedRef,
        diaryId: diaryId,
        locale: const Locale('zh'),
        l10n: l10n,
      ),
    );
    await h.settle();
    expect(requests, hasLength(1));
    await h.unmount();
  });
}
