import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import 'diary_editor_controller.dart';
import 'diary_editor_insert.dart';

/// 日记链接在正文里的写入：行内链接（`href` 为内部地址）与卡片块
/// （[kDiaryBlockLinkCard]）。每个函数一次事务、一步撤销；只读正文不改。

/// 在 [at] 处写入带日记链接的 [label]，光标停在它后面。
///
/// 链接后接着打字不会延长链接：上游只把 `supportSliced` 里的行内属性带给
/// 新字，`href` 不在其中。
void insertDiaryInlineLink(
  DiaryEditorController controller,
  af.Position at,
  DiaryLinkTarget target,
  String label,
) {
  if (controller.readOnly || controller.isDisposed) return;
  final node = controller.document.nodeAtPath(at.path);
  final delta = node?.delta;
  final text = _singleLine(label);
  if (node == null || delta == null || text.isEmpty) return;
  final offset = at.offset.clamp(0, delta.length);
  final transaction = controller.state.transaction
    ..insertText(
      node,
      offset,
      text,
      attributes: {kDiaryInlineHref: target.toHref()},
    )
    ..afterSelection = af.Selection.collapsed(
      af.Position(path: node.path, offset: offset + text.length),
    );
  controller.apply(transaction);
}

/// 在光标处插入日记链接卡片（[insertDiaryEditorNodes] 的口径：光标所在的
/// 空段落被卡片取代，否则插在后面；格子里插到表格后面），光标落到卡片后
/// 的段落。[title] 为标题快照。
void insertDiaryLinkCard(
  DiaryEditorController controller,
  DiaryLinkTarget target,
  String title,
) {
  insertDiaryEditorNodes(
    controller: controller,
    nodes: [
      af.Node(
        type: kDiaryBlockLinkCard,
        attributes: diaryLinkCardData(target, title),
      ),
    ],
  );
}

/// 链接对话框选定日记链接后写入：恢复打开对话框前的 [selection]；选中了
/// 文字时给它加链接，折叠时在光标处写入 [label]。
void applyDiaryLinkToSelection(
  DiaryEditorController controller,
  af.Selection selection,
  DiaryLinkTarget target,
  String label,
) {
  if (controller.readOnly || controller.isDisposed) return;
  controller.select(selection);
  if (selection.isCollapsed) {
    insertDiaryInlineLink(controller, selection.end, target, label);
  } else {
    controller.format(kDiaryInlineHref, target.toHref());
  }
}

/// 把卡片换成一段只有链接文字的段落（文字取标题快照，没有时用 [fallback]）。
void convertDiaryLinkCardToInline(
  DiaryEditorController controller,
  af.Node card, {
  required String fallback,
}) {
  if (controller.readOnly || controller.isDisposed) return;
  final target = diaryLinkCardTarget(card.attributes);
  if (target == null || card.parent == null) return;
  final text = diaryLinkCardTitle(card.attributes) ?? _singleLine(fallback);
  if (text.isEmpty) return;
  final paragraph = af.paragraphNode(
    delta: af.Delta()
      ..insert(text, attributes: {kDiaryInlineHref: target.toHref()}),
  );
  final path = card.path;
  // 先插后删（同 insertDiaryEditorNodes）：原卡片的删除路径随插入后移。
  final transaction = controller.state.transaction
    ..insertNode(path, paragraph)
    ..deleteNode(card)
    ..afterSelection = af.Selection.collapsed(
      af.Position(path: path, offset: text.length),
    );
  controller.apply(transaction);
}

/// 删除卡片，光标落到前一个文字块末尾或后一个文字块开头（都不是文字块时
/// 不设选区）。
void deleteDiaryLinkCard(DiaryEditorController controller, af.Node card) {
  if (controller.readOnly || controller.isDisposed || card.parent == null) {
    return;
  }
  final previous = card.previous;
  final next = card.next;
  final transaction = controller.state.transaction..deleteNode(card);
  if (previous?.delta case final delta?) {
    transaction.afterSelection = af.Selection.collapsed(
      af.Position(path: previous!.path, offset: delta.length),
    );
  } else if (next?.delta != null) {
    // 删掉卡片后，后一块挪到卡片原来的路径。
    transaction.afterSelection = af.Selection.collapsed(
      af.Position(path: card.path),
    );
  }
  controller.apply(transaction);
}

/// 选区所在的日记链接：选中文字全在同一个日记链接里，或折叠光标在一段
/// 日记链接里或紧挨着它（见 [diaryLinkRangeAtCaret]）。不是日记链接时为 null。
DiaryLinkTarget? diaryLinkTargetAtSelection(DiaryEditorController controller) {
  final selection = controller.selection?.normalized;
  if (selection == null) return null;
  if (!selection.isCollapsed) {
    return DiaryLinkTarget.tryParse(
      controller.selectionAttributes[kDiaryInlineHref],
    );
  }
  return DiaryLinkTarget.tryParse(diaryLinkRangeAtCaret(controller)?.href);
}

/// 折叠光标所在或紧挨着的那段链接（同一个 `href` 的连续文字，网址与日记
/// 链接都算）：返回整段的选区与地址；光标不挨着链接时为 null。前后各有
/// 一段时取光标前面那段（刚打完的链接）。
///
/// 为什么不看 `selectionAttributes`：折叠光标前一个字带 `supportSliced` 以外
/// 的属性（`href` 就是）时，上游整组不返回。
({af.Selection range, String href})? diaryLinkRangeAtCaret(
  DiaryEditorController controller,
) {
  final selection = controller.selection?.normalized;
  if (selection == null || !selection.isCollapsed) return null;
  final path = selection.end.path;
  final delta = controller.document.nodeAtPath(path)?.delta;
  if (delta == null) return null;
  final offset = selection.end.offset;
  // 相邻且 href 相同的片段（加粗等其他属性不同）并成一段。
  final runs = <(int, int, String)>[];
  var position = 0;
  for (final op in delta) {
    final length = op.length;
    final href = op.attributes?[kDiaryInlineHref];
    if (href is String && href.isNotEmpty) {
      final last = runs.isEmpty ? null : runs.last;
      if (last != null && last.$2 == position && last.$3 == href) {
        runs[runs.length - 1] = (last.$1, position + length, href);
      } else {
        runs.add((position, position + length, href));
      }
    }
    position += length;
  }
  (int, int, String)? hit;
  for (final run in runs) {
    if (run.$1 < offset && offset <= run.$2) {
      hit = run;
      break;
    }
    if (run.$1 == offset) hit ??= run;
  }
  if (hit == null) return null;
  return (
    range: af.Selection.single(
      path: path,
      startOffset: hit.$1,
      endOffset: hit.$2,
    ),
    href: hit.$3,
  );
}

String _singleLine(String value) =>
    value.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();
