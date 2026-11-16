import 'package:meta/meta.dart';

/// 一段纯文字上的局部样式（纯 Dart）：delta 的解析、校验、编码与改写。
/// 导图主题文字（节点 `delta`）与日记留言（`diary_comments.delta`）共用。
///
/// 输入为文字 + delta 原文，或一串 [InlineTextRun]，输出为新的 run 列表或
/// 可存储的 delta；全部是纯函数，不改动输入。口径：
/// - 文字是唯一的权威，delta 只是附在上面的样式：各段 insert 拼起来等于
///   文字才算数（[inlineDeltaMatches]），对不上一律按没有样式读，旧版本
///   改了文字后不会显示错位的样式；
/// - `bold` / `italic` / `underline` / `strike` 为三态：缺省随整条样式
///   （导图主题的整条样式；留言没有整条样式，即都不开），true / false 是
///   在整条样式之上局部打开 / 取消；`color` / `highlight` 按原色存
///   `#AARRGGBB`、按原色显示；`href` 为链接地址（网址或 `jotsy://` 日记
///   链接，校验由使用方负责）；认不出的属性原样跟着文字走、原样写回；
/// - 编码时合并相邻同样式的段、丢掉空段；一个样式都没有时不写 delta。
///
/// 改字（打字、粘贴、外部改写）一律经 [remapRunsAfterEdit] 按公共前缀 /
/// 后缀把样式挪到新文字上；设样式经 [formatRuns] / [toggleMark] /
/// [setRunsLink]，整段替换经 [replaceRunsRange]。

const String kInlineBoldKey = 'bold';
const String kInlineItalicKey = 'italic';
const String kInlineUnderlineKey = 'underline';
const String kInlineStrikeKey = 'strike';
const String kInlineColorKey = 'color';
const String kInlineHighlightKey = 'highlight';
const String kInlineHrefKey = 'href';

/// 可开关的四种文字样式。
enum InlineMark {
  bold(kInlineBoldKey),
  italic(kInlineItalicKey),
  underline(kInlineUnderlineKey),
  strike(kInlineStrikeKey);

  const InlineMark(this.key);

  /// 在 delta 属性里的键名。
  final String key;
}

/// 带颜色的两种文字样式。
enum InlineColorMark {
  color(kInlineColorKey),
  highlight(kInlineHighlightKey);

  const InlineColorMark(this.key);

  final String key;
}

/// 一段文字的局部样式。值相等（[==]），可直接比较、作缓存键。
@immutable
final class InlineTextMarks {
  const InlineTextMarks({
    this.bold,
    this.italic,
    this.underline,
    this.strike,
    this.color,
    this.highlight,
    this.href,
    this.extra = const <String, Object?>{},
  });

