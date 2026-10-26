import '../code_block_codec.dart';
import 'diary_blocks_embed.dart';
import 'diary_blocks_builder.dart';
import 'diary_blocks_schema.dart';

/// 把 Quill Delta（旧版正文、旧备份、导入器与模板的输出）转换为块文档。
///
/// 输入：Delta 的 op 列表（`{"insert": 文字或嵌入, "attributes": {…}}`）。
/// 输出：块文档 JSON（见 diary_blocks_schema.dart），纯 Map，无 IO。
///
/// 转换规则：
/// - Delta 按换行切成行，行级属性挂在换行符上：`header` → heading，`list`
///   → 三种列表（checked / unchecked 为待办），`blockquote` → quote，其余为
///   paragraph；`align` 原样保留。
/// - 连续且语言相同的 `code-block` 行合并为一个代码块，`true` 记为未指定
///   语言（不写 `language`）。
/// - 嵌入独占一个块：同一行里夹着嵌入的文字被拆成前后两个同类型的块（编辑器
///   插入媒体时本就让它独占一行，只有手改数据才会出现这种行）。
/// - `indent` 换算为嵌套：缩进 n 的行挂到前面最近一个缩进 n-1、且能收子块
///   的块下面；找不到时就近挂到更外层，保证不跳级。
/// - 行内属性名换成编辑器的写法（strike → strikethrough、link → href、
///   color / background → font_color / bg_color），其余原样保留。
Map<String, Object?> diaryBlocksFromQuillOps(List<Object?> ops) {
  final lines = _splitLines(ops);
  final builder = DiaryBlocksBuilder();
  void place(Map<String, Object?> node, int indent) =>
      builder.add(node, indent);

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final codeValue = line.attributes['code-block'];
    if (codeValue != null && codeValue != false && !line.hasEmbeds) {
      // 连续、语言相同的代码行合为一块；语言不同的相邻代码行各成一块。
      final language = codeBlockExplicitLanguage(codeValue);
      final delta = <Map<String, Object?>>[];
      var first = true;
      while (i < lines.length) {
        final next = lines[i].attributes['code-block'];
        if (lines[i].hasEmbeds ||
            next == null ||
            next == false ||
            codeBlockExplicitLanguage(next) != language) {
          break;
        }
        if (!first) _appendText(delta, '\n', const {});
        first = false;
        for (final segment in lines[i].segments) {
          final text = segment.text;
          if (text != null) {
            _appendText(delta, text, segment.attributes);
          }
        }
        i++;
      }
      place(<String, Object?>{
        kDiaryBlockTypeKey: kDiaryBlockCode,
        kDiaryBlockDataKey: <String, Object?>{
          kDiaryBlockDeltaKey: delta,
          kDiaryBlockLanguageKey: ?language,
        },
      }, _indentOf(line.attributes));
      continue;
    }

    final indent = _indentOf(line.attributes);
    var pending = <Map<String, Object?>>[];
    var emittedAny = false;
    for (final segment in line.segments) {
      final text = segment.text;
      if (text != null) {
        _appendText(pending, text, segment.attributes);
        continue;
      }
      if (pending.isNotEmpty) {
        place(_textBlock(pending, line.attributes), indent);
        pending = <Map<String, Object?>>[];
      }
      place(
        diaryBlockFromQuillEmbed(
          segment.embed!,
          segment.attributes,
          line.attributes,
        ),
        indent,
      );
      emittedAny = true;
    }
    // 只含嵌入的行不再补一个空文字块；纯文字行与空行照常成块。
    if (pending.isNotEmpty || !emittedAny) {
      place(_textBlock(pending, line.attributes), indent);
    }
    i++;
  }

  return builder.build();
}

/// 一行里的一个片段：文字（[text] 非空）或嵌入（[embed] 非空）。
class _Segment {
  const _Segment.text(String this.text, this.attributes) : embed = null;

  const _Segment.embed(Map<Object?, Object?> this.embed, this.attributes)
    : text = null;

  final String? text;
  final Map<Object?, Object?>? embed;
  final Map<String, Object?> attributes;
}

class _Line {
  _Line();

