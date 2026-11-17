import 'package:flutter/material.dart';

import 'notebook_cover_parts.dart';

/// 有子本的日记本在卡组里的“叠放”外观：卡片后面两层错开的纸边，从行尾
/// 一侧露出 4 / 8dp、上下各收进 8 / 16dp，越往后越偏向中性色，读作“这本里
/// 还放着几本”。卡组的横卡上缘被前一张盖住，只能从侧边看出来。
///
/// 只在卡片外面包一层，不改卡片本身；纸边画在卡片行尾外侧（卡组为它留了
/// 位置），不占卡片尺寸。[childCount] 大于 0 时才画；子本数由卡片顶条上的
/// 角标读出，这里不补读屏说明。
class NotebookStackedCover extends StatelessWidget {
  const NotebookStackedCover({
    super.key,
    required this.childCount,
    required this.color,
    required this.child,
  });

  /// 直接子本数；0 时原样返回 [child]。
  final int childCount;

  /// 这本的强调色种子（与封面同一套换算），纸边取它的容器色。
  final int? color;
  final Widget child;

  /// 第一层纸边露出的宽度与上下收进的高度（第二层加倍）。
  static const double _peek = 4;
  static const double _inset = 8;

  /// 纸边的宽度与圆角：圆角比卡片小，露出的那一窄条才是一道清楚的边，
  /// 而不是两个圆角。
  static const double _width = 40;
  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    if (childCount <= 0) return child;
    final scheme = Theme.of(context).colorScheme;
    final accent = notebookAccentColors(color, scheme);
    // 往后一层多混一点 surfaceContainerHighest：明暗两套里都比面板底色
    // 更显眼（暗色下不会沉进背景），又比卡片本身更素；不透明，叠在玻璃
    // 面板上也看得清。描边用 outlineVariant，窄条的轮廓更清楚。
    Widget layer(int depth) => PositionedDirectional(
      end: -_peek * depth,
      top: _inset * depth,
      bottom: _inset * depth,
      width: _width,
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
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[layer(2), layer(1), child],
    );
  }
}
