import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_body.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_surface.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import '../../../support/expressive_test_theme.dart';

/// 手机正文的选区菜单跟着正文走（#221）：上下滚动时跟随选区，整段离开
/// 看得见的范围（滚出视口、被底部浮层盖住）时隐藏、回来时再出现，菜单
/// 本身不压在正文底部的浮层上。
void main() {
  const lines = 60;
  const appearance = DiaryTextAppearance(typography: DiaryTypography());
  final menu = find.byType(AppTextSelectionToolbar);
  final card = find.descendant(
    of: menu,
    matching: find.byType(ExpressiveMenuSurface),
  );

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle()),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 整页正文；[coveredHeight] 模拟叠在正文底部的悬浮工具栏。
  Future<DiaryEditorController> pumpEditor(
    WidgetTester tester, {
    double coveredHeight = 0,
  }) async {
    final controller = DiaryEditorController.fromContent(
      List.generate(lines, (i) => 'line $i alpha').join('\n'),
    );
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpApp(
      tester,
      Scaffold(
        body: DiaryEditor(
          controller: controller,
          appearance: appearance,
          focusNode: focus,
          autoScrollEdgeOffset: coveredHeight,
        ),
      ),
    );
    return controller;
  }

  Future<void> unmount(
    WidgetTester tester,
    DiaryEditorController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// 菜单在帧尾按本帧布局重新定位、下一帧画出：滚动后推进两帧。
  Future<void> settleFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Rect selectionRect(DiaryEditorController controller) =>
      controller.state.selectionRects().first;

  void selectWord(DiaryEditorController controller, int line) => controller
      .select(af.Selection.single(path: [line], startOffset: 0, endOffset: 4));

  testWidgets('the menu follows the selection while the body scrolls', (
    tester,
  ) async {
    final controller = await pumpEditor(tester);
    selectWord(controller, 10);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    final gap = selectionRect(controller).top - tester.getRect(card).bottom;
    expect(gap, greaterThan(0));

    final position = controller.state.scrollableState!.position;
    position.jumpTo(60);
    await settleFrames(tester);
    expect(card, findsOneWidget);
    // 仍贴着选区上方，间距不变。
    expect(
      selectionRect(controller).top - tester.getRect(card).bottom,
      closeTo(gap, 0.5),
    );
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('the menu hides while the selection is scrolled out of view and '
      'returns with it', (tester) async {
    final controller = await pumpEditor(tester);
    selectWord(controller, 10);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);

    final position = controller.state.scrollableState!.position;
    position.jumpTo(position.maxScrollExtent);
    await settleFrames(tester);
    expect(card, findsNothing);
    // 选区还在，只是看不见。
    expect(controller.state.selection, isNotNull);

    position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    expect(
      tester.getRect(card).bottom,
      lessThanOrEqualTo(selectionRect(controller).top),
    );
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('a selection under the bottom layer has no menu until it is '
      'scrolled above the layer', (tester) async {
    const covered = 400.0;
    final controller = await pumpEditor(tester, coveredHeight: covered);
    const visibleBottom = 800 - covered;
    selectWord(controller, 40);
    await tester.pumpAndSettle();
    final position = controller.state.scrollableState!.position;
    // 把选中的那一行滚到浮层底下（但仍在屏幕上）。
    position.jumpTo(
      position.pixels + selectionRect(controller).top - (visibleBottom + 100),
    );
    await tester.pumpAndSettle();
    expect(selectionRect(controller).top, greaterThan(visibleBottom));
    expect(card, findsNothing);

    position.jumpTo(position.pixels + selectionRect(controller).top - 200);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    expect(tester.getRect(card).bottom, lessThanOrEqualTo(visibleBottom));
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('a menu that flips below the selection stays above the bottom '
      'layer', (tester) async {
    // 第一行贴着屏幕顶端，上方放不下菜单，翻到下方；下方剩下的地方放不下
    // 让出把手后的整个菜单，菜单夹进浮层上方（会盖住选区下面几行）。
    const covered = 700.0;
    final controller = await pumpEditor(tester, coveredHeight: covered);
    selectWord(controller, 0);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    final rect = tester.getRect(card);
    expect(rect.bottom, lessThanOrEqualTo(800 - covered));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('scrolling a reading page moves the menu with the selection', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      List.generate(12, (i) => 'line $i alpha').join('\n'),
      readOnly: true,
    );
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: [
              const SizedBox(height: 300),
              DiaryPreviewBody(
                controller: controller,
                appearance: appearance,
                onOpenImage: (_, _) {},
              ),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    );
    selectWord(controller, 2);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    final before = tester.getRect(card);

    // 过去外层页面一滚菜单就收起；现在跟着选区走。
    scroll.jumpTo(80);
    await settleFrames(tester);
    expect(card, findsOneWidget);
    expect(tester.getRect(card).top, closeTo(before.top - 80, 0.5));

    // 选区滚出页面顶端后隐藏。
    scroll.jumpTo(900);
    await settleFrames(tester);
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
