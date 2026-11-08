/// 快速新建待办的日期 / 时刻识别规则：词表、正则与取值。
///
/// - 输入：原文、“今天”（本地零点）。
/// - 输出：原文里每一处可能的日期 / 时刻片段（[TodoQuickCandidate]），按起点
///   升序、同起点时长的在前；取值不合法（2 月 30 日、上午 15 点）的片段在这里
///   就丢掉，不产出候选。
/// - 副作用：无。正则在首次使用时编译一次。
///
/// 中 / 英 / 日 / 俄四种写法同时生效，与界面语言无关。每种只取第一个、与清单
/// 和优先级片段是否重叠，都由 `todo_quick_parse.dart` 决定。本文件放公共部分与
/// 日期规则，时刻规则在 `todo_quick_parse_time_rules.dart`。
library;

import 'package:flutter/foundation.dart';

part 'todo_quick_parse_time_rules.dart';

/// 原文里一处候选片段 `[start, end)` 与它解析出的值。
@immutable
class TodoQuickCandidate<T> {
  const TodoQuickCandidate(this.start, this.end, this.value);

  final int start;
  final int end;
  final T value;
}

/// 原文里所有可能的日期片段，值为本地零点。
List<TodoQuickCandidate<DateTime>> findQuickDateCandidates(
  String text,
  DateTime today,
) => _collect(_dateRules, text, today);

/// 原文里所有可能的时刻片段，值为一天中的分钟数。
List<TodoQuickCandidate<int>> findQuickTimeCandidates(
  String text,
  DateTime today,
) => _collect(_timeRules, text, today);

/// 是否为汉字（CJK 统一表意文字、扩展 A 与兼容表意文字）。
bool todoQuickIsHan(int unit) =>
    (unit >= 0x4E00 && unit <= 0x9FFF) ||
    (unit >= 0x3400 && unit <= 0x4DBF) ||
    (unit >= 0xF900 && unit <= 0xFAFF);

/// 是否为英文 / 俄文“单词”里的字符：片段前后紧挨着它就不算独立成词。
bool todoQuickIsWordChar(String char) => _wordChar.hasMatch(char);

/// 单词字符：拉丁字母（含带重音的 U+00C0–U+024F）、西里尔字母
/// （U+0400–U+04FF）、数字与下划线。
const _wordChars = r'A-Za-z0-9_\u00C0-\u024F\u0400-\u04FF';
final _wordChar = RegExp('[$_wordChars]');

/// 英文 / 俄文片段两侧加单词边界；中日文没有空格分词，不用它。
String _words(List<String> parts) =>
    '(?<![$_wordChars])(?:${parts.join()})(?![$_wordChars])';

typedef _Resolve<T> = T? Function(Match m, String text, DateTime today);

class _Rule<T> {
  _Rule(String pattern, this.resolve)
    : regex = RegExp(pattern, caseSensitive: false);

  final RegExp regex;

  /// 取值；返回 null 表示这一处不算（非法日期、不独立成词等）。
  final _Resolve<T> resolve;
}

List<TodoQuickCandidate<T>> _collect<T>(
  List<_Rule<T>> rules,
  String text,
  DateTime today,
) {
  final out = <TodoQuickCandidate<T>>[];
  for (final rule in rules) {
    for (final m in rule.regex.allMatches(text)) {
      final value = rule.resolve(m, text, today);
      if (value != null) out.add(TodoQuickCandidate(m.start, m.end, value));
    }
  }
  // 起点靠前的优先；同起点取更长的（“大后天”胜过“后天”，“at 3pm”胜过“at 3”）。
  out.sort((a, b) => a.start != b.start ? a.start - b.start : b.end - a.end);
  return out;
}

// ───────────────────────────── 日期 ─────────────────────────────

/// 中日文相对日期词 → 距今天的天数。
const _cjkRelativeDays = <String, int>{
  '今天': 0, '今日': 0, '今晚': 0, '今夜': 0, '今早': 0, //
  '明天': 1, '明日': 1, '明晚': 1, '明夜': 1, '明早': 1, //
  '后天': 2, '後天': 2, '明後日': 2, '大后天': 3, '大後天': 3,
};

const _cnWeekdays = <String, int>{
  '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7, //
};
const _jaWeekdays = <String, int>{
  '月': 1, '火': 2, '水': 3, '木': 4, '金': 5, '土': 6, '日': 7, //
};

/// 俄文星期按前两个字母（全称或缩写）。
const _ruWeekdays = <String, int>{
  'по': 1, 'пн': 1, 'вт': 2, 'ср': 3, 'че': 4, 'чт': 4, 'пя': 5, 'пт': 5, //
  'су': 6, 'сб': 6, 'во': 7, 'вс': 7,
};

