import 'package:meta/meta.dart';

import 'mind_map_document.dart';
import 'mind_map_schema.dart';

/// 导图主题文字的局部样式（纯 Dart）：节点 `delta` 的解析、校验、编码与
/// 改写。
///
/// 输入为节点（`text` + `delta` 原文）或一串 [MindMapTextRun]，输出为新的
/// run 列表或可存储的 delta；全部是纯函数，不改动输入。口径：
/// - `text` 是唯一的权威文字，delta 只是附在上面的样式：各段 insert 拼起来
///   等于 `text` 才算数（[mindMapDeltaMatches]），对不上一律按没有样式读，
///   旧版本改了文字后不会显示错位的样式；
/// - 属性名与节点 `style` 同一套。`bold` / `italic` / `underline` / `strike`
///   为三态：缺省随整条样式，true / false 是在整条样式之上局部打开 / 取消；
///   `color` / `highlight` 存种子色 `#AARRGGBB`，显示时由界面层按明暗换算；
///   认不出的属性原样跟着文字走、原样写回；
/// - 编码时合并相邻同样式的段、丢掉空段；一个样式都没有时不写 delta。
///
/// 改字（打字、粘贴、大纲里编辑、外部改写）一律经 [remapRunsAfterEdit]
/// 按公共前缀 / 后缀把样式挪到新文字上；设样式经 [formatRuns] /
/// [toggleMark]。

/// 可开关的四种文字样式。
enum MindMapMark {
  bold(kMindMapStyleBoldKey),
  italic(kMindMapStyleItalicKey),
  underline(kMindMapStyleUnderlineKey),
  strike(kMindMapStyleStrikeKey);

  const MindMapMark(this.key);

  /// 在 `style` 与 delta 属性里的键名。
  final String key;
}

/// 带颜色的两种文字样式。
enum MindMapColorMark {
  color(kMindMapStyleColorKey),
  highlight(kMindMapStyleHighlightKey);

  const MindMapColorMark(this.key);

  final String key;
}

/// 一段文字的局部样式。值相等（[==]），可直接比较、作缓存键。
@immutable
final class MindMapTextMarks {
  const MindMapTextMarks({
    this.bold,
    this.italic,
    this.underline,
    this.strike,
    this.color,
    this.highlight,
    this.extra = const <String, Object?>{},
  });

  /// 从 delta 的 `attributes` 读取：类型不对的属性按没设处理，认不出的键
  /// 留在 [extra]。
  factory MindMapTextMarks.fromJson(Object? raw) {
    if (raw is! Map) return none;
    bool? flag(String key) => raw[key] is bool ? raw[key] as bool : null;
    String? color(String key) {
      final value = raw[key];
      return value is String && _isColor(value) ? value : null;
    }

    final extra = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String && !_knownKeys.contains(entry.key))
          entry.key as String: entry.value,
    };
    return MindMapTextMarks(
      bold: flag(kMindMapStyleBoldKey),
      italic: flag(kMindMapStyleItalicKey),
      underline: flag(kMindMapStyleUnderlineKey),
      strike: flag(kMindMapStyleStrikeKey),
      color: color(kMindMapStyleColorKey),
      highlight: color(kMindMapStyleHighlightKey),
      extra: extra.isEmpty ? const <String, Object?>{} : extra,
    );
  }

  static const MindMapTextMarks none = MindMapTextMarks();

  static const Set<String> _knownKeys = <String>{
    kMindMapStyleBoldKey,
    kMindMapStyleItalicKey,
    kMindMapStyleUnderlineKey,
    kMindMapStyleStrikeKey,
    kMindMapStyleColorKey,
    kMindMapStyleHighlightKey,
  };

  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strike;

  /// 文字颜色（种子色原文）。
  final String? color;

  /// 高亮底色（种子色原文）。
  final String? highlight;

  /// 认不出的属性，原样写回。
  final Map<String, Object?> extra;

  bool get isEmpty =>
      bold == null &&
      italic == null &&
      underline == null &&
      strike == null &&
      color == null &&
      highlight == null &&
      extra.isEmpty;

  bool? flag(MindMapMark mark) => switch (mark) {
    MindMapMark.bold => bold,
    MindMapMark.italic => italic,
    MindMapMark.underline => underline,
    MindMapMark.strike => strike,
  };

  String? colorOf(MindMapColorMark mark) => switch (mark) {
    MindMapColorMark.color => color,
    MindMapColorMark.highlight => highlight,
  };

  /// 把 [mark] 设为 [value]（null 为随整条样式）。
  MindMapTextMarks withFlag(MindMapMark mark, bool? value) => MindMapTextMarks(
    bold: mark == MindMapMark.bold ? value : bold,
    italic: mark == MindMapMark.italic ? value : italic,
    underline: mark == MindMapMark.underline ? value : underline,
    strike: mark == MindMapMark.strike ? value : strike,
    color: color,
    highlight: highlight,
    extra: extra,
  );

  /// 把 [mark] 设为 [value]（`#AARRGGBB`；null 为随整条样式）。
  MindMapTextMarks withColor(MindMapColorMark mark, String? value) =>
      MindMapTextMarks(
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
        color: mark == MindMapColorMark.color ? value : color,
        highlight: mark == MindMapColorMark.highlight ? value : highlight,
        extra: extra,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    ...extra,
    kMindMapStyleBoldKey: ?bold,
    kMindMapStyleItalicKey: ?italic,
    kMindMapStyleUnderlineKey: ?underline,
    kMindMapStyleStrikeKey: ?strike,
    kMindMapStyleColorKey: ?color,
    kMindMapStyleHighlightKey: ?highlight,
  };

  @override
  bool operator ==(Object other) =>
      other is MindMapTextMarks &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.color == color &&
      other.highlight == highlight &&
      _shallowMapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    underline,
    strike,
    color,
    highlight,
    extra.isEmpty ? 0 : Object.hashAllUnordered(extra.keys),
  );

  static bool _isColor(String value) {
    final hex = value.startsWith('#') ? value.substring(1) : value;
    return (hex.length == 8 || hex.length == 6) &&
        int.tryParse(hex, radix: 16) != null;
  }
}

