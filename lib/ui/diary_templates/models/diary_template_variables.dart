/// 模板变量：标题与正文里的 `{{日期}}`、`{{date}}` 这类占位，套用时按日记
/// 的日期替换成具体文字（取值见 `DiaryTemplateVariableValues`）。
enum DiaryTemplateVariable {
  date,
  weekday,
  time,
  year,
  month,
  day,
  week,
  dayOfYear,
  yearProgress,
  lunar,
  solarTerm,
  question,
}

/// 变量名的全部写法（比较前转小写），中英文等价。
///
/// 这是语法而不是界面文案，所以固定写在代码里、不进 ARB：模板码分享给
/// 另一种界面语言的设备、或者用户切换了应用语言，`{{日期}}` 与 `{{date}}`
/// 都必须照样能解析。界面上“插入变量”插入的是当前语言的写法（ARB 里的
/// `diaryTemplateVar…Token`），测试保证那些写法都在这张表里。
const Map<String, DiaryTemplateVariable> _aliases =
    <String, DiaryTemplateVariable>{
      'date': DiaryTemplateVariable.date,
      '日期': DiaryTemplateVariable.date,
      'weekday': DiaryTemplateVariable.weekday,
      '星期': DiaryTemplateVariable.weekday,
      'time': DiaryTemplateVariable.time,
      '时间': DiaryTemplateVariable.time,
      'year': DiaryTemplateVariable.year,
      '年': DiaryTemplateVariable.year,
      '年份': DiaryTemplateVariable.year,
      'month': DiaryTemplateVariable.month,
      '月': DiaryTemplateVariable.month,
      '月份': DiaryTemplateVariable.month,
      'day': DiaryTemplateVariable.day,
      '日': DiaryTemplateVariable.day,
      'week': DiaryTemplateVariable.week,
      'weekofyear': DiaryTemplateVariable.week,
      '周数': DiaryTemplateVariable.week,
      '第几周': DiaryTemplateVariable.week,
      'dayofyear': DiaryTemplateVariable.dayOfYear,
      '第几天': DiaryTemplateVariable.dayOfYear,
      'yearprogress': DiaryTemplateVariable.yearProgress,
      '年进度': DiaryTemplateVariable.yearProgress,
      'lunar': DiaryTemplateVariable.lunar,
      '农历': DiaryTemplateVariable.lunar,
      'solarterm': DiaryTemplateVariable.solarTerm,
      'term': DiaryTemplateVariable.solarTerm,
      '节气': DiaryTemplateVariable.solarTerm,
      'question': DiaryTemplateVariable.question,
      '今日一问': DiaryTemplateVariable.question,
      '每日一问': DiaryTemplateVariable.question,
    };

/// `{{` 与 `}}` 之间、不含花括号与换行的一段，两侧空白不计。
final RegExp _tokenPattern = RegExp(r'\{\{\s*([^{}\n]+?)\s*\}\}');

DiaryTemplateVariable? parseDiaryTemplateVariable(String name) =>
    _aliases[name.trim().toLowerCase()];

/// 一个变量的占位写法，如 `{{日期}}`。
String diaryTemplateToken(String name) => '{{$name}}';

/// 替换 [text] 里认得的变量；认不出的写法、[valueOf] 返回 null 的变量原样
/// 保留（用户可能本来就想写花括号）。取值里的换行折成空格：变量在一行文字
/// 中间，换行会把那一行的段落格式拆到两行上。
String resolveDiaryTemplateText(
  String text,
  String? Function(DiaryTemplateVariable variable) valueOf,
) {
  if (!text.contains('{{')) return text;
  return text.replaceAllMapped(_tokenPattern, (match) {
    final variable = parseDiaryTemplateVariable(match.group(1)!);
    final value = variable == null ? null : valueOf(variable);
    if (value == null) return match.group(0)!;
    return value.replaceAll(RegExp(r'[\r\n]+'), ' ');
  });
}

/// 逐个文字操作替换变量，格式属性不变。一个变量被拆在两段不同格式的文字
/// 里时不会被识别——编辑页“插入变量”总是把它作为同一段文字插入。
List<Map<String, Object?>> resolveDiaryTemplateOps(
  List<Map<String, Object?>> ops,
  String? Function(DiaryTemplateVariable variable) valueOf,
) {
  return <Map<String, Object?>>[
    for (final op in ops)
      if (op['insert'] case final String text when text.contains('{{'))
        <String, Object?>{
          ...op,
          'insert': resolveDiaryTemplateText(text, valueOf),
        }
      else
        op,
  ];
}

/// [text] 里用到的全部变量。
Set<DiaryTemplateVariable> diaryTemplateVariablesIn(String text) {
  if (!text.contains('{{')) return const <DiaryTemplateVariable>{};
  return <DiaryTemplateVariable>{
    for (final match in _tokenPattern.allMatches(text))
      ?parseDiaryTemplateVariable(match.group(1)!),
  };
}
