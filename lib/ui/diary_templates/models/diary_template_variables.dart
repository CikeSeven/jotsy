/// 模板变量：标题与正文里的 `{{日期}}`、`{{date}}` 这类占位，套用时按日记
/// 的日期替换成具体文字（取值见 `DiaryTemplateVariableValues`）。
///
/// 写法有两种：只写变量名 `{{时间}}`，或在变量名后加冒号与格式
/// `{{时间:HH:mm}}`。格式只对 [acceptsFormat] 的变量有效，其余变量带冒号的
/// 写法一律认不出、原样保留——这样以后给别的变量加格式时，已有模板里的
/// 写法不会突然变了含义。
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
  question;

  /// 能否在冒号后写格式。目前只有时间：格式是 intl `DateFormat` 图案，按
  /// 当下时刻格式化（图案能否使用由取值一侧判断，见
  /// `formatDiaryTemplateMoment`）。
  bool get acceptsFormat => this == DiaryTemplateVariable.time;
}

/// 变量取值的回调：[format] 为冒号后写的格式（已去掉两侧空白、非空），
/// 只写变量名时为 null。返回 null 表示这一处原样保留。
typedef DiaryTemplateValueOf =
    String? Function(DiaryTemplateVariable variable, String? format);

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

/// 变量名与格式之间的冒号。全角冒号同样认：中文输入法下冒号默认是全角，
/// `{{时间：HH:mm}}` 不该因此失效。
final RegExp _formatSeparator = RegExp('[:：]');

/// 变量名（不含冒号与格式）对应的变量，认不出为 null。
DiaryTemplateVariable? parseDiaryTemplateVariable(String name) =>
    _aliases[name.trim().toLowerCase()];

/// 花括号里的一整段（如 `时间:HH:mm`）→ 变量与格式；认不出为 null。
///
/// 只按第一个冒号拆：格式里常有冒号（`HH:mm`），变量名里从来没有。冒号后
/// 是空白、或这个变量不收格式时整段认不出，由调用方原样保留。
(DiaryTemplateVariable, String?)? _parseVariableUse(String inner) {
  final separator = inner.indexOf(_formatSeparator);
  if (separator < 0) {
    final variable = parseDiaryTemplateVariable(inner);
    return variable == null ? null : (variable, null);
  }
  final variable = parseDiaryTemplateVariable(inner.substring(0, separator));
  final format = inner.substring(separator + 1).trim();
  if (variable == null || !variable.acceptsFormat || format.isEmpty) {
    return null;
  }
  return (variable, format);
}

/// 一个变量的占位写法，如 `{{日期}}`；带 [format] 时为 `{{时间:HH:mm}}`。
String diaryTemplateToken(String name, [String? format]) =>
    format == null ? '{{$name}}' : '{{$name:$format}}';

/// 替换 [text] 里认得的变量；认不出的写法、[valueOf] 返回 null 的变量原样
/// 保留（用户可能本来就想写花括号）。取值里的换行折成空格：变量在一行文字
/// 中间，换行会把那一行的段落格式拆到两行上。
String resolveDiaryTemplateText(String text, DiaryTemplateValueOf valueOf) {
  if (!text.contains('{{')) return text;
  return text.replaceAllMapped(_tokenPattern, (match) {
    final use = _parseVariableUse(match.group(1)!);
    final value = use == null ? null : valueOf(use.$1, use.$2);
    if (value == null) return match.group(0)!;
    return value.replaceAll(RegExp(r'[\r\n]+'), ' ');
  });
}

/// 逐个文字操作替换变量，格式属性不变。一个变量被拆在两段不同格式的文字
/// 里时不会被识别——编辑页“插入变量”总是把它作为同一段文字插入。
List<Map<String, Object?>> resolveDiaryTemplateOps(
  List<Map<String, Object?>> ops,
  DiaryTemplateValueOf valueOf,
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

/// [text] 里用到的全部变量（带格式的写法同样算用到了这个变量）。
Set<DiaryTemplateVariable> diaryTemplateVariablesIn(String text) {
  if (!text.contains('{{')) return const <DiaryTemplateVariable>{};
  return <DiaryTemplateVariable>{
    for (final match in _tokenPattern.allMatches(text))
      ?_parseVariableUse(match.group(1)!)?.$1,
  };
}
