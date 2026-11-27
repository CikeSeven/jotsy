import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_quick_parse.dart';

/// 2026-11-08 是周日。
final DateTime _today = DateTime(2026, 11, 8);

TodoQuickParse _parse(String text) => parseTodoQuickInput(text, today: _today);

int _hm(int hour, int minute) => hour * 60 + minute;

/// 快速新建的重复与提醒识别：四种写法同时生效，与日期、时刻不重叠。
void main() {
  group('重复', () {
    test('every-day forms in four languages', () {
      for (final text in <String>[
        '每天 背单词',
        '毎日 単語',
        'every day vocab',
        'daily vocab',
        'каждый день слова',
      ]) {
        final parse = _parse(text);
        expect(
          parse.repeat?.frequency,
          TodoRepeatFrequency.daily,
          reason: text,
        );
        // 没写日期：从今天开始。
        expect(parse.date, _today, reason: text);
        expect(parse.repeatRule?.anchor, _today, reason: text);
      }
      expect(_parse('每3天 浇花').repeat?.interval, 3);
      expect(_parse('every 2 days water').repeat?.interval, 2);
      expect(_parse('каждые 5 дней полить').repeat?.interval, 5);
      expect(_parse('2日ごと 水やり').repeat?.interval, 2);
    });

    test('weekly with days starts on the first matching day', () {
      final zh = _parse('每周一三五 跑步');
      expect(zh.repeat?.weekdays, <int>[1, 3, 5]);
      expect(zh.date, DateTime(2026, 11, 9));
      expect(zh.title, '跑步');
      expect(_parse('毎週火・木 ジム').repeat?.weekdays, <int>[2, 4]);
      expect(_parse('every Monday and Thursday gym').repeat?.weekdays, <int>[
        1,
        4,
      ]);
      expect(_parse('по средам бассейн').repeat?.weekdays, <int>[3]);
      expect(_parse('каждую пятницу отчёт').repeat?.weekdays, <int>[5]);
      // 今天（周日）就符合：从今天开始。
      expect(_parse('每周日 大扫除').date, _today);
      expect(_parse('每周末 爬山').repeat?.weekdays, <int>[6, 7]);
    });

    test('workdays, monthly and yearly', () {
      expect(
        _parse('工作日 站会').repeat?.frequency,
        TodoRepeatFrequency.legalWorkdays,
      );
      // 工作日后面紧跟汉字是别的词。
      expect(_parse('写工作日报').repeat, isNull);
      expect(_parse('weekdays standup').repeat?.weekdays, <int>[1, 2, 3, 4, 5]);
      expect(_parse('по будням зарядка').repeat?.weekdays, <int>[
        1,
        2,
        3,
        4,
        5,
      ]);
      final monthly = _parse('每月15号 还信用卡');
      expect(monthly.repeat?.frequency, TodoRepeatFrequency.monthly);
      expect(monthly.date, DateTime(2026, 11, 15));
      expect(monthly.title, '还信用卡');
      expect(
        _parse('monthly review').repeat?.frequency,
        TodoRepeatFrequency.monthly,
      );
      expect(_parse('毎年 健康診断').repeat?.frequency, TodoRepeatFrequency.yearly);
      expect(
        _parse('ежегодно техосмотр').repeat?.frequency,
        TodoRepeatFrequency.yearly,
      );
    });

    test('a written date wins as the anchor; time still parses', () {
      final parse = _parse('每周一 早上9点 例会 11月16日');
      expect(parse.repeat?.weekdays, <int>[1]);
      expect(parse.date, DateTime(2026, 11, 16));
      expect(parse.minute, _hm(9, 0));
      expect(parse.repeatRule?.anchor, DateTime(2026, 11, 16));
    });
  });

  group('提醒', () {
    test('minutes before a timed due in four languages', () {
      for (final (text, minutes) in <(String, int)>[
        ('明天下午3点 开会 提前10分钟', 10),
        ('明天下午3点 开会 提前半小时', 30),
        ('tomorrow 3pm meeting remind me 2 hours before', 120),
        ('明日 15時 会議 10分前に通知', 10),
        ('завтра в 15:00 встреча за 15 минут', 15),
      ]) {
        final parse = _parse(text);
        expect(parse.reminder?.minutesBefore, minutes, reason: text);
        expect(
          parse.reminder?.resolve(dueMinute: parse.minute, allDayMinute: 540),
          TodoReminder.beforeDue(minutes),
          reason: text,
        );
      }
    });

    test('the day before at a set time is a reminder, not the due time', () {
      final parse = _parse('周五 交报告 前一天晚上8点提醒');
      expect(parse.date, DateTime(2026, 11, 13));
      expect(parse.minute, isNull);
      expect(parse.title, '交报告');
      expect(
        parse.reminder?.resolve(dueMinute: null, allDayMinute: 540),
        const TodoReminder.onDay(days: -1, minute: 20 * 60),
      );
      // 提前一天、没写时刻：全天待办取默认提醒时刻。
      expect(
        _parse(
          '明天 交房租 提前一天',
        ).reminder?.resolve(dueMinute: null, allDayMinute: 540),
        const TodoReminder.onDay(days: -1, minute: 540),
      );
    });

    test(
      'reminders without a due, or minutes on an all-day due, stay text',
      () {
        expect(_parse('提前10分钟 出门').reminder, isNull);
        expect(_parse('提前10分钟 出门').title, '提前10分钟 出门');
        expect(_parse('明天 体检 提前10分钟').reminder, isNull);
      },
    );
  });
}
