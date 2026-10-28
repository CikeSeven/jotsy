import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../viewmodels/diary_comment_timeline.dart';
import 'diary_comment_item.dart';

/// 留言的动作（预览页经 `diary_comment_flows.dart` 接线）。
@immutable
class DiaryCommentActions {
  const DiaryCommentActions({
    required this.onWrite,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final VoidCallback onWrite;
  final ValueChanged<DiaryCommentRow> onEdit;
  final ValueChanged<DiaryCommentRow> onCopy;
  final ValueChanged<DiaryCommentRow> onDelete;
}

/// 预览页留言区的数据与动作（`DiaryPreviewContent.comments`）；为 null 时
/// 不显示留言区（功能关闭、日记在回收站、截取分享长图时）。
@immutable
class DiaryPreviewComments {
  const DiaryPreviewComments({
    required this.diaryCreatedAt,
    required this.comments,
    this.actions,
    this.sectionKey,
  });

  /// 日记写下的时间：每条留言的“写下后 N 天”从它算起。
  final DateTime diaryCreatedAt;

  /// 按写下时间旧 → 新。
  final List<DiaryCommentRow> comments;

  /// 为 null 时只读（设置页的样式预览）：“写留言…”一行点按无反应，没有
  /// 长按菜单。
  final DiaryCommentActions? actions;

  /// 挂在留言区上：信息栏的留言数与“更多 → 写留言”据此滚到这里。
  final GlobalKey? sectionKey;
}

/// 预览页正文末尾的留言区：标题“留言 · N”、批注时间线与“写留言…”。
///
/// 时间线左边一条竖线，节点为这条留言的心情 emoji，没选心情时是小圆点；
/// 按写下时间旧 → 新，条数多时折叠中间的（[DiaryCommentFold]）。
///
/// 状态：只有“是否展开”与“已经出现过的留言”。首次构建时已有的留言直接
/// 显示；之后新出现的（刚写下、撤销删除）淡入，高度变化（增删、展开收起）
/// 经 [AnimatedSize] 补间，下方的上一篇 / 下一篇不会在一帧内跳动。
class DiaryCommentsSection extends StatefulWidget {
  const DiaryCommentsSection({super.key, required this.data, this.textColor});

  final DiaryPreviewComments data;

  /// 留言正文的颜色（预览页样式的正文色）；null 时取主题色。
  final Color? textColor;

  /// 滚到留言区：[end] 为 true 时让留言区末尾（最新一条与“写留言…”）
  /// 进入视口，否则让留言区开头对齐视口顶部。留言区还没构建时什么也不做。
  static Future<void> reveal(
    BuildContext context,
    GlobalKey sectionKey, {
    bool end = false,
  }) async {
    final target = sectionKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: end ? 1 : 0,
      duration: ExpressiveMotion.duration(context),
      curve: ExpressiveMotion.effects,
    );
  }

  @override
  State<DiaryCommentsSection> createState() => _DiaryCommentsSectionState();
}

class _DiaryCommentsSectionState extends State<DiaryCommentsSection> {
  bool _expanded = false;

  /// 已经显示过的留言 id；不在其中的是本次打开后新出现的，淡入。
  Set<String>? _seen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final data = widget.data;
    final comments = data.comments;
    final seen = _seen ??= <String>{
      for (final comment in comments) comment.commentId,
    };
    final fold = DiaryCommentFold<DiaryCommentRow>.of(
      comments,
      expanded: _expanded,
    );
    Widget item(DiaryCommentRow comment) {
      // 在 build 里登记：条目的入场只在它的 State 创建时读取一次。
      final appearing = seen.add(comment.commentId);
      return DiaryCommentItem(
        key: ValueKey<String>(comment.commentId),
        comment: comment,
        diaryCreatedAt: data.diaryCreatedAt,
        actions: data.actions,
        textColor: widget.textColor,
        appearing: appearing,
      );
    }

    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      key: data.sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (comments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.diaryCommentsHeading(comments.length),
              style: theme.textTheme.titleSmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ...fold.head.map(item),
              if (fold.folded)
                _CommentsLinkRow(
                  icon: FontAwesomeIcons.ellipsis,
                  label: l10n.diaryCommentsExpand(fold.hiddenCount),
                  onTap: () => setState(() => _expanded = true),
                ),
              ...fold.tail.map(item),
              if (_expanded &&
                  DiaryCommentFold<DiaryCommentRow>.of(
                    comments,
                    expanded: false,
                  ).folded)
                _CommentsLinkRow(
                  icon: FontAwesomeIcons.angleUp,
                  label: l10n.diaryCommentsCollapse,
                  onTap: () => setState(() => _expanded = false),
                ),
            ],
          ),
        ),
        _CommentsLinkRow(
          icon: FontAwesomeIcons.plus,
          label: l10n.diaryCommentsWrite,
          onTap: data.actions?.onWrite,
          emphasized: true,
        ),
      ],
    );
  }
}

/// 时间线下方的一行文字按钮（展开 / 收起 / 写留言），左侧图标与节点对齐。
class _CommentsLinkRow extends StatelessWidget {
  const _CommentsLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onTap;

  /// “写留言…”用主色，展开 / 收起用次要色。
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasized
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: DiaryCommentItem.railWidth,
                child: Center(child: FaIcon(icon, size: 13, color: color)),
              ),
              const SizedBox(width: DiaryCommentItem.railGap),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
