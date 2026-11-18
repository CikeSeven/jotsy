// 按正文 Markdown（`ai_diary_markdown.dart`）修改日记正文：`edit_diary` 与
// `create_diary` 的唯一写法。纯函数：输入块文档与改法，输出新的块文档，
// 不碰数据库；任何问题都在写库之前抛 [AiToolFailure]，不留半截改动。
//
// 改法借鉴编码智能体（pi）的文件编辑：
// - `edits[]`：每段 old_text 都对**改动前**的正文匹配（不是一段改完再找下一
//   段），必须恰好出现一次、互不重叠；先精确匹配，找不到时再宽松匹配一次
//   （弯引号、破折号、各种空格、全角字母与标点按半角比），宽松匹配到的那段
//   里模型没改的字换回原文的写法（不把中文引号悄悄改成英文引号）；把一整行
//   换成空文字时连同换行一起删掉（不留空段落）；
// - `body`：整段替换（新建日记即对空正文整段替换）。
//
// 写回时只重读改到的行：改动落在哪几行（一个块一行，代码块、表格一行占
// 几行），就只把这几行替换后的文字按正文写法重新读成块；其余的块原样保留
// （写法表达不了的属性也不丢）。改到的几行里，与原来一字不差的行仍用原来
// 的块（按行做最长公共子序列对照）；一对一改写的行，同类型时把写法表达
// 不了的块属性（如编号列表的起始号）带过去。标记行（[图片 1] 等）按标记取回
// 原来的块：删掉一行就是删掉，挪动就是挪动；对话里的图片写 `![](P1)`。
// 新写的链接只认网址、邮件、电话与原文里已有的日记链接，其余只留文字。

import 'dart:collection';

import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_table.dart';
import '../../../core/database/diary_blocks/diary_blocks_walk.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/database/diary_blocks/diary_list_style.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/sequence_lcs.dart';
import '../viewmodels/ai_chat_images.dart';
import 'ai_diary_markdown.dart';
import 'ai_template_markdown_parse.dart';
import 'ai_tool.dart';
import 'ai_tool_diary_images.dart';

/// 一处替换：[oldText] 必须在正文 Markdown 里恰好出现一次。
typedef AiDiaryTextEdit = ({String oldText, String newText});

/// 修改的结果。
class AiDiaryEditResult {
  const AiDiaryEditResult({
    required this.document,
    required this.removedMarks,
    required this.photosAdded,
    required this.changes,
    this.droppedLinks = const <String>[],
  });

  /// 新的块文档。
  final Map<String, Object?> document;

  /// 不再出现的媒体标记（删掉的图片、附件等），按原文顺序。
  final List<String> removedMarks;

  /// 新放进正文的对话图片张数。
  final int photosAdded;

  /// 改到的行（确认卡片用）：`- 原来的行` / `+ 新的行`，按顺序。
  final List<String> changes;

  /// 新写的、不被接受而只留了文字的链接地址。
  final List<String> droppedLinks;
}

/// 链接不被接受时给模型的说明。
String aiDroppedLinksNote(Iterable<String> links) =>
    'Links can only point to web pages, mail or phone, or to entries the text '
    'already links to; ${links.join(', ')} '
    '${links.length == 1 ? 'was' : 'were'} left as plain text.';

