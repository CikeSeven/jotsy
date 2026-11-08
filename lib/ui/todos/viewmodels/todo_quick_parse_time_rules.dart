// 快速新建待办的时刻识别规则（`todo_quick_parse_rules.dart` 的一部分）。
//
// 输入：原文；输出：时刻候选（一天中的分钟数）；无副作用。
// 中日文按“时段 + 字面小时”换算（下午 / 晚上 1–11 点加 12，中午 1 点为 13:00），
// 英文 am / pm、俄文 утра / дня / вечера / ночи 同理；没写时段按字面，只有紧跟
// “今晚 / tonight”时按晚上算。
part of 'todo_quick_parse_rules.dart';

/// 时段决定字面小时怎么换算成 24 小时制，见 [_clock]。
enum _Period {
  /// 上午 / 早上：0–12 按字面。
  am,

  /// 12 点算零点的上午（12am、午前12時、凌晨12点、12 часов ночи）。
  amMidnight,

  /// 中午 / дня：1–5 点加 12，11–15 点按字面。
  noon,

  /// 下午 / 晚上：1–11 点加 12，12–23 点按字面。
  pm,
}

const _periodWords = <String, _Period>{
  '上午': _Period.am, '早上': _Period.am, '早晨': _Period.am, //
  '凌晨': _Period.amMidnight, '午前': _Period.amMidnight,
  '中午': _Period.noon, '下午': _Period.pm, '傍晚': _Period.pm, //
  '晚上': _Period.pm, '午後': _Period.pm,
  'утра': _Period.am, 'ночи': _Period.amMidnight, //
  'дня': _Period.noon, 'вечера': _Period.pm,
};

/// 时刻前紧挨着“今晚 / tonight”时，没写时段的小时按晚上算（“今晚8点”是 20:00）。
final _eveningContext = RegExp(
  r'(?:今晚|明晚|今夜|明夜|tonight)\s*$',
  caseSensitive: false,
);

const _cnNumerals = '零〇一二两三四五六七八九十';
const _cnDigits = <String, int>{
  '零': 0, '〇': 0, '一': 1, '二': 2, '两': 2, '三': 3, //
  '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
};

final List<_Rule<int>> _timeRules = [
  // 中日文：[时段] 3点 / 3点半 / 3点15(分) / 3点钟 / 三点 / 15時 / 午後3時半。
  // 小时前不能紧挨数字、汉字数字或“第 / 周 / 星期”（“第三点”“周三点名”）；
  // “3時間”是时长不是时刻。
  _Rule(
    [
      r'(?:(',
      _cjkPeriods,
      r')\s*)?(?<![\d.第周週期拜',
      _cnNumerals,
      r'])(\d{1,2}|[',
      _cnNumerals,
      r']{1,3})\s*[点點時时](?![間间])',
      r'(?:\s*(半)|\s*(\d{1,2})\s*分|(\d{2})(?!\d)|[钟鐘])?',
    ].join(),
    (m, text, today) => _cjkClock(m, text),
  ),
  // [时段] HH:MM（含全角冒号），以及通用的独立 HH:MM。
  _Rule(
    [
      r'(?:(',
      _cjkPeriods,
      r')\s*)?(?<![\d:：.])(\d{1,2})[:：](\d{2})(?![\d:：])',
    ].join(),
    (m, text, today) => _clock(
      int.parse(m[2]!),
      int.parse(m[3]!),
      _periodWords[m[1]] ?? _impliedPeriod(text, m.start),
    ),
  ),
  // 英文：[at] 3pm / 3 pm / 3:30pm / 11 a.m.（12am 为零点，12pm 为正午）。
  _Rule(
    _words([r'(?:at\s+|@\s*)?(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m\.?']),
    (m, text, today) => _englishClock(m),
  ),
  // 英文：at 15:00 / at 3（小时按字面）。
  _Rule(
    _words([r'(?:at|@)\s*(\d{1,2})(?::(\d{2}))?']),
    (m, text, today) => _clock(
      int.parse(m[1]!),
      int.parse(m[2] ?? '0'),
      _impliedPeriod(text, m.start),
    ),
  ),
  // 俄文：в 15:00 / в 15.00。
  _Rule(
    _words([r'в\s+(\d{1,2})[:.](\d{2})']),
    (m, text, today) => _clock(int.parse(m[1]!), int.parse(m[2]!), null),
  ),
  // 俄文：в 3 часа / в 15 часов / в 7 ч [утра / дня / вечера / ночи]。
  _Rule(
    _words([
      r'в\s+(\d{1,2})\s*(?:часов|часа|час|ч\.?)(?:\s+(утра|дня|вечера|ночи))?',
    ]),
    (m, text, today) =>
        _clock(int.parse(m[1]!), 0, _periodWords[m[2]?.toLowerCase()]),
  ),
];

