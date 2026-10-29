import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';

import '../../../support/expressive_test_theme.dart';

final _desktop = TargetPlatformVariant({
  TargetPlatform.linux,
  TargetPlatform.windows,
});

void main() {
  late FocusNode focus;
  String? copied;

  setUp(() {
    focus = FocusNode();
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });
  tearDown(() {
    focus.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester,
    DiaryEditorController controller,
  ) async {
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
          home: Scaffold(
            body: controller.readOnly
                ? SingleChildScrollView(
                    child: DiaryEditor(
                      controller: controller,
                      appearance: const DiaryTextAppearance(
                        typography: DiaryTypography(),
                      ),
                      shrinkWrap: true,
                    ),
                  )
                : DiaryEditor(
                    controller: controller,
                    appearance: const DiaryTextAppearance(
                      typography: DiaryTypography(),
                    ),
                    focusNode: focus,
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(
    WidgetTester tester,
    DiaryEditorController controller,
    af.Selection selection,
  ) async {
    controller.select(selection);
    await tester.pumpAndSettle();
  }

  Future<void> rightClick(WidgetTester tester, Offset point) async {
    await tester.tapAt(
      point,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  Rect firstSelectionRect(DiaryEditorController controller) =>
      controller.state.selectionRects().first;

  List<String> menuLabels(WidgetTester tester) => [
    for (final element
        in find
            .descendant(
              of: find.byType(AdaptiveTextSelectionToolbar),
              matching: find.byType(Text),
            )
            .evaluate())
      (element.widget as Text).data ?? '',
  ];

  MaterialLocalizations labels(WidgetTester tester) =>
      MaterialLocalizations.of(tester.element(find.byType(DiaryEditor)));

  Future<void> unmount(
    WidgetTester tester,
    DiaryEditorController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'desktop selection shows no menu until a right click at the pointer',
    (tester) async {
      final controller = DiaryEditorController.fromContent('alpha bravo');
      await pump(tester, controller);
      final range = af.Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: 5,
      );
      await select(tester, controller, range);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

      final point = firstSelectionRect(controller).center;
      await rightClick(tester, point);
      final l10n = labels(tester);
      expect(menuLabels(tester), [
        l10n.copyButtonLabel,
        l10n.cutButtonLabel,
        l10n.pasteButtonLabel,
        l10n.selectAllButtonLabel,
      ]);
      // 与系统文本框一致，菜单以指针为左上角，不再右下偏出一截。
      final menu = tester.getTopLeft(
        find
            .descendant(
              of: find.byType(DesktopTextSelectionToolbar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(menu, point);

      await tester.tap(find.text(l10n.copyButtonLabel));
      await tester.pumpAndSettle();
      expect(copied, 'alpha');
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      // 桌面复制后保留选区。
      expect(controller.state.selection?.normalized, range);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
    variant: _desktop,
  );

  testWidgets(
    'escape closes the desktop menu first and returns focus to the body',
    (tester) async {
      final controller = DiaryEditorController.fromContent('alpha bravo');
      await pump(tester, controller);
      await select(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await rightClick(tester, firstSelectionRect(controller).center);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(focus.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
    variant: _desktop,
  );

  testWidgets('right clicking at the caret offers paste and select all only', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent('alpha bravo');
    await pump(tester, controller);
    await select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 3)),
    );
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

    await rightClick(tester, firstSelectionRect(controller).center);
    final l10n = labels(tester);
    expect(menuLabels(tester), [
      l10n.pasteButtonLabel,
      l10n.selectAllButtonLabel,
    ]);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  }, variant: _desktop);

  testWidgets(
    'readonly desktop body offers copy and closes when clicking elsewhere',
    (tester) async {
      final controller = DiaryEditorController.fromContent(
        'alpha bravo',
        readOnly: true,
      );
      await pump(tester, controller);
      await select(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 6, endOffset: 11),
      );
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

      await rightClick(tester, firstSelectionRect(controller).center);
      final l10n = labels(tester);
      expect(menuLabels(tester), [
        l10n.copyButtonLabel,
        l10n.selectAllButtonLabel,
      ]);

      await tester.tapAt(const Offset(4, 590), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      expect(controller.revision, 0);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
    variant: _desktop,
  );

  testWidgets('phones still show the menu as soon as text is selected', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent('alpha bravo');
    await pump(tester, controller);
    await select(
      tester,
      controller,
      af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
    );
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