/// 按 [edits]（或整段 [body]，二者给一个）修改 [document]。标记按 [l10n]
/// （提示词语言，与读给模型的写法相同）识别，`![](P1)` 按 [chatImages] 解析。
AiDiaryEditResult aiEditDiaryMarkdown(
  Map<String, Object?> document, {
  required AppLocalizations l10n,
  required List<AiChatImage> chatImages,
  List<AiDiaryTextEdit>? edits,
  String? body,
}) {
  assert((edits == null) != (body == null), 'give edits or body');
  final source = aiDiaryMarkdown(document, l10n);
  final text = source.text;
  final replacements = body != null
      ? <_Replacement>[_Replacement(0, text.length, _lf(body))]
      : _absorbLineBreaks(source, _locate(text, edits!));
  if (_apply(text, replacements, 0) == text) {
    throw const AiToolFailure(
      'Nothing changed: the new text is the same as the entry already has.',
    );
  }
  final groups = body != null
      ? <_Group>[_Group(0, source.rows.length - 1, replacements)]
      : _groups(source, replacements);

  final reader = _LineReader(source, AiChatPhotoRefs(chatImages), document);
  final items = <({int depth, Map<String, Object?> node})>[];
  final changes = <String>[];
  var next = 0;
  for (final group in groups) {
    for (; next < group.first; next++) {
      items.add(reader.keep(source.rows[next]));
    }
    _rewrite(source, group, reader, items, changes);
    next = group.last + 1;
  }
  for (; next < source.rows.length; next++) {
    items.add(reader.keep(source.rows[next]));
  }
  reader.check();

  final roots = _pruned(aiNestMarkdownBlocks(items));
  final result = roots.isEmpty
      ? diaryBlocksFromPlainText('')
      : <String, Object?>{
          kDiaryBlocksDocumentKey: <String, Object?>{
            kDiaryBlockTypeKey: kDiaryBlockPage,
            kDiaryBlockChildrenKey: roots,
          },
        };
  // 文字变了、块却没变（例如只改了编号列表的序号）：同样算没有改动。
  if (_sameJson(result, document)) {
    throw AiToolFailure(
      reader.droppedLinks.isEmpty
          ? 'Nothing changed: the edits do not change the entry (list numbers, '
                'for example, are counted automatically).'
          : 'Nothing changed. ${aiDroppedLinksNote(reader.droppedLinks)}',
    );
  }
  return AiDiaryEditResult(
    document: result,
    removedMarks: reader.removedMarks(),
    photosAdded: reader.photos.placed,
    changes: changes,
    droppedLinks: reader.droppedLinks.toList(),
  );
}

// ---- 定位（pi 的 edit：对原文匹配、唯一、不重叠） ----

