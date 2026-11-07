import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/diary_search_terms.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../viewmodels/search_highlight.dart';

/// 搜索结果卡片下方的一条“命中的留言”：有搜索词只出现在这篇的留言里
/// （标题与正文都没有）时，说明它为什么被搜到。
///
/// 留言长时只取第一个命中处前后一段（前面最多 [searchExcerptLead] 个字），
/// 每个词的命中处都以主色容器底标出（`search_highlight.dart`，与结果卡片
/// 同一套）；垫一层容器色，放在背景图上也读得清。底色与描边按
/// [AppGlassField] 跟随“控件”材质（经典时为 surfaceContainerHigh、无描边）。
class DiarySearchCommentHit extends StatelessWidget {
  const DiarySearchCommentHit({
    super.key,
    required this.content,
    required this.keyword,
  });

  final String content;

  /// 搜索框里的原文，按 [splitSearchTerms] 拆词（与查询同一口径）。
  final String keyword;

  /// 有词在标题与正文里都找不到（与 SQL `LIKE` 一样不分大小写）时，这篇
  /// 是靠留言才被搜到的，才需要这一条说明。
  static bool matchesOnlyComment({
    required String title,
    required String contentText,
    required String keyword,
  }) {
    final terms = splitSearchTerms(keyword);
    if (terms.isEmpty) return false;
    final lowerTitle = title.toLowerCase();
    final lowerContent = contentText.toLowerCase();
    return terms.any((term) {
      final needle = term.toLowerCase();
      return !lowerTitle.contains(needle) && !lowerContent.contains(needle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final terms = splitSearchTerms(keyword);
    final shown = searchExcerpt(text, terms) ?? text;
    final glassField = AppGlassField.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final spans = searchHighlightSpans(
      shown,
      terms,
      searchHighlightStyle(scheme),
    );
    return Semantics(
      label: context.l10n.diarySearchCommentHit(text),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glassField?.fill ?? scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: glassField?.border == null
                ? null
                : Border.fromBorderSide(glassField!.border!),
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
