import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_auto_rule.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';

void main() {
  test('defaults encode to null so the settings key is removed', () {
    expect(DiaryTemplatePrefs.defaults.encode(), isNull);
    expect(DiaryTemplatePrefs.decode(null), DiaryTemplatePrefs.defaults);
    expect(DiaryTemplatePrefs.decode('{'), DiaryTemplatePrefs.defaults);
    expect(DiaryTemplatePrefs.decode('[]'), DiaryTemplatePrefs.defaults);
  });

  test('round-trips every field', () {
    final prefs = DiaryTemplatePrefs.defaults
        .withStrip(false)
        .withAuto('builtin.daily')
        .withHidden('builtin.emotion', true)
        .recordUse('a')
        .recordUse('builtin.daily');
    expect(DiaryTemplatePrefs.decode(prefs.encode()), prefs);
    expect(prefs.recent, ['builtin.daily', 'a']);
  });

  test('broken fields fall back one by one', () {
    final prefs = DiaryTemplatePrefs.decode(
      '{"strip":"no","auto":"  ","hidden":["builtin.a","user-id",3],'
      '"recent":["x","x","",7,"y"]}',
    );
    expect(prefs.showStrip, isTrue);
    expect(prefs.autoTemplateId, isNull);
    expect(prefs.hiddenBuiltIns, {'builtin.a'});
    expect(prefs.recent, ['x', 'y']);
  });

  test('recent use moves to the front and keeps at most six', () {
    var prefs = DiaryTemplatePrefs.defaults;
    for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
      prefs = prefs.recordUse(id);
    }
    expect(prefs.recent, ['g', 'f', 'e', 'd', 'c', 'b']);
    expect(prefs.recordUse('d').recent, ['d', 'g', 'f', 'e', 'c', 'b']);
  });

  test('only built-in templates can be hidden', () {
    final prefs = DiaryTemplatePrefs.defaults
        .withHidden('builtin.reading', true)
        .withHidden('user-id', true);
    expect(prefs.hiddenBuiltIns, {'builtin.reading'});
    expect(
      prefs.withHidden('builtin.reading', false),
      DiaryTemplatePrefs.defaults,
    );
  });

  test('time range rules round-trip sorted and are written sparsely', () {
    const weekend = DiaryTemplateAutoRule(
      startMinute: 420,
      endMinute: 600,
      weekdays: {7, 6},
      templateId: 'builtin.weekly',
    );
    const night = DiaryTemplateAutoRule(
      startMinute: 1320,
      endMinute: 120,
      templateId: 'builtin.night',
    );
    final prefs = DiaryTemplatePrefs.defaults.withAutoRules([night, weekend]);
    expect(prefs.autoRules, [weekend, night]);
    final raw = prefs.encode()!;
    expect(
      raw,
      contains(
        '"rules":[{"from":420,"to":600,"days":[6,7],"id":"builtin.weekly"},'
        '{"from":1320,"to":120,"id":"builtin.night"}]',
      ),
    );
    expect(DiaryTemplatePrefs.decode(raw), prefs);
    expect(DiaryTemplatePrefs.defaults.encode(), isNull);
    expect(
      DiaryTemplatePrefs.defaults.withAutoRules(const []).encode(),
      isNull,
    );
  });

  test('old prefs without rules decode unchanged', () {
    final prefs = DiaryTemplatePrefs.decode(
      '{"v":1,"auto":"builtin.daily","recent":["a"]}',
    );
    expect(prefs.autoTemplateId, 'builtin.daily');
    expect(prefs.recent, ['a']);
    expect(prefs.autoRules, isEmpty);
  });

  test('broken rules are dropped one by one and at most 12 are kept', () {
    final prefs = DiaryTemplatePrefs.decode(
      '{"auto":"builtin.daily","rules":['
      '"x",'
      '{"from":"7","to":600,"id":"a"},'
      '{"from":420,"to":1440,"id":"a"},'
      '{"from":-1,"to":600,"id":"a"},'
      '{"from":420,"to":420,"id":"a"},'
      '{"from":420,"to":600,"id":" "},'
      '{"from":420,"to":600,"id":"ok","days":[1,1,8,0,"2",7]}'
      ']}',
    );
    expect(prefs.autoTemplateId, 'builtin.daily');
    expect(prefs.autoRules, const [
      DiaryTemplateAutoRule(
        startMinute: 420,
        endMinute: 600,
        weekdays: {1, 7},
        templateId: 'ok',
      ),
    ]);
    expect(
      DiaryTemplatePrefs.decode('{"rules":{"from":1}}').autoRules,
      isEmpty,
    );

    final many = [
      for (var i = 0; i < 15; i++)
        '{"from":${i * 60},"to":${i * 60 + 30},"id":"t$i"}',
    ].join(',');
    final capped = DiaryTemplatePrefs.decode('{"rules":[$many]}').autoRules;
    expect(capped, hasLength(DiaryTemplatePrefs.maxAutoRules));
    expect(capped.last.templateId, 't11', reason: '保留先出现的 12 条');
  });
}