class _Replacement {
  const _Replacement(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;
}

String _lf(String text) => text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

List<_Replacement> _locate(String text, List<AiDiaryTextEdit> edits) {
  if (edits.isEmpty) {
    throw const AiToolFailure('`edits` is empty; give at least one edit.');
  }
  String? folded;
  final found = <(int, _Replacement)>[];
  for (final (index, edit) in edits.indexed) {
    final name = edits.length == 1 ? '`old_text`' : '`edits[$index].old_text`';
    final oldText = _lf(edit.oldText);
    final newText = _lf(edit.newText);
    if (oldText.isEmpty) throw AiToolFailure('$name is empty.');
    var at = _unique(text, oldText, name);
    var replacement = newText;
    if (at == null) {
      folded ??= _fold(text);
      at = _unique(folded, _fold(oldText), name);
      if (at == null) {
        throw AiToolFailure(
          'Could not find $name in the entry. It must match the entry text '
          'exactly as read_diaries shows it (Markdown marks, indentation and '
          'line breaks included); read the entry again if it may have '
          'changed.',
        );
      }
      replacement = _keepOriginalChars(
        text.substring(at, at + oldText.length),
        oldText,
        newText,
      );
    }
    found.add((index, _Replacement(at, at + oldText.length, replacement)));
  }
  found.sort((a, b) => a.$2.start.compareTo(b.$2.start));
  for (var i = 1; i < found.length; i++) {
    if (found[i - 1].$2.end > found[i].$2.start) {
      throw AiToolFailure(
        '`edits[${found[i - 1].$1}]` and `edits[${found[i].$1}]` overlap; '
        'merge them into one edit.',
      );
    }
  }
  return [for (final (_, replacement) in found) replacement];
}

/// 整行删掉（新文字为空，替换的恰好是一行或连续几行的全部文字）时连同一个
/// 换行一起删：模型只删掉一行的文字时几乎都是想删掉这一行（例如删一张图片
/// 的标记行），留下空行就多出一个空段落。优先删后面的换行，最后一行删前面
/// 的；会碰到别的替换时不扩展。
List<_Replacement> _absorbLineBreaks(
  AiDiaryMarkdown source,
  List<_Replacement> replacements,
) {
  final rowStarts = source.starts.toSet();
  final rowEnds = <int>{
    for (final (index, row) in source.rows.indexed)
      source.starts[index] + row.text.length,
  };
  final length = source.text.length;
  final result = [...replacements];
  for (var i = 0; i < result.length; i++) {
    final replacement = result[i];
    if (replacement.text.isNotEmpty ||
        !rowStarts.contains(replacement.start) ||
        !rowEnds.contains(replacement.end)) {
      continue;
    }
    final previousEnd = i > 0 ? result[i - 1].end : 0;
    final nextStart = i + 1 < result.length ? result[i + 1].start : length;
    if (replacement.end < length && replacement.end + 1 <= nextStart) {
      result[i] = _Replacement(replacement.start, replacement.end + 1, '');
    } else if (replacement.start > 0 && replacement.start - 1 >= previousEnd) {
      result[i] = _Replacement(replacement.start - 1, replacement.end, '');
    }
  }
  return result;
}

/// [needle] 在 [haystack] 里唯一出现的位置；没有时为 null，多于一次时报错。
int? _unique(String haystack, String needle, String name) {
  final first = haystack.indexOf(needle);
  if (first < 0) return null;
  var count = 1;
  for (
    var at = haystack.indexOf(needle, first + 1);
    at >= 0;
    at = haystack.indexOf(needle, at + 1)
  ) {
    count++;
  }
  if (count > 1) {
    throw AiToolFailure(
      '$name occurs $count times in the entry; include more of the '
      'surrounding text so it matches exactly once.',
    );
  }
  return first;
}

/// 宽松匹配：逐个 UTF-16 单位换成比较用的写法，长度不变（位置与原文一一
/// 对应）。弯引号、各种破折号与减号、各种空格、全角字母数字与标点。
String _fold(String text) =>
    String.fromCharCodes([for (final unit in text.codeUnits) _foldUnit(unit)]);

int _foldUnit(int unit) {
  if (unit >= 0x2018 && unit <= 0x201B) return 0x27;
  if (unit >= 0x201C && unit <= 0x201F) return 0x22;
  if ((unit >= 0x2010 && unit <= 0x2015) || unit == 0x2212) return 0x2D;
  if (unit == 0x00A0 ||
      (unit >= 0x2002 && unit <= 0x200A) ||
      unit == 0x202F ||
      unit == 0x205F ||
      unit == 0x3000) {
    return 0x20;
  }
  if (unit >= 0xFF01 && unit <= 0xFF5E) return unit - 0xFEE0;
  return unit;
}

/// 宽松匹配到的一段：[newText] 里模型没改的字（与它给的 [oldText] 对得上的）
/// 换回原文 [original] 同一位置的写法。
String _keepOriginalChars(String original, String oldText, String newText) {
  final units = newText.codeUnits.toList();
  // 改得太多时只换回开头与结尾里没改的字（省下逐字比对的时间与内存）。
  for (final (i, j) in longestCommonSubsequence(
    oldText.codeUnits,
    newText.codeUnits,
    maxEdits: 800,
  )) {
    units[j] = original.codeUnitAt(i);
  }
  return String.fromCharCodes(units);
}

/// 把 [replacements]（按位置排好、互不重叠，位置相对 [base]）套到 [text] 上。
String _apply(String text, List<_Replacement> replacements, int base) {
  final out = StringBuffer();
  var at = 0;
  for (final replacement in replacements) {
    out
      ..write(text.substring(at, replacement.start - base))
      ..write(replacement.text);
    at = replacement.end - base;
  }
  out.write(text.substring(at));
  return out.toString();
}

// ---- 改到哪几行 ----

/// 一组连续的、被改到的行 `[first, last]` 与落在其中的替换。
class _Group {
  _Group(this.first, this.last, this.replacements);

