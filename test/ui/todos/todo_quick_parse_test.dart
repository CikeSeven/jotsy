import 'package:flutter/services.dart' show TextRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_quick_parse.dart';

/// 2026-11-08 是周日。
final DateTime _today = DateTime(2026, 11, 8);

TodoQuickParse _parse(
  String text, {
  Map<String, String> lists = const {},
  Set<TodoQuickTokenKind> ignore = const {},
}) => parseTodoQuickInput(text, today: _today, lists: lists, ignore: ignore);

/// 各片段在原文里截出的文字，便于一眼核对范围。
Map<TodoQuickTokenKind, String> _pieces(String text, TodoQuickParse parse) => {
  for (final token in parse.tokens) token.kind: token.range.textInside(text),
};

int _hm(int hour, int minute) => hour * 60 + minute;

void main() {
  group('中文', () {
    test('日期、时段时刻、清单与优先级一起识别', () {
      const text = '明天下午3点 开会 #工作 !!!';
      final parse = _parse(text, lists: {'work': '工作'});
      expect(parse.title, '开会');
      expect(parse.date, DateTime(2026, 11, 9));
      expect(parse.minute, _hm(15, 0));
      expect(parse.listId, 'work');
      expect(parse.priority, TodoPriority.high);
      expect(parse.tokens.map((t) => t.kind), [
        TodoQuickTokenKind.date,
        TodoQuickTokenKind.time,
        TodoQuickTokenKind.list,
        TodoQuickTokenKind.priority,
      ]);
      expect(parse.tokens.map((t) => t.range), const [
        TextRange(start: 0, end: 2),
        TextRange(start: 2, end: 6),
        TextRange(start: 10, end: 13),
        TextRange(start: 14, end: 17),
      ]);
    });

    test('周X 取今天之后最近的一天，今天是周日时“周日”是下周日', () {
      expect(_parse('周五 交报告').date, DateTime(2026, 11, 13));
      expect(_parse('周五 交报告').title, '交报告');
      expect(_parse('星期天 休息').date, DateTime(2026, 11, 15));
      expect(_parse('礼拜三 体检').date, DateTime(2026, 11, 11));
    });

    test('下周X 取下一周（周一开始）里的那一天', () {
      const text = '下周一 9:30 例会';
      final parse = _parse(text);
      expect(parse.date, DateTime(2026, 11, 9));
      expect(parse.minute, _hm(9, 30));
      expect(parse.title, '例会');
      expect(_pieces(text, parse), {
        TodoQuickTokenKind.date: '下周一',
        TodoQuickTokenKind.time: '9:30',
      });
      expect(_parse('下下周五 复查').date, DateTime(2026, 11, 20));
      expect(_parse('下个星期三 交稿').date, DateTime(2026, 11, 11));
    });

    test('周X 后面紧跟汉字不识别，紧跟时段词照样识别', () {
      final weekly = _parse('周一例会');
      expect(weekly.isEmpty, isTrue);
      expect(weekly.title, '周一例会');
      expect(_parse('一周一次').isEmpty, isTrue);
      expect(_parse('每周一 例会').isEmpty, isTrue);

      final parse = _parse('周五下午3点开会');
      expect(parse.date, DateTime(2026, 11, 13));
      expect(parse.minute, _hm(15, 0));
      expect(parse.title, '开会');
    });

    test('相对日期词后面紧跟汉字也识别', () {
      expect(_parse('明天开会').date, DateTime(2026, 11, 9));
      expect(_parse('明天开会').title, '开会');
      expect(_parse('今天买菜').date, _today);
      expect(_parse('后天交房租').date, DateTime(2026, 11, 10));
      expect(_parse('大后天出发').date, DateTime(2026, 11, 11));
    });

    test('月日与只有日', () {
      expect(_parse('11月20日 体检').date, DateTime(2026, 11, 20));
      expect(_parse('11月20号体检').title, '体检');
      expect(_parse('3月1日 报税').date, DateTime(2027, 3, 1));
      expect(_parse('2027年1月2日 出发').date, DateTime(2027, 1, 2));

      final day = _parse('20号 还信用卡');
      expect(day.date, DateTime(2026, 11, 20));
      expect(day.title, '还信用卡');
      // 今天就是 8 号；5 号已过取下个月；11 月没有 31 号取 12 月。
      expect(_parse('8号 交水费').date, _today);
      expect(_parse('5号 交电费').date, DateTime(2026, 12, 5));
      expect(_parse('31日 结账').date, DateTime(2026, 12, 31));
    });

    test('非法日期不识别，也不退化成只有日', () {
      final parse = _parse('2月30日 体检');
      expect(parse.isEmpty, isTrue);
      expect(parse.title, '2月30日 体检');
      expect(_parse('13/5 开会').isEmpty, isTrue);
      expect(_parse('2026-02-30 续费').isEmpty, isTrue);
      // 2 月 29 日顺延到下一个闰年。
      expect(_parse('2月29日 纪念').date, DateTime(2028, 2, 29));
    });

    test('时刻：时段换算、半与分、只有时刻时日期为今天', () {
      expect(_parse('下午3点半 开会').minute, _hm(15, 30));
      expect(_parse('上午10点15分 面试').minute, _hm(10, 15));
      expect(_parse('晚上8点 跑步').minute, _hm(20, 0));
      expect(_parse('中午12点 午饭').minute, _hm(12, 0));
      expect(_parse('中午1点 午睡').minute, _hm(13, 0));
      expect(_parse('下午三点 开会').minute, _hm(15, 0));
      expect(_parse('15点 交接').minute, _hm(15, 0));

      // 不带时段按字面；已经过了的时刻照样是今天。
      final parse = _parse('3点 提醒');
      expect(parse.minute, _hm(3, 0));
      expect(parse.date, _today);
      expect(parse.title, '提醒');

      // 时刻后面紧跟汉字照样识别。
      final meeting = _parse('下午3点开会');
      expect(meeting.minute, _hm(15, 0));
      expect(meeting.title, '开会');
    });

    test('今晚 的时刻按晚上算', () {
      final parse = _parse('今晚8点 吃饭');
      expect(parse.date, _today);
      expect(parse.minute, _hm(20, 0));
      expect(parse.title, '吃饭');
    });

    test('“快一点”“第三点”不是时刻', () {
      expect(_parse('快一点 写完').isEmpty, isTrue);
      expect(_parse('第三点 补充').isEmpty, isTrue);
      expect(_parse('一点半 开会').minute, _hm(1, 30));
    });
  });

  group('英文', () {
    test('tomorrow + 3pm', () {
      const text = 'buy milk tomorrow 3pm';
      final parse = _parse(text);
      expect(parse.title, 'buy milk');
      expect(parse.date, DateTime(2026, 11, 9));
      expect(parse.minute, _hm(15, 0));
      expect(_pieces(text, parse), {
        TodoQuickTokenKind.date: 'tomorrow',
        TodoQuickTokenKind.time: '3pm',
      });
    });

    test('on friday at 18:30 连同 on / at 一起吃掉', () {
      const text = 'call mom on friday at 18:30';
      final parse = _parse(text);
      expect(parse.title, 'call mom');
      expect(parse.date, DateTime(2026, 11, 13));
      expect(parse.minute, _hm(18, 30));
      expect(_pieces(text, parse), {
        TodoQuickTokenKind.date: 'on friday',
        TodoQuickTokenKind.time: 'at 18:30',
      });
    });

    test('next mon、月日、日月，不区分大小写', () {
      expect(_parse('report next mon').date, DateTime(2026, 11, 9));
      expect(_parse('report next mon').title, 'report');
      final dentist = _parse('Jan 5 dentist');
      expect(dentist.date, DateTime(2027, 1, 5));
      expect(dentist.title, 'dentist');
      expect(_parse('dentist January 5th').date, DateTime(2027, 1, 5));
      expect(_parse('pay rent 5 Dec').date, DateTime(2026, 12, 5));
      expect(_parse('TOMORROW gym').date, DateTime(2026, 11, 9));
      expect(_parse('gym tmr').date, DateTime(2026, 11, 9));
    });

    test('am / pm 与 at 的换算', () {
      expect(_parse('standup 11am').minute, _hm(11, 0));
      expect(_parse('call 3:30 PM').minute, _hm(15, 30));
      expect(_parse('backup 12am').minute, 0);
      expect(_parse('lunch 12pm').minute, _hm(12, 0));
      expect(_parse('meet at 3').minute, _hm(3, 0));
      expect(_parse('dinner tonight at 8').minute, _hm(20, 0));
    });

    test('按单词边界：单词里的星期缩写不算', () {
      expect(_parse('monster truck').isEmpty, isTrue);
      expect(_parse('sunday school').date, DateTime(2026, 11, 15));
    });
  });

  group('日文', () {
    test('明日 午後3時', () {
      const text = '明日 午後3時 会議';
      final parse = _parse(text);
      expect(parse.date, DateTime(2026, 11, 9));
      expect(parse.minute, _hm(15, 0));
      expect(parse.title, '会議');
      expect(_pieces(text, parse), {
        TodoQuickTokenKind.date: '明日',
        TodoQuickTokenKind.time: '午後3時',
      });
    });

    test('来週月曜、曜日与時分', () {
      final parse = _parse('来週月曜 提出');
      expect(parse.date, DateTime(2026, 11, 9));
      expect(parse.title, '提出');
      expect(_parse('金曜日に 飲み会').date, DateTime(2026, 11, 13));
      expect(_parse('毎週月曜 ゴミ出し').isEmpty, isTrue);
      expect(_parse('午前10時半 歯医者').minute, _hm(10, 30));
      expect(_parse('15時30分 打ち合わせ').minute, _hm(15, 30));
      expect(_parse('3時間 勉強').isEmpty, isTrue);
      expect(_parse('来週の月曜日 面接').date, DateTime(2026, 11, 9));
    });
  });

  group('俄文', () {
    test('завтра в 15:00', () {
      const text = 'завтра в 15:00 встреча';
      final parse = _parse(text);
      expect(parse.date, DateTime(2026, 11, 9));
      expect(parse.minute, _hm(15, 0));
      expect(parse.title, 'встреча');
      expect(_pieces(text, parse), {
        TodoQuickTokenKind.date: 'завтра',
        TodoQuickTokenKind.time: 'в 15:00',
      });
    });

    test('星期、下周与月份属格', () {
      final report = _parse('в пятницу отчёт');
      expect(report.date, DateTime(2026, 11, 13));
      expect(report.title, 'отчёт');
      expect(_parse('во вторник врач').date, DateTime(2026, 11, 10));
      expect(_parse('пт отчёт').date, DateTime(2026, 11, 13));
      expect(
        _parse('в следующий понедельник план').date,
        DateTime(2026, 11, 9),
      );
      final doctor = _parse('20 ноября врач');
      expect(doctor.date, DateTime(2026, 11, 20));
      expect(doctor.title, 'врач');
      expect(_parse('Послезавтра спорт').date, DateTime(2026, 11, 10));
    });

    test('в 3 часа 按字面，带 дня / вечера 换算', () {
      expect(_parse('в 3 часа звонок').minute, _hm(3, 0));
      expect(_parse('в 7 часов вечера ужин').minute, _hm(19, 0));
      expect(_parse('в 2 часа дня обед').minute, _hm(14, 0));

      const text = 'в пятницу в 15:00 созвон';
      final parse = _parse(text);
      expect(parse.title, 'созвон');
      expect(_pieces(text, parse), {
        TodoQuickTokenKind.date: 'в пятницу',
        TodoQuickTokenKind.time: 'в 15:00',
      });
    });
  });

  group('数字日期', () {
    test('年月日与月日', () {
      final renew = _parse('2026-12-01 续费');
      expect(renew.date, DateTime(2026, 12, 1));
      expect(renew.title, '续费');
      expect(_parse('2027/1/15 体检').date, DateTime(2027, 1, 15));
      expect(_parse('11/20 体检').date, DateTime(2026, 11, 20));
      expect(_parse('体检 11-20').date, DateTime(2026, 11, 20));
      // 已过的月日取明年；写了年份的过去日期照样认。
      expect(_parse('3/1 报税').date, DateTime(2027, 3, 1));
      expect(_parse('2025-01-01 补记').date, DateTime(2025, 1, 1));
    });

    test('前后紧挨数字不识别', () {
      expect(_parse('编号 123/45').isEmpty, isTrue);
      expect(_parse('版本 1:234').isEmpty, isTrue);
    });
  });

  group('清单', () {
    test('不存在的清单原样保留', () {
      final parse = _parse('#不存在 买菜', lists: {'work': '工作'});
      expect(parse.isEmpty, isTrue);
      expect(parse.listId, isNull);
      expect(parse.title, '#不存在 买菜');
    });

    test('多个清单前缀冲突取最长，名称可含空格，不区分大小写', () {
      const lists = {'home': '家', 'chores': '家 务', 'work': 'Work'};
      const text = '扫地 #家 务';
      final parse = _parse(text, lists: lists);
      expect(parse.listId, 'chores');
      expect(parse.title, '扫地');
      expect(_pieces(text, parse), {TodoQuickTokenKind.list: '#家 务'});

      expect(_parse('#家务', lists: lists).listId, 'home');
      expect(_parse('report ＃work', lists: lists).listId, 'work');
      expect(_parse('#workout', lists: lists).isEmpty, isTrue);
    });

    test('清单名里的日期词不另算日期', () {
      const text = '#明天要做 洗车';
      final parse = _parse(text, lists: {'todo': '明天要做'});
      expect(parse.listId, 'todo');
      expect(parse.date, isNull);
      expect(parse.title, '洗车');
    });
  });

  group('优先级', () {
    test('感叹号个数与全角混用', () {
      expect(_parse('交报告 !').priority, TodoPriority.low);
      expect(_parse('交报告 ！!').priority, TodoPriority.medium);
      expect(_parse('!!!! 交报告').priority, TodoPriority.high);
    });

    test('紧跟文字的感叹号不算', () {
      final parse = _parse('你好!');
      expect(parse.isEmpty, isTrue);
      expect(parse.priority, isNull);
      expect(parse.title, '你好!');
      expect(_parse('!你好').isEmpty, isTrue);
    });
  });

  group('ignore 与边界', () {
    test('ignore 的种类不识别，原文留在标题里', () {
      final parse = _parse('明天 开会 下午3点', ignore: {TodoQuickTokenKind.date});
      expect(parse.title, '明天 开会');
      expect(parse.minute, _hm(15, 0));
      // 只识别出时刻时日期为今天。
      expect(parse.date, _today);
      expect(parse.tokens.map((t) => t.kind), [TodoQuickTokenKind.time]);

      final none = _parse(
        '明天 开会',
        ignore: {TodoQuickTokenKind.date, TodoQuickTokenKind.time},
      );
      expect(none.isEmpty, isTrue);
      expect(none.date, isNull);
      expect(none.title, '明天 开会');
    });

    test('空字符串与只有标点', () {
      final empty = _parse('');
      expect(empty.isEmpty, isTrue);
      expect(empty.title, '');
      expect(empty, TodoQuickParse.none);
      expect(_parse('   ').title, '');
      final marks = _parse('。，？');
      expect(marks.isEmpty, isTrue);
      expect(marks.title, '。，？');
      // 只有优先级时标题为空。
      final bang = _parse('!!!');
      expect(bang.priority, TodoPriority.high);
      expect(bang.title, '');
    });

    test('标题空白折叠，接缝两侧都是中文时去掉空格', () {
      expect(_parse('  买   牛奶  ').title, '买 牛奶');
      expect(_parse('开会 明天 准备材料').title, '开会准备材料');
      expect(_parse('buy   milk  tomorrow   now').title, 'buy milk now');
      expect(_parse('开会 tomorrow 准备').title, '开会准备');
      // 接缝一侧不是中文时留一个空格。
      expect(_parse('开会 明天 prep').title, '开会 prep');
      // 原本没有空白的接缝直接相连。
      expect(_parse('提交明天报告').title, '提交报告');
    });

    test('每种只取第一个，tokens 按位置升序', () {
      const text = '后天 买菜 明天 下午3点 晚上8点';
      final parse = _parse(text);
      expect(parse.date, DateTime(2026, 11, 10));
      expect(parse.minute, _hm(15, 0));
      // 只有去掉片段的接缝会去空格，“买菜 明天”之间原有的空格保留。
      expect(parse.title, '买菜 明天晚上8点');
      expect(parse.tokens.map((t) => t.range.start), [0, 9]);
    });

    test('today 带时分秒时只取日期', () {
      final parse = parseTodoQuickInput(
        '明天 开会',
        today: DateTime(2026, 11, 8, 15, 30),
      );
      expect(parse.date, DateTime(2026, 11, 9));
    });
  });
}
