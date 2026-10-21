import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/ui/settings/widgets/recycle_bin_tile.dart';
import 'package:node_diary/ui/widgets/empty_hint.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../notebooks/notebook_test_support.dart';

/// 回收站：内容预览、全选、底部操作栏、恢复与彻底删除、返回先清空勾选。
void main() {
  /// 写入一篇日记并移进回收站，返回它的 id。[unlockAt] 不为空时是一枚
  /// 时间胶囊。
  Future<String> trashed(
    DiaryDraftsHarness h,
    String title, {
    String text = '正文',
    DateTime? unlockAt,
  }) async {
    final id = (await h.tester.runAsync(
      () => h.database.createDiary(
        title: title,
        contentDocJson: '[{"insert":"$text\\n"}]',
        contentText: text,
        metadataJson: '{}',
        capsuleUnlockAt: unlockAt,
        capsuleLockedAt: unlockAt == null ? null : DateTime.now(),
      ),
    ))!;
    await h.tester.runAsync(() => h.database.softDeleteDiary(id));
    return id;
  }

  Future<DiaryDraftsHarness> openPage(
    WidgetTester tester,
    Future<void> Function(DiaryDraftsHarness h) seed,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await seed(h);
    await h.pump(const RecycleBinPage());
    await h.settleAll();
    return h;
  }

  Future<bool> isTrashed(DiaryDraftsHarness h, String id) async {
    final row = await h.tester.runAsync(
      () => h.database.getDiaryWithTagsByDiaryId(id),
    );
    return row?.diary.isDeleted ?? false;
  }

  Finder tileOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(RecycleBinTile),
  );

  List<bool?> checkboxValues(WidgetTester tester) => tester
      .widgetList<Checkbox>(find.byType(Checkbox))
      .map((box) => box.value)
      .toList();

  testWidgets('deleted diaries show a snippet and when they were deleted', (
    tester,
  ) async {
    final h = await openPage(tester, (h) => trashed(h, '周末', text: '去公园散步'));

    expect(find.text('周末'), findsOneWidget);
    expect(find.text('去公园散步'), findsOneWidget);
    expect(find.textContaining('删除于'), findsOneWidget);
    // 还没勾选：底部操作栏不出现。
    expect(find.text(h.l10n.autoT0030), findsNothing);
    await h.unmount();
  });

  testWidgets('a sealed time capsule keeps its content hidden', (tester) async {
    final h = await openPage(
      tester,
      (h) => trashed(
        h,
        '给未来',
        text: '胶囊里的话',
        unlockAt: DateTime.now().add(const Duration(days: 30)),
      ),
    );

    expect(find.text('给未来'), findsOneWidget);
    expect(find.text('胶囊里的话'), findsNothing);
    await h.unmount();
  });

  testWidgets('select all picks every diary and toggles back', (tester) async {
    final h = await openPage(tester, (h) async {
      await trashed(h, '一');
      await trashed(h, '二');
      await trashed(h, '三');
    });
    final l10n = h.l10n;

    await tester.tap(find.byTooltip(l10n.commonSelectAll));
    await tester.pumpAndSettle();
    expect(find.text(l10n.autoT0099('3')), findsOneWidget);
    expect(checkboxValues(tester), <bool?>[true, true, true]);
    expect(find.text(l10n.autoT0030), findsOneWidget);

    // 全选后再点一下取消全选，操作栏随之收起。
    await tester.tap(find.byTooltip(l10n.commonDeselectAll));
    await tester.pumpAndSettle();
    expect(find.text(l10n.autoT0029), findsOneWidget);
    expect(checkboxValues(tester), <bool?>[false, false, false]);
    expect(find.text(l10n.autoT0030), findsNothing);

    // 部分勾选时按钮仍是“全选”，补齐剩下的。
    await tester.tap(tileOf('二'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.commonSelectAll));
    await tester.pumpAndSettle();
    expect(find.text(l10n.autoT0099('3')), findsOneWidget);
    await h.unmount();
  });

  testWidgets('restoring the selection brings the diaries back', (
    tester,
  ) async {
    late final String first;
    late final String second;
    final h = await openPage(tester, (h) async {
      first = await trashed(h, '回来一');
      second = await trashed(h, '回来二');
    });
    final l10n = h.l10n;

    await tester.tap(find.byTooltip(l10n.commonSelectAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.autoT0030));
    await h.settleAll();
    await h.settleAll();

    expect(await isTrashed(h, first), isFalse);
    expect(await isTrashed(h, second), isFalse);
    expect(find.byType(EmptyHint), findsOneWidget);
    expect(find.text(l10n.autoT0191('2')), findsOneWidget);
    // 清空后全选按钮一起退场。
    expect(find.byTooltip(l10n.commonSelectAll), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('permanent delete asks first and can be cancelled', (
    tester,
  ) async {
    late final String keep;
    late final String purge;
    final h = await openPage(tester, (h) async {
      keep = await trashed(h, '留在回收站');
      purge = await trashed(h, '删干净');
    });
    final l10n = h.l10n;

    await tester.tap(tileOf('删干净'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.autoT0028));
    await tester.pumpAndSettle();
    expect(find.text(l10n.autoT0193('1')), findsOneWidget);

    // 取消：什么都不删，勾选保留。
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(await isTrashed(h, purge), isTrue);
    expect(find.text(l10n.autoT0099('1')), findsOneWidget);

    await tester.tap(find.text(l10n.autoT0028));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.commonDelete));
    await h.settleAll();
    await h.settleAll();

    final purged = await tester.runAsync(
      () => h.database.getDiaryWithTagsByDiaryId(purge),
    );
    expect(purged, isNull);
    expect(await isTrashed(h, keep), isTrue);
    expect(find.text('删干净'), findsNothing);
    expect(find.text('留在回收站'), findsOneWidget);
    expect(find.text(l10n.autoT0192('1')), findsOneWidget);
    expect(h.mediaCleanup.sweeps, 1);
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('back clears the selection before leaving the page', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await trashed(h, '一篇');
    await h.pump(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const RecycleBinPage()),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await h.settleAll();

    await tester.tap(tileOf('一篇'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RecycleBinPage), findsOneWidget);
    expect(find.text(h.l10n.autoT0029), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RecycleBinPage), findsNothing);
    await h.unmount();
  });
}
