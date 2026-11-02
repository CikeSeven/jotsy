import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_variables.dart';

void main() {
  String? valueOf(DiaryTemplateVariable variable, String? format) =>
      switch ((variable, format)) {
        (DiaryTemplateVariable.date, null) => '10月18日',
        (DiaryTemplateVariable.weekday, null) => '星期日',
        (DiaryTemplateVariable.question, null) => '第一行\n第二行',
        _ => null,
      };

  /// 把收到的格式原样写出来，看清楚冒号后哪一段被当成了格式。
  String? echoFormat(DiaryTemplateVariable variable, String? format) =>
      '${variable.name}|${format ?? '-'}';

  test('Chinese and English names resolve to the same value', () {
    expect(resolveDiaryTemplateText('{{日期}}', valueOf), '10月18日');
    expect(resolveDiaryTemplateText('{{date}}', valueOf), '10月18日');
    expect(resolveDiaryTemplateText('{{ Date }}', valueOf), '10月18日');
    expect(resolveDiaryTemplateText('{{weekDay}}', valueOf), '星期日');
  });

  test('several tokens in one string are all replaced', () {
    expect(
      resolveDiaryTemplateText('{{日期}} {{星期}} · {{date}}', valueOf),
      '10月18日 星期日 · 10月18日',
    );
  });

  test('unknown names and variables without a value stay as written', () {
    expect(resolveDiaryTemplateText('{{心情}}', valueOf), '{{心情}}');
    expect(resolveDiaryTemplateText('{{时间}}', valueOf), '{{时间}}');
    expect(resolveDiaryTemplateText('{单花括号}', valueOf), '{单花括号}');
    expect(resolveDiaryTemplateText('{{}}', valueOf), '{{}}');
  });

  test('line breaks in a value become spaces', () {
    expect(resolveDiaryTemplateText('> {{今日一问}}', valueOf), '> 第一行 第二行');
  });

  test('ops are resolved run by run and keep their attributes', () {
    final ops = resolveDiaryTemplateOps(<Map<String, Object?>>[
      <String, Object?>{
        'insert': '{{日期}}',
        'attributes': <String, Object?>{'bold': true},
      },
      <String, Object?>{'insert': '{{da'},
      <String, Object?>{'insert': 'te}}\n'},
      <String, Object?>{
        'insert': <String, Object?>{'divider': 'hr'},
      },
    ], valueOf);
    expect(ops[0], <String, Object?>{
      'insert': '10月18日',
      'attributes': <String, Object?>{'bold': true},
    });
    // 被拆在两段文字里的变量不识别。
    expect(ops[1]['insert'], '{{da');
    expect(ops[2]['insert'], 'te}}\n');
    expect(ops[3]['insert'], <String, Object?>{'divider': 'hr'});
  });

  test('lists the variables a text uses', () {
    expect(diaryTemplateVariablesIn('{{今日一问}} 与 {{date}} 和 {{未知}}'), {
      DiaryTemplateVariable.question,
      DiaryTemplateVariable.date,
    });
    expect(diaryTemplateVariablesIn('没有变量'), isEmpty);
  });

  test('a bare time name passes no format', () {
    expect(resolveDiaryTemplateText('{{时间}}', echoFormat), 'time|-');
    expect(resolveDiaryTemplateText('{{ Time }}', echoFormat), 'time|-');
  });

  test('the time format is everything after the first colon', () {
    expect(resolveDiaryTemplateText('{{时间:HH:mm}}', echoFormat), 'time|HH:mm');
    expect(
      resolveDiaryTemplateText('{{time:h:mm a}}', echoFormat),
      'time|h:mm a',
    );
    // 两侧空白不算格式；中文输入法下的全角冒号同样分隔。
    expect(
      resolveDiaryTemplateText('{{ 时间 : HH:mm }}', echoFormat),
      'time|HH:mm',
    );
    expect(resolveDiaryTemplateText('{{时间：H点mm分}}', echoFormat), 'time|H点mm分');
  });

  test('an empty format or a format on another variable stays as written', () {
    expect(resolveDiaryTemplateText('{{时间:}}', echoFormat), '{{时间:}}');
    expect(resolveDiaryTemplateText('{{time: }}', echoFormat), '{{time: }}');
    expect(
      resolveDiaryTemplateText('{{日期:yyyy-MM-dd}}', echoFormat),
      '{{日期:yyyy-MM-dd}}',
    );
    expect(resolveDiaryTemplateText('{{心情:x}}', echoFormat), '{{心情:x}}');
  });

  test('a formatted time counts as using the time variable', () {
    expect(diaryTemplateVariablesIn('{{时间:HH:mm}} {{日期:yyyy}}'), {
      DiaryTemplateVariable.time,
    });
  });

  test('tokens are written with an optional format', () {
    expect(diaryTemplateToken('时间'), '{{时间}}');
    expect(diaryTemplateToken('time', 'h:mm a'), '{{time:h:mm a}}');
  });
}
