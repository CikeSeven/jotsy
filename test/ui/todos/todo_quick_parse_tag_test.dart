import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_quick_parse.dart';

/// 快速新建识别 `@标签`：多个标签、已有标签优先、邮箱不算、新标签在下一个
/// 片段前结束、单个点掉。
void main() {
  final today = DateTime(2026, 11, 28);

  TodoQuickParse parse(
    String text, {
    List<String> tags = const <String>[],
    Set<String> ignoreTags = const <String>{},
  }) => parseTodoQuickInput(
    text,
    today: today,
    lists: const <String, String>{'l1': '工作'},
    tags: tags,
    ignoreTags: ignoreTags,
  );

  test('several tags come out in text order and leave the title', () {
    final p = parse('买牛奶 @家务 @采购');
    expect(p.tags, <String>['家务', '采购']);
    expect(p.title, '买牛奶');
    expect(
      p.tokens.where((t) => t.kind == TodoQuickTokenKind.tag),
      hasLength(2),
    );
  });

  test('emails and a mid-word @ are not tags', () {
    final p = parse('发邮件给 a@b.com 和 me@example');
    expect(p.tags, isEmpty);
    expect(p.title, '发邮件给 a@b.com 和 me@example');
  });

  test('a new tag stops before the next recognized token', () {
    final p = parse('打扫@家务明天');
    expect(p.tags, isEmpty, reason: '@ 前面紧跟文字，不是标签');
    final spaced = parse('打扫 @家务明天');
    expect(spaced.tags, <String>['家务']);
    expect(spaced.date, DateTime(2026, 11, 29));
    expect(spaced.title, '打扫');
    // 标点结束标签。
    expect(parse('读书 @学习，今晚').tags, <String>['学习']);
  });

  test('an existing tag wins with its own spelling, longest first', () {
    final p = parse(
      '复盘 @deep workflow',
      tags: const <String>['Deep', 'deep_work'],
    );
    // “deep workflow”里有空格：只对上“Deep”，后面的 workflow 留在标题里。
    expect(p.tags, <String>['Deep']);
    expect(p.title, '复盘 workflow');
    expect(
      parse('复盘 @DEEP_WORK', tags: const <String>['Deep', 'deep_work']).tags,
      <String>['deep_work'],
    );
    // 已有标签以字母结尾、后面紧跟字母时不算它，按新标签整段识别。
    expect(parse('@Deeper', tags: const <String>['Deep']).tags, <String>[
      'Deeper',
    ]);
  });

  test('tags sit beside the list, priority and date', () {
    final p = parse('写周报 #工作 @周会 !! 周五');
    expect(p.listId, 'l1');
    expect(p.tags, <String>['周会']);
    expect(p.date, DateTime(2026, 12, 4));
    expect(p.title, '写周报');
  });

  test('dismissed tags stay in the title one by one', () {
    final p = parse('买菜 @家务 @采购', ignoreTags: const <String>{'家务'});
    expect(p.tags, <String>['采购']);
    expect(p.title, '买菜 @家务');
    final none = parseTodoQuickInput(
      '买菜 @家务',
      today: today,
      ignore: const <TodoQuickTokenKind>{TodoQuickTokenKind.tag},
    );
    expect(none.tags, isEmpty);
    expect(none.title, '买菜 @家务');
  });
}