const _enMonths =
    'january|february|march|april|may|june|july|august|september|october|'
    'november|december|sept|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec';
const _enMonthKeys = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];
const _ruMonths = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', //
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

/// 时段词：既用于时刻（“下午3点”），也让“周五下午”里的星期不被当成长词拒掉。
const _cjkPeriods = '上午|早上|早晨|凌晨|中午|下午|傍晚|晚上|午前|午後';
final _periodPrefix = RegExp(_cjkPeriods);

final List<_Rule<DateTime>> _dateRules = [
  // 中日文相对日期：后面紧跟汉字照样识别（“明天开会”“今天买菜”）。
  _Rule(
    '大后天|大後天|明後日|今天|今日|今晚|今夜|今早|明天|明日|明晚|明夜|明早|后天|後天',
    (m, text, today) => _addDays(today, _cjkRelativeDays[m[0]]!),
  ),
  // 中文星期：[下下/下/这/本][个]周X / 星期X / 礼拜X；“每周一”“上周一”不算。
  _Rule(
    '(?:(下下|下|这|這|本)[个個]?|(?<![每毎上]))(?:周|週|星期|礼拜|禮拜)'
    '([一二三四五六日天])',
    (m, text, today) => _standaloneCjkWeekday(text, m.end)
        ? _weekdayDate(today, _cnWeekdays[m[2]]!, switch (m[1]) {
            '下下' => 2,
            '下' => 1,
            null => null,
            _ => 0,
          })
        : null,
  ),
  // 日文星期：[再来週/来週/今週][の]X曜[日]；“毎週”“先週”后面的不算。
  _Rule(
    '(?:(再来週|来週|今週)の?|(?<!週))([月火水木金土日])曜日?',
    (m, text, today) => _standaloneCjkWeekday(text, m.end)
        ? _weekdayDate(today, _jaWeekdays[m[2]]!, switch (m[1]) {
            '再来週' => 2,
            '来週' => 1,
            null => null,
            _ => 0,
          })
        : null,
  ),
  // 中日文年月日 / 月日：2026年11月20日、11月20日、11月20号。
  _Rule(
    r'(?<!\d)(?:(\d{4})\s*年\s*)?(\d{1,2})\s*月\s*(\d{1,2})\s*[日号號]',
    (m, text, today) => _monthDay(today, m[1], m[2]!, m[3]!),
  ),
  // 只有日：20号、20日。前面是“月”的归上一条（“2月30日”非法时不退化成“30日”），
  // “10日元”是钱不是日子。
  _Rule(
    r'(?<!月\s*)(?<![\d.])(\d{1,2})\s*[号號日](?![元円])',
    (m, text, today) => _dayOfMonth(today, int.parse(m[1]!)),
  ),
  // 数字年月日：2026-11-20、2026/11/20、2026.11.20（两个分隔符一致）。
  _Rule(
    r'(?<![\d/.\-])(\d{4})([-/.])(\d{1,2})\2(\d{1,2})(?!\d)',
    (m, text, today) =>
        _validDate(int.parse(m[1]!), int.parse(m[3]!), int.parse(m[4]!)),
  ),
  // 数字月日：11/20、11-20。
  _Rule(
    r'(?<![\d/.\-])(\d{1,2})[-/](\d{1,2})(?!\d|[-/.]\d)',
    (m, text, today) => _monthDay(today, null, m[1]!, m[2]!),
  ),
  // 英文相对日期：(the) day after tomorrow / today / tonight / tomorrow / tmr。
  _Rule(
    _words([
      r'(?:the\s+)?(day\s+after\s+tomorrow)|today|tonight|tomorrow|tmrw?|tmw',
    ]),
    (m, text, today) => _addDays(today, switch (m[0]!.toLowerCase()) {
      _ when m[1] != null => 2,
      'today' || 'tonight' => 0,
      _ => 1,
    }),
  ),
  // 英文星期：[on] [next/this] mon / monday …（“on”一并吃掉）。
  _Rule(
    _words([
      r'(?:on\s+)?(?:(next|this)\s+)?(monday|tuesday|wednesday|thursday|'
          r'friday|saturday|sunday|tues|thurs|thur|mon|tue|wed|thu|fri|sat|sun)',
    ]),
    (m, text, today) =>
        _weekdayDate(today, _enWeekday(m[2]!), switch (m[1]?.toLowerCase()) {
          'next' => 1,
          'this' => 0,
          _ => null,
        }),
  ),
  // 英文月日：[on] Jan 5 / January 5th。
  _Rule(
    _words([r'(?:on\s+)?(', _enMonths, r')\.?\s+(\d{1,2})(?:st|nd|rd|th)?']),
    (m, text, today) => _monthDay(today, null, _enMonth(m[1]!), m[2]!),
  ),
  // 英文日月：[on] 5 Jan / 5th of January。
  _Rule(
    _words([
      r'(?:on\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(',
      _enMonths,
      r')\.?',
    ]),
    (m, text, today) => _monthDay(today, null, _enMonth(m[2]!), m[1]!),
  ),
  // 俄文相对日期。
  _Rule(
    _words([r'(сегодня|завтра|послезавтра)']),
    (m, text, today) => _addDays(
      today,
      const ['сегодня', 'завтра', 'послезавтра'].indexOf(m[1]!.toLowerCase()),
    ),
  ),
  // 俄文星期：[в/во] [следующий/следующую…] понедельник / пятницу / пт …。
  _Rule(
    _words([
      r'(?:во?\s+)?(?:(следующ(?:ий|ую|ее|ая))\s+)?(понедельник|вторник|среду|'
          r'среда|четверг|пятницу|пятница|субботу|суббота|воскресенье|'
          r'пн|вт|ср|чт|пт|сб|вс)',
    ]),
    (m, text, today) => _weekdayDate(
      today,
      _ruWeekdays[m[2]!.toLowerCase().substring(0, 2)]!,
      m[1] != null ? 1 : null,
    ),
  ),
  // 俄文日月（月份属格）：20 ноября、20-го ноября。
  _Rule(
    _words([r'(\d{1,2})(?:-?го)?\s+(', _ruMonths.join('|'), ')']),
    (m, text, today) => _monthDay(
      today,
      null,
      '${_ruMonths.indexOf(m[2]!.toLowerCase()) + 1}',
      m[1]!,
    ),
  ),
];

