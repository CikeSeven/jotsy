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
/// `{{今日一问}}` 的题号 = 日记日期距 1970-01-01 的天数 + [questionShift]，
/// 对题库长度取模：同一天固定是同一题，跨天依次轮换，“换一题”把偏移加一。
/// 不用字符串哈希——那在不同平台、不同版本之间不保证稳定。
class DiaryTemplateVariableValues {
  DiaryTemplateVariableValues._(this._values);

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
    return DiaryTemplateVariableValues._(<DiaryTemplateVariable, String>{
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
    });
  }

  final Map<DiaryTemplateVariable, String> _values;

  String? operator [](DiaryTemplateVariable variable) => _values[variable];

  String resolve(String text) =>
      resolveDiaryTemplateText(text, (variable) => _values[variable]);

  List<Map<String, Object?>> resolveOps(List<Map<String, Object?>> ops) =>
      resolveDiaryTemplateOps(ops, (variable) => _values[variable]);

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

/// ISO 8601 周数：周一为一周之始，含当年第一个星期四的那周是第 1 周（年初
/// 几天可能属于上一年的第 52/53 周，年末几天可能属于下一年的第 1 周）。
int isoWeekNumber(DateTime day) {
  final date = DateTime.utc(day.year, day.month, day.day);
  final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
  final firstDay = DateTime.utc(thursday.year);
  return thursday.difference(firstDay).inDays ~/ 7 + 1;
}