  final int first;
  int last;
  final List<_Replacement> replacements;
}

/// 每处替换改到的行：起点所在的行到终点所在的行（碰到行尾的换行就连同下
/// 一行，因为两行要并在一起）。行有重叠的合成一组。
List<_Group> _groups(AiDiaryMarkdown source, List<_Replacement> replacements) {
  final rows = source.rows;
  final starts = source.starts;
  final groups = <_Group>[];
  for (final replacement in replacements) {
    var first = 0;
    while (first < rows.length - 1 &&
        starts[first] + rows[first].text.length < replacement.start) {
      first++;
    }
    var last = first;
    while (last < rows.length - 1 && starts[last + 1] <= replacement.end) {
      last++;
    }
    final previous = groups.lastOrNull;
    if (previous != null && first <= previous.last) {
      if (last > previous.last) previous.last = last;
      previous.replacements.add(replacement);
    } else {
      groups.add(_Group(first, last, <_Replacement>[replacement]));
    }
  }
  return groups;
}

/// 重读一组行：替换后的文字按正文写法读成块，与原来逐行对照。
void _rewrite(
  AiDiaryMarkdown source,
  _Group group,
  _LineReader reader,
  List<({int depth, Map<String, Object?> node})> items,
  List<String> changes,
) {
  final from = source.starts[group.first];
  final to = source.starts[group.last] + source.rows[group.last].text.length;
  final region = _apply(
    source.text.substring(from, to),
    group.replacements,
    from,
  );
  final lines = region.split('\n');
  final entries = aiMarkdownBlockEntries(region, line: reader.read);
  final oldRows = source.rows.sublist(group.first, group.last + 1);
  final newTexts = [
    for (final entry in entries)
      lines.sublist(entry.start, entry.end).join('\n'),
  ];
  // 一字不差的行用原来的块；其余一对一（个数相同的一段）带过原来的属性。
  final ids = <String, int>{};
  int id(String text) => ids.putIfAbsent(text, () => ids.length);
  final pairs = longestCommonSubsequence(
    [for (final row in oldRows) id(row.text)],
    [for (final text in newTexts) id(text)],
  );
  var oldAt = 0;
  var newAt = 0;
  void gap(int oldEnd, int newEnd) {
    final oneToOne = oldEnd - oldAt == newEnd - newAt;
    for (var i = oldAt; i < oldEnd; i++) {
      changes.add('- ${_firstLine(oldRows[i].text)}');
    }
    String? previous;
    for (var j = newAt; j < newEnd; j++) {
      final partner = oneToOne ? oldRows[oldAt + j - newAt].node : null;
      items.add(reader.fresh(entries[j], partner));
      final line = '+ ${_firstLine(newTexts[j])}';
      if (line != previous) changes.add(line);
      previous = line;
    }
    oldAt = oldEnd;
    newAt = newEnd;
  }

  for (final (oldIndex, newIndex) in pairs) {
    gap(oldIndex, newIndex);
    items.add(reader.keep(oldRows[oldIndex]));
    oldAt = oldIndex + 1;
    newAt = newIndex + 1;
  }
  gap(oldRows.length, entries.length);
}

String _firstLine(String text) {
  final line = text.split('\n').first.trim();
  final more = text.contains('\n') ? ' …' : '';
  return line.length > 80 ? '${line.substring(0, 80)}…' : '$line$more';
}

// ---- 读行、取回原来的块 ----

/// 一次修改里共用的读法：标记行取回原来的块、对话图片换成图片块、记下
/// 问题与标记的去留。
class _LineReader {
  _LineReader(this.source, this.photos, Map<String, Object?> document)
    : _jotsyLinks = _diaryLinksIn(document) {
    for (final row in source.rows) {
      final mark = row.mark;
      if (mark == null) continue;
      (_rowsByMark[mark] ??= <AiDiaryMarkdownRow>[]).add(row);
    }
  }

  final AiDiaryMarkdown source;
  final AiChatPhotoRefs photos;
  final Set<String> _jotsyLinks;
  final Map<String, List<AiDiaryMarkdownRow>> _rowsByMark =
      <String, List<AiDiaryMarkdownRow>>{};
  final Map<String, int> _handedOut = <String, int>{};

