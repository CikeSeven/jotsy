import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/expressive_icon_swap.dart';

/// 卡片标题行末尾的选择标记。
///
/// 选择模式下常驻：未选中为空心圆、选中为实心勾，切换选中只替换图标
/// （[ExpressiveIconSwap]），标题可用宽度不变——此前勾选图标按需插入，会把
/// 标题挤窄、重新折行，整张卡片跳一下。进出选择模式时槽位宽度经补间展开/收起
/// （Align.widthFactor + ClipRect，结构恒定），减少动画时直接落位。
class DiaryCardSelectionMark extends StatelessWidget {
  const DiaryCardSelectionMark({
    super.key,
    required this.selected,
    required this.isSelectionMode,
    required this.compact,
    required this.selectedColor,
    required this.unselectedColor,
    required this.duration,
  });

  final bool selected;
  final bool isSelectionMode;
  final bool compact;
  final Color selectedColor;
  final Color unselectedColor;

  /// 进出选择模式的展开时长（与列表项进出动画同一 token）。
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isSelectionMode ? 1 : 0),
      duration: ExpressiveMotion.duration(context, duration),
      curve: ExpressiveMotion.effects,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: compact ? 6 : 8,
          top: compact ? 0 : 2,
        ),
        child: ExpressiveIconSwap(
          switchKey: selected,
          child: FaIcon(
            selected
                ? FontAwesomeIcons.solidCircleCheck
                : FontAwesomeIcons.circle,
            size: compact ? 16 : 18,
            color: selected ? selectedColor : unselectedColor,
          ),
        ),
      ),
      builder: (BuildContext context, double reveal, Widget? child) {
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            widthFactor: reveal,
            child: Opacity(opacity: reveal, child: child),
          ),
        );
      },
    );
  }
}
