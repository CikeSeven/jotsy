import 'package:intl/intl.dart';

import '../../../l10n/app_localizations_gen.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../models/built_in/diary_template_questions.dart';
import '../models/diary_template_variables.dart';

/// 套用模板时各变量的取值。
///
/// 日期类变量取日记的日期 [diaryDate]（日历里补写昨天，`{{日期}}` 就是
/// 昨天），`{{时间}}` 取当下 [now]。日期与星期按界面语言格式化；农历与节气
/// 经 [CalendarLunarDay]（与日历同一处换算），只有中文名称。
///
/// `{{时间:HH:mm}}` 这类带格式的写法按界面语言把 [now] 格式化成指定图案
/// （见 [formatDiaryTemplateMoment]），没写格式时仍是该语言的 `Hm`。
///
/// `{{今日一问}}` 的题号 = 日记日期距 1970-01-01 的天数 + [questionShift]，
/// 对题库长度取模：同一天固定是同一题，跨天依次轮换，“换一题”把偏移加一。
/// 不用字符串哈希——那在不同平台、不同版本之间不保证稳定。
class DiaryTemplateVariableValues {
  DiaryTemplateVariableValues._(this._values, this._now, this._locale);

  factory DiaryTemplateVariableValues.compute({
    required AppLocalizations l10n,
    required DateTime diaryDate,
    required DateTime now,
    int questionShift = 0,
  }) {
    final locale = l10n.localeName;
    final day = DateTime(diaryDate.year, diaryDate.month, diaryDate.day);
    final dayOfYear = _dayOfYear(day);
    final daysInYear = _dayOfYear(DateTime(day.year, 12, 31));
    final lunar = CalendarLunarDay.of(day);
    final questions = diaryTemplateQuestions(l10n);
    final questionIndex = (_epochDays(day) + questionShift) % questions.length;
    return DiaryTemplateVariableValues._(
      <DiaryTemplateVariable, String>{
        DiaryTemplateVariable.date: DateFormat.yMMMMd(locale).format(day),
        DiaryTemplateVariable.weekday: DateFormat.EEEE(locale).format(day),
        DiaryTemplateVariable.time: DateFormat.Hm(locale).format(now),
        DiaryTemplateVariable.year: '${day.year}',
        DiaryTemplateVariable.month: DateFormat.MMMM(locale).format(day),
        DiaryTemplateVariable.day: '${day.day}',
        DiaryTemplateVariable.week: '${isoWeekNumber(day)}',
        DiaryTemplateVariable.dayOfYear: '$dayOfYear',
        DiaryTemplateVariable.yearProgress: NumberFormat.percentPattern(
          locale,
        ).format(dayOfYear / daysInYear),
        DiaryTemplateVariable.lunar: lunar.date,
        DiaryTemplateVariable.solarTerm: lunar.termPeriod,
        DiaryTemplateVariable.question: questions[questionIndex],
      },
      now,
      locale,
    );
  }

  /// 只写变量名时的取值，套用前一次算好。
  final Map<DiaryTemplateVariable, String> _values;

  /// 带格式的时间按需格式化，所以留着当下时刻与界面语言。
  final DateTime _now;
  final String _locale;

  /// 只写变量名（`{{时间}}`）时的取值。
  String? operator [](DiaryTemplateVariable variable) => _values[variable];

  /// 一处变量的取值：[format] 为 null 时同 [operator []]；带格式时只有
  /// [DiaryTemplateVariable.acceptsFormat] 的变量有值，图案不能用返回 null
  /// （占位原样保留）。
  String? valueOf(DiaryTemplateVariable variable, String? format) {
    if (format == null) return _values[variable];
    return switch (variable) {
      DiaryTemplateVariable.time => formatDiaryTemplateMoment(
        _now,
        format,
        _locale,
      ),
      _ => null,
    };
  }

  String resolve(String text) => resolveDiaryTemplateText(text, valueOf);

  static int _dayOfYear(DateTime day) =>
      DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(day.year)).inDays +
      1;

  static int _epochDays(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

/// 时间格式里能用的字段字母：intl `DateFormat` 真正实现了的那些。时区
/// `z` / `Z` / `v` 在 intl 里也是字段，但格式化时输出空串，不收。
const String _momentFieldLetters = 'GyMkSEahKHcLQdDms';

final RegExp _asciiLetter = RegExp('[A-Za-z]');

/// 按 intl `DateFormat` 图案 [pattern] 与界面语言 [locale] 格式化 [moment]；
/// 图案不能用时返回 null，模板里的这一处占位原样保留。
///
/// DateFormat 自己几乎不拒绝图案：认不出的字母当原文输出、未闭合的引号把
/// 后面整段丢掉（`{{时间:hh:mm A}}` 里的 A 原样出现，`{{时间:foo}}` 整个
/// 变成 foo），用户看不出写错了。所以先按它的词法检查一遍（见
/// [_isUsableMomentPattern]）。检查的是 DateFormat 实际采用的图案：与骨架
/// 同名的写法（`Hm`、`jm`、`yMd` 等）会被 intl 换成这个语言的本地图案，
/// 这是 intl 的约定，照用（`{{time:jm}}` 在英文里就是 `h:mm a`）。
///
/// 过了检查仍可能被 intl 拒绝（6 个以上的 E 会抛 UnsupportedError），同样
/// 按不能用处理：用户写的一处格式不能弄坏整次套用，所以这里接住一切错误。
String? formatDiaryTemplateMoment(
  DateTime moment,
  String pattern,
  String locale,
) {
  try {
    final format = DateFormat(pattern, locale);
    if (!_isUsableMomentPattern(format.pattern ?? '')) return null;
    return format.format(moment);
  } on Object {
    return null;
  }
}

/// [pattern] 是否是一个能用的时间图案：
/// - 单引号外的 ASCII 字母只能是 [_momentFieldLetters]（与 CLDR 一样，字母
///   都是保留的字段名，要写字母原文得放进单引号，`''` 为一个单引号）；
/// - 单引号成对；
/// - 至少有一个字段（只有原文的“格式”多半是写错了，不该悄悄变成一段字）。
bool _isUsableMomentPattern(String pattern) {
  var quoted = false;
  var hasField = false;
  for (final char in pattern.split('')) {
    if (char == "'") {
      // `''` 连续翻转两次回到原状态，与 intl 把它读作一个单引号一致。
      quoted = !quoted;
    } else if (!quoted && _asciiLetter.hasMatch(char)) {
      if (!_momentFieldLetters.contains(char)) return false;
      hasField = true;
    }
  }
  return !quoted && hasField;
}

/// ISO 8601 周数：周一为一周之始，含当年第一个星期四的那周是第 1 周（年初
/// 几天可能属于上一年的第 52/53 周，年末几天可能属于下一年的第 1 周）。
int isoWeekNumber(DateTime day) {
  final date = DateTime.utc(day.year, day.month, day.day);
  final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
  final firstDay = DateTime.utc(thursday.year);
  return thursday.difference(firstDay).inDays ~/ 7 + 1;
}
