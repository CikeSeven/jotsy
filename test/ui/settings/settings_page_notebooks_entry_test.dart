import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';

import '../../support/diary_drafts_harness.dart';

/// 设置首页的“日记本”入口：紧跟“标签管理”，点按进入日记本管理页。
void main() {
  testWidgets('settings home links to the notebooks page', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const Scaffold(body: SettingsPage()));
    await tester.pumpAndSettle();

    final entry = find.text('日记本');
    expect(entry, findsOneWidget);
    expect(find.text('整理、排序、合并你的日记本'), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.book.data), findsOneWidget);
    // 位置在“标签管理”之后。
    expect(
      tester.getTopLeft(entry).dy,
      greaterThan(
        tester.getTopLeft(find.text(h.l10n.settingsTagManagement)).dy,
      ),
    );

    await tester.tap(entry);
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.byType(NotebooksPage), findsOneWidget);
    await h.unmount();
  });
}
