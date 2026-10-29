import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_link_target.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_link_candidate.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_commands.dart';

import '../../../support/diary_link_editor_harness.dart';

Map<String, Object?> _card(DiaryLinkTarget target, String title) => {
  'type': 'link_card',
  'data': diaryLinkCardData(target, title),
};

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
      contentDocJson: '[{"insert":"出发去海边\\n"}]',
      contentText: '出发去海边',
      metadataJson: '{}',
    );
  });
  tearDown(() => db.close());

  test('card commands follow the link source and the notebooks switch', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    List<String> labels({
      void Function(DiaryLinkKind)? onLinkCard,
      bool notebookCards = false,
    }) => [
      for (final command in diaryBlockCommands(
        l10n,
        onLinkCard: onLinkCard,
        notebookCards: notebookCards,
      ))
        command.label,
    ];
    expect(labels(), isNot(contains('日记卡片')));
    expect(labels(onLinkCard: (_) {}), contains('日记卡片'));
    expect(labels(onLinkCard: (_) {}), isNot(contains('日记本卡片')));
    expect(
      labels(onLinkCard: (_) {}, notebookCards: true),
      containsAll(['日记卡片', '日记本卡片']),
    );
  });

  testWidgets('the / card command searches in card mode and inserts a card', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final controller = DiaryEditorController.fromContent(
      '',
      linkSource: const DiaryLinkSource(),
    );
    controller.select(af.Selection.single(path: [0], startOffset: 0));
    await pumpLinkEditor(tester, db, controller, focusNode: node);
    final prefix = await focusLinkEditor(tester, node);

    await typeIntoLinkEditor(tester, prefix, '/');
    await typeIntoLinkEditor(tester, prefix, '/日记卡片');
    await tester.tap(find.text('日记卡片'));
    await settleLinkEditor(tester);
    // 卡片模式只列日记，菜单标题写明在插入卡片。
    expect(find.text('日记卡片'), findsOneWidget);
    expect(find.text('旅行手账'), findsNothing);
    await tester.tap(find.text('旅行的第一天'));
    await settleLinkEditor(tester);

    final children = controller.document.root.children;
    expect(children.map((node) => node.type), ['link_card', 'paragraph']);
    expect(children.first.attributes, {
      'target': 'jotsy://diary/$diaryId',
      'title': '旅行的第一天',
    });
    // `/日记卡片` 与 `@` 都删掉了。
    expect(children.last.delta!.toPlainText(), isEmpty);
    await unmountLinkEditor(tester);
  });

  testWidgets('cards show live content, missing and private targets', (
    tester,
  ) async {
    // 测试体在假异步里，写库放进真实异步。
    final secret = (await tester.runAsync(() async {
      final locked = await db.createNotebook(
        name: '秘密',
        visibility: NotebookVisibility.locked,
      );
      return db.createDiary(
        title: '不能说的事',
        contentDocJson: '[{"insert":"秘密\\n"}]',
        contentText: '秘密',
        metadataJson: '{}',
        notebookIds: [locked],
      );
    }))!;
    final controller = DiaryEditorController.fromContent(
      linkTestDocument([
        _card(DiaryLinkTarget.diary(diaryId), '旧标题'),
        _card(const DiaryLinkTarget.diary('gone'), '早就删了'),
        _card(DiaryLinkTarget.diary(secret), '不能说的事'),
        _card(DiaryLinkTarget.notebook(notebookId), '旅行手账'),
      ]),
      readOnly: true,
    );
    await pumpLinkEditor(tester, db, controller);

    // 显示实时标题与摘要，不用快照。
    expect(find.text('旅行的第一天'), findsOneWidget);
    expect(find.text('出发去海边'), findsOneWidget);
    expect(find.text('旧标题'), findsNothing);
    // 目标不存在：快照 + 说明。
    expect(find.text('早就删了'), findsOneWidget);
    expect(find.text('这篇日记不存在或已删除'), findsOneWidget);
    // 私密日记不露出标题。
    expect(find.text('私密日记'), findsOneWidget);
    expect(find.text('不能说的事'), findsNothing);
    // 日记本：本名与篇数。
    expect(find.text('旅行手账'), findsOneWidget);
    expect(find.text('0 篇'), findsOneWidget);
    await unmountLinkEditor(tester);
  });

  testWidgets('notebook cards are inert while notebooks are off', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      linkTestDocument([_card(DiaryLinkTarget.notebook(notebookId), '旅行手账')]),
      readOnly: true,
    );
    await pumpLinkEditor(
      tester,
      db,
      controller,
      features: AppFeatures.defaults.copyWith(notebooks: false),
    );
    expect(find.text('旅行手账'), findsOneWidget);
    expect(find.text('0 篇'), findsNothing);
    final card = find.ancestor(
      of: find.text('旅行手账'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(card.first).onTap, isNull);
    await unmountLinkEditor(tester);
  });

  testWidgets('editing: the card menu converts to an inline link or deletes', (
    tester,
  ) async {
    final controller = DiaryEditorController.fromContent(
      linkTestDocument([
        _card(DiaryLinkTarget.diary(diaryId), '旧标题'),
        _card(DiaryLinkTarget.notebook(notebookId), '旅行手账'),
        linkTestParagraph([
          {'insert': '末尾'},
        ]),
      ]),
      linkSource: const DiaryLinkSource(),
    );
    await pumpLinkEditor(tester, db, controller);

    await tester.tap(find.text('旅行的第一天'));
    await settleLinkEditor(tester);
    expect(find.text('打开'), findsOneWidget);
    await tester.tap(find.text('转为行内链接'));
    await settleLinkEditor(tester);
    expect(controller.document.nodeAtPath([0])!.type, 'paragraph');
    // 行内链接的文字取卡片的快照。
    expect(linkTestDelta(controller), [
      {
        'insert': '旧标题',
        'attributes': {'href': 'jotsy://diary/$diaryId'},
      },
    ]);

    // 日记本卡片在编辑态不提供“打开”（会回到首页关掉正在写的这篇）。
    await tester.tap(find.text('旅行手账'));
    await settleLinkEditor(tester);
    expect(find.text('打开'), findsNothing);
    await tester.tap(find.text('删除'));
    await settleLinkEditor(tester);
    expect(controller.document.root.children.map((node) => node.type), [
      'paragraph',
      'paragraph',
    ]);
    await unmountLinkEditor(tester);
  });
}