  /// 从 delta 的 `attributes` 读取：类型不对的属性按没设处理，认不出的键
  /// 留在 [extra]。
  factory InlineTextMarks.fromJson(Object? raw) {
    if (raw is! Map) return none;
    bool? flag(String key) => raw[key] is bool ? raw[key] as bool : null;
    String? color(String key) {
      final value = raw[key];
      return value is String && _isColor(value) ? value : null;
    }

    final href = raw[kInlineHrefKey];
    final extra = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String && !_knownKeys.contains(entry.key))
          entry.key as String: entry.value,
    };
    return InlineTextMarks(
      bold: flag(kInlineBoldKey),
      italic: flag(kInlineItalicKey),
      underline: flag(kInlineUnderlineKey),
      strike: flag(kInlineStrikeKey),
      color: color(kInlineColorKey),
      highlight: color(kInlineHighlightKey),
      href: href is String && href.trim().isNotEmpty ? href : null,
      extra: extra.isEmpty ? const <String, Object?>{} : extra,
    );
  }

  static const InlineTextMarks none = InlineTextMarks();

  static const Set<String> _knownKeys = <String>{
    kInlineBoldKey,
    kInlineItalicKey,
    kInlineUnderlineKey,
    kInlineStrikeKey,
    kInlineColorKey,
    kInlineHighlightKey,
    kInlineHrefKey,
  };

  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strike;

  /// 文字颜色（`#AARRGGBB` 原文）。
  final String? color;

  /// 高亮底色（`#AARRGGBB` 原文，可带透明度）。
  final String? highlight;

  /// 链接地址（原文）。
  final String? href;

  /// 认不出的属性，原样写回。
  final Map<String, Object?> extra;

  bool get isEmpty =>
      bold == null &&
      italic == null &&
      underline == null &&
      strike == null &&
      color == null &&
      highlight == null &&
      href == null &&
      extra.isEmpty;

  bool? flag(InlineMark mark) => switch (mark) {
    InlineMark.bold => bold,
    InlineMark.italic => italic,
    InlineMark.underline => underline,
    InlineMark.strike => strike,
  };

  String? colorOf(InlineColorMark mark) => switch (mark) {
    InlineColorMark.color => color,
    InlineColorMark.highlight => highlight,
  };

  InlineTextMarks _copy({
    bool? Function()? bold,
    bool? Function()? italic,
    bool? Function()? underline,
    bool? Function()? strike,
    String? Function()? color,
    String? Function()? highlight,
    String? Function()? href,
  }) => InlineTextMarks(
    bold: bold == null ? this.bold : bold(),
    italic: italic == null ? this.italic : italic(),
    underline: underline == null ? this.underline : underline(),
    strike: strike == null ? this.strike : strike(),
    color: color == null ? this.color : color(),
    highlight: highlight == null ? this.highlight : highlight(),
    href: href == null ? this.href : href(),
    extra: extra,
  );

  /// 把 [mark] 设为 [value]（null 为随整条样式）。
  InlineTextMarks withFlag(InlineMark mark, bool? value) => _copy(
    bold: mark == InlineMark.bold ? () => value : null,
    italic: mark == InlineMark.italic ? () => value : null,
    underline: mark == InlineMark.underline ? () => value : null,
    strike: mark == InlineMark.strike ? () => value : null,
  );

  /// 把 [mark] 设为 [value]（`#AARRGGBB`；null 为随整条样式）。
  InlineTextMarks withColor(InlineColorMark mark, String? value) => _copy(
    color: mark == InlineColorMark.color ? () => value : null,
    highlight: mark == InlineColorMark.highlight ? () => value : null,
  );

  /// 把链接设为 [value]（null 为去掉链接）。
  InlineTextMarks withHref(String? value) => _copy(href: () => value);

  Map<String, Object?> toJson() => <String, Object?>{
    ...extra,
    kInlineBoldKey: ?bold,
    kInlineItalicKey: ?italic,
    kInlineUnderlineKey: ?underline,
    kInlineStrikeKey: ?strike,
    kInlineColorKey: ?color,
    kInlineHighlightKey: ?highlight,
    kInlineHrefKey: ?href,
  };

  @override
  bool operator ==(Object other) =>
      other is InlineTextMarks &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.color == color &&
      other.highlight == highlight &&
      other.href == href &&
      _shallowMapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    underline,
    strike,
    color,
    highlight,
    href,
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
final class InlineTextRun {
  const InlineTextRun(this.text, [this.marks = InlineTextMarks.none]);

  final String text;
  final InlineTextMarks marks;

  @override
  bool operator ==(Object other) =>
      other is InlineTextRun && other.text == text && other.marks == marks;

  @override
  int get hashCode => Object.hash(text, marks);

  @override
  String toString() => 'InlineTextRun($text, ${marks.toJson()})';
}

/// [delta] 的各段 insert 拼起来是否正好是 [text]，且至少有一段带样式（没有
/// 样式的 delta 没必要存）。
bool inlineDeltaMatches(List<Map<String, Object?>> delta, String text) {
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

/// [text] 按 [delta] 分好的段；没有（或对不上的）delta 时整段一个无样式的
/// run，空文字为空列表。
List<InlineTextRun> inlineRunsFromDelta(
  List<Map<String, Object?>>? delta,
  String text,
) {
  if (delta == null || !inlineDeltaMatches(delta, text)) {
    return text.isEmpty
        ? const <InlineTextRun>[]
        : <InlineTextRun>[InlineTextRun(text)];
  }
  return normalizeInlineRuns(<InlineTextRun>[
    for (final op in delta)
      InlineTextRun(
        op['insert']! as String,
        InlineTextMarks.fromJson(op['attributes']),
      ),
  ]);
}

/// 编码成可存储的 delta；一个样式都没有时为 null。
List<Map<String, Object?>>? encodeInlineDelta(List<InlineTextRun> runs) {
  final normalized = normalizeInlineRuns(runs);
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
String inlineRunsText(List<InlineTextRun> runs) =>
    runs.length == 1 ? runs.first.text : runs.map((run) => run.text).join();

/// 丢掉空段、合并相邻同样式的段。
List<InlineTextRun> normalizeInlineRuns(List<InlineTextRun> runs) {
  final out = <InlineTextRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) continue;
    if (out.isNotEmpty && out.last.marks == run.marks) {
      out[out.length - 1] = InlineTextRun(out.last.text + run.text, run.marks);
    } else {
      out.add(run);
    }
  }
  return out;
}

