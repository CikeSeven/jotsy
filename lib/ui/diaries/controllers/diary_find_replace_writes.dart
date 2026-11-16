import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../models/diary_find_query.dart';

/// 查找替换写进正文的事务（会话与时机见 `DiaryFindReplace`）：只往
/// [af.Transaction] 里加改动，应用、撤销口径与之后的重新查找由会话负责。
///
/// 格式：替换文字沿用被换掉的第一个字的行内格式（粗体、颜色、链接……），
/// 零宽匹配（插入）沿用前一个字的——与在那里直接打字一致。上游
/// `replaceText` 不给格式时取的是替换位置前一个字的格式，替换一段粗体
/// 开头的文字会丢掉粗体，所以这里总是明确给出。

/// 把 [match] 换成 [value]。零宽匹配换成空串什么也不改。
void addDiaryFindReplacement(
  af.Transaction transaction,
  DiaryFindMatch match,
  String value,
) {
  final delta = match.node.delta;
  if (delta == null || (match.isEmpty && value.isEmpty)) return;
  final Map<String, dynamic>? attributes;
  if (match.isEmpty) {
    attributes = delta.sliceAttributes(match.start);
  } else {
    final first = delta.slice(match.start, match.start + 1);
    attributes = first.isEmpty ? null : first.first.attributes;
  }
  transaction.replaceText(
    match.node,
    match.start,
    match.length,
    value,
    attributes: {...?attributes},
  );
}

/// 把 [matches]（按阅读顺序，同一块的相邻）全部换掉，替换文字由
/// [valueFor] 给出；整批在同一个事务里，应用后是一步撤销。
///
/// 同一块里的多处从后往前换：上游把同一块的多次改动按加入的先后依次合成，
/// 每次的偏移都以前面那次换过之后的文字为准；从后往前换时前面的位置不受
/// 已换部分影响，查找时记下的偏移可以直接用。
void addDiaryFindReplacements(
  af.Transaction transaction,
  List<DiaryFindMatch> matches,
  String Function(DiaryFindMatch match) valueFor,
) {
  for (var end = matches.length; end > 0;) {
    final node = matches[end - 1].node;
    var start = end - 1;
    while (start > 0 && identical(matches[start - 1].node, node)) {
      start--;
    }
    for (var i = end - 1; i >= start; i--) {
      addDiaryFindReplacement(transaction, matches[i], valueFor(matches[i]));
    }
    end = start;
  }
}
