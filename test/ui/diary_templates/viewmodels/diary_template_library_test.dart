import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_recommend.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_library.dart';

void main() {
  const plain = DiaryTemplate(id: 'builtin.plain', name: 'plain');
  const morning = DiaryTemplate(
    id: 'builtin.morning',
    name: 'morning',
    recommend: DiaryTemplateRecommendRules(
      slots: {DiaryTemplateTimeSlot.morning},
    ),
  );
  const sundayMorning = DiaryTemplate(
    id: 'builtin.sunday',
    name: 'sunday morning',
    recommend: DiaryTemplateRecommendRules(
      slots: {DiaryTemplateTimeSlot.morning},
      weekdays: {7},
    ),
  );
  const hidden = DiaryTemplate(id: 'builtin.hidden', name: 'hidden');
  const mine = DiaryTemplate(id: 'u1', name: 'mine');
  const mine2 = DiaryTemplate(id: 'u2', name: 'mine 2');

  DiaryTemplateLibrary library([DiaryTemplatePrefs? prefs]) =>
      DiaryTemplateLibrary(
        builtIns: const [plain, morning, sundayMorning, hidden],
        userTemplates: const [mine, mine2],
        prefs:
            prefs ??
            DiaryTemplatePrefs.defaults.withHidden('builtin.hidden', true),
      );

  final sunday8am = DateTime(2026, 10, 18, 8);

  test('user templates come first and deleted built-ins are left out', () {
    expect(library().visible.map((t) => t.id), [
      'u1',
      'u2',
      'builtin.plain',
      'builtin.morning',
      'builtin.sunday',
    ]);
    expect(library().deletedBuiltIns, [hidden]);
    expect(library().byId('builtin.hidden'), isNull);
    expect(library().byId('missing'), isNull);
  });

  test('an edited built-in replaces the default in place', () {
    const edited = DiaryTemplate(id: 'builtin.morning', name: 'my morning');
    final lib = DiaryTemplateLibrary(
      builtIns: const [plain, morning, sundayMorning],
      userTemplates: const [mine, edited, mine2],
      prefs: DiaryTemplatePrefs.defaults,
    );
    expect(lib.userTemplates, [mine, mine2]);
    expect(lib.builtIns, [plain, edited, sundayMorning]);
    expect(lib.editedBuiltIns, {'builtin.morning'});
    expect(lib.byId('builtin.morning'), edited);
    expect(lib.visible.map((t) => t.id), [
      'u1',
      'u2',
      'builtin.plain',
      'builtin.morning',
      'builtin.sunday',
    ]);
  });

  test('a stored built-in id no version ships any more stays as mine', () {
    const orphan = DiaryTemplate(id: 'builtin.gone', name: 'gone');
    final lib = DiaryTemplateLibrary(
      builtIns: const [plain],
      userTemplates: const [orphan],
      prefs: DiaryTemplatePrefs.defaults,
    );
    expect(lib.userTemplates, [orphan]);
    expect(lib.editedBuiltIns, isEmpty);
  });

  test('recommended templates rank first, more specific ones higher', () {
    final ranked = library().ranked(now: sunday8am, diaryDate: sunday8am);
    expect(ranked.map((s) => s.template.id), [
      'builtin.sunday',
      'builtin.morning',
      'u1',
      'u2',
      'builtin.plain',
    ]);
    expect(ranked.map((s) => s.recommended), [true, true, false, false, false]);
  });

  test('suggestions are recommended, then recent, then library order', () {
    final prefs = DiaryTemplatePrefs.defaults
        .withHidden('builtin.hidden', true)
        .recordUse('builtin.morning')
        .recordUse('builtin.plain')
        .recordUse('deleted-template');
    final suggestions = library(
      prefs,
    ).suggestions(now: sunday8am, diaryDate: sunday8am, limit: 4);
    expect(suggestions.map((s) => s.template.id), [
      'builtin.sunday',
      'builtin.morning',
      'builtin.plain',
      'u1',
    ]);
  });

  test('the auto template is null once it is deleted', () {
    expect(
      library(
        DiaryTemplatePrefs.defaults.withAuto('builtin.plain'),
      ).autoTemplate,
      plain,
    );
    final withAuto = DiaryTemplatePrefs.defaults
        .withHidden('builtin.hidden', true)
        .withAuto('builtin.hidden');
    expect(library(withAuto).autoTemplate, isNull);
    expect(
      library(DiaryTemplatePrefs.defaults.withAuto('gone')).autoTemplate,
      isNull,
    );
  });
}
