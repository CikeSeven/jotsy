import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/pages/diary_drafts_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_draft_tile.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_templates_page.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';
import 'package:node_diary/ui/notebooks/sections/notebooks_page_lists.dart';
import 'package:node_diary/ui/settings/pages/editor_settings_page.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/settings/widgets/recycle_bin_tile.dart';
import 'package:node_diary/ui/settings/widgets/settings_card_group.dart';

import '../../support/diary_drafts_harness.dart';
import '../notebooks/notebook_test_support.dart';

/// 表单类二级页在宽窗口下的内容列：最宽 720、水平居中，标题栏随内容列内收；
/// 手机宽度下左右留白与改版前完全相同（16）。
void main() {
  /// SettingsCardGroup 的内容列（标题与卡片所在的 Column，不含外边距）。
  Finder cardGroupColumn() => find
      .descendant(
        of: find.byType(SettingsCardGroup).first,
        matching: find.byType(Column),
      )
      .first;

  final cases = <_PageCase>[
    _PageCase(
      'settings root',
      page: (_) => const Scaffold(body: SettingsPage()),
      content: () => find.byType(Card).first,
      hasTopBar: false,
    ),
    _PageCase(
      'editor settings subpage',
      page: (_) => const EditorSettingsPage(),
      content: cardGroupColumn,
    ),
    _PageCase(
      'recycle bin',
      seed: (h) async {
        final id = (await h.tester.runAsync(
          () => h.database.createDiary(
            title: '周末',
            contentDocJson: '[{"insert":"正文\\n"}]',
            contentText: '正文',
            metadataJson: '{}',
          ),
        ))!;
        await h.tester.runAsync(() => h.database.softDeleteDiary(id));
      },
      page: (_) => const RecycleBinPage(),
      content: () => find.byType(RecycleBinTile).first,
    ),
    _PageCase(
      'drafts',
      seed: (h) => h.seed('草稿', updatedAt: DateTime(2026, 1, 2)),
      page: (_) => const DiaryDraftsPage(),
      content: () => find.byType(DiaryDraftTile).first,
    ),
    _PageCase(
      'templates list',
      page: (_) => const DiaryTemplatesPage(),
      content: cardGroupColumn,
    ),
    _PageCase(
      'notebooks',
      seed: (h) => h.notebook('旅行'),
      page: (_) => const NotebooksPage(),
      content: () => find.byType(NotebookManageRow).first,
    ),
  ];

  Future<DiaryDraftsHarness> open(
    WidgetTester tester,
    _PageCase c,
    Size size,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await c.seed?.call(h);
    await h.pump(c.page(h));
    await h.settleAll();
    await tester.pumpAndSettle();
    return h;
  }

  for (final c in cases) {
    testWidgets('${c.name}: wide window centres a column at most 720 wide', (
      tester,
    ) async {
      final h = await open(tester, c, const Size(1280, 800));
      final rect = tester.getRect(c.content());
      expect(rect.width, lessThanOrEqualTo(720));
      expect(rect.width, greaterThan(600));
      expect(rect.center.dx, moreOrLessEquals(640, epsilon: 0.5));
      if (c.hasTopBar) {
        // 标题栏两侧各缩进 gutter − 16，返回键与内容列对齐。
        final bar = tester.getRect(find.byType(AppBar));
        expect(bar.left, moreOrLessEquals((1280 - 720) / 2 - 16));
        expect(bar.right, moreOrLessEquals(1280 - ((1280 - 720) / 2 - 16)));
      } else {
        // 设置首页的 PageHeader：标题与卡片列左缘对齐。
        final title = find.text(h.l10n.settingsTitle);
        expect(tester.getTopLeft(title).dx, moreOrLessEquals(rect.left));
      }
      await h.unmount();
    });

    testWidgets('${c.name}: phone width keeps the 16dp side padding', (
      tester,
    ) async {
      final h = await open(tester, c, const Size(400, 860));
      final rect = tester.getRect(c.content());
      expect(rect.left, 16);
      expect(rect.right, 400 - 16);
      if (c.hasTopBar) {
        expect(tester.getRect(find.byType(AppBar)).width, 400);
      }
      await h.unmount();
    });
  }
}

class _PageCase {
  _PageCase(
    this.name, {
    this.seed,
    required this.page,
    required this.content,
    this.hasTopBar = true,
  });

  final String name;
  final Future<void> Function(DiaryDraftsHarness h)? seed;
  final Widget Function(DiaryDraftsHarness h) page;
  final Finder Function() content;
  final bool hasTopBar;
}
