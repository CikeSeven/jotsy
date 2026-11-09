import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_built_ins.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';

import '../../../support/diary_content_test_helpers.dart';
import '../../../support/diary_drafts_harness.dart';
import '../../../support/expressive_test_theme.dart';

/// 模板工具栏展开后的视口与移动端自动滚动回归，覆盖明暗主题。
void main() {
  Future<DiaryDraftsHarness> openEditor(
    WidgetTester tester,
    Brightness brightness, {
    DiaryTemplate? template,
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    addTearDown(h.unmount);
    await h.pump(
      Theme(
        data: expressiveTestTheme(brightness),
        child: DiaryTemplateEditorPage(template: template),
      ),
    );
    await tester.pumpAndSettle();
    return h;
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'expanded More respects a shorter desktop window in its first frame '
      '(${brightness.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final h = await openEditor(tester, brightness);
        await tester.tap(find.byTooltip(h.l10n.diaryToolbarMoreTools));
        await tester.pumpAndSettle();

        tester.view.physicalSize = const Size(400, 320);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(DiaryEditor)).height, greaterThan(0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 收起动画仍在画旧内容，也必须服从缩窗的新高度。
        tester.view.physicalSize = const Size(400, 900);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(h.l10n.diaryToolbarHideMoreTools));
        await tester.pump(const Duration(milliseconds: 16));
        tester.view.physicalSize = const Size(400, 320);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'collapsed toolbar ignores desktop height animation (${brightness.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await openEditor(tester, brightness);
        var builds = 0;
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          if (element.widget is DiaryFloatingToolbar) builds++;
        };
        for (final height in <double>[800, 700, 600, 500]) {
          tester.view.physicalSize = Size(400, height);
          await tester.pump();
        }
        debugOnRebuildDirtyWidget = null;
        expect(builds, 0);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'expanding More gives upstream no auto scroller to loop in a short '
      'viewport (${brightness.name})',
      (tester) async {
        final h = await openEditor(
          tester,
          brightness,
          template: buildBuiltInDiaryTemplates(
            lookupAppLocalizations(const Locale('zh')),
          ).first,
        );
        tester.view.physicalSize = const Size(400, 760);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        final body = find.byType(DiaryEditor);
        await tester.tap(body);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(h.l10n.diaryToolbarMoreTools));
        await tester.pumpAndSettle(const Duration(milliseconds: 16));

        final editor = tester.widget<DiaryEditor>(body);
        final state = editor.controller.state;
        final position = state.scrollableState!.position;
        position.jumpTo(
          (position.minScrollExtent + position.maxScrollExtent) / 2,
        );
        await tester.pump();

        // 上游按宿主操作系统选择滚动服务，Linux widget 测试不会进入移动端。
        // 这里照手机滚动服务的写法重放选区通知后的零时长边缘滚动（先取
        // `editorState.autoScroller`，再 `autoScroller?.startAutoScroll`）。
        // 可编辑的整页正文关掉了自动滚动，会话的 EditorState 不再把滚动器
        // 交给上游（`DiaryEditorController` 的 `_DiaryEditorState`）：这一下
        // 什么都不做，短视口里零时长滚动反复换向、耗尽微任务队列的卡死
        // 无从发生。正文自己的边缘滚动见 diary_cursor_drag_follow_test。
        expect(state.disableAutoScroll, isTrue);
        final autoScroller = state.autoScroller;
        expect(autoScroller, isNull);
        var scrolled = 0;
        void countScroll() => scrolled++;
        state.addScrollViewScrolledListener(countScroll);
        addTearDown(() => state.removeScrollViewScrolledListener(countScroll));
        final before = position.pixels;
        autoScroller?.startAutoScroll(
          tester.getCenter(body),
          edgeOffset: editor.autoScrollEdgeOffset,
          duration: Duration.zero,
        );
        await tester.pump();

        expect(scrolled, 0);
        expect(position.pixels, before);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'More preserves room to edit with a tall keyboard (${brightness.name})',
      (tester) async {
        final h = await openEditor(tester, brightness);
        tester.view.physicalSize = const Size(400, 640);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        final body = find.byType(DiaryEditor);
        await tester.tap(body);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(h.l10n.diaryToolbarMoreTools));
        await tester.pumpAndSettle(const Duration(milliseconds: 16));

        expect(tester.getSize(body).height, greaterThan(0));
        expect(
          tester.getBottomRight(find.byType(DiaryFloatingToolbar)).dy,
          lessThanOrEqualTo(640 - 300),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.widgetWithText(ActionChip, '日期'));
        await tester.pumpAndSettle();
        expect(tester.widget<DiaryEditor>(body).controller.plainText, '{{日期}}');
        await tester.tap(find.byTooltip(h.l10n.diaryToolbarHideMoreTools));
        await tester.pumpAndSettle();
        await tester.tap(find.text(h.l10n.diaryTemplateEditorTabSettings));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