/// 一段同样式的文字。
@immutable
final class MindMapTextRun {
  const MindMapTextRun(this.text, [this.marks = MindMapTextMarks.none]);

  final String text;
  final MindMapTextMarks marks;

  @override
  bool operator ==(Object other) =>
      other is MindMapTextRun && other.text == text && other.marks == marks;

  @override
  int get hashCode => Object.hash(text, marks);

  @override
  String toString() => 'MindMapTextRun($text, ${marks.toJson()})';
}

/// [delta] 的各段 insert 拼起来是否正好是 [text]，且至少有一段带样式（没有
/// 样式的 delta 没必要存）。
bool mindMapDeltaMatches(List<Map<String, Object?>> delta, String text) {
  final buffer = StringBuffer();
  var styled = false;
  for (final op in delta) {
    final insert = op['insert'];
    if (insert is! String) return false;
    buffer.write(insert);
    final attributes = op['attributes'];
    if (attributes is Map && attributes.isNotEmpty) styled = true;
  }
  return styled && buffer.toString() == text;
}

/// 节点文字按样式分好的段；没有（或对不上的）delta 时整段一个无样式的 run，
/// 空文字为空列表。
List<MindMapTextRun> mindMapRunsOf(MindMapNode node) {
  final delta = node.delta;
  if (delta == null || !mindMapDeltaMatches(delta, node.text)) {
    return node.text.isEmpty
        ? const <MindMapTextRun>[]
        : <MindMapTextRun>[MindMapTextRun(node.text)];
  }
  return normalizeMindMapRuns(<MindMapTextRun>[
    for (final op in delta)
      MindMapTextRun(
        op['insert']! as String,
        MindMapTextMarks.fromJson(op['attributes']),
      ),
  ]);
}

/// 节点文字有没有局部样式。
bool mindMapHasRichText(MindMapNode node) =>
    node.delta != null && mindMapDeltaMatches(node.delta!, node.text);

/// 编码成可存储的 delta；一个样式都没有时为 null。
List<Map<String, Object?>>? encodeMindMapDelta(List<MindMapTextRun> runs) {
  final normalized = normalizeMindMapRuns(runs);
  if (normalized.every((run) => run.marks.isEmpty)) return null;
  return List<Map<String, Object?>>.unmodifiable(<Map<String, Object?>>[
    for (final run in normalized)
      <String, Object?>{
        'insert': run.text,
        if (!run.marks.isEmpty) 'attributes': run.marks.toJson(),
      },
  ]);
}

/// 各段文字拼起来。
String mindMapRunsText(List<MindMapTextRun> runs) =>
    runs.length == 1 ? runs.first.text : runs.map((run) => run.text).join();