  /// 取回原来的块时给出的新块 → 它的标记（按对象身份）。
  final Map<Map<String, Object?>, String> _reused =
      LinkedHashMap<Map<String, Object?>, String>.identity();

  /// 改完以后每个标记还剩几处。
  final Map<String, int> _kept = <String, int>{};
  final List<String> _problems = <String>[];

  /// 新写的、不被接受而只留了文字的链接地址。
  final Set<String> droppedLinks = <String>{};

  /// `aiMarkdownBlockEntries` 的特殊读法（见 [AiMarkdownLineReader]）。
  List<Map<String, Object?>>? read(String content) {
    final rows = _rowsByMark[content];
    if (rows != null) {
      final index = _handedOut[content] ?? 0;
      _handedOut[content] = index + 1;
      final node = _withoutChildren(
        rows[index < rows.length ? index : rows.length - 1].node,
      );
      _reused[node] = content;
      return <Map<String, Object?>>[node];
    }
    if (source.marks.looksLikeMark(content)) {
      _problems.add(
        '"${content.trim()}" is not in this entry (a mark can only keep, move '
        'or remove what the entry already has; to add a photo the user sent '
        'in this chat, write ![](P1) on its own line)',
      );
      return const <Map<String, Object?>>[];
    }
    final (:rest, :refs) = aiChatPhotoRefsInLine(content);
    if (aiHasOtherImageSyntax(rest)) {
      _problems.add(
        'only photos the user sent in this chat can be added, as ![](P1); '
        'other ![…](…) images are not supported',
      );
      return const <Map<String, Object?>>[];
    }
    if (refs.isEmpty) return null;
    final text = rest.trimRight();
    return <Map<String, Object?>>[
      if (text.trim().isNotEmpty) aiMarkdownLineBlock(text),
      for (final ref in refs) ?photos.imageBlock(ref),
    ];
  }

  /// 原样保留的一行（子块由挂树时重新挂上）。
  ({int depth, Map<String, Object?> node}) keep(AiDiaryMarkdownRow row) {
    final mark = row.mark;
    if (mark != null) _kept[mark] = (_kept[mark] ?? 0) + 1;
    return (depth: row.depth, node: _withoutChildren(row.node));
  }

  /// 重读出来的一行；[partner] 为一对一改写前的块。
  ({int depth, Map<String, Object?> node}) fresh(
    AiMarkdownBlockEntry entry,
    Map<String, Object?>? partner,
  ) {
    final node = entry.node;
    final mark = _reused[node];
    if (mark != null) {
      _kept[mark] = (_kept[mark] ?? 0) + 1;
      return (depth: entry.depth, node: node);
    }
    if (node[kDiaryBlockTypeKey] == kDiaryBlockImage) {
      // 对话图片（photos.imageBlock 给出的新块）。
      return (depth: entry.depth, node: node);
    }
    var cleaned = _cleaned(node);
    if (partner != null) cleaned = _withPartnerData(cleaned, partner);
    return (depth: entry.depth, node: cleaned);
  }

  /// 有问题时整次不写（对话图片的问题一并列出）。
  void check() {
    photos.check();
    if (_problems.isEmpty) return;
    throw AiToolFailure(
      '${_problems.toSet().join('; ')}. Nothing was written.',
    );
  }

  /// 原文里有、改完后少了的标记（按原文顺序，同一标记少几处列几次）。
  List<String> removedMarks() {
    final remaining = Map<String, int>.of(_kept);
    final removed = <String>[];
    for (final row in source.rows) {
      final mark = row.mark;
      if (mark == null) continue;
      final left = remaining[mark] ?? 0;
      if (left > 0) {
        remaining[mark] = left - 1;
      } else {
        removed.add(mark);
      }
    }
    return removed;
  }

