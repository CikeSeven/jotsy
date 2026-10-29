import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_link_target.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_link_providers.dart';
import 'package:node_diary/ui/diaries/widgets/diary_link/diary_backlinks_section.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../notebooks/notebook_test_support.dart';

/// 一篇正文里带着指向 [target] 的行内链接的日记。
Future<String> _linking(
  DiaryDraftsHarness h,
  String title,
  DiaryLinkTarget target, {
  DateTime? createdAt,
}) async => (await h.tester.runAsync(
  () => h.database.createDiary(
    title: title,
    contentDocJson: encodeDiaryBlocks({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {
                  'insert': '那天',
                  'attributes': {'href': target.toHref()},
                },
                {'insert': '，$title'},
              ],
            },
          },
        ],
      },
    }),
    contentText: '那天，$title',
    metadataJson: '{}',
    createdAtOverride: createdAt,
  ),
))!;

/// 与预览页同一口径：订阅反向链接，有才显示区块。
class _Host extends ConsumerWidget {
  const _Host(this.target);

  final DiaryLinkTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(diaryBacklinksProvider(target)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: DiaryBacklinksSection(
        data: DiaryPreviewBacklinks(target: target, items: items),
      ),
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting());

  testWidgets('the preview lists the five latest mentions and opens the rest', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final target = DiaryLinkTarget.diary(await h.diary('目标'));
    for (var i = 1; i <= 7; i++) {
      await _linking(h, '第$i篇', target, createdAt: DateTime(2026, 3, i));
    }
    await h.pump(Scaffold(body: _Host(target)));
    await h.settleAll();

    expect(find.text('提到这篇的日记 · 7'), findsOneWidget);
    // 新 → 旧，只列 5 篇。
    expect(find.text('第7篇'), findsOneWidget);
    expect(find.text('第3篇'), findsOneWidget);
    expect(find.text('第2篇'), findsNothing);
    // 有标题时下一行是摘要。
    expect(find.text('那天，第7篇'), findsOneWidget);

    await tester.tap(find.text('全部 7 篇'));
    await h.settleAll();
    expect(find.text('第1篇'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('nothing shows until a diary mentions this one', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final target = DiaryLinkTarget.diary(await h.diary('目标'));
    await h.pump(Scaffold(body: _Host(target)));
    await h.settleAll();
    expect(find.byType(DiaryBacklinksSection), findsNothing);

    await _linking(h, '后来写的', target);
    await h.settleAll();
    expect(find.text('提到这篇的日记 · 1'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('the notebook header offers its mentions', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    await h.diary('在京都', notebookIds: <String>[travel]);
    await _linking(h, '想去旅行', DiaryLinkTarget.notebook(travel));
    await h.pump(
      const DiariesPage(),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
      ],
    );
    await h.settleAll();
    ProviderScope.containerOf(
      tester.element(find.byType(DiariesPage)),
    ).read(homeNotebookScopeProvider.notifier).enter(travel);
    await h.settleAll();

    await tester.tap(find.text('被 1 篇日记提到'));
    await h.settleAll();
    expect(find.text('提到这本的日记'), findsOneWidget);
    expect(find.text('想去旅行'), findsWidgets);
    await h.unmount();
  });
}
