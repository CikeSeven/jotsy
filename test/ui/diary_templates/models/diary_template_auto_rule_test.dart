import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_auto_rule.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';

/// 按时间段自动套用：区间命中（含跨夜与星期）、多条命中时的先后、补写只用
/// 默认模板。
void main() {
  DiaryTemplateAutoRule rule(
    String from,
    String to,
    String id, {
    Set<int> days = const <int>{},
  }) {
    int minute(String hhmm) {
      final [h, m] = hhmm.split(':').map(int.parse).toList();
      return h * 60 + m;
    }

    return DiaryTemplateAutoRule(
      startMinute: minute(from),
      endMinute: minute(to),
      weekdays: days,
      templateId: id,
    );
  }

  // 2026-10-19 是周一，2026-10-25 是周日。
  DateTime mon(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 19, hour, minute);
  DateTime sun(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 25, hour, minute);

  List<String> candidates(
    List<DiaryTemplateAutoRule> rules,
    DateTime now, {
    DateTime? diaryDate,
    String? fallback = 'default',
  }) => DiaryTemplatePrefs(autoTemplateId: fallback)
      .withAutoRules(rules)
      .autoApplyCandidates(now: now, diaryDate: diaryDate ?? now);

  test('a same-day range covers its start and stops at its end', () {
    final morning = rule('07:00', '10:00', 'morning');
    expect(morning.matches(mon(6, 59)), isFalse);
    expect(morning.matches(mon(7)), isTrue);
    expect(morning.matches(mon(9, 59)), isTrue);
    expect(morning.matches(mon(10)), isFalse);
    expect(candidates([morning], mon(8)), ['morning', 'default']);
    expect(candidates([morning], mon(11)), ['default']);
  });

  test('an overnight range matches on both sides of midnight', () {
    final night = rule('22:00', '02:00', 'night');
    expect(night.crossesMidnight, isTrue);
    expect(night.durationMinutes, 240);
    expect(night.matches(mon(21, 59)), isFalse);
    expect(night.matches(mon(23)), isTrue);
    expect(night.matches(mon(1, 59)), isTrue);
    expect(night.matches(mon(2)), isFalse);
  });

  test('an overnight range belongs to the weekday it starts on', () {
    final sundayNight = rule('22:00', '02:00', 'sun', days: {7});
    final mondayNight = rule('22:00', '02:00', 'mon', days: {1});
    // 周一凌晨 1 点属于周日晚上开始的那一段。
    expect(sundayNight.matches(mon(1)), isTrue);
    expect(mondayNight.matches(mon(1)), isFalse);
    expect(sundayNight.matches(sun(23)), isTrue);
    expect(mondayNight.matches(mon(23)), isTrue);
    expect(sundayNight.matches(sun(1)), isFalse, reason: '那是周六晚上开始的');
  });

  test('the weekday filter skips other days', () {
    final weekend = rule('07:00', '10:00', 'weekend', days: {6, 7});
    expect(candidates([weekend], sun(8)), ['weekend', 'default']);
    expect(candidates([weekend], mon(8)), ['default']);
  });

  test('a rule with weekdays beats an every-day rule, then shorter wins', () {
    final everyDayShort = rule('08:00', '09:00', 'everyday-short');
    final mondayLong = rule('06:00', '12:00', 'monday-long', days: {1});
    final everyDayLong = rule('07:00', '11:00', 'everyday-long');
    expect(candidates([everyDayLong, everyDayShort, mondayLong], mon(8, 30)), [
      'monday-long',
      'everyday-short',
      'everyday-long',
      'default',
    ]);
  });

  test('equal specificity falls back to the earlier start', () {
    expect(
      candidates([
        rule('08:00', '10:00', 'later'),
        rule('07:00', '09:00', 'earlier'),
      ], mon(8, 30)),
      ['earlier', 'later', 'default'],
    );
  });

  test('backfilling or writing for a future day only uses the default', () {
    final morning = rule('07:00', '10:00', 'morning');
    expect(candidates([morning], mon(8), diaryDate: DateTime(2026, 10, 18)), [
      'default',
    ]);
    expect(candidates([morning], mon(8), diaryDate: DateTime(2026, 10, 20)), [
      'default',
    ]);
    // 同一天的其他时刻仍算今天。
    expect(candidates([morning], mon(8), diaryDate: DateTime(2026, 10, 19)), [
      'morning',
      'default',
    ]);
  });

  test('no rules means only the default, and nothing when it is unset', () {
    expect(candidates(const [], mon(8)), ['default']);
    expect(candidates(const [], mon(8), fallback: null), isEmpty);
    expect(candidates([rule('07:00', '10:00', 'default')], mon(8)), [
      'default',
    ], reason: '同一个模板只尝试一次');
  });
}
