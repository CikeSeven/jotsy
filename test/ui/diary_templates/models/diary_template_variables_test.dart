import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_variables.dart';

void main() {
  String? valueOf(DiaryTemplateVariable variable) => switch (variable) {
    DiaryTemplateVariable.date => '10月18日',
    DiaryTemplateVariable.weekday => '星期日',
    DiaryTemplateVariable.question => '第一行\n第二行',
    _ => null,
  };

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
}
