import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_search.dart';

/// 模板搜索：名称 / 说明 / 分类名称命中，多词取“且”，不分大小写。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  const reading = DiaryTemplate(
    id: 'builtin.reading',
    name: '读书笔记',
    description: '摘录与感想，留下读过的痕迹',
    category: DiaryTemplateCategory.life,
  );
  const weekly = DiaryTemplate(
    id: 'u1',
    name: 'Weekly Review',
    description: 'Highlights of the week',
    category: DiaryTemplateCategory.review,
  );
  const untitled = DiaryTemplate(id: 'u2', name: '');

  bool hit(DiaryTemplate t, String q, [AppLocalizations? l10n]) =>
      diaryTemplateMatchesQuery(l10n ?? zh, t, q);

  test('an empty or blank query matches everything', () {
    expect(diaryTemplateSearchTerms('   '), isEmpty);
    expect(hit(reading, ''), isTrue);
    expect(hit(untitled, ' \t '), isTrue);
  });

  test('matches the name, the description and the category label', () {
    expect(hit(reading, '读书'), isTrue);
    expect(hit(reading, '痕迹'), isTrue);
    expect(hit(reading, '生活'), isTrue);
    expect(hit(reading, '工作'), isFalse);
  });

  test('every term must match somewhere (AND)', () {
    expect(hit(reading, '读书 感想'), isTrue);
    expect(hit(reading, '读书  生活 '), isTrue);
    expect(hit(reading, '读书 电影'), isFalse);
  });

  test('matching ignores case', () {
    expect(hit(weekly, 'weekly', en), isTrue);
    expect(hit(weekly, '  HIGHLIGHTS  review ', en), isTrue);
    expect(hit(weekly, 'monthly', en), isFalse);
  });

  test('the category label follows the interface language', () {
    expect(hit(weekly, '复盘'), isTrue);
    expect(hit(weekly, '复盘', en), isFalse);
  });

  test('an untitled user template is found by the untitled label', () {
    expect(hit(untitled, zh.diaryTemplateUntitled), isTrue);
    expect(hit(untitled, en.diaryTemplateUntitled.toUpperCase(), en), isTrue);
    expect(hit(untitled, '读书'), isFalse);
  });

  test('a term does not match across the joined fields', () {
    // 名称末尾“笔记”与说明开头“摘录”之间有分隔符，不能拼成一个词命中。
    expect(hit(reading, '笔记摘录'), isFalse);
  });
}
