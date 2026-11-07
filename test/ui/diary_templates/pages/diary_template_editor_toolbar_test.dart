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
      'expanding More lets mobile auto scrolling stop in a short viewport '
      '(${brightness.name})',
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
        // 直接重放手机选区通知使用的零时长滚动；计步到上限主动停止，旧代码的
        // 微任务换向循环才会正常报断言失败，而不是卡住整个测试进程。
        final scroller = state.autoScroller!;
        const maxScrollSteps = 100;
        var scrollSteps = 0;
        void countScroll() {
          if (++scrollSteps >= maxScrollSteps) scroller.stopAutoScroll();
        }

        state.addScrollViewScrolledListener(countScroll);
        addTearDown(() {
          scroller.stopAutoScroll();
          state.removeScrollViewScrolledListener(countScroll);
        });
        scroller.startAutoScroll(
          tester.getCenter(body),
          edgeOffset: editor.autoScrollEdgeOffset,
          duration: Duration.zero,
        );
        await tester.pump();

        expect(scrollSteps, lessThan(maxScrollSteps));
        expect(scroller.scrolling, isFalse);
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
