import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_table.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_commands.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_blocks.dart';
import 'package:node_diary/ui/diary_templates/sections/diary_template_editor_content_tab.dart';

import '../../../support/diary_color_panel_harness.dart';
import '../../../support/diary_content_test_helpers.dart';

/// 工具栏「分隔线」：在光标处插入一条分隔线（与 `/` 菜单同一条插入、同一
/// 图标与名称），一步撤销；表格格子里落到表格后面，代码块里在光标处拆开；
/// 已保存过顺序的用户补到末尾。
const String _dividerTool = '分隔线';

/// 加入分隔线之前、已保存过的完整工具栏顺序（当时默认顺序的存储串）。
const String _legacySavedOrder =
    'undo,redo,recording,bold,italic,underline,bullet_list,check_list,'
    'ordered_list,image,video,attachment,current_time,quote,callout,toggle,'
    'header_style,align,font_size,link,text_color,background_color,'
    'clear_format,strike_through,superscript,subscript,indent,inline_code,'
    'code_block,table';

/// 分隔线排在最前，360dp 下常驻在工具栏一排上。
final List<DiaryToolbarItem> _dividerFirstOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.divider,
  for (final item in kDefaultDiaryToolbarOrder)
    if (item != DiaryToolbarItem.divider) item,
];

Map<String, Object?> _block(
  String type,
  String text, {
  Map<String, Object?> data = const {},
}) => {
  'type': type,
  'data': {
    ...data,
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

/// 1 × 2 的表格，格子文字为 `r0c0` / `r0c1`。
Map<String, Object?> _table() => {
  'type': 'table',
  'data': {'rowsLen': 1, 'colsLen': 2},
  'children': [
    for (var col = 0; col < 2; col++)
      {
        'type': 'table/cell',
        'data': {'rowPosition': 0, 'colPosition': col},
        'children': [_block('paragraph', 'r0c$col')],
      },
  ],
};

DiaryEditorController _document(List<Map<String, Object?>> blocks) {
  final controller = DiaryEditorController.fromContent(
    jsonEncode({
      'document': {'type': 'page', 'children': blocks},
    }),
  );
  addTearDown(controller.dispose);
  return controller;
}

List<String> _types(DiaryEditorController controller) => [
  for (final node in controller.document.root.children) node.type,
];

String _text(DiaryEditorController controller, int index) =>
    controller.document.nodeAtPath([index])!.delta!.toPlainText();

Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller,
) async {
  final harness = await pumpColorPanel(
    tester,
    controller: controller,
    order: _dividerFirstOrder,
  );
  harness.editorFocus.requestFocus();
  await tester.pumpAndSettle();
}

Future<void> _caretAt(
  WidgetTester tester,
  DiaryEditorController controller,
  af.Path path,
  int offset,
) async {
  controller.select(
    af.Selection.collapsed(af.Position(path: path, offset: offset)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapDivider(WidgetTester tester) async {
  await tester.tap(find.byTooltip(_dividerTool));
  await tester.pumpAndSettle();
}

void main() {
  test('saved orders from before the divider tool gain it at the end, and '
      'the default order puts it right after the table tool', () {
    final decoded = decodeDiaryToolbarOrder(_legacySavedOrder);
    final legacy = _legacySavedOrder.split(',');
    expect(decoded.map((item) => item.storageKey).take(legacy.length), legacy);
    expect(decoded.last, DiaryToolbarItem.divider);
    expect(decoded, hasLength(DiaryToolbarItem.values.length));
    // 隐藏项只记用户取消过的工具，新工具照常出现。
    expect(
      decodeDiaryToolbarHiddenItems('bold,table'),
      isNot(contains(DiaryToolbarItem.divider)),
    );

    final table = kDefaultDiaryToolbarOrder.indexOf(DiaryToolbarItem.table);
    expect(kDefaultDiaryToolbarOrder[table + 1], DiaryToolbarItem.divider);
    expect(decodeDiaryToolbarOrder(null), contains(DiaryToolbarItem.divider));
    expect(DiaryToolbarItem.divider.storageKey, 'divider');
    expect(
      decodeDiaryToolbarOrder(
        encodeDiaryToolbarOrder(kDefaultDiaryToolbarOrder),
      ),
      kDefaultDiaryToolbarOrder,
    );
  });

  test('the slash menu divider takes its name and icon from the toolbar '
      'tool', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final command = diaryBlockCommands(
      l10n,
    ).singleWhere((command) => command.type == 'divider');
    expect(DiaryToolbarItem.divider.label(l10n), _dividerTool);
    expect(DiaryToolbarItem.divider.iconData, FontAwesomeIcons.minus);
    expect(command.label, DiaryToolbarItem.divider.label(l10n));
    expect(command.icon, DiaryToolbarItem.divider.iconData);
  });

  testWidgets('tapping the tool splits the paragraph at the caret, puts the '
      'caret after the divider and undoes in one step', (tester) async {
    final controller = _document([_block('paragraph', 'beforeafter')]);
    await _pump(tester, controller);
    await _caretAt(tester, controller, [0], 6);
    final before = controller.contentJson;

    await _tapDivider(tester);

    expect(_types(controller), ['paragraph', 'divider', 'paragraph']);
    expect(_text(controller, 0), 'before');
    expect(_text(controller, 2), 'after');
    expect(
      controller.selection,
      af.Selection.collapsed(af.Position(path: [2], offset: 0)),
    );

    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.contentJson, before);
  });

  testWidgets('on an empty paragraph the divider takes its place and a '
      'writable paragraph follows', (tester) async {
    final controller = _document([_block('paragraph', '')]);
    await _pump(tester, controller);
    await _caretAt(tester, controller, [0], 0);

    await _tapDivider(tester);

    expect(_types(controller), ['divider', 'paragraph']);
    expect(controller.selection!.end.path, [1]);
  });

  testWidgets('from a table cell the divider lands after the table; in a '
      'code block it splits the code at the caret like an image does', (
    tester,
  ) async {
    final controller = _document([
      _table(),
      _block('code', 'abcd', data: {'language': 'python'}),
    ]);
    await _pump(tester, controller);

    await _caretAt(tester, controller, [0, 1, 0], 2);
    await _tapDivider(tester);
    expect(_types(controller), ['table', 'divider', 'paragraph', 'code']);
    final grid = DiaryTableGrid.of(
      controller.document.nodeAtPath([0])!.toJson(),
    );
    expect(grid, isNotNull, reason: 'the table must stay intact');
    expect(grid!.rowTexts(), ['r0c0 | r0c1']);
    expect(controller.selection!.end.path, [2]);

    await _caretAt(tester, controller, [3], 2);
    final beforeCode = controller.contentJson;
    await _tapDivider(tester);
    expect(_types(controller), [
      'table',
      'divider',
      'paragraph',
      'code',
      'divider',
      'code',
    ]);
    expect(_text(controller, 3), 'ab');
    expect(_text(controller, 5), 'cd');
    expect(
      controller.document.nodeAtPath([5])!.attributes['language'],
      'python',
    );
    expect(
      controller.selection,
      af.Selection.collapsed(af.Position(path: [5], offset: 0)),
    );
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.contentJson, beforeCode);
  });

  testWidgets('the template editor keeps the tool and its whitelist keeps the '
      'inserted divider', (tester) async {
    expect(
      DiaryTemplateEditorContentTab.excludedToolbarItems,
      isNot(contains(DiaryToolbarItem.divider)),
    );
    final controller = _document([_block('paragraph', 'ab')]);
    await _pump(tester, controller);
    await _caretAt(tester, controller, [0], 2);
    await _tapDivider(tester);

    final sanitized = sanitizeDiaryTemplateBlocks(controller.contentJson);
    expect(
      [
        for (final node in diaryBlockChildren(diaryBlocksRoot(sanitized)!))
          node['type'],
      ],
      ['paragraph', 'divider', 'paragraph'],
    );
  });
}
