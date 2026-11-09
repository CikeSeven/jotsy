import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/core/services/text_process_actions_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import '../../../support/expressive_test_theme.dart';

final _desktop = TargetPlatformVariant({
  TargetPlatform.linux,
  TargetPlatform.windows,
});

/// 不经平台通道的 ProcessText：动作列表与回写结果由用例给定。
class _FakeProcessText implements ProcessTextService {
  _FakeProcessText({this.actions = const [], this.result});

  final List<ProcessTextAction> actions;
  final String? result;
  final List<(String, String, bool)> processed = [];

  @override
  Future<List<ProcessTextAction>> queryTextActions() async => actions;

  @override
  Future<String?> processTextAction(
    String id,
    String text,
    bool readOnly,
  ) async {
    processed.add((id, text, readOnly));
    // 只读时也照样回写，验证正文这一侧自己挡住。
    return result;
  }
}

void main() {
  late FocusNode focus;
  String? copied;
  late int pageEscapes;

  setUp(() {
    focus = FocusNode();
    copied = null;
    pageEscapes = 0;
    // 默认没有其他应用的文字处理，用例按需换成自己的。
    TextProcessActionsService.debugOverride(
      TextProcessActionsService(service: _FakeProcessText()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });
  tearDown(() {
    TextProcessActionsService.debugOverride(null);
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
        // 页面自己的 Esc（编辑页是返回）：包在应用最外层，菜单（插在根
        // Overlay 里）的焦点也在它下面，菜单开着时不该收到。
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                pageEscapes++,
          },
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

  /// 菜单里各项的文字（不含「更多 / 收起」与桌面行尾的快捷键提示），按树序。
  List<String> menuLabels(WidgetTester tester) {
    final menu = find.byWidgetPredicate(
      (widget) =>
          widget is AppTextSelectionToolbar ||
          widget is AppTextContextMenuPanel,
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(DiaryEditor)));
    final skipped = {l10n.textSelectionMenuMore, l10n.textSelectionMenuLess};
    return [
      for (final element
          in find.descendant(of: menu, matching: find.byType(Text)).evaluate())
        if ((element.widget as Text).data case final String label
            when !skipped.contains(label) && !label.startsWith('Ctrl+'))
          label,
    ];
  }

  Future<void> toggleMore(WidgetTester tester) async {
    final l10n = AppLocalizations.of(tester.element(find.byType(DiaryEditor)));
    await tester.tap(
      find.ancestor(
        of: find.text(l10n.textSelectionMenuMore),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  String bodyText(DiaryEditorController controller) =>
      controller.document.root.children.first.delta!.toPlainText();

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
      expect(find.byType(AppTextContextMenuPanel), findsNothing);

      final point = firstSelectionRect(controller).center;
      await rightClick(tester, point);
      final l10n = labels(tester);
      expect(menuLabels(tester), [
        l10n.cutButtonLabel,
        l10n.copyButtonLabel,
        l10n.pasteButtonLabel,
        l10n.selectAllButtonLabel,
        AppLocalizations.of(
          tester.element(find.byType(DiaryEditor)),
        ).diaryEditorSelectBlocks,
      ]);
      // 行尾是与输入框同源的快捷键提示；桌面没有分享。
      for (final key in ['X', 'C', 'V', 'A']) {
        expect(find.text('Ctrl+$key'), findsOneWidget);
      }
      expect(find.text(l10n.shareButtonLabel), findsNothing);
      // 与系统文本框一致，菜单以指针为左上角，不再右下偏出一截。
      final menu = tester.getTopLeft(
        find
            .ancestor(
              of: find.text(l10n.cutButtonLabel),
              matching: find.byType(IntrinsicWidth),
            )
            .first,
      );
      expect(menu, point);

      await tester.tap(find.text(l10n.copyButtonLabel));
      await tester.pumpAndSettle();
      expect(copied, 'alpha');
      expect(find.byType(AppTextContextMenuPanel), findsNothing);
      // 桌面复制后保留选区。
      expect(controller.state.selection?.normalized, range);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
    variant: _desktop,
  );

  testWidgets(
    'escape closes the desktop menu without reaching the page and returns focus to the body',
    (tester) async {
      final controller = DiaryEditorController.fromContent('alpha bravo');
      await pump(tester, controller);
      await select(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await rightClick(tester, firstSelectionRect(controller).center);
      expect(find.byType(AppTextContextMenuPanel), findsOneWidget);
      expect(focus.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AppTextContextMenuPanel), findsNothing);
      expect(focus.hasFocus, isTrue);
      // Esc 只收起菜单，不落到页面（编辑页的 Esc 是返回）。
      expect(pageEscapes, 0);
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
    expect(find.byType(AppTextContextMenuPanel), findsNothing);

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
      expect(find.byType(AppTextContextMenuPanel), findsNothing);

      await rightClick(tester, firstSelectionRect(controller).center);
      final l10n = labels(tester);
      expect(menuLabels(tester), [
        l10n.copyButtonLabel,
        l10n.selectAllButtonLabel,
      ]);

      await tester.tapAt(const Offset(4, 590), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byType(AppTextContextMenuPanel), findsNothing);
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
    expect(find.byType(AppTextSelectionToolbar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  // 测试环境里上游按宿主机（Linux）装的是桌面选区服务，这里照手机选区
  // 服务长按松手时的方式交还选区。
  Future<void> releaseLongPress(
    WidgetTester tester,
    DiaryEditorController controller,
    af.Selection selection,
  ) async {
    unawaited(
      controller.state.updateSelectionWithReason(
        selection,
        reason: af.SelectionUpdateReason.uiEvent,
        extraInfo: {af.selectionExtraInfoDoNotAttachTextService: false},
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long pressing an empty paragraph on phones offers paste', (
    tester,
  ) async {
    final controller = DiaryEditorController(
      document: af.Document.blank(withInitialText: true),
    );
    await pump(tester, controller);
    final caret = af.Selection.collapsed(af.Position(path: [0]));
    await releaseLongPress(tester, controller, caret);
    final l10n = labels(tester);
    expect(menuLabels(tester), [
      l10n.pasteButtonLabel,
      l10n.selectAllButtonLabel,
    ]);

    // 正文此时才取得焦点、按原选区重设一次（iOS），菜单不受影响。
    controller.select(caret);
    await tester.pumpAndSettle();
    expect(find.byType(AppTextSelectionToolbar), findsOneWidget);

    // 之后的点按只放光标，菜单随之收起。
    unawaited(
      controller.state.updateSelectionWithReason(
        caret,
        reason: af.SelectionUpdateReason.uiEvent,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppTextSelectionToolbar), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('pasting from the caret menu closes it', (tester) async {
    final controller = DiaryEditorController(
      document: af.Document.blank(withInitialText: true),
    );
    await pump(tester, controller);
    await releaseLongPress(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0])),
    );
    await tester.tap(find.text(labels(tester).pasteButtonLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AppTextSelectionToolbar), findsNothing);

    // 剪贴板为空时选区不变，之后的通知也不会把菜单弹回来。
    controller.state.updateToggledStyle('bold', true);
    await tester.pumpAndSettle();
    expect(find.byType(AppTextSelectionToolbar), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('long pressing a readonly body on phones shows no caret menu', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      'alpha bravo',
      readOnly: true,
    );
    await pump(tester, controller);
    await releaseLongPress(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 3)),
    );
    expect(find.byType(AppTextSelectionToolbar), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('a programmatic caret on phones shows no menu', (tester) async {
    final controller = DiaryEditorController.fromContent('alpha bravo');
    await pump(tester, controller);
    await select(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0], offset: 3)),
    );
    expect(find.byType(AppTextSelectionToolbar), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets(
    'phone selection lists cut, copy, paste, select all and AI with share under more',
    (tester) async {
      final controller = DiaryEditorController.fromContent('alpha bravo')
        ..aiSelectionHandler = () {};
      await pump(tester, controller);
      await select(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      final l10n = labels(tester);
      final app = AppLocalizations.of(tester.element(find.byType(DiaryEditor)));
      final row = [
        l10n.cutButtonLabel,
        l10n.copyButtonLabel,
        l10n.pasteButtonLabel,
        l10n.selectAllButtonLabel,
        app.diaryEditorSelectBlocks,
        app.aiSelectionMenu,
      ];
      expect(menuLabels(tester), row);
      final xs = [
        for (final label in row) tester.getCenter(find.text(label)).dx,
      ];
      expect(xs, orderedEquals(List<double>.of(xs)..sort()));
      expect(find.text(l10n.shareButtonLabel), findsNothing);

      await toggleMore(tester);
      expect(find.text(l10n.shareButtonLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
  );

  testWidgets('Select blocks turns the text selection into block selection', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      'alpha\nbravo\ncharlie',
    );
    await pump(tester, controller);
    await select(
      tester,
      controller,
      af.Selection(
        start: af.Position(path: [0], offset: 2),
        end: af.Position(path: [1], offset: 3),
      ),
    );
    final app = AppLocalizations.of(tester.element(find.byType(DiaryEditor)));
    await tester.tap(find.text(app.diaryEditorSelectBlocks));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final selection = controller.blockSelection;
    expect(selection.isActive, isTrue);
    expect(selection.roots.map((node) => node.delta!.toPlainText()), [
      'alpha',
      'bravo',
    ]);
    // 正文选区清空，选区菜单随之收起。
    expect(controller.state.selection, isNull);
    expect(find.text(app.diaryEditorSelectBlocks), findsNothing);
    selection.exit();
    await tester.pump(const Duration(milliseconds: 300));
    await unmount(tester, controller);
  });

  testWidgets(
    'widening the selection keeps the same phone menu and collapses more',
    (tester) async {
      final controller = DiaryEditorController.fromContent('alpha bravo');
      await pump(tester, controller);
      await select(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      final state = tester.state(find.byType(AppTextSelectionToolbar));
      await toggleMore(tester);
      final share = labels(tester).shareButtonLabel;
      expect(find.text(share), findsOneWidget);

      // 像拖动把手那样扩大选区：胶囊原地更新，不重新挂载（不重播入场）。
      await select(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 0, endOffset: 11),
      );
      expect(find.byType(AppTextSelectionToolbar), findsOneWidget);
      expect(tester.state(find.byType(AppTextSelectionToolbar)), same(state));
      expect(find.text(share), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    },
  );

  group('sharing from the phone menu', () {
    late List<String?> shared;

    setUp(() {
      shared = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (call) async {
              shared.add((call.arguments as Map)['text'] as String?);
              return 'dev.fluttercommunity.plus/share/unavailable';
            },
          );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
    });

    Future<void> tapShare(
      WidgetTester tester,
      DiaryEditorController controller,
      af.Selection range,
    ) async {
      await select(tester, controller, range);
      await toggleMore(tester);
      await tester.tap(find.text(labels(tester).shareButtonLabel));
      await tester.pumpAndSettle();
    }

    testWidgets('shares the selected text taken at tap time', (tester) async {
      final controller = DiaryEditorController.fromContent('alpha bravo');
      await pump(tester, controller);
      await tapShare(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 6, endOffset: 11),
      );
      expect(shared, ['bravo']);
      expect(find.byType(AppTextSelectionToolbar), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });

    testWidgets('only closes the menu when the selection is blank', (
      tester,
    ) async {
      final controller = DiaryEditorController.fromContent('alpha   bravo');
      await pump(tester, controller);
      await tapShare(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 5, endOffset: 8),
      );
      expect(shared, isEmpty);
      expect(find.byType(AppTextSelectionToolbar), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });
  });

  testWidgets('readonly phone selection offers copy, select all and share', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      'alpha bravo',
      readOnly: true,
    )..aiSelectionHandler = () {};
    await pump(tester, controller);
    await select(
      tester,
      controller,
      af.Selection.single(path: [0], startOffset: 6, endOffset: 11),
    );
    final l10n = labels(tester);
    expect(menuLabels(tester), [
      l10n.copyButtonLabel,
      l10n.selectAllButtonLabel,
    ]);
    await toggleMore(tester);
    expect(menuLabels(tester), [
      l10n.copyButtonLabel,
      l10n.selectAllButtonLabel,
      l10n.shareButtonLabel,
    ]);
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  testWidgets('the caret menu on phones has no more button', (tester) async {
    final controller = DiaryEditorController(
      document: af.Document.blank(withInitialText: true),
    );
    await pump(tester, controller);
    await releaseLongPress(
      tester,
      controller,
      af.Selection.collapsed(af.Position(path: [0])),
    );
    final l10n = labels(tester);
    expect(menuLabels(tester), [
      l10n.pasteButtonLabel,
      l10n.selectAllButtonLabel,
    ]);
    expect(
      find.text(
        AppLocalizations.of(
          tester.element(find.byType(DiaryEditor)),
        ).textSelectionMenuMore,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await unmount(tester, controller);
  });

  group('text processing from other apps', () {
    const translate = ProcessTextAction('translate', '翻译');

    _FakeProcessText useFake({String? result}) {
      final fake = _FakeProcessText(actions: const [translate], result: result);
      TextProcessActionsService.debugOverride(
        TextProcessActionsService(service: fake),
      );
      return fake;
    }

    Future<void> runTranslate(
      WidgetTester tester,
      DiaryEditorController controller,
      af.Selection range,
    ) async {
      await select(tester, controller, range);
      await toggleMore(tester);
      await tester.tap(find.text(translate.label));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'replaces the selection with the returned text in one undo step',
      (tester) async {
        final fake = useFake(result: 'ALPHA');
        final controller = DiaryEditorController.fromContent('alpha bravo');
        await pump(tester, controller);
        final range = af.Selection.single(
          path: [0],
          startOffset: 0,
          endOffset: 5,
        );
        await select(tester, controller, range);
        // 菜单打开时才查询，查到的动作补进次要区。
        await toggleMore(tester);
        expect(find.text(translate.label), findsOneWidget);
        await tester.tap(find.text(translate.label));
        await tester.pumpAndSettle();

        expect(fake.processed, [('translate', 'alpha', false)]);
        expect(bodyText(controller), 'ALPHA bravo');
        expect(find.byType(AppTextSelectionToolbar), findsNothing);

        controller.state.undoManager.undo();
        await tester.pumpAndSettle();
        expect(bodyText(controller), 'alpha bravo');
        expect(tester.takeException(), isNull);
        await unmount(tester, controller);
      },
    );

    testWidgets('leaves a readonly body untouched', (tester) async {
      final fake = useFake(result: 'BRAVO');
      final controller = DiaryEditorController.fromContent(
        'alpha bravo',
        readOnly: true,
      );
      await pump(tester, controller);
      await runTranslate(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 6, endOffset: 11),
      );
      expect(fake.processed, [('translate', 'bravo', true)]);
      expect(bodyText(controller), 'alpha bravo');
      expect(controller.revision, 0);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });

    testWidgets('keeps the body when the other app returns nothing', (
      tester,
    ) async {
      final fake = useFake();
      final controller = DiaryEditorController.fromContent('alpha bravo');
      await pump(tester, controller);
      await runTranslate(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      expect(fake.processed, hasLength(1));
      expect(bodyText(controller), 'alpha bravo');
      expect(controller.revision, 0);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    });

    testWidgets('is not offered on desktop', (tester) async {
      useFake(result: 'ALPHA');
      final controller = DiaryEditorController.fromContent('alpha bravo');
      await pump(tester, controller);
      await select(
        tester,
        controller,
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      await rightClick(tester, firstSelectionRect(controller).center);
      expect(find.byType(AppTextContextMenuPanel), findsOneWidget);
      expect(find.text(translate.label), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester, controller);
    }, variant: _desktop);
  });
}

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}
