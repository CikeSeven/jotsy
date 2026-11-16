import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_link_candidate.dart';

import '../../../support/diary_link_editor_harness.dart';

/// Obsidian 式的 `[[`（及中文输入法的 `【【`）开启日记链接会话。
void main() {
  late AppDatabase db;
  late String diaryId;

  setUpAll(() => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createNotebook(name: '旅行手账');
    diaryId = await db.createDiary(
      title: '旅行的第一天',
      contentDocJson: '[{"insert":"出发\\n"}]',
      contentText: '出发',
      metadataJson: '{}',
    );
  });
  tearDown(() => db.close());

  Future<(DiaryEditorController, String)> start(
    WidgetTester tester, {
    String content = '',
    int offset = 0,
    DiaryLinkSource? linkSource = const DiaryLinkSource(),
  }) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final controller = DiaryEditorController.fromContent(
      content,
      linkSource: linkSource,
    );
    controller.select(af.Selection.single(path: [0], startOffset: offset));
    await pumpLinkEditor(tester, db, controller, focusNode: node);
    return (controller, await focusLinkEditor(tester, node));
  }

  Future<void> type(WidgetTester tester, String prefix, String text) =>
      typeIntoLinkEditor(tester, prefix, text);

  testWidgets('[[ right after text searches and inserts an inline link', (
    tester,
  ) async {
    final (controller, prefix) = await start(tester);

    // 字符快捷键只在一次只输入一个字时触发，逐字输入。
    await type(tester, prefix, '想起');
    await type(tester, prefix, '想起[');
    expect(find.text('旅行的第一天'), findsNothing);
    await type(tester, prefix, '想起[[');
    expect(find.text('旅行的第一天'), findsOneWidget);
    expect(find.text('旅行手账'), findsOneWidget);

    await type(tester, prefix, '想起[[第一');
    expect(find.text('旅行手账'), findsNothing);
    await tester.tap(find.text('旅行的第一天'));
    await settleLinkEditor(tester);

    expect(linkTestDelta(controller), [
      {'insert': '想起'},
      {
        'insert': '旅行的第一天',
        'attributes': {'href': 'jotsy://diary/$diaryId'},
      },
    ]);
    expect(controller.selection!.end.offset, '想起旅行的第一天'.length);
    await unmountLinkEditor(tester);
  });

  testWidgets('【【 from a Chinese keyboard works the same, enter picks', (
    tester,
  ) async {
    final (controller, prefix) = await start(tester);

    await type(tester, prefix, '【');
    await type(tester, prefix, '【【');
    await type(tester, prefix, '【【第一');
    expect(find.text('旅行的第一天'), findsOneWidget);
    await type(tester, prefix, '【【第一\n');

    expect(linkTestDelta(controller), [
      {
        'insert': '旅行的第一天',
        'attributes': {'href': 'jotsy://diary/$diaryId'},
      },
    ]);
    expect(controller.document.root.children, hasLength(1));
    await unmountLinkEditor(tester);
  });

  testWidgets('a closing bracket ends the session and keeps the text', (
    tester,
  ) async {
    final (controller, prefix) = await start(tester);

    await type(tester, prefix, '[');
    await type(tester, prefix, '[[');
    await type(tester, prefix, '[[旅行');
    expect(find.text('旅行的第一天'), findsOneWidget);
    await type(tester, prefix, '[[旅行]');
    expect(find.text('旅行的第一天'), findsNothing);

    // 会话已经结束：回车照常换行，不再写入候选。
    await type(tester, prefix, '[[旅行]\n');
    expect(linkTestDelta(controller), [
      {'insert': '[[旅行]'},
    ]);
    expect(controller.document.root.children, hasLength(2));
    await unmountLinkEditor(tester);
  });

  testWidgets('mixed brackets and inline code do not open the menu', (
    tester,
  ) async {
    final (_, prefix) = await start(
      tester,
      content: linkTestDocument([
        linkTestParagraph([
          {
            'insert': 'a[',
            'attributes': {'code': true},
          },
        ]),
      ]),
      offset: 2,
    );

    await type(tester, prefix, '[');
    expect(find.text('旅行的第一天'), findsNothing);
    await type(tester, prefix, '[【');
    expect(find.text('旅行的第一天'), findsNothing);
    await unmountLinkEditor(tester);
  });

  testWidgets('[[ does nothing without a link source (template editor)', (
    tester,
  ) async {
    final (controller, prefix) = await start(tester, linkSource: null);

    await type(tester, prefix, '[');
    await type(tester, prefix, '[[');
    expect(find.text('旅行的第一天'), findsNothing);
    expect(linkTestDelta(controller), [
      {'insert': '[['},
    ]);
    await unmountLinkEditor(tester);
  });
}