/// 丢掉空段、合并相邻同样式的段。
List<MindMapTextRun> normalizeMindMapRuns(List<MindMapTextRun> runs) {
  final out = <MindMapTextRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) continue;
    if (out.isNotEmpty && out.last.marks == run.marks) {
      out[out.length - 1] = MindMapTextRun(out.last.text + run.text, run.marks);
    } else {
      out.add(run);
    }
  }
  return out;
}

/// [start, end) 范围内的段（按需切开首尾两段）。
List<MindMapTextRun> sliceMindMapRuns(
  List<MindMapTextRun> runs,
  int start,
  int end,
) {
  final out = <MindMapTextRun>[];
  var offset = 0;
  for (final run in runs) {
    final runStart = offset;
    final runEnd = offset + run.text.length;
    offset = runEnd;
    if (runEnd <= start || runStart >= end) continue;
    final from = start > runStart ? start - runStart : 0;
    final to = end < runEnd ? end - runStart : run.text.length;
    out.add(MindMapTextRun(run.text.substring(from, to), run.marks));
  }
  return out;
}

/// 第 [offset] 个字（UTF-16 下标）的样式；越界为无样式。
MindMapTextMarks mindMapMarksAt(List<MindMapTextRun> runs, int offset) {
  if (offset < 0) return MindMapTextMarks.none;
  var start = 0;
  for (final run in runs) {
    final end = start + run.text.length;
    if (offset < end) return run.marks;
    start = end;
  }
  return MindMapTextMarks.none;
}

/// 在 [offset] 处打字时新字的样式：继承前一个字，开头时继承后一个字。
MindMapTextMarks mindMapMarksForInsertion(
  List<MindMapTextRun> runs,
  int offset,
) {
  if (runs.isEmpty) return MindMapTextMarks.none;
  return offset > 0
      ? mindMapMarksAt(runs, offset - 1)
      : mindMapMarksAt(runs, 0);
}

/// 文字从 [runs] 改成 [newText] 后的样式：按公共前缀 / 后缀找出改动的那段，
/// 两侧没动的字保留原样式，新插入的字取 [pending]（设了“接下来打的字”的
/// 样式时），否则取被替换的第一个字的样式，纯插入时继承前一个字（开头时
/// 继承后一个字）。代理对不会被切开。
List<MindMapTextRun> remapRunsAfterEdit(
  List<MindMapTextRun> runs,
  String newText, {
  MindMapTextMarks? pending,
}) {
  final oldText = mindMapRunsText(runs);
  if (oldText == newText) return runs;
  final oldLength = oldText.length;
  final newLength = newText.length;
  var prefix = 0;
  final limit = oldLength < newLength ? oldLength : newLength;
  while (prefix < limit &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix++;
  }
  // 停在代理对中间时退回一格，整对字一起算作改动。
  if (prefix > 0 && _isHighSurrogate(oldText.codeUnitAt(prefix - 1))) {
    prefix--;
  }
  var suffix = 0;
  while (suffix < limit - prefix &&
      oldText.codeUnitAt(oldLength - 1 - suffix) ==
          newText.codeUnitAt(newLength - 1 - suffix)) {
    suffix++;
  }
  if (suffix > 0 && _isLowSurrogate(oldText.codeUnitAt(oldLength - suffix))) {
    suffix--;
  }
  final removedEnd = oldLength - suffix;
  final inserted = newText.substring(prefix, newLength - suffix);
  final MindMapTextMarks marks;
  if (pending != null) {
    marks = pending;
  } else if (removedEnd > prefix) {
    marks = mindMapMarksAt(runs, prefix);
  } else {
    marks = mindMapMarksForInsertion(runs, prefix);
  }
  return normalizeMindMapRuns(<MindMapTextRun>[
    ...sliceMindMapRuns(runs, 0, prefix),
    MindMapTextRun(inserted, marks),
    ...sliceMindMapRuns(runs, removedEnd, oldLength),
  ]);
}

