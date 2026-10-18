import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_recommend.dart';

void main() {
  const morning = DiaryTemplateRecommendRules(
    slots: {DiaryTemplateTimeSlot.morning},
  );

  int? score(
    DiaryTemplateRecommendRules rules,
    DateTime now, [
    DateTime? day,
  ]) => scoreDiaryTemplate(rules, now: now, diaryDate: day ?? now);

  test('time slot boundaries', () {
    DiaryTemplateTimeSlot at(int h, int m) =>
        DiaryTemplateTimeSlot.of(DateTime(2026, 10, 18, h, m));
    expect(at(4, 59), DiaryTemplateTimeSlot.night);
    expect(at(5, 0), DiaryTemplateTimeSlot.morning);
    expect(at(10, 59), DiaryTemplateTimeSlot.morning);
    expect(at(11, 0), DiaryTemplateTimeSlot.afternoon);
    expect(at(16, 59), DiaryTemplateTimeSlot.afternoon);
    expect(at(17, 0), DiaryTemplateTimeSlot.evening);
    expect(at(21, 59), DiaryTemplateTimeSlot.evening);
    expect(at(22, 0), DiaryTemplateTimeSlot.night);
  });

  test('month start and end, including February in leap years', () {
    bool end(int y, int m, int d) =>
        DiaryTemplateMonthPhase.end.matches(DateTime(y, m, d));
    expect(DiaryTemplateMonthPhase.start.matches(DateTime(2026, 3, 3)), isTrue);
    expect(
      DiaryTemplateMonthPhase.start.matches(DateTime(2026, 3, 4)),
      isFalse,
    );
    expect(end(2026, 2, 26), isTrue);
    expect(end(2026, 2, 25), isFalse);
    expect(end(2028, 2, 26), isFalse);
    expect(end(2028, 2, 27), isTrue);
    expect(end(2026, 10, 29), isTrue);
    expect(end(2026, 10, 28), isFalse);
  });

  test('templates without rules are never recommended', () {
    expect(
      score(DiaryTemplateRecommendRules.none, DateTime(2026, 10, 18, 8)),
      isNull,
    );
  });

  test('a slot rule follows the current time', () {
    expect(score(morning, DateTime(2026, 10, 18, 8)), 1);
    expect(score(morning, DateTime(2026, 10, 18, 14)), isNull);
  });

  test('categories combine with AND, values within one with OR', () {
    const work = DiaryTemplateRecommendRules(
      slots: {DiaryTemplateTimeSlot.afternoon, DiaryTemplateTimeSlot.evening},
      weekdays: {1, 2, 3, 4, 5},
    );
    expect(score(work, DateTime(2026, 10, 16, 15)), 2); // 周五下午
    expect(score(work, DateTime(2026, 10, 16, 19)), 2); // 周五傍晚
    expect(score(work, DateTime(2026, 10, 17, 15)), isNull); // 周六
    expect(score(work, DateTime(2026, 10, 16, 9)), isNull); // 周五早上
  });

  test('backfilling skips slot rules and judges dates by the diary day', () {
    final now = DateTime(2026, 10, 19, 8); // 周一早上
    final sunday = DateTime(2026, 10, 18);
    expect(score(morning, now, sunday), isNull);
    const weekly = DiaryTemplateRecommendRules(weekdays: {7});
    expect(score(weekly, now, sunday), 1);
    expect(score(weekly, now), isNull);
    const weeklyMorning = DiaryTemplateRecommendRules(
      slots: {DiaryTemplateTimeSlot.evening},
      weekdays: {7},
    );
    expect(score(weeklyMorning, now, sunday), 1);
  });

  test('rules round-trip through JSON and drop bad values', () {
    const rules = DiaryTemplateRecommendRules(
      slots: {DiaryTemplateTimeSlot.night, DiaryTemplateTimeSlot.morning},
      weekdays: {7, 1},
      monthPhases: {DiaryTemplateMonthPhase.end},
    );
    expect(rules.toJson(), {
      'slots': ['morning', 'night'],
      'weekdays': [1, 7],
      'monthPhases': ['end'],
    });
    expect(DiaryTemplateRecommendRules.fromJson(rules.toJson()), rules);
    expect(
      DiaryTemplateRecommendRules.fromJson({
        'slots': ['dawn', 'evening', 3],
        'weekdays': [0, 8, 3, '1'],
        'monthPhases': 'end',
      }),
      const DiaryTemplateRecommendRules(
        slots: {DiaryTemplateTimeSlot.evening},
        weekdays: {3},
      ),
    );
    expect(
      DiaryTemplateRecommendRules.fromJson('x'),
      DiaryTemplateRecommendRules.none,
    );
    expect(DiaryTemplateRecommendRules.none.toJson(), isEmpty);
  });
}
