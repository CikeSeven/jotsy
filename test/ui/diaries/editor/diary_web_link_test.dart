import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_link_spans.dart';

import '../../../support/diary_link_editor_harness.dart';

/// 正文里的网址链接（#336）：点按与 Ctrl / ⌘ + K 都经应用的链接对话框编辑，
/// 不再弹上游的链接浮层（手机窄屏上会摆到屏幕外）。
void main() {
  const url = 'https://example.com';

  /// “看 ” + 一段网址链接，链接后半截加粗（同一条链接分成两个片段）。
  List<Map<String, Object?>> linkedDelta([String href = url]) => [
    {'insert': '看 '},
    {
      'insert': '官网',
      'attributes': {'href': href},
    },
    {
      'insert': '首页',
      'attributes': {'href': href, 'bold': true},
    },
  ];

  /// 上游打开网址经可替换的 `editorLaunchUrl`，测试里记下而不真的打开。
  List<String?> recordLaunches() {
    final launched = <String?>[];
    final original = af.editorLaunchUrl;
    af.editorLaunchUrl = (href) async {
      launched.add(href);
      return true;
    };
    addTearDown(() => af.editorLaunchUrl = original);
    return launched;
  }

  group('web link span', () {
    af.EditorState state({required bool editable}) => af.EditorState(
      document: af.Document.fromJson(
        jsonDecode(linkTestDocument([linkTestParagraph(linkedDelta())]))
            as Map<String, Object?>,
      ),
    )..editable = editable;

    /// 加粗的“首页”片段（偏移 4）的点按识别器；[edits] 记下打开对话框的次数。
    TapGestureRecognizer recognizer(af.EditorState state, List<int> edits) {
      final node = state.document.nodeAtPath([0])!;
      final span = diaryWebLinkTextSpan(
        node,
        4,
        af.TextInsert('首页', attributes: {'href': url, 'bold': true}),
        const TextSpan(text: '首页'),
        url,
        DiaryLinkSpanOptions(
          state: state,
          onOpen: (_) => fail('web links never open as diary links'),
          onEditWebLink: () => edits.add(1),
          notebooksEnabled: true,
          plainColor: null,
        ),
      );
      return span.recognizer! as TapGestureRecognizer;
    }

    testWidgets('read-only taps open the address right away', (tester) async {
      final launched = recordLaunches();
      final edits = <int>[];
      recognizer(state(editable: false), edits).onTap!();
      await tester.pump();
      expect(launched, [url]);
      expect(edits, isEmpty);
    });

    testWidgets('editing: a tap selects the whole link and opens the link '
        'dialog; a double tap opens the address instead', (tester) async {
      final launched = recordLaunches();
      final edits = <int>[];
      final editor = state(editable: true);
      final tap = recognizer(editor, edits);

      tap.onTap!();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      // 整段链接（“官网首页”），不只是被点的加粗片段。
      expect(
        editor.selection,
        af.Selection.single(path: [0], startOffset: 2, endOffset: 6),
      );
      expect(edits, hasLength(1));
      expect(launched, isEmpty);

      tap.onTap!();
      tap.onTap!();
      await tester.pump(const Duration(milliseconds: 250));
      expect(launched, [url]);
      expect(edits, hasLength(1));
    });
  });

  group('in the editor', () {
    late AppDatabase db;

    setUpAll(() => initializeDateFormatting());
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    /// 手机竖屏大小：上游浮层按“编辑器宽度减 300”摆放，在这里会出界。
    void usePhoneScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    void expectLinkDialogOnScreen(WidgetTester tester, String address) {
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.widgetWithText(TextField, address), findsOneWidget);
      // 对话框的面板（AlertDialog 自身还含四周的外边距）整个在屏幕里。
      final rect = tester.getRect(
        find.descendant(of: dialog, matching: find.byType(Material)).first,
      );
      expect(
        rect.left >= 0 && rect.top >= 0 && rect.right <= 360,
        isTrue,
        reason: 'dialog panel $rect should lie inside the 360×640 screen',
      );
      expect(rect.bottom, lessThanOrEqualTo(640));
      // 上游的链接浮层不再出现。
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == 'LinkMenu'),
        findsNothing,
      );
    }

    testWidgets('tapping a web link opens the app link dialog on screen, '
        'and confirming relinks the whole link', (tester) async {
      usePhoneScreen(tester);
      final launched = recordLaunches();
      final controller = DiaryEditorController.fromContent(
        linkTestDocument([linkTestParagraph(linkedDelta())]),
      );
      await pumpLinkEditor(tester, db, controller);

      // 点在“首页”的第一个字上。
      final paragraph = tester.renderObject<RenderParagraph>(
        find.textContaining('官网首页', findRichText: true),
      );
      final offset = paragraph.text.toPlainText().indexOf('首');
      final glyph = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 1),
          )
          .first
          .toRect();
      await tester.tapAt(paragraph.localToGlobal(glyph.center));
      await settleLinkEditor(tester);

      expectLinkDialogOnScreen(tester, url);
      expect(launched, isEmpty);

      await tester.enterText(find.byType(TextField), 'example.org');
      await tester.tap(find.text('确认'));
      await settleLinkEditor(tester);
      // 两个片段都换成新地址，加粗不变。
      expect(linkTestDelta(controller), linkedDelta('https://example.org'));
      await unmountLinkEditor(tester);
    });

    testWidgets('Ctrl + K on a phone opens the app link dialog too', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final node = FocusNode();
      addTearDown(node.dispose);
      final controller = DiaryEditorController.fromContent(
        linkTestDocument([linkTestParagraph(linkedDelta())]),
      );
      controller.select(af.Selection.single(path: [0], startOffset: 3));
      await pumpLinkEditor(tester, db, controller, focusNode: node);
      await focusLinkEditor(tester, node);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settleLinkEditor(tester);

      expectLinkDialogOnScreen(tester, url);
      // 取消不改动正文。
      await tester.tap(find.text('取消'));
      await settleLinkEditor(tester);
      expect(linkTestDelta(controller), linkedDelta());
      await unmountLinkEditor(tester);
    });
  });
}