  /// 新读出的块：链接只留认得的，提示块图标与底色、列表样式不合规的去掉，
  /// 表格超出上限时记下问题。
  Map<String, Object?> _cleaned(Map<String, Object?> node) {
    final type = node[kDiaryBlockTypeKey];
    if (type == kDiaryBlockTable) {
      final data = diaryBlockData(node);
      final rows = data[kDiaryTableRowsLenKey];
      final cols = data[kDiaryTableColsLenKey];
      if (rows is int &&
          cols is int &&
          (rows > kDiaryTableMaxRows || cols > kDiaryTableMaxCols)) {
        _problems.add(
          'a table can have at most $kDiaryTableMaxCols columns and '
          '$kDiaryTableMaxRows rows',
        );
      }
      return <String, Object?>{
        ...node,
        kDiaryBlockChildrenKey: [
          for (final cell in diaryBlockChildren(node))
            <String, Object?>{
              ...cell,
              kDiaryBlockChildrenKey: [
                for (final paragraph in diaryBlockChildren(cell))
                  _withCleanText(paragraph),
              ],
            },
        ],
      };
    }
    final data = Map<String, Object?>.of(diaryBlockData(node));
    if (type == kDiaryBlockCallout) {
      final icon = data[kDiaryCalloutIconKey];
      if (icon is! String ||
          icon.length > 8 ||
          icon.trim().isEmpty ||
          icon.characters.length != 1) {
        data.remove(kDiaryCalloutIconKey);
      }
      if (!kDiaryCalloutTones.contains(data[kDiaryCalloutToneKey])) {
        data.remove(kDiaryCalloutToneKey);
      }
    }
    if (data.containsKey(kDiaryListStyleKey) &&
        sanitizeDiaryListStyleId(type, data[kDiaryListStyleKey]) == null) {
      data.remove(kDiaryListStyleKey);
    }
    return _withCleanText(<String, Object?>{...node, kDiaryBlockDataKey: data});
  }

  /// 行内链接只留网址、邮件、电话与原文里已有的日记链接，其余只留文字。
  Map<String, Object?> _withCleanText(Map<String, Object?> node) {
    final data = diaryBlockData(node);
    final delta = data[kDiaryBlockDeltaKey];
    if (delta is! List) return node;
    return <String, Object?>{
      ...node,
      kDiaryBlockDataKey: <String, Object?>{
        ...data,
        kDiaryBlockDeltaKey: [
          for (final op in delta)
            if (op is Map) _withAllowedLink(op.cast<String, Object?>()) else op,
        ],
      },
    };
  }

  Map<String, Object?> _withAllowedLink(Map<String, Object?> op) {
    final attributes = op['attributes'];
    if (attributes is! Map) return op;
    final href = attributes[kDiaryInlineHref];
    if (href == null || _allowedHref(href)) return op;
    droppedLinks.add('$href');
    final rest = <String, Object?>{
      for (final entry in attributes.entries)
        if (entry.key != kDiaryInlineHref) '${entry.key}': entry.value,
    };
    return <String, Object?>{
      'insert': op['insert'],
      if (rest.isNotEmpty) 'attributes': rest,
    };
  }

