import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_header_card.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 首页日记本头部卡片的“更多”菜单里有“导出成书”，点按进入导出面板，并带
/// 上“书籍结构”开关。
void main() {
  testWidgets('the header menu exports the notebook as a book', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    await h.diary('在京都', notebookIds: <String>[travel]);
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

    await tester.tap(
      find.descendant(
        of: find.byType(NotebookHeaderCard),
        matching: find.byTooltip(h.l10n.notebookMoreActions),
      ),
    );
    await h.settleAll();
    expect(find.text(h.l10n.notebookExportAsBook), findsOneWidget);

    await tester.tap(find.text(h.l10n.notebookExportAsBook));
    await h.settleAll();
    await tester.pumpAndSettle();
    expect(find.text(h.l10n.diaryExportBookStructure), findsOneWidget);

    await h.unmount();
  });
}