/// 中日文“周X / X曜”后面紧跟汉字时多半是更长的词（“周一例会”“一周一次”），
/// 不识别；紧跟时段词（“周五下午3点”）例外。相对日期词不走这条。
bool _standaloneCjkWeekday(String text, int end) {
  if (end >= text.length || !todoQuickIsHan(text.codeUnitAt(end))) {
    return true;
  }
  return _periodPrefix.matchAsPrefix(text, end) != null;
}

int _enWeekday(String word) =>
    const [
      'mo',
      'tu',
      'we',
      'th',
      'fr',
      'sa',
      'su',
    ].indexOf(word.substring(0, 2).toLowerCase()) +
    1;

String _enMonth(String word) =>
    '${_enMonthKeys.indexOf(word.substring(0, 3).toLowerCase()) + 1}';

/// 按日历加减天数（不经 Duration，避开夏令时切换日的 23 / 25 小时）。
DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// 星期 X 对应的日期。
///
/// [weeksAhead] 为 null：今天之后（不含今天）最近的那一天；
/// 0：本周（周一开始）里的那一天，已过就顺延到下周；
/// 1 / 2：下一周 / 下下周里的那一天。
DateTime _weekdayDate(DateTime today, int weekday, int? weeksAhead) {
  if (weeksAhead == null) {
    final delta = (weekday - today.weekday) % 7;
    return _addDays(today, delta == 0 ? 7 : delta);
  }
  final monday = _addDays(today, 1 - today.weekday);
  final date = _addDays(monday, weeksAhead * 7 + weekday - 1);
  return date.isBefore(today) ? _addDays(date, 7) : date;
}

/// 合法的年月日，否则 null（2 月 30 日、13 月）。
DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  return date.month == month && date.day == day ? date : null;
}

/// 月日：给了年份就按那一年（过去的日期也照样认）；没给年份取今天或之后最近的
/// 那一次——今年已过就明年，2 月 29 日顺延到下一个闰年；哪年都不合法时为 null。
DateTime? _monthDay(DateTime today, String? year, String month, String day) {
  final m = int.parse(month);
  final d = int.parse(day);
  if (year != null) return _validDate(int.parse(year), m, d);
  for (var y = today.year; y <= today.year + 8; y++) {
    final date = _validDate(y, m, d);
    if (date != null && !date.isBefore(today)) return date;
  }
  return null;
}

/// 只有日：今天或之后最近的那一天；本月已过（或本月没有这一天）就往后找月份。
DateTime? _dayOfMonth(DateTime today, int day) {
  if (day < 1 || day > 31) return null;
  for (var i = 0; i < 12; i++) {
    final month = DateTime(today.year, today.month + i);
    final date = _validDate(month.year, month.month, day);
    if (date != null && !date.isBefore(today)) return date;
  }
  return null;
}
