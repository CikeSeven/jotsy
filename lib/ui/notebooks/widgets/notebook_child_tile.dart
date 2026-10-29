import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_cover_tile.dart';

// 头部子本网格（`NotebookChildrenGrid`）的子本格与新格子的出现动画。只负责
// 展示与回调，数据由网格传入；“还有 N 本 / 收起”格见
// `notebook_children_toggle_tile.dart`。

/// 一本子本：`surfaceContainerHigh` 底、14dp 圆角，缩小的封面 + 名称与篇数，
/// 铺满网格的一格（名称按格宽省略）。
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

  /// 格子里的小封面尺寸（列表行小封面 44×56 的 3/4）。
  static const double coverWidth = 33;
  static const double coverHeight = 42;

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
    // 头部卡片里的子本格子随“控件”材质：玻璃卡片上不留一块实色补丁。
    final glassField = AppGlassField.of(context);
    final glassSide = glassField?.border;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: notebook.isClosed ? 0.6 : 1,
        child: Material(
          color: glassField?.fill ?? scheme.surfaceContainerHigh,
          borderRadius: glassSide == null ? BorderRadius.circular(14) : null,
          shape: glassSide == null
              ? null
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: glassSide,
                ),
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
                  children: <Widget>[
                    // 列表行的小封面（44×56）按 3/4 缩小，圆角与描边一起缩。
                    SizedBox(
                      width: NotebookChildTile.coverWidth,
                      height: NotebookChildTile.coverHeight,
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
                    Expanded(
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
    );
  }
}

/// 新出现的格子：淡入并从 92% 放大到原尺寸（[appearing] 只在首次创建时
/// 起作用）；其余格子原样显示，结构恒定。
///
/// 用于网格里新增的子本（比如刚在这里新建的）、展开后露出来的子本，以及
/// “还有 N 本 / 收起”两格互换的那一刻。格子不是磨砂玻璃（随“控件”材质只换
/// 底色与描边、不模糊），可以放进 FadeTransition。
class NotebookChildEntrance extends StatefulWidget {
  const NotebookChildEntrance({
    super.key,
    required this.appearing,
    required this.duration,
    required this.child,
  });

  final bool appearing;
  final Duration duration;
  final Widget child;

  @override
  State<NotebookChildEntrance> createState() => _NotebookChildEntranceState();
}

class _NotebookChildEntranceState extends State<NotebookChildEntrance>
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
  late final Animation<double> _scale = _progress.drive(
    Tween<double>(begin: 0.92, end: 1),
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
    return FadeTransition(
      opacity: _progress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
