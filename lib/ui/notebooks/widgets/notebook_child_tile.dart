import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_cover_tile.dart';

// 头部子本条（`NotebookChildrenStrip`）的格子：子本格、“＋ 新建子本”格与
// 新格子的横向展开。只负责展示与回调，数据由子本条传入。

/// 一本子本：`surfaceContainerHigh` 底、14dp 圆角，缩小的封面 + 名称与篇数。
class NotebookChildTile extends StatelessWidget {
  const NotebookChildTile({
    super.key,
    required this.notebook,
    required this.parentVisibility,
    required this.count,
    required this.onTap,
  });

  final NotebookView notebook;

  /// 当前这本（上级）的生效可见性：子本比它更私密时才标出私密图标。
  final NotebookVisibility parentVisibility;
  final int? count;
  final VoidCallback onTap;

  /// 格子的最小高度（小封面 42 + 上下各 6）；同一行的格子按最高的拉齐。
  static const double minHeight = 54;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visibility = notebook.effectiveVisibility;
    final stricter = visibility.index > parentVisibility.index;
    final privateIcon = !stricter
        ? null
        : visibility == NotebookVisibility.locked
        ? FontAwesomeIcons.lock
        : FontAwesomeIcons.eyeSlash;
    final count = this.count;
    final semantics = <String>[
      notebook.name,
      if (count != null) l10n.notebookEntryCount(count),
      if (stricter)
        visibility == NotebookVisibility.locked
            ? l10n.notebookStateLocked
            : l10n.notebookStateHidden,
      if (notebook.isClosed) l10n.notebookStateClosed,
    ].join(l10n.notebookSemanticsSeparator);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
      child: Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        onTap: onTap,
        child: Opacity(
          opacity: notebook.isClosed ? 0.6 : 1,
          child: Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: NotebookChildTile.minHeight,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 12, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // 列表行的小封面（44×56）按 3/4 缩小，圆角与描边一起缩。
                      SizedBox(
                        width: 33,
                        height: 42,
                        child: FittedBox(
                          child: NotebookCoverTile.mini(
                            icon: notebook.icon,
                            color: notebook.color,
                            coverPath: notebook.coverPath,
                            style: notebook.coverStyle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 112),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              notebook.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                // 篇数算出前留住一行高度，算好后格子不跳。
                                Flexible(
                                  child: Text(
                                    count == null
                                        ? ' '
                                        : l10n.notebookEntryCount(count),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: mutedStyle,
                                  ),
                                ),
                                if (privateIcon != null) ...<Widget>[
                                  const SizedBox(width: 4),
                                  FaIcon(
                                    privateIcon,
                                    size: 10,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 末尾的“＋ 新建子本”：与书架的新建格同一语言（`outlineVariant` 描边、
/// 无底色、primary 12% 圆里的加号），高度随同一行的子本格。
class NotebookCreateChildTile extends StatelessWidget {
  const NotebookCreateChildTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: NotebookChildTile.minHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.plus,
                      size: 11,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    context.l10n.notebookSubCreateShort,
                    maxLines: 1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 新出现的子本格：从 0 宽度横向展开并淡入（[appearing] 只在首次创建时
/// 起作用）；其余格子原样显示，结构恒定。
class NotebookStripEntrance extends StatefulWidget {
  const NotebookStripEntrance({
    super.key,
    required this.appearing,
    required this.duration,
    required this.child,
  });

  final bool appearing;
  final Duration duration;
  final Widget child;

  @override
  State<NotebookStripEntrance> createState() => _NotebookStripEntranceState();
}

class _NotebookStripEntranceState extends State<NotebookStripEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.appearing ? 0 : 1,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: ExpressiveMotion.effects,
  );

  @override
  void initState() {
    super.initState();
    if (widget.appearing) _controller.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      axis: Axis.horizontal,
      sizeFactor: _progress,
      alignment: AlignmentDirectional.centerStart,
      child: FadeTransition(opacity: _progress, child: widget.child),
    );
  }
}
