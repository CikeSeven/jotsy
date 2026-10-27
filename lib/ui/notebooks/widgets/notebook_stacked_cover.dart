import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import 'notebook_cover_parts.dart';
import 'notebook_cover_tile.dart';

/// 有子本的日记本在书架上的“叠放”外观：封面后面两层错开的纸边，从封面
/// 上缘露出 4 / 8dp、左右各收进 8 / 16dp，越往后越偏向中性色，读作“这本里
/// 还放着几本”。
///
/// 只在封面外面包一层，不改封面组件本身。纸边画在格子上方的间距里（网格
/// 行距与分组标题下方都有 12dp），不占格子高度，同一行的封面仍然对齐。
/// [childCount] 大于 0 时才画；读屏在封面的说明之后补一句“含 N 本子日记本”。
class NotebookStackedCover extends StatelessWidget {
  const NotebookStackedCover({
    super.key,
    required this.childCount,
    required this.color,
    this.closed = false,
    required this.child,
  });

  /// 直接子本数；0 时原样返回 [child]。
  final int childCount;

  /// 这本的强调色种子（与封面同一套换算），纸边取它的容器色。
  final int? color;

  /// 已合上：纸边与封面一样降到 0.6 不透明度。
  final bool closed;
  final Widget child;

  /// 第一层纸边露出的高度与左右收进的宽度（第二层加倍）。
  static const double _peek = 4;
  static const double _inset = 8;

  /// 纸边的圆角比封面小：露出的那一窄条才是一道清楚的边，而不是两个圆角。
  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    if (childCount <= 0) return child;
    final scheme = Theme.of(context).colorScheme;
    final accent = notebookAccentColors(color, scheme);
    // 往后一层多混一点 surfaceContainerHighest：明暗两套里都比面板底色
    // 更显眼（暗色下不会沉进背景），又比封面本身更素；不透明，叠在玻璃
    // 背景上也看得清。描边用 outlineVariant，窄条的轮廓更清楚。
    Widget layer(int depth) => Positioned(
      top: -_peek * depth,
      left: _inset * depth,
      right: _inset * depth,
      height: NotebookCoverTile.radius * 2,
      child: Opacity(
        opacity: closed ? 0.6 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
              accent.container,
              scheme.surfaceContainerHighest,
              0.3 * depth,
            ),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: scheme.outlineVariant, width: 0.8),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          layer(2),
          layer(1),
          child,
          // 排在封面之后：合并后的说明先读名称与篇数，再读子本数。
          Positioned.fill(
            child: Semantics(
              label: context.l10n.notebookSubCountSemantics(childCount),
            ),
          ),
        ],
      ),
    );
  }
}
