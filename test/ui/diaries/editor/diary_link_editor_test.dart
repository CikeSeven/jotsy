import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_link_target.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_link_candidate.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_spans.dart';
import 'package:node_diary/ui/diaries/widgets/diary_link_dialog.dart';

import '../../../support/diary_link_editor_harness.dart';

String _document(List<Map<String, Object?>> delta) =>
    linkTestDocument([linkTestParagraph(delta)]);

void main() {
  late AppDatabase db;
  late String notebookId;
  late String diaryId;

  setUpAll(() => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notebookId = await db.createNotebook(name: '旅行手账');
    diaryId = await db.createDiary(
      title: '旅行的第一天',
      contentDocJson: '[{"insert":"出发\\n"}]',
      contentText: '出发',
      metadataJson: '{}',
    );
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    DiaryEditorController controller, {
    FocusNode? focusNode,
    AppFeatures features = AppFeatures.defaults,
  }) => pumpLinkEditor(
    tester,
    db,
    controller,
    focusNode: focusNode,
    features: features,
  );

  Future<void> type(WidgetTester tester, String prefix, String text) =>
      typeIntoLinkEditor(tester, prefix, text);

  Future<String> focus(
    WidgetTester tester,
    DiaryEditorController controller,
    FocusNode node,
  ) => focusLinkEditor(tester, node);

  List<Map<String, Object?>> delta(DiaryEditorController controller) =>
      linkTestDelta(controller);

  testWidgets('typing @ searches and inserts an inline diary link', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final controller = DiaryEditorController.fromContent(
      '',
      linkSource: const DiaryLinkSource(),
    );
    controller.select(af.Selection.single(path: [0], startOffset: 0));
    await pump(tester, controller, focusNode: node);
    final prefix = await focus(tester, controller, node);

    // 字符快捷键只在一次只输入一个字时触发（同 `/`）。
    await type(tester, prefix, '想起 ');
    await type(tester, prefix, '想起 @');
    expect(find.text('旅行手账'), findsOneWidget);
    expect(find.text('旅行的第一天'), findsOneWidget);
    expect(node.hasFocus, isTrue);

    // 接着输入的文字就是检索词。
    await type(tester, prefix, '想起 @第一');
    expect(find.text('旅行手账'), findsNothing);
    await tester.tap(find.text('旅行的第一天'));
    await settleLinkEditor(tester);

    expect(delta(controller), [
      {'insert': '想起 '},
      {
        'insert': '旅行的第一天',
        'attributes': {'href': 'jotsy://diary/$diaryId'},
      },
    ]);
    expect(controller.selection!.end.offset, '想起 旅行的第一天'.length);
    expect(find.text('旅行手账'), findsNothing);
    await unmountLinkEditor(tester);
  });

  testWidgets('enter picks the highlighted candidate', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final controller = DiaryEditorController.fromContent(
      '',
      linkSource: const DiaryLinkSource(),
    );
    controller.select(af.Selection.single(path: [0], startOffset: 0));
    await pump(tester, controller, focusNode: node);
    final prefix = await focus(tester, controller, node);

    await type(tester, prefix, '@');
    await type(tester, prefix, '@旅行');
    // 日记本排在前面，第一项高亮。
    // 软键盘的回车以插入换行送达，经字符事件处理。
    await type(tester, prefix, '@旅行\n');
    expect(delta(controller), [
      {
        'insert': '旅行手账',
        'attributes': {'href': 'jotsy://notebook/$notebookId'},
      },
    ]);
    expect(controller.document.root.children, hasLength(1));
    await unmountLinkEditor(tester);
  });

  Future<(DiaryEditorController, String)> start(
    WidgetTester tester, {
    DiaryLinkSource? linkSource = const DiaryLinkSource(),
    AppFeatures features = AppFeatures.defaults,
  }) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final controller = DiaryEditorController.fromContent(
      '',
      linkSource: linkSource,
    );
    controller.select(af.Selection.single(path: [0], startOffset: 0));
    await pump(tester, controller, focusNode: node, features: features);
    return (controller, await focus(tester, controller, node));
  }

  testWidgets('@ right after a letter does not open the menu', (tester) async {
    final (_, prefix) = await start(tester);
    // 邮箱这类紧跟文字的 @ 不触发。
    await type(tester, prefix, 'me');
    await type(tester, prefix, 'me@');
    expect(find.text('旅行的第一天'), findsNothing);
    await unmountLinkEditor(tester);
  });

  testWidgets('@ does nothing without a link source (template editor)', (
    tester,
  ) async {
    final (_, prefix) = await start(tester, linkSource: null);
    await type(tester, prefix, '@');
    expect(find.text('旅行的第一天'), findsNothing);
    await unmountLinkEditor(tester);
  });

  testWidgets('@ only lists diaries while notebooks are off', (tester) async {
    final (_, prefix) = await start(
      tester,
      features: AppFeatures.defaults.copyWith(notebooks: false),
    );
    await type(tester, prefix, '@');
    await type(tester, prefix, '@旅行');
    expect(find.text('旅行的第一天'), findsOneWidget);
    expect(find.text('旅行手账'), findsNothing);
    await unmountLinkEditor(tester);
  });

  testWidgets('read-only links open, and a missing diary says so', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      _document([
        {
          'insert': '那一天那一天那一天',
          'attributes': {'href': 'jotsy://diary/gone'},
        },
      ]),
      readOnly: true,
    );
    await pump(tester, controller);
    await tester.tap(find.textContaining('那一天', findRichText: true));
    await settleLinkEditor(tester);
    expect(find.text('这篇日记不存在或已删除'), findsOneWidget);
    // 等提示条自己收起，不留计时器。
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await unmountLinkEditor(tester);
  });

  group('link span', () {
    const target = DiaryLinkTarget.diary('d-1');
    final insert = af.TextInsert(
      '那天',
      attributes: {'href': 'jotsy://diary/d-1'},
    );

    TextSpan span(
      af.EditorState state, {
      required List<DiaryLinkTarget> opened,
      DiaryLinkTarget? link,
      bool notebooks = true,
    }) => diaryLinkTextSpan(
      state.document.nodeAtPath([0])!,
      3,
      insert,
      const TextSpan(
        text: '那天',
        style: TextStyle(color: Color(0xFF0000FF)),
      ),
      link ?? target,
      DiaryLinkSpanOptions(
        state: state,
        onOpen: opened.add,
        notebooksEnabled: notebooks,
        plainColor: const Color(0xFF111111),
      ),
    );

    af.EditorState state({required bool editable}) => af.EditorState(
      document: af.Document.fromJson(
        jsonDecode(
              _document([
                {'insert': '想起 '},
                insert.toJson(),
              ]),
            )
            as Map<String, Object?>,
      ),
    )..editable = editable;

    testWidgets('read-only taps open right away', (tester) async {
      final opened = <DiaryLinkTarget>[];
      final recognizer =
          span(state(editable: false), opened: opened).recognizer
              as TapGestureRecognizer;
      recognizer.onTap!();
      expect(opened, [target]);
    });

    testWidgets('editing: a tap selects the link, a double tap opens', (
      tester,
    ) async {
      final opened = <DiaryLinkTarget>[];
      final editor = state(editable: true);
      final recognizer =
          span(editor, opened: opened).recognizer as TapGestureRecognizer;
      recognizer.onTap!();
      await tester.pump(const Duration(milliseconds: 250));
      expect(opened, isEmpty);
      expect(
        editor.selection,
        af.Selection.single(path: [0], startOffset: 3, endOffset: 5),
      );
      recognizer.onTap!();
      recognizer.onTap!();
      expect(opened, [target]);
    });

    testWidgets('notebook links are plain text while notebooks are off', (
      tester,
    ) async {
      final opened = <DiaryLinkTarget>[];
      final plain = span(
        state(editable: false),
        opened: opened,
        link: const DiaryLinkTarget.notebook('n'),
        notebooks: false,
      );
      expect(plain.recognizer, isNull);
      expect(plain.style!.color, const Color(0xFF111111));
      expect(plain.style!.decoration, TextDecoration.none);
    });
  });

  testWidgets('the link dialog links the selection to a diary', (tester) async {
    final controller = DiaryEditorController.fromContent(
      _document([
        {'insert': '看这里'},
      ]),
      linkSource: const DiaryLinkSource(),
    );
    await pump(tester, controller);
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 3),
    );
    await tester.pump();
    unawaited(
      editDiaryLink(tester.element(find.byType(DiaryEditor)), controller),
    );
    await settleLinkEditor(tester);
    // 三页：网址 / 日记 / 日记本。
    expect(find.text('网址'), findsOneWidget);
    await tester.tap(find.text('日记'));
    await settleLinkEditor(tester);
    await tester.tap(find.text('旅行的第一天'));
    await settleLinkEditor(tester);
    expect(delta(controller), [
      {
        'insert': '看这里',
        'attributes': {'href': 'jotsy://diary/$diaryId'},
      },
    ]);

    // 光标落在链接里：对话框打开在“日记”页，“移除链接”去掉整段链接。
    controller.select(
      af.Selection.collapsed(af.Position(path: [0], offset: 1)),
    );
    await tester.pump();
    unawaited(
      editDiaryLink(tester.element(find.byType(DiaryEditor)), controller),
    );
    await settleLinkEditor(tester);
    expect(find.text('链接到日记'), findsOneWidget);
    await tester.tap(find.text('移除链接'));
    await settleLinkEditor(tester);
    expect(delta(controller), [
      {'insert': '看这里'},
    ]);
    await unmountLinkEditor(tester);
  });

  testWidgets('without a link source the dialog only edits web links', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      _document([
        {'insert': '看这里'},
      ]),
    );
    await pump(tester, controller);
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 3),
    );
    await tester.pump();
    unawaited(
      editDiaryLink(tester.element(find.byType(DiaryEditor)), controller),
    );
    await settleLinkEditor(tester);
    expect(find.text('网址'), findsNothing);
    expect(find.text('链接地址'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await settleLinkEditor(tester);
    await unmountLinkEditor(tester);
  });
}