/// 用 [update] 改 [start, end) 内每一段的样式。
List<MindMapTextRun> formatRuns(
  List<MindMapTextRun> runs,
  int start,
  int end,
  MindMapTextMarks Function(MindMapTextMarks marks) update,
) {
  final length = mindMapRunsText(runs).length;
  final from = start.clamp(0, length);
  final to = end.clamp(from, length);
  if (from == to) return runs;
  return normalizeMindMapRuns(<MindMapTextRun>[
    ...sliceMindMapRuns(runs, 0, from),
    for (final run in sliceMindMapRuns(runs, from, to))
      MindMapTextRun(run.text, update(run.marks)),
    ...sliceMindMapRuns(runs, to, length),
  ]);
}

/// [start, end) 内每个字的 [mark] 实际是否都开着（没设的随 [base]，即整条
/// 主题的取值）。空范围为 false。
bool mindMapMarkActive(
  List<MindMapTextRun> runs,
  int start,
  int end,
  MindMapMark mark, {
  required bool base,
}) {
  if (start >= end) return false;
  final slice = sliceMindMapRuns(runs, start, end);
  return slice.isNotEmpty && slice.every((run) => run.marks.flag(mark) ?? base);
}

/// 一个样式按“开关”改写后的取值：等于整条取值 [base] 时去掉（随整条），
/// 不留冗余。
bool? mindMapFlagFor(bool on, {required bool base}) => on == base ? null : on;

/// 切换 [start, end) 的 [mark]：范围里每个字实际都开着就关掉，否则打开。
List<MindMapTextRun> toggleMark(
  List<MindMapTextRun> runs,
  int start,
  int end,
  MindMapMark mark, {
  required bool base,
}) {
  final on = !mindMapMarkActive(runs, start, end, mark, base: base);
  final value = mindMapFlagFor(on, base: base);
  return formatRuns(runs, start, end, (marks) => marks.withFlag(mark, value));
}

/// [start, end) 内各字共同的 [mark] 颜色；不一致或都没设时为 null。
String? mindMapCommonColor(
  List<MindMapTextRun> runs,
  int start,
  int end,
  MindMapColorMark mark,
) {
  final slice = sliceMindMapRuns(runs, start, end);
  if (slice.isEmpty) return null;
  final first = slice.first.marks.colorOf(mark);
  return slice.every((run) => run.marks.colorOf(mark) == first) ? first : null;
}

/// 去掉所有段上的 [key] 属性（整条主题改了同一项时用：整条设置就是整条
/// 生效）。[key] 为 [MindMapMark.key] 或 [MindMapColorMark.key]。
List<MindMapTextRun> clearMindMapMark(
  List<MindMapTextRun> runs,
  String key,
) => normalizeMindMapRuns(<MindMapTextRun>[
  for (final run in runs)
    MindMapTextRun(run.text, switch (key) {
      kMindMapStyleBoldKey => run.marks.withFlag(MindMapMark.bold, null),
      kMindMapStyleItalicKey => run.marks.withFlag(MindMapMark.italic, null),
      kMindMapStyleUnderlineKey => run.marks.withFlag(
        MindMapMark.underline,
        null,
      ),
      kMindMapStyleStrikeKey => run.marks.withFlag(MindMapMark.strike, null),
      kMindMapStyleColorKey => run.marks.withColor(
        MindMapColorMark.color,
        null,
      ),
      kMindMapStyleHighlightKey => run.marks.withColor(
        MindMapColorMark.highlight,
        null,
      ),
      _ => run.marks,
    }),
]);

/// 压成一行：与 `mindMapOutlineLines` 同一口径（换行连同两侧空白压成一个
/// 空格，再去掉首尾空白），样式跟着字走，压出来的空格取换行前那个字的样式。
List<MindMapTextRun> oneLineMindMapRuns(List<MindMapTextRun> runs) {
  final text = mindMapRunsText(runs);
  final pieces = <MindMapTextRun>[];
  var cursor = 0;
  for (final match in RegExp(r'\s*\n\s*').allMatches(text)) {
    pieces.addAll(sliceMindMapRuns(runs, cursor, match.start));
    pieces.add(
      MindMapTextRun(' ', mindMapMarksForInsertion(runs, match.start)),
    );
    cursor = match.end;
  }
  pieces.addAll(sliceMindMapRuns(runs, cursor, text.length));
  final joined = normalizeMindMapRuns(pieces);
  final flat = mindMapRunsText(joined);
  final leading = flat.length - flat.trimLeft().length;
  final trailing = flat.length - flat.trimRight().length;
  if (leading + trailing >= flat.length) return const <MindMapTextRun>[];
  return sliceMindMapRuns(joined, leading, flat.length - trailing);
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

bool _shallowMapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}
