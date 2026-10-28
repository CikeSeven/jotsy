import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';

/// 搜索结果卡片下方的一条“命中的留言”：搜索词只出现在这篇的留言里（标题
/// 与正文都没有）时，说明它为什么被搜到。
///
/// 留言长时只取命中处前后一段（前面最多 [_lead] 个字），关键词以主色容器
/// 底标出；垫一层容器色，放在背景图上也读得清。
class DiarySearchCommentHit extends StatelessWidget {
  const DiarySearchCommentHit({
    super.key,
    required this.content,
    required this.keyword,
  });

  final String content;
  final String keyword;

  /// 命中处前面保留的字数：再往前的用省略号代替，关键词不会被挤出两行之外。
  static const int _lead = 16;

  /// 只命中留言（标题与正文都不含 [keyword]，与 SQL `LIKE` 一样不分大小写）
  /// 时才需要这一条说明。
  static bool matchesOnlyComment({
    required String title,
    required String contentText,
    required String keyword,
  }) {
    final needle = keyword.trim().toLowerCase();
    if (needle.isEmpty) return false;
    return !title.toLowerCase().contains(needle) &&
        !contentText.toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final needle = keyword.trim();
    final at = text.toLowerCase().indexOf(needle.toLowerCase());
    final start = at > _lead ? at - _lead : 0;
    final shown = start > 0 ? '…${text.substring(start)}' : text;
    final hit = at < 0 ? -1 : at - start + (start > 0 ? 1 : 0);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    // 大小写转换可能改变个别字符的长度（如土耳其语 İ），对不上时不标出。
    final highlightable =
        hit >= 0 && needle.isNotEmpty && hit + needle.length <= shown.length;
    final spans = !highlightable
        ? <InlineSpan>[TextSpan(text: shown)]
        : <InlineSpan>[
            TextSpan(text: shown.substring(0, hit)),
            TextSpan(
              text: shown.substring(hit, hit + needle.length),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                backgroundColor: scheme.primaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: shown.substring(hit + needle.length)),
          ];
    return Semantics(
      label: context.l10n.diarySearchCommentHit(text),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: FaIcon(
                    FontAwesomeIcons.comment,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: spans),
                    style: base,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
