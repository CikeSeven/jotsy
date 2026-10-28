import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../viewmodels/diary_comment_timeline.dart';
import 'diary_comments_section.dart';

/// 留言时间线上的一条：左侧节点（心情 emoji 或小圆点）与向下延伸的竖线，
/// 右侧“写下后 N 天 · 时间 · 已编辑”与留言文字。
///
/// 长按（桌面右键）在按下处打开菜单：编辑、复制、删除（[ExpressiveMenuAnchor]，
/// 与探索页卡片菜单同一做法）；[actions] 为 null 时（设置页预览）没有菜单。
/// [appearing] 为 true 时（本次打开后新写下或撤销删除回来的）淡入。
class DiaryCommentItem extends StatefulWidget {
  const DiaryCommentItem({
    super.key,
    required this.comment,
    required this.diaryCreatedAt,
    required this.actions,
    this.textColor,
    this.appearing = false,
  });

  /// 左侧节点列的宽度；时间线下方各行的图标与它居中对齐。
  static const double railWidth = 24;

  /// 节点列与文字之间的间距。
  static const double railGap = 10;

  final DiaryCommentRow comment;
  final DateTime diaryCreatedAt;
  final DiaryCommentActions? actions;
  final Color? textColor;
  final bool appearing;

  @override
  State<DiaryCommentItem> createState() => _DiaryCommentItemState();
}

class _DiaryCommentItemState extends State<DiaryCommentItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    value: widget.appearing ? 0 : 1,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _entrance,
    curve: ExpressiveMotion.effects,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.value < 1 && !_entrance.isAnimating) {
      _entrance
        ..duration = ExpressiveMotion.duration(context, ExpressiveMotion.medium)
        ..forward();
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final comment = widget.comment;
    final meta = <String>[
      diaryCommentRelativeLabel(l10n, widget.diaryCreatedAt, comment.createdAt),
      l10n.formatPreciseDateTime(comment.createdAt, DateTime.now()),
      if (comment.editedAt != null) l10n.diaryCommentEdited,
    ].join(' · ');
    final body = Stack(
      children: <Widget>[
        // 竖线从节点下方一直画到条目底部（含与下一条的间距），在下一条的
        // 节点上方留一小段空隙。
        PositionedDirectional(
          start: DiaryCommentItem.railWidth / 2 - 1,
          top: 26,
          bottom: 0,
          width: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: DiaryCommentItem.railWidth,
                height: 22,
                child: Center(child: _CommentNode(mood: comment.mood)),
              ),
              const SizedBox(width: DiaryCommentItem.railGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: widget.textColor ?? scheme.onSurface,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = widget.actions;
    final content = FadeTransition(opacity: _opacity, child: body);
    if (actions == null) return content;
    return ExpressiveMenuAnchor(
      menuChildren: <Widget>[
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.pen),
          onPressed: () => actions.onEdit(comment),
          child: Text(l10n.commonEdit),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.copy),
          onPressed: () => actions.onCopy(comment),
          child: Text(l10n.diaryCommentCopy),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
          destructive: true,
          onPressed: () => actions.onDelete(comment),
          child: Text(l10n.commonDelete),
        ),
      ],
      builder:
          (
            BuildContext context,
            ExpressiveMenuAnchorState menu,
            Widget? child,
          ) {
            return Semantics(
              onLongPressHint: l10n.diaryCommentActionsHint,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (LongPressStartDetails details) {
                  unawaited(Feedback.forLongPress(context));
                  if (Theme.of(context).platform == TargetPlatform.iOS) {
                    unawaited(HapticFeedback.mediumImpact());
                  }
                  menu.openAt(details.globalPosition);
                },
                onSecondaryTapUp: (TapUpDetails details) =>
                    menu.openAt(details.globalPosition),
                child: child,
              ),
            );
          },
      child: content,
    );
  }
}

/// 时间线节点：有心情时画 emoji，没有时是一个小圆点。
class _CommentNode extends StatelessWidget {
  const _CommentNode({required this.mood});

  final String? mood;

  @override
  Widget build(BuildContext context) {
    final mood = this.mood;
    if (mood != null && mood.isNotEmpty) {
      return Text(
        mood,
        style: const TextStyle(fontSize: 16, height: 1),
        textAlign: TextAlign.center,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
    );
  }
}
