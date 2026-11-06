import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_link_dialog.dart';

import '../../../support/diary_link_editor_harness.dart';

/// 链接输入会话：折叠光标上确认网址后，接着输入的文字都写成链接，空白
/// 字符结束（`DiaryLinkTyping`）。
void main() {
  const url = 'https://example.com';
  late AppDatabase db;

  setUpAll(() => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// 正文为“看这里”、光标在末尾、正文有焦点；返回控制器与焦点。
  Future<(DiaryEditorController, FocusNode)> start(WidgetTester tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final controller = DiaryEditorController.fromContent(
      linkTestDocument([
        linkTestParagraph([
          {'insert': '看这里'},
        ]),
      ]),
    );
    controller.select(af.Selection.single(path: [0], startOffset: 3));
    await pumpLinkEditor(tester, db, controller, focusNode: node);
    await focusLinkEditor(tester, node);
    return (controller, node);
  }

  /// 在当前选区上打开链接对话框，填入 [address] 并确认；返回正文重新取得
  /// 焦点后输入法里的文字。
  Future<String> confirmLink(
    WidgetTester tester,
    DiaryEditorController controller,
    FocusNode node,
    String address,
  ) async {
    unawaited(
      editDiaryLink(tester.element(find.byType(DiaryEditor)), controller),
    );
    await settleLinkEditor(tester);
    await tester.enterText(find.byType(TextField), address);
    await tester.tap(find.text('确认'));
    await settleLinkEditor(tester);
    return focusLinkEditor(tester, node);
  }

  /// 逐字输入（每个字一次插入，与软键盘打字相同）。
  Future<void> typeEach(WidgetTester tester, String prefix, String text) async {
    for (var i = 1; i <= text.length; i++) {
      await typeIntoLinkEditor(tester, prefix, text.substring(0, i));
    }
  }

  List<Map<String, Object?>> delta(DiaryEditorController controller) =>
      linkTestDelta(controller);

  testWidgets('letters typed after confirming a web link stay linked until '
      'a space', (tester) async {
    final (controller, node) = await start(tester);
    final prefix = await confirmLink(tester, controller, node, 'example.com');
    // 输入法里的文字前面有上游放的占位空格。
    expect(prefix.trim(), '看这里');
    // 还没打字时工具栏「链接」已高亮。
    expect(controller.selectionAttributes['href'], url);

    // 重复的字母也一样（会话终点跟着光标，不靠比对文字）。
    await typeEach(tester, prefix, 'abb d');
    expect(delta(controller), [
      {'insert': '看这里'},
      {
        'insert': 'abb',
        'attributes': {'href': url},
      },
      {'insert': ' d'},
    ]);
    expect(controller.linkTyping.href, isNull);
    expect(controller.selectionAttributes['href'], isNull);
    await unmountLinkEditor(tester);
  });

  testWidgets('composed input (pinyin) is linked once committed', (
    tester,
  ) async {
    final (controller, node) = await start(tester);
    final prefix = await confirmLink(tester, controller, node, url);

    // 组字中的拼音先上屏，确认候选时整段替换成汉字。
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '${prefix}ni',
        selection: TextSelection.collapsed(offset: prefix.length + 2),
        composing: TextRange(start: prefix.length, end: prefix.length + 2),
      ),
    );
    await settleLinkEditor(tester);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$prefix你好',
        selection: TextSelection.collapsed(offset: prefix.length + 2),
      ),
    );
    await settleLinkEditor(tester);
    await typeIntoLinkEditor(tester, prefix, '你好 ');

    expect(delta(controller), [
      {'insert': '看这里'},
      {
        'insert': '你好',
        'attributes': {'href': url},
      },
      {'insert': ' '},
    ]);
    await unmountLinkEditor(tester);
  });

  testWidgets('one input with a space links only the part before it', (
    tester,
  ) async {
    final (controller, node) = await start(tester);
    final prefix = await confirmLink(tester, controller, node, url);

    // 语音输入等一次上屏一整句。
    await typeIntoLinkEditor(tester, prefix, 'abc def');
    expect(delta(controller), [
      {'insert': '看这里'},
      {
        'insert': 'abc',
        'attributes': {'href': url},
      },
      {'insert': ' def'},
    ]);
    expect(controller.selection!.end.offset, '看这里abc def'.length);
    expect(controller.linkTyping.href, isNull);
    await unmountLinkEditor(tester);
  });

  testWidgets('backspace keeps the session; undo drops a letter with its '
      'link in one step', (tester) async {
    final (controller, node) = await start(tester);
    final prefix = await confirmLink(tester, controller, node, url);
    await typeEach(tester, prefix, 'ab');
    await typeIntoLinkEditor(tester, prefix, 'a');
    await typeIntoLinkEditor(tester, prefix, 'ac');
    expect(delta(controller), [
      {'insert': '看这里'},
      {
        'insert': 'ac',
        'attributes': {'href': url},
      },
    ]);

    // 补上的链接与这次输入是同一步撤销：撤销后不留下没有链接的字。
    controller.undo();
    await tester.pump();
    expect(delta(controller).map((op) => op['insert']).join(), isNot('看这里ac'));
    for (final op in delta(controller).skip(1)) {
      expect(op['attributes'], {'href': url});
    }
    await unmountLinkEditor(tester);
  });

  testWidgets('moving the caret away ends the session', (tester) async {
    final (controller, node) = await start(tester);
    final prefix = await confirmLink(tester, controller, node, url);
    await typeIntoLinkEditor(tester, prefix, 'a');
    expect(controller.linkTyping.href, url);

    controller.select(af.Selection.single(path: [0], startOffset: 1));
    await tester.pump();
    expect(controller.linkTyping.href, isNull);

    // 回到链接末尾也不再延长链接（与上游“链接后接着打字”一致）。
    controller.select(af.Selection.single(path: [0], startOffset: 4));
    await tester.pump();
    expect(controller.linkTyping.href, isNull);
    await unmountLinkEditor(tester);
  });

  testWidgets('removing the link before typing ends the session', (
    tester,
  ) async {
    final (controller, node) = await start(tester);
    await confirmLink(tester, controller, node, url);

    // 还没打字时再开对话框：显示刚填的网址，可以移除。
    unawaited(
      editDiaryLink(tester.element(find.byType(DiaryEditor)), controller),
    );
    await settleLinkEditor(tester);
    expect(find.widgetWithText(TextField, url), findsOneWidget);
    await tester.tap(find.text('移除链接'));
    await settleLinkEditor(tester);
    final prefix = await focusLinkEditor(tester, node);
    expect(controller.linkTyping.href, isNull);

    await typeIntoLinkEditor(tester, prefix, 'a');
    expect(delta(controller), [
      {'insert': '看这里a'},
    ]);
    await unmountLinkEditor(tester);
  });
}