/// [start, end) 范围内的段（按需切开首尾两段）。
List<InlineTextRun> sliceInlineRuns(
  List<InlineTextRun> runs,
  int start,
  int end,
) {
  final out = <InlineTextRun>[];
  var offset = 0;
  for (final run in runs) {
    final runStart = offset;
    final runEnd = offset + run.text.length;
    offset = runEnd;
    if (runEnd <= start || runStart >= end) continue;
    final from = start > runStart ? start - runStart : 0;
    final to = end < runEnd ? end - runStart : run.text.length;
    out.add(InlineTextRun(run.text.substring(from, to), run.marks));
  }
  return out;
}

/// 第 [offset] 个字（UTF-16 下标）的样式；越界为无样式。
InlineTextMarks inlineMarksAt(List<InlineTextRun> runs, int offset) {
  if (offset < 0) return InlineTextMarks.none;
  var start = 0;
  for (final run in runs) {
    final end = start + run.text.length;
    if (offset < end) return run.marks;
    start = end;
  }
  return InlineTextMarks.none;
}

/// 在 [offset] 处打字时新字的样式：继承前一个字，开头时继承后一个字。
///
/// 链接只在链接中间打字时延续（前后两个字是同一个地址）：紧挨着链接的
/// 开头或末尾打的字不算进链接，与正文一致（刚写完的日记链接后面接着打字
/// 不会延长链接）。
InlineTextMarks inlineMarksForInsertion(List<InlineTextRun> runs, int offset) {
  if (runs.isEmpty) return InlineTextMarks.none;
  final marks = offset > 0
      ? inlineMarksAt(runs, offset - 1)
      : inlineMarksAt(runs, 0);
  final href = marks.href;
  if (href == null) return marks;
  final inside = offset > 0 && inlineMarksAt(runs, offset).href == href;
  return inside ? marks : marks.withHref(null);
}

/// 文字从 [runs] 改成 [newText] 后的样式：按公共前缀 / 后缀找出改动的那段，
/// 两侧没动的字保留原样式，新插入的字取 [pending]（设了“接下来打的字”的
/// 样式时），否则取被替换的第一个字的样式，纯插入时按
/// [inlineMarksForInsertion]。代理对不会被切开。
List<InlineTextRun> remapRunsAfterEdit(
  List<InlineTextRun> runs,
  String newText, {
  InlineTextMarks? pending,
}) {
  final oldText = inlineRunsText(runs);
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
  final InlineTextMarks marks;
  if (pending != null) {
    marks = pending;
  } else if (removedEnd > prefix) {
    marks = inlineMarksAt(runs, prefix);
  } else {
    marks = inlineMarksForInsertion(runs, prefix);
  }
  return normalizeInlineRuns(<InlineTextRun>[
    ...sliceInlineRuns(runs, 0, prefix),
    InlineTextRun(inserted, marks),
    ...sliceInlineRuns(runs, removedEnd, oldLength),
  ]);
}

/// 把 [start, end) 换成 [text]，新字的样式为 [marks]；两侧的字原样保留。
List<InlineTextRun> replaceRunsRange(
  List<InlineTextRun> runs,
  int start,
  int end,
  String text,
  InlineTextMarks marks,
) {
  final length = inlineRunsText(runs).length;
  final from = start.clamp(0, length);
  final to = end.clamp(from, length);
  return normalizeInlineRuns(<InlineTextRun>[
    ...sliceInlineRuns(runs, 0, from),
    InlineTextRun(text, marks),
    ...sliceInlineRuns(runs, to, length),
  ]);
}

