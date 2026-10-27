import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'notebook_cover_layouts.dart';
import 'notebook_cover_texture.dart';

/// 极简版式（[NotebookCoverLayoutBody] 的一种）：不画图标，名称放大加粗
/// 靠上，篇数在底部；有封面图时图片在下方做背景，名称写在顶部的实色带上、
/// 篇数写在左下的实色小牌上（不用渐变遮罩）。名称在行尾让出右上角角标。
class NotebookCoverMinimalBody extends StatelessWidget {
  const NotebookCoverMinimalBody(this.data, {super.key});

  final NotebookCoverLayoutBody data;

  /// 名称靠上时给右上角角标（22dp，距边 8）让出的宽度。
  static const double _badgeReserve = 22 + AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = data.accent;
    final cover = data.coverPath;
    final endReserve = data.reserveBadge ? _badgeReserve : 0.0;
    final name = Text(
      data.name,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: accent.onContainer,
      ),
    );
    final countStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: accent.onContainer.withValues(alpha: 0.72),
    );
    final count = data.countLabel;
    if (cover == null) {
      return notebookCoverTextured(
        texture: data.style.texture,
        color: notebookCoverTextureColor(accent.onContainer),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: EdgeInsetsDirectional.only(end: endReserve),
                child: name,
              ),
              const Spacer(),
              if (count != null)
                Text(
                  count,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: countStyle,
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 顶部实色带：名称写在底色上，图片在下方做背景。
        notebookCoverTextured(
          texture: data.style.texture,
          color: notebookCoverTextureColor(accent.onContainer),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              14,
              AppSpacing.m,
              14 + endReserve,
              AppSpacing.m,
            ),
            child: name,
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              NotebookCoverFilledImage(path: cover, style: data.style),
              if (count != null)
                PositionedDirectional(
                  start: AppSpacing.s,
                  bottom: AppSpacing.s,
                  end: AppSpacing.s,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.container,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s,
                          vertical: 3,
                        ),
                        child: Text(
                          count,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: countStyle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
