// 与日记对话的本地检索（纯函数，不碰数据库与网络）。
//
// - [aiQueryKeywords]：从问题里抽关键词。中文按连续汉字切开，先去掉常见的
//   虚词与问句用语，剩下的每段取整段（2–4 字时）与相邻两字（2-gram）；
//   其他文字按词，去掉常见停用词。最多 12 个，长的在前（更有区分度）；
// - [aiRankDiaries]：按命中次数（标题加权）与时间远近给候选日记打分；
// - [AiRetrievalPlan]：智能检索时模型给出的检索计划（关键词与日期范围）。

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import 'ai_json_output.dart';

/// 中文问句里不带信息的词（长的在前，先删长的）。
const List<String> _zhStopPhrases = <String>[
  '为什么',
  '怎么样',
  '是不是',
  '有没有',
  '那时候',
  '这时候',
  '什么',
  '怎么',
  '怎样',
  '如何',
  '哪些',
  '哪里',
  '哪个',
  '最近',
  '这个',
  '那个',
  '这些',
  '那些',
  '一下',
  '一些',
  '时候',
  '日记',
  '我们',
  '你们',
  '他们',
  '自己',
  '感觉',
  '觉得',
  '还是',
  '可以',
  '应该',
  '已经',
  '因为',
  '所以',
  '但是',
  '然后',
  '帮我',
  '告诉',
  '总结',
  '回顾',
  '过得',
  '一直',
  '经常',
  '常常',
];

/// 单独出现时没有信息的字（把汉字段切开）。
const String _zhStopChars = '我你他她它的了是在有吗呢吧啊呀么和与及或也都就还又很太最被把给让对从到这那个些么嘛哦哈';

const Set<String> _enStopWords = <String>{
  'the',
  'a',
  'an',
  'i',
  'me',
  'my',
  'mine',
  'you',
  'your',
  'we',
  'our',
  'what',
  'how',
  'when',
  'where',
  'why',
  'which',
  'who',
  'did',
  'do',
  'does',
  'was',
  'were',
  'is',
  'are',
  'am',
  'be',
  'been',
  'have',
  'has',
  'had',
  'about',
  'in',
  'on',
  'at',
  'of',
  'to',
  'for',
  'and',
  'or',
  'but',
  'with',
  'this',
  'that',
  'these',
  'those',
  'last',
  'recent',
  'recently',
  'lately',
  'any',
  'some',
  'there',
  'can',
  'could',
  'would',
  'should',
  'tell',
  'diary',
  'diaries',
  'entry',
  'entries',
  'time',
  'times',
  'it',
  'its',
  'so',
  'as',
  'from',
  'into',
  'over',
  'past',
  'like',
  'feel',
  'felt',
  'things',
};

final RegExp _cjkRun = RegExp(r'[㐀-䶿一-鿿豈-﫿]+');
final RegExp _latinWord = RegExp(r"[A-Za-z][A-Za-z0-9'\-]*|\d{2,}");

/// 从问题里抽关键词，最多 [max] 个，长的在前。
List<String> aiQueryKeywords(String question, {int max = 12}) {
  final result = <String>{};
  for (final match in _cjkRun.allMatches(question)) {
    var run = match.group(0)!;
    for (final phrase in _zhStopPhrases) {
      run = run.replaceAll(phrase, ' ');
    }
    for (final segment in run.split(RegExp('[ $_zhStopChars]+'))) {
      if (segment.length < 2) continue;
      if (segment.length <= 4) result.add(segment);
      if (segment.length > 2) {
        for (var i = 0; i + 2 <= segment.length; i++) {
          result.add(segment.substring(i, i + 2));
        }
      }
    }
  }
  for (final match in _latinWord.allMatches(question)) {
    final word = match.group(0)!.toLowerCase();
    if (word.length < 2 || _enStopWords.contains(word)) continue;
    result.add(word);
  }
  final sorted = result.toList()..sort((a, b) => b.length.compareTo(a.length));
  return sorted.take(max).toList();
}

/// 按与 [keywords] 的相关程度给 [diaries] 排序（高 → 低；同分时新的在前）。
/// 没有关键词时按时间新 → 旧。
List<AiContextDiary> aiRankDiaries(
  List<AiContextDiary> diaries,
  List<String> keywords, {
  required DateTime now,
}) {
  double score(AiContextDiary diary) {
    if (keywords.isEmpty) return 0;
    final title = diary.title.toLowerCase();
    final body = diary.contentText.toLowerCase();
    final tags = diary.tags.join(' ').toLowerCase();
    var total = 0.0;
    for (final keyword in keywords) {
      final word = keyword.toLowerCase();
      final weight = word.length >= 3 ? 1.5 : 1.0;
      var hits = _count(body, word);
      if (hits > 3) hits = 3;
      total += hits * weight;
      if (title.contains(word)) total += 3 * weight;
      if (tags.contains(word)) total += 2 * weight;
    }
    if (total == 0) return 0;
    // 越近越相关一点：一个月前约打七五折，一年前约打四折。
    final age = now.difference(diary.createdAt).inDays.clamp(0, 36500);
    return total * (0.4 + 0.6 / (1 + age / 90));
  }

  final scored = [for (final diary in diaries) (diary, score(diary))];
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    return b.$1.createdAt.compareTo(a.$1.createdAt);
  });
  return [for (final (diary, _) in scored) diary];
}

int _count(String text, String word) {
  if (word.isEmpty) return 0;
  var count = 0;
  var index = text.indexOf(word);
  while (index >= 0 && count < 10) {
    count++;
    index = text.indexOf(word, index + word.length);
  }
  return count;
}

/// 智能检索的计划：模型给出的关键词与可能的日期范围（[from] / [to] 含首尾，
/// 本地零点）。
@immutable
class AiRetrievalPlan {
  const AiRetrievalPlan({this.keywords = const <String>[], this.from, this.to});

  /// 从模型输出解析；读不出 JSON 时为 null（调用方退回本地关键词）。
  static AiRetrievalPlan? parse(String raw) {
    final json = aiExtractJsonObject(raw);
    if (json == null) return null;
    final rawKeywords = json['keywords'];
    final keywords = <String>{
      if (rawKeywords is List)
        for (final item in rawKeywords)
          if (item is String &&
              item.trim().isNotEmpty &&
              item.trim().length <= 24)
            item.trim(),
    }.take(12).toList();
    DateTime? date(Object? value) {
      if (value is! String) return null;
      final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(value);
      if (match == null) return null;
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      return DateTime(year, month, day);
    }

    var from = date(json['from']);
    var to = date(json['to']);
    if (from != null && to != null && from.isAfter(to)) {
      (from, to) = (to, from);
    }
    return AiRetrievalPlan(keywords: keywords, from: from, to: to);
  }

  final List<String> keywords;
  final DateTime? from;
  final DateTime? to;

  bool get hasDates => from != null || to != null;
}