/// 用 [update] 改 [start, end) 内每一段的样式。
List<InlineTextRun> formatRuns(
  List<InlineTextRun> runs,
  int start,
  int end,
  InlineTextMarks Function(InlineTextMarks marks) update,
) {
  final length = inlineRunsText(runs).length;
  final from = start.clamp(0, length);
  final to = end.clamp(from, length);
  if (from == to) return runs;
  return normalizeInlineRuns(<InlineTextRun>[
    ...sliceInlineRuns(runs, 0, from),
    for (final run in sliceInlineRuns(runs, from, to))
      InlineTextRun(run.text, update(run.marks)),
    ...sliceInlineRuns(runs, to, length),
  ]);
}

/// [start, end) 内每个字的 [mark] 实际是否都开着（没设的随 [base]，即整条
/// 的取值）。空范围为 false。
bool inlineMarkActive(
  List<InlineTextRun> runs,
  int start,
  int end,
  InlineMark mark, {
  required bool base,
}) {
  if (start >= end) return false;
  final slice = sliceInlineRuns(runs, start, end);
  return slice.isNotEmpty && slice.every((run) => run.marks.flag(mark) ?? base);
}

/// 一个样式按“开关”改写后的取值：等于整条取值 [base] 时去掉（随整条），
/// 不留冗余。
bool? inlineFlagFor(bool on, {required bool base}) => on == base ? null : on;

/// 切换 [start, end) 的 [mark]：范围里每个字实际都开着就关掉，否则打开。
List<InlineTextRun> toggleMark(
  List<InlineTextRun> runs,
  int start,
  int end,
  InlineMark mark, {
  required bool base,
}) {
  final on = !inlineMarkActive(runs, start, end, mark, base: base);
  final value = inlineFlagFor(on, base: base);
  return formatRuns(runs, start, end, (marks) => marks.withFlag(mark, value));
}

/// [start, end) 内各字共同的 [mark] 颜色；不一致或都没设时为 null。
String? inlineCommonColor(
  List<InlineTextRun> runs,
  int start,
  int end,
  InlineColorMark mark,
) {
  final slice = sliceInlineRuns(runs, start, end);
  if (slice.isEmpty) return null;
  final first = slice.first.marks.colorOf(mark);
  return slice.every((run) => run.marks.colorOf(mark) == first) ? first : null;
}

/// 给 [start, end) 设链接 [href]（null 为去掉链接）。
List<InlineTextRun> setRunsLink(
  List<InlineTextRun> runs,
  int start,
  int end,
  String? href,
) => formatRuns(runs, start, end, (marks) => marks.withHref(href));

/// 一段链接：同一个地址的连续文字 [start, end)。
typedef InlineLinkRange = ({int start, int end, String href});

/// [start, end) 所在或紧挨着的那段链接：
/// - 有选区时，选中的字全在同一段链接里才算；
/// - 折叠光标在链接里或紧挨着它（前后各有一段时取光标前面那段，即刚打完
///   的链接）。
/// 不挨着链接时为 null。
InlineLinkRange? inlineLinkRangeAt(
  List<InlineTextRun> runs,
  int start,
  int end,
) {
  final length = inlineRunsText(runs).length;
  if (start < 0 || end > length || start > end) return null;
  final String? href;
  final int anchor;
  if (start < end) {
    href = inlineMarksAt(runs, start).href;
    if (href == null) return null;
    for (final run in sliceInlineRuns(runs, start, end)) {
      if (run.marks.href != href) return null;
    }
    anchor = start;
  } else {
    final before = start > 0 ? inlineMarksAt(runs, start - 1).href : null;
    final after = inlineMarksAt(runs, start).href;
    href = before ?? after;
    if (href == null) return null;
    anchor = before != null ? start - 1 : start;
  }
  var from = anchor;
  while (from > 0 && inlineMarksAt(runs, from - 1).href == href) {
    from--;
  }
  var to = anchor + 1;
  while (to < length && inlineMarksAt(runs, to).href == href) {
    to++;
  }
  return (start: from, end: to, href: href);
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
