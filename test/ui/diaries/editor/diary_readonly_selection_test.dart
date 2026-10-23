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
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_body.dart';

import '../../../support/expressive_test_theme.dart';

Future<ScrollController> _pumpReader(
  WidgetTester tester,
  DiaryEditorController controller, {
  Brightness brightness = Brightness.light,
  bool textSelection = true,
}) async {
  final scroll = ScrollController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle())],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          af.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 160),
                DiaryPreviewBody(
                  controller: controller,
                  appearance: const DiaryTextAppearance(
                    typography: DiaryTypography(),
                  ),
                  textSelection: textSelection,
                  onOpenImage: (_, _) {},
                ),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return scroll;
}

Rect _cursorRect(DiaryEditorController controller, af.Position position) {
  final selectable = controller.document.nodeAtPath(position.path)!.selectable!;
  return selectable.transformRectToGlobal(
    selectable.getCursorRectInPosition(position)!,
  );
}

void _expectHandleHitTargets(
  WidgetTester tester,
  DiaryEditorController controller,
) {
  final selection = controller.state.selection!.normalized;
  final editorBox = tester.renderObject<RenderBox>(
    find.byType(af.AppFlowyEditor),
  );
  // 上游按宿主平台选择桌面/手机服务。即使 Linux 测试机不绘制手机把手，
  // 也要验证水滴所在位置确实能命中编辑器，而非仅检查溢出的绘制结果。
  for (final point in [
    _cursorRect(controller, selection.start).bottomCenter + const Offset(-6, 6),
    _cursorRect(controller, selection.end).bottomCenter + const Offset(6, 6),
  ]) {
    expect(
      tester
          .hitTestOnBinding(point)
          .path
          .any((entry) => identical(entry.target, editorBox)),
      isTrue,
      reason: 'The selection handle at $point must receive pointer events',
    );
  }
}

Future<void> _unmount(
  WidgetTester tester,
  DiaryEditorController controller,
  ScrollController scroll,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  scroll.dispose();
  // 上游手机滚动服务在选区更新后延迟等待键盘，卸载后让该回调自然退出。
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets(
    'last-line selection handle touch targets receive pointer events',
    (tester) async {
      for (final brightness in Brightness.values) {
        final controller = DiaryEditorController.fromContent(
          'alpha bravo charlie delta echo',
          readOnly: true,
        );
        final scroll = await _pumpReader(
          tester,
          controller,
          brightness: brightness,
        );
        controller.select(
          af.Selection.single(path: [0], startOffset: 6, endOffset: 11),
        );
        await tester.pumpAndSettle();
        _expectHandleHitTargets(tester, controller);
        expect(controller.revision, 0);
        expect(tester.takeException(), isNull);
        await _unmount(tester, controller, scroll);
      }
    },
  );

  testWidgets('last-paragraph handles stay interactive after page scrolling', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      List.filled(20, 'alpha bravo charlie delta echo').join('\n'),
      readOnly: true,
    );
    final scroll = await _pumpReader(tester, controller);
    final last = af.Position(path: [19], offset: 6);
    scroll.jumpTo(_cursorRect(controller, last).center.dy - 240);
    await tester.pumpAndSettle();
    final range = af.Selection.single(
      path: [19],
      startOffset: 6,
      endOffset: 11,
    );
    controller.select(range);
    await tester.pumpAndSettle();
    _expectHandleHitTargets(tester, controller);

    scroll.jumpTo(scroll.offset + 40);
    await tester.pumpAndSettle();
    _expectHandleHitTargets(tester, controller);
    expect(controller.state.selection, range);
    expect(controller.revision, 0);
    expect(tester.takeException(), isNull);
    await _unmount(tester, controller, scroll);
  });

  testWidgets('dragging below the last line still scrolls the reading page', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      'alpha bravo charlie delta echo',
      readOnly: true,
    );
    final scroll = await _pumpReader(tester, controller);
    final belowText =
        _cursorRect(
          controller,
          af.Position(path: [0], offset: 11),
        ).bottomCenter +
        const Offset(6, 6);
    await tester.dragFrom(belowText, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(controller.revision, 0);
    expect(tester.takeException(), isNull);
    await _unmount(tester, controller, scroll);
  });

  testWidgets('disabling text selection preserves page scrolling', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      'alpha bravo charlie delta echo',
      readOnly: true,
    );
    final scroll = await _pumpReader(tester, controller, textSelection: false);
    final point = _cursorRect(
      controller,
      af.Position(path: [0], offset: 8),
    ).center;
    await tester.longPressAt(point);
    await tester.pumpAndSettle();
    expect(controller.state.selection, isNull);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    await tester.dragFrom(point, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
    await _unmount(tester, controller, scroll);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
