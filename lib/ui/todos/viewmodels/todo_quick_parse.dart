/// 快速新建待办的“智能识别”：从一行输入里认出日期、时刻、清单与优先级。
///
/// - 输入：用户正在输入的原文、“今天”（本地零点）、已有清单（id → 名称，按
///   显示顺序）、用户点掉不要识别的种类。
/// - 输出：[TodoQuickParse]——去掉识别片段后的标题、各字段的值，以及每个片段在
///   原文里的位置（界面据此高亮、做成可点掉的标签）。
/// - 副作用：无。每次按键都会重新解析，纯函数、不缓存。
///
/// 取舍：每种最多取一个片段（原文里第一个合法的）；清单 → 优先级 → 日期 →
/// 时刻依次识别，后识别的不与先识别的重叠——“#明天要做”整体是清单，
/// “at 5 Jan”里日期先占了“5 Jan”，“at”不再当时刻。日期 / 时刻的词表与正则在
/// `todo_quick_parse_rules.dart`。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextRange;

import '../../../core/database/app_database.dart';
import 'todo_quick_parse_rules.dart';

/// 识别出的片段种类。
enum TodoQuickTokenKind { date, time, list, priority }

/// 原文里被识别的一段。
@immutable
class TodoQuickToken {
  const TodoQuickToken({required this.kind, required this.range});

  final TodoQuickTokenKind kind;

  /// 在原文里的位置（start 含、end 不含，UTF-16 下标，与输入框选区一致）。
  final TextRange range;

  @override
  bool operator ==(Object other) =>
      other is TodoQuickToken && other.kind == kind && other.range == range;

  @override
  int get hashCode => Object.hash(kind, range);

  @override
  String toString() => 'TodoQuickToken($kind, $range)';
}

/// 一行输入的识别结果。
@immutable
class TodoQuickParse {
  const TodoQuickParse({
    required this.title,
    this.date,
    this.minute,
    this.listId,
    this.priority,
    this.tokens = const [],
  });

  /// 什么都没识别的结果：标题只做空白折叠。
  factory TodoQuickParse.plain(String text) =>
      TodoQuickParse(title: _collapseSpaces(text));

  static const TodoQuickParse none = TodoQuickParse(title: '');

  /// 去掉识别片段后的标题：空白折叠为一个空格、首尾去空白。
  final String title;

  /// 截止日期（本地零点）；只识别出时刻时为“今天”。
  final DateTime? date;

  /// 一天中的分钟数。
  final int? minute;

  final String? listId;
  final TodoPriority? priority;

  /// 识别出的片段，按 `range.start` 升序。
  final List<TodoQuickToken> tokens;

  bool get isEmpty => tokens.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is TodoQuickParse &&
      other.title == title &&
      other.date == date &&
      other.minute == minute &&
      other.listId == listId &&
      other.priority == priority &&
      listEquals(other.tokens, tokens);

  @override
  int get hashCode => Object.hash(
    title,
    date,
    minute,
    listId,
    priority,
    Object.hashAll(tokens),
  );
}

/// 解析快速新建的一行输入。
///
/// [today] 为本地零点（带时分秒也只取日期）；[lists] 为清单 id → 名称，同名时
/// 取靠前的；[ignore] 里的种类完全不识别，原文保留在标题里。只识别出时刻时
/// 日期取今天——即使这个时刻今天已经过了。
TodoQuickParse parseTodoQuickInput(
  String text, {
  required DateTime today,
  Map<String, String> lists = const {},
  Set<TodoQuickTokenKind> ignore = const {},
}) {
  final day = DateTime(today.year, today.month, today.day);
  final tokens = <TodoQuickToken>[];
  bool isFree(int start, int end) =>
      tokens.every((t) => end <= t.range.start || start >= t.range.end);
  void take(TodoQuickTokenKind kind, int start, int end) => tokens.add(
    TodoQuickToken(
      kind: kind,
      range: TextRange(start: start, end: end),
    ),
  );

  String? listId;
  if (!ignore.contains(TodoQuickTokenKind.list)) {
    final hit = _findList(text, lists);
    if (hit != null) {
      listId = hit.id;
      take(TodoQuickTokenKind.list, hit.start, hit.end);
    }
  }

  TodoPriority? priority;
  if (!ignore.contains(TodoQuickTokenKind.priority)) {
    for (final m in _priorityMarks.allMatches(text)) {
      if (!isFree(m.start, m.end)) continue;
      priority = switch (m.end - m.start) {
        1 => TodoPriority.low,
        2 => TodoPriority.medium,
        _ => TodoPriority.high,
      };
      take(TodoQuickTokenKind.priority, m.start, m.end);
      break;
    }
  }

  DateTime? date;
  if (!ignore.contains(TodoQuickTokenKind.date)) {
    for (final c in findQuickDateCandidates(text, day)) {
      if (!isFree(c.start, c.end)) continue;
      date = c.value;
      take(TodoQuickTokenKind.date, c.start, c.end);
      break;
    }
  }

  int? minute;
  if (!ignore.contains(TodoQuickTokenKind.time)) {
    for (final c in findQuickTimeCandidates(text, day)) {
      if (!isFree(c.start, c.end)) continue;
      minute = c.value;
      take(TodoQuickTokenKind.time, c.start, c.end);
      break;
    }
  }

  if (tokens.isEmpty) return TodoQuickParse.plain(text);
  tokens.sort((a, b) => a.range.start.compareTo(b.range.start));
  return TodoQuickParse(
    title: _titleWithout(text, tokens),
    date: date ?? (minute != null ? day : null),
    minute: minute,
    listId: listId,
    priority: priority,
    tokens: List.unmodifiable(tokens),
  );
}