  bool _allowedHref(Object? href) {
    if (href is! String) return false;
    if (DiaryLinkTarget.isLink(href)) return _jotsyLinks.contains(href);
    return const <String>{
      'http',
      'https',
      'mailto',
      'tel',
    }.contains(Uri.tryParse(href)?.scheme.toLowerCase());
  }
}

/// 正文里已有的日记链接地址（新写的链接只认这些）。
Set<String> _diaryLinksIn(Map<String, Object?> document) => <String>{
  for (final (node, _) in walkDiaryBlocks(document))
    for (final op in diaryBlockDelta(node))
      if (op['attributes'] case final Map attributes)
        if (attributes[kDiaryInlineHref] case final String href
            when DiaryLinkTarget.isLink(href))
          href,
};

/// 写法表达得了的块属性：一对一改写时以新读出的为准，其余从原来的块带过去。
const Set<String> _expressedKeys = <String>{
  kDiaryBlockDeltaKey,
  kDiaryBlockLevelKey,
  kDiaryBlockCheckedKey,
  kDiaryBlockAlignKey,
  kDiaryParagraphIndentKey,
  kDiaryBlockLanguageKey,
  kDiaryListStyleKey,
  kDiaryCalloutIconKey,
  kDiaryCalloutToneKey,
  kDiaryToggleCollapsedKey,
  kDiaryTableColsLenKey,
  kDiaryTableRowsLenKey,
  kDiaryTableHeaderRowKey,
  kDiaryTableRowPositionKey,
  kDiaryTableColPositionKey,
};

/// 一对一改写、类型没变时，把写法表达不了的块属性从 [partner] 带过来
/// （表格连同同一位置的格子）。
Map<String, Object?> _withPartnerData(
  Map<String, Object?> node,
  Map<String, Object?> partner,
) {
  final type = node[kDiaryBlockTypeKey];
  if (type != partner[kDiaryBlockTypeKey]) return node;
  var result = node;
  final extra = _extraData(partner);
  if (extra.isNotEmpty) {
    result = <String, Object?>{
      ...result,
      kDiaryBlockDataKey: <String, Object?>{
        ...extra,
        ...diaryBlockData(result),
      },
    };
  }
  if (type == kDiaryBlockTable) {
    final oldGrid = DiaryTableGrid.of(partner);
    if (oldGrid == null) return result;
    result = <String, Object?>{
      ...result,
      kDiaryBlockChildrenKey: [
        for (final cell in diaryBlockChildren(result))
          () {
            final data = diaryBlockData(cell);
            final row = data[kDiaryTableRowPositionKey];
            final col = data[kDiaryTableColPositionKey];
            if (row is! int ||
                col is! int ||
                row >= oldGrid.rows ||
                col >= oldGrid.cols) {
              return cell;
            }
            final cellExtra = _extraData(oldGrid.cells[row][col]);
            return cellExtra.isEmpty
                ? cell
                : <String, Object?>{
                    ...cell,
                    kDiaryBlockDataKey: <String, Object?>{
                      ...cellExtra,
                      ...data,
                    },
                  };
          }(),
      ],
    };
  }
  return result;
}

Map<String, Object?> _extraData(Map<String, Object?> node) => <String, Object?>{
  for (final entry in diaryBlockData(node).entries)
    if (!_expressedKeys.contains(entry.key)) entry.key: entry.value,
};

/// 两段 JSON 值是否相同（Map 不论键的顺序；空的子块列表与没有子块相同）。
bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    bool emptyChildren(Map map, Object? key) =>
        key == kDiaryBlockChildrenKey &&
        map[key] is List &&
        (map[key] as List).isEmpty;
    final keys = <Object?>{
      for (final key in a.keys)
        if (!emptyChildren(a, key)) key,
      for (final key in b.keys)
        if (!emptyChildren(b, key)) key,
    };
    return keys.every(
      (key) =>
          a.containsKey(key) && b.containsKey(key) && _sameJson(a[key], b[key]),
    );
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameJson(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// 去掉子块的副本（表格的格子留着）；能有子块的类型给一个新的空列表，挂树
/// 时往里挂。
Map<String, Object?> _withoutChildren(Map<String, Object?> node) {
  final type = node[kDiaryBlockTypeKey];
  if (type == kDiaryBlockTable) return <String, Object?>{...node};
  final copy = <String, Object?>{...node}..remove(kDiaryBlockChildrenKey);
  if (kDiaryContainerBlockTypes.contains(type)) {
    copy[kDiaryBlockChildrenKey] = <Map<String, Object?>>[];
  }
  return copy;
}

/// 挂好树后去掉空的子块列表（存储格式里空的子块省略）；表格不动。
List<Map<String, Object?>> _pruned(List<Map<String, Object?>> nodes) => [
  for (final node in nodes)
    if (node[kDiaryBlockTypeKey] == kDiaryBlockTable)
      node
    else if (node[kDiaryBlockChildrenKey] case final List children
        when children.isNotEmpty)
      <String, Object?>{
        ...node,
        kDiaryBlockChildrenKey: _pruned([
          for (final child in children)
            if (child is Map) child.cast<String, Object?>(),
        ]),
      }
    else
      <String, Object?>{...node}..remove(kDiaryBlockChildrenKey),
];
