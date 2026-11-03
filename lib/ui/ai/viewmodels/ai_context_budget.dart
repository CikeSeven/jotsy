// 多篇上下文的字数预算（纯函数）。
//
// 字数一律按 `TextStats` 口径（中文按字、其他按词），与界面上“最多发送
// N 字”的说法一致。每篇都整篇放（不设每篇上限），按顺序放进总预算，
// 放不下的那篇截到剩余字数（太短就不放），之后的不再放。

import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../utils/text_stats.dart';

/// 一篇放进上下文的日记：编号（`D1`…）与它该保留的字数。
@immutable
class AiBudgetedDiary {
  const AiBudgetedDiary({
    required this.diary,
    required this.ref,
    required this.maxWords,
  });

  final AiContextDiary diary;

  /// 引用编号，如 `D3`（提示词里写作 `[D3]`）。
  final String ref;

  /// 这篇最多保留的字数；不小于原文时即全文。
  final int maxWords;

  String get marker => '[$ref]';
}

/// 在 [budget] 字以内依次放入 [diaries]（调用方决定先后顺序），每篇整篇
/// 放入。少于 [minWords] 的剩余预算不再放半篇。
List<AiBudgetedDiary> aiBudgetDiaries(
  List<AiContextDiary> diaries, {
  required int budget,
  int minWords = 80,
}) {
  final result = <AiBudgetedDiary>[];
  var remaining = budget;
  for (final diary in diaries) {
    if (remaining < minWords) break;
    final words =
        TextStats.countWords(diary.contentText) +
        TextStats.countWords(diary.title);
    final take = words < remaining ? words : remaining;
    if (take <= 0) continue;
    result.add(
      AiBudgetedDiary(
        diary: diary,
        ref: 'D${result.length + 1}',
        maxWords: take,
      ),
    );
    remaining -= take < 1 ? 1 : take;
  }
  return result;
}

/// 截取 [text] 的开头，使字数不超过 [maxWords]。已经不超过时原样返回。
/// 二分查找前缀长度（不切开代理对），对几十 KB 的正文也只数十次计数。
String aiTruncateWords(String text, int maxWords) {
  if (maxWords <= 0) return '';
  if (TextStats.countWords(text) <= maxWords) return text;
  var low = 0;
  var high = text.length;
  while (low < high) {
    final mid = (low + high + 1) >> 1;
    if (TextStats.countWords(_safePrefix(text, mid)) <= maxWords) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return _safePrefix(text, low).trimRight();
}

String _safePrefix(String text, int length) {
  if (length <= 0) return '';
  if (length >= text.length) return text;
  final unit = text.codeUnitAt(length - 1);
  // 不在高位代理之后切开。
  if (unit >= 0xD800 && unit <= 0xDBFF) return text.substring(0, length - 1);
  return text.substring(0, length);
}