/// 独立的 `!` / `!!` / `!!!`（全角混用也算）：前后必须是空白或文本边界，
/// “你好!”里紧跟文字的感叹号是语气，不是优先级。
final _priorityMarks = RegExp(r'(?<!\S)[!！]+(?!\S)');

final _spaces = RegExp(r'\s+');

String _collapseSpaces(String text) => text.replaceAll(_spaces, ' ').trim();

typedef _ListHit = ({String id, int start, int end});

/// 第一个能对上已有清单的 `#` / `＃`。
///
/// `#` 后面的文字以清单名开头（不区分大小写）即算对上；多个清单都对上时取名称
/// 最长的（“#家 务”里有“家”和“家 务”两个清单时取后者）。清单名以字母数字结尾
/// 而后面紧跟字母数字时不算（“#workout”不是清单“work”）。片段为 `#` + 清单名。
_ListHit? _findList(String text, Map<String, String> lists) {
  if (lists.isEmpty) return null;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char != '#' && char != '＃') continue;
    _ListHit? best;
    for (final MapEntry(key: id, value: rawName) in lists.entries) {
      final name = rawName.trim();
      final end = i + 1 + name.length;
      if (name.isEmpty || end > text.length) continue;
      if (best != null && end <= best.end) continue;
      if (text.substring(i + 1, end).toLowerCase() != name.toLowerCase()) {
        continue;
      }
      if (end < text.length &&
          todoQuickIsWordChar(name[name.length - 1]) &&
          todoQuickIsWordChar(text[end])) {
        continue;
      }
      best = (id: id, start: i, end: end);
    }
    if (best != null) return best;
  }
  return null;
}

/// 原文去掉 [tokens]（已按起点排序、互不重叠）后的标题。
///
/// 去掉片段的接缝处原本有空白时：两侧都是中日文字符就直接相连（“开会 明天
/// 准备”→“开会准备”），否则留一个空格；原本没空白就直接相连。最后整体折叠
/// 空白、去首尾空白。
String _titleWithout(String text, List<TodoQuickToken> tokens) {
  var out = text.substring(0, tokens.first.range.start);
  for (var i = 0; i < tokens.length; i++) {
    final end = i + 1 < tokens.length ? tokens[i + 1].range.start : text.length;
    out = _joinAtSeam(out, text.substring(tokens[i].range.end, end));
  }
  return _collapseSpaces(out);
}

String _joinAtSeam(String before, String after) {
  final left = before.trimRight();
  final right = after.trimLeft();
  if (left.isEmpty) return right;
  // 右侧只有空白时原样保留，让下一个接缝还知道这里有过空白。
  if (right.isEmpty) return before + after;
  if (left.length == before.length && right.length == after.length) {
    return left + right;
  }
  final cjk =
      _isCjk(left.codeUnitAt(left.length - 1)) && _isCjk(right.codeUnitAt(0));
  return cjk ? left + right : '$left $right';
}

/// 不用空格分词的中日文字符：汉字、假名、中日文标点与全角符号。
bool _isCjk(int unit) =>
    todoQuickIsHan(unit) ||
    (unit >= 0x3000 && unit <= 0x30FF) ||
    (unit >= 0xFF00 && unit <= 0xFFEF);