  final List<_Segment> segments = <_Segment>[];
  bool get hasEmbeds => segments.any((segment) => segment.embed != null);
  Map<String, Object?> attributes = const <String, Object?>{};
}

List<_Line> _splitLines(List<Object?> ops) {
  final lines = <_Line>[];
  var current = _Line();
  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    final rawAttributes = op['attributes'];
    final attributes = rawAttributes is Map
        ? <String, Object?>{
            for (final entry in rawAttributes.entries)
              if (entry.key is String && entry.value != null)
                entry.key as String: entry.value,
          }
        : const <String, Object?>{};
    if (insert is String) {
      final parts = insert.split('\n');
      for (var p = 0; p < parts.length; p++) {
        if (parts[p].isNotEmpty) {
          current.segments.add(_Segment.text(parts[p], attributes));
        }
        if (p < parts.length - 1) {
          // 换行符上的属性就是这一行的行级属性。
          current.attributes = attributes;
          lines.add(current);
          current = _Line();
        }
      }
    } else if (insert is Map && insert.isNotEmpty) {
      current.segments.add(_Segment.embed(insert, attributes));
    }
  }
  // Delta 应以换行结尾；缺了也保留最后一行的内容。
  if (current.segments.isNotEmpty) lines.add(current);
  return lines;
}

int _indentOf(Map<String, Object?> attributes) {
  final indent = attributes['indent'];
  if (indent is num && indent.isFinite && indent > 0) return indent.toInt();
  if (indent is String) return int.tryParse(indent) ?? 0;
  return 0;
}

Map<String, Object?> _textBlock(
  List<Map<String, Object?>> delta,
  Map<String, Object?> lineAttributes,
) {
  final data = <String, Object?>{kDiaryBlockDeltaKey: delta};
  final String type;
  final header = lineAttributes['header'];
  final list = lineAttributes['list'];
  final codeValue = lineAttributes['code-block'];
  // 媒体可能继承所在行的代码格式：先按嵌入拆行，前后的文字仍为代码，
  // 不能进入只合并文字的代码行分支而丢掉媒体。
  if (codeValue != null && codeValue != false) {
    type = kDiaryBlockCode;
    final language = codeBlockExplicitLanguage(codeValue);
    if (language != null) data[kDiaryBlockLanguageKey] = language;
  } else if (header is num && header.isFinite && header >= 1) {
    type = kDiaryBlockHeading;
    data[kDiaryBlockLevelKey] = header.toInt().clamp(1, 6);
  } else if (list == 'bullet') {
    type = kDiaryBlockBulletedList;
  } else if (list == 'ordered') {
    type = kDiaryBlockNumberedList;
  } else if (list == 'checked' || list == 'unchecked') {
    type = kDiaryBlockTodoList;
    data[kDiaryBlockCheckedKey] = list == 'checked';
  } else if (lineAttributes['blockquote'] == true) {
    type = kDiaryBlockQuote;
  } else {
    type = kDiaryBlockParagraph;
  }
  final align = lineAttributes['align'];
  if (align is String && align.isNotEmpty) data[kDiaryBlockAlignKey] = align;
  return <String, Object?>{kDiaryBlockTypeKey: type, kDiaryBlockDataKey: data};
}

/// 追加一段文字，与前一段属性相同时合并，保持 Delta 紧凑。
void _appendText(
  List<Map<String, Object?>> delta,
  String text,
  Map<String, Object?> quillAttributes,
) {
  if (text.isEmpty) return;
  final attributes = <String, Object?>{
    for (final entry in quillAttributes.entries)
      kQuillToDiaryInlineKeys[entry.key] ?? entry.key: entry.value,
  };
  if (delta.isNotEmpty) {
    final last = delta.last;
    final lastAttributes =
        last['attributes'] as Map<String, Object?>? ??
        const <String, Object?>{};
    if (_sameAttributes(lastAttributes, attributes)) {
      last['insert'] = '${last['insert']}$text';
      return;
    }
  }
  delta.add(<String, Object?>{
    'insert': text,
    if (attributes.isNotEmpty) 'attributes': attributes,
  });
}

bool _sameAttributes(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}
