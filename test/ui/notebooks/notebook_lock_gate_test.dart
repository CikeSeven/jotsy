import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 上锁日记本的“会露出内容”的操作都要先验证身份：打开编辑页、合并、删除；
/// 置顶不需要；首页里已解锁的头部卡片不再二次验证。
void main() {
  late String vault;

  Future<DiaryDraftsHarness> openManager(
    WidgetTester tester,
    FakeDeviceAuth auth,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    vault = await h.notebook('保险箱', visibility: NotebookVisibility.locked);
    await h.notebook('旅行');
    await h.diary('秘密', notebookIds: <String>[vault]);
    await h.pump(
      const NotebooksPage(),
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );
    await h.settleAll();
    return h;
  }

  Finder row(String id) => find.byKey(ValueKey<String>('notebook_row_$id'));

  Future<void> openMore(DiaryDraftsHarness h, String action) async {
    await h.tester.tap(
      find.descendant(of: row(vault), matching: find.byTooltip('更多操作')),
    );
    await h.tester.pumpAndSettle();
    await h.tester.tap(find.widgetWithText(ListTile, action));
    await h.settleAll();
  }

  testWidgets('opening the editor asks first; a denial stays put', (
    tester,
  ) async {
    final auth = FakeDeviceAuth(results: <bool>[false, true]);
    final h = await openManager(tester, auth);

    await tester.tap(find.text('保险箱'));
    await h.settleAll();
    expect(auth.reasons, <String>['解锁「保险箱」']);
    expect(find.byType(NotebookEditorPage), findsNothing);

    await tester.tap(find.text('保险箱'));
    await h.settleAll();
    expect(find.byType(NotebookEditorPage), findsOneWidget);
    await h.unmount();
  });

  testWidgets('delete asks first and a denial shows no dialog', (tester) async {
    final auth = FakeDeviceAuth(results: <bool>[false, true]);
    final h = await openManager(tester, auth);

    await openMore(h, '删除');
    expect(auth.reasons, hasLength(1));
    expect(find.text('只删除日记本'), findsNothing);

    await openMore(h, '删除');
    expect(auth.reasons, hasLength(2));
    expect(find.text('只删除日记本'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await h.settleAll();
    await h.unmount();
  });

  testWidgets('merge asks first and a denial shows no target sheet', (
    tester,
  ) async {
    final auth = FakeDeviceAuth(results: <bool>[false, true]);
    final h = await openManager(tester, auth);

    await openMore(h, '合并到…');
    expect(auth.reasons, hasLength(1));
    expect(find.text(h.l10n.notebookMergeSheetTitle), findsNothing);

    await openMore(h, '合并到…');
    expect(find.text(h.l10n.notebookMergeSheetTitle), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await h.settleAll();
    await h.unmount();
  });

  testWidgets('pinning needs no authentication', (tester) async {
    final auth = FakeDeviceAuth();
    final h = await openManager(tester, auth);
    await openMore(h, '置顶');
    expect(auth.reasons, isEmpty);
    expect((await h.notebookRow(vault))!.isPinned, isTrue);
    await h.unmount();
  });

  testWidgets('a device without a screen lock never opens the editor', (
    tester,
  ) async {
    final auth = FakeDeviceAuth(supported: false);
    final h = await openManager(tester, auth);
    await tester.tap(find.text('保险箱'));
    await h.settleAll();
    expect(find.text('无法打开上锁的日记本'), findsOneWidget);
    expect(find.text('去设置'), findsNothing);
    await tester.tap(find.text('知道了'));
    await h.settleAll();
    expect(find.byType(NotebookEditorPage), findsNothing);
    await h.unmount();
  });

  testWidgets('the header card of an unlocked notebook edits without asking '
      'again', (tester) async {
    final auth = FakeDeviceAuth(results: <bool>[true]);
    final h = await DiaryDraftsHarness.create(tester);
    vault = await h.notebook('保险箱', visibility: NotebookVisibility.locked);
    await h.pump(
      const DiariesPage(),
      overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
    );
    await h.settleAll();
    ProviderScope.containerOf(
      tester.element(find.byType(DiariesPage)),
    ).read(homeNotebookScopeProvider.notifier).enter(vault);
    await h.settleAll();
    expect(find.byType(NotebookHeaderCard), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NotebookHeaderCard),
        matching: find.byTooltip('更多操作'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑日记本'));
    await h.settleAll();
    expect(auth.reasons, isEmpty);
    expect(find.byType(NotebookEditorPage), findsOneWidget);
    await h.unmount();
  });
}