/// 中日文时刻的取值。组：1 时段、2 小时、3 “半”、4 带“分”的分钟、5 紧跟的两位分钟。
int? _cjkClock(Match m, String text) {
  final rawHour = m[2]!;
  final hour = int.tryParse(rawHour) ?? _cnNumber(rawHour);
  if (hour == null) return null;
  final hasMinute = m[3] != null || m[4] != null || m[5] != null;
  final last = m[0]![m[0]!.length - 1];
  // 没有时段、分钟或“钟”的“一点 / 一時”多半是“快一点”“一時保存”，不当时刻。
  if (rawHour == '一' &&
      m[1] == null &&
      !hasMinute &&
      last != '钟' &&
      last != '鐘') {
    return null;
  }
  final minute = m[3] != null ? 30 : int.parse(m[4] ?? m[5] ?? '0');
  return _clock(
    hour,
    minute,
    _periodWords[m[1]] ?? _impliedPeriod(text, m.start),
  );
}

/// 英文 am / pm 的取值：小时只能 1–12。组：1 小时、2 分钟、3 a / p。
int? _englishClock(Match m) {
  final hour = int.parse(m[1]!);
  if (hour < 1 || hour > 12) return null;
  final period = m[3]!.toLowerCase() == 'a' ? _Period.amMidnight : _Period.pm;
  return _clock(hour, int.parse(m[2] ?? '0'), period);
}

_Period? _impliedPeriod(String text, int start) =>
    _eveningContext.hasMatch(text.substring(0, start)) ? _Period.pm : null;

/// 字面小时 + 时段 → 一天中的分钟数；不合法（上午15点、25点、61分）为 null。
int? _clock(int hour, int minute, _Period? period) {
  if (minute < 0 || minute > 59) return null;
  final int? h = switch (period) {
    null => hour <= 23 ? hour : null,
    _Period.am => hour <= 12 ? hour : null,
    _Period.amMidnight => hour == 12 ? 0 : (hour < 12 ? hour : null),
    _Period.noon =>
      hour >= 1 && hour <= 5
          ? hour + 12
          : (hour >= 11 && hour <= 15 ? hour : null),
    _Period.pm =>
      hour >= 1 && hour <= 11
          ? hour + 12
          : (hour >= 12 && hour <= 23 ? hour : null),
  };
  return h == null ? null : h * 60 + minute;
}

/// 汉字数字 0–99（“三”“十一”“二十三”“两”），无法解析为 null。
int? _cnNumber(String s) {
  final ten = s.indexOf('十');
  if (ten < 0) return s.length == 1 ? _cnDigits[s] : null;
  if (s.indexOf('十', ten + 1) >= 0 || ten > 1 || s.length - ten > 2) {
    return null;
  }
  final tens = ten == 0 ? 1 : _cnDigits[s[0]];
  final ones = ten == s.length - 1 ? 0 : _cnDigits[s[s.length - 1]];
  return tens == null || ones == null ? null : tens * 10 + ones;
}
