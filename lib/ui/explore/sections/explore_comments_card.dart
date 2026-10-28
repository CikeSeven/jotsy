import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../diaries/viewmodels/diary_comment_timeline.dart';
import '../controllers/explore_comment_stats.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_options.dart';
import '../providers/explore_providers.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

/// 最近的留言：顶部一行回看统计（共几条、回应了几篇、平均隔几天回看），
/// 下面是最近写下的几条留言（条数可选 3 / 5 / 8）。每条为心情（没选时一个
/// 小圆点）+ 一行留言摘录，下一行是所属日记的标题与“写下后 N 天”；点按经
/// 打开日记的流程进入那篇日记，可在这几篇之间左右翻。
///
/// 数据来自留言表（[exploreRecentCommentsProvider] / [exploreCommentStatsProvider]，
/// 只在卡片显示时订阅）；留言功能关闭时页面整张不显示（见 ExploreModuleSpec）。
/// 自定义页预览在示例数据模式下替换这两个 provider，卡片本身不区分。
class ExploreCommentsCard extends ConsumerWidget {
  const ExploreCommentsCard({super.key, required this.config});

  final ExploreModuleConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ExploreActionsScope.of(context);
    final recent = ref.watch(exploreRecentCommentsProvider).value;
    final stats = ref.watch(exploreCommentStatsProvider).value;
    final shown = recent
        ?.take(config.count(ExploreOptions.commentsCount))
        .toList(growable: false);
    // 同一篇的多条留言只在顺序里出现一次，预览页左右翻时不会原地翻到自己。
    final sequence = <String>{
      for (final comment in shown ?? const <DiaryCommentSummary>[])
        comment.diaryId,
    }.toList(growable: false);
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.comment,
            title: l10n.exploreModuleComments,
          ),
          // 两条流都到了才画内容：统计与列表来自不同查询，先到的一半单独
          // 画出来会在另一半到达时跳一下。
          if (shown == null || stats == null)
            const SizedBox(height: 40)
          else if (shown.isEmpty)
            ExploreInlineHint(message: l10n.exploreCommentsEmpty)
          else ...<Widget>[
            _CommentStatsLine(stats: stats),
            const SizedBox(height: 4),
            for (final comment in shown)
              _CommentRow(
                comment: comment,
                onTap: () =>
                    actions.openDiary(comment.diaryId, sequence: sequence),
              ),
          ],
        ],
      ),
    );
  }
}

/// 统计：第一行是条数（与时间胶囊卡的“还有 N 个”同一字重），第二行是回应
/// 了几篇与平均间隔。没有留言时卡片显示空态，不会走到这里；平均间隔为 null
/// 时（理论上只在没有留言时）省掉这一项。
class _CommentStatsLine extends StatelessWidget {
  const _CommentStatsLine({required this.stats});

  final ExploreCommentStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final gap = stats.averageGapDays;
    final details = <String>[
      l10n.exploreCommentsDiaries(stats.diaryCount),
      if (gap != null) l10n.exploreCommentsAverageGap(gap),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.diaryCommentsCount(stats.total),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          details.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 一条留言：心情 + 一行摘录，下一行“日记标题 · 写下后 N 天”。
class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.onTap});

  final DiaryCommentSummary comment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final mood = comment.mood?.trim();
    final title = comment.diaryTitle.trim();
    // 留言可以有多行，这里只要一句摘录：换行与连续空白收成一个空格，
    // 省略号落在一行的末尾而不是第一行换行处。
    final excerpt = comment.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Center(
                child: mood == null || mood.isEmpty
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: look.accentOf(scheme),
                          shape: BoxShape.circle,
                        ),
                      )
                    // 心情是装饰性的表情，固定在 28 宽的槽里：随系统字号最多
                    // 放大到 1.3 倍，超大字号下不把摘录挤出卡片。
                    : Text(
                        mood,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: 1.3),
                        style: const TextStyle(fontSize: 16, height: 1.2),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    excerpt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _CommentMetaLine(
                    title: title.isEmpty ? l10n.autoT0033 : title,
                    relative: diaryCommentRelativeLabel(
                      l10n,
                      comment.diaryCreatedAt,
                      comment.createdAt,
                    ),
                    style: metaStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// “日记标题 · 写下后 N 天”：标题过长时先省略标题，间隔留在行尾。
///
/// 间隔最多占这一行的 60%（超大字号的窄屏上它也省略，不溢出）；标题拿剩下
/// 的宽度。直接拼成一段文字的话，长标题会把更要紧的间隔挤成省略号。
class _CommentMetaLine extends StatelessWidget {
  const _CommentMetaLine({
    required this.title,
    required this.relative,
    required this.style,
  });

  final String title;
  final String relative;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => Row(
        children: <Widget>[
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
            child: Text(
              ' · $relative',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
