import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../viewmodels/notebook_view.dart';
import 'notebook_child_tile.dart';
import 'notebook_cover_tile.dart';

// 头部子本网格（`NotebookChildrenGrid`）折叠后的最后一格：收起时为“还有 N 本”，
// 展开时为“收起”。两格都是动作而不是一本日记本，所以与书架的新建格同一
// 语言：`outlineVariant` 描边、无底色、`primary` 文字；高度随同一行的子本格。

/// 收起时的“还有 N 本”：左边叠放前几本没列出的子本的小封面，右边两行
/// “还有 N 本 / 展开 ⌄”，与子本格“名称 / 篇数”同一节奏。
class NotebookChildrenMoreTile extends StatelessWidget {
  const NotebookChildrenMoreTile({
    super.key,
    required this.hidden,
    required this.maxCovers,
    required this.onTap,
  });

  /// 没列出的子本（书架顺序）。
  final List<NotebookView> hidden;

  /// 最多叠放几张小封面：窄格子少叠一张，给文字让出宽度（由网格按格宽给出，
  /// 格子在 IntrinsicHeight 里，不能自己用 LayoutBuilder 量宽度）。
  final int maxCovers;
  final VoidCallback onTap;

  /// 相邻两张小封面错开的距离；后面的每张上下各收进 [_coverInset]，像一叠。
  static const double _coverStep = 7;
  static const double _coverInset = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final covers = hidden.take(maxCovers).toList();
    return _ToggleCell(
      semanticsLabel: l10n.notebookSubMoreSemantics(hidden.length),
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 12, 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width:
                NotebookChildTile.coverWidth + _coverStep * (covers.length - 1),
            height: NotebookChildTile.coverHeight,
            child: Stack(
              children: <Widget>[
                // 倒序画：第一本在最上面，后面的从它右侧露出一条边。
                for (var i = covers.length - 1; i >= 0; i--)
                  PositionedDirectional(
                    start: _coverStep * i,
                    top: _coverInset * i,
                    bottom: _coverInset * i,
                    width:
                        NotebookChildTile.coverWidth *
                        (NotebookChildTile.coverHeight - 2 * _coverInset * i) /
                        NotebookChildTile.coverHeight,
                    child: FittedBox(
                      child: NotebookCoverTile.mini(
                        icon: covers[i].icon,
                        color: covers[i].color,
                        coverPath: covers[i].coverPath,
                        style: covers[i].coverStyle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.notebookSubMore(hidden.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        l10n.notebookSubMoreHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    FaIcon(
                      FontAwesomeIcons.angleDown,
                      size: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 展开后的“收起”：居中的 `angleUp` + “收起”。
class NotebookChildrenLessTile extends StatelessWidget {
  const NotebookChildrenLessTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _ToggleCell(
      semanticsLabel: l10n.notebookSubLessSemantics,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FaIcon(FontAwesomeIcons.angleUp, size: 12, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.notebookSubLess,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 两格共用的外壳：描边、14dp 圆角、最小高度与子本格一致。
class _ToggleCell extends StatelessWidget {
  const _ToggleCell({
    required this.semanticsLabel,
    required this.onTap,
    required this.padding,
    required this.child,
  });

  final String semanticsLabel;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: NotebookChildTile.minHeight,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
