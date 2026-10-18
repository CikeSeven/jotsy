import 'package:flutter_test/flutter_test.dart';
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
        .withHidden('builtin.dream', true)
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
        .withHidden('builtin.work', true)
        .withHidden('user-id', true);
    expect(prefs.hiddenBuiltIns, {'builtin.work'});
    expect(
      prefs.withHidden('builtin.work', false),
      DiaryTemplatePrefs.defaults,
    );
  });
}
