import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import 'settings_card_group.dart';
import 'settings_option_tiles.dart';

/// 设置页里有条件显示的区块：出现时随高度展开淡入，消失时随高度收拢淡出。
///
/// 用 AnimatedSwitcher 而不是 AnimatedSize：收起时旧内容要留在原处随高度
/// 一起收拢，而不是先消失再收高度。每次出现都重新构建子项，其中的开关直接
/// 以当前值出现，不会补播一次拨动动画。时长经 [ExpressiveMotion.duration]，
/// 系统减少动态效果时直接显隐。
///
/// 放进 `SettingsCardGroup` 时，应与它所从属的那一行合成分组里的同一项：
/// 分组按位置复用子项并在子项之间插分割线，单独增删会多出分割线，后面的行
/// 也会接手前一行的状态、补播开关动画。
class SettingsReveal extends StatelessWidget {
  /// [visible] 为 false 时收起为零高度。
  SettingsReveal({super.key, required bool visible, required Widget child})
    : child = visible
          ? KeyedSubtree(key: const ValueKey<bool>(true), child: child)
          : const SizedBox.shrink(key: ValueKey<bool>(false));

  /// 在两种内容之间切换：[child] 必须带 key（按 key 区分新旧），否则同类型
  /// 的新旧子项会被当成同一个而不播过渡。
  const SettingsReveal.swap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      layoutBuilder: (Widget? current, List<Widget> previous) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[...previous, ?current],
        );
      },
      child: child,
    );
  }
}

/// 从属行上方的分割线：起点与从属行（`nested: true`）的内容对齐。
const Widget settingsNestedDivider = SettingsCardGroupDivider(
  indent: SettingsSwitchTile.nestedIndent,
);

/// 二级从属行上方的分割线：起点与二级从属行（`deep: true`）的内容对齐。
const Widget settingsDeepNestedDivider = SettingsCardGroupDivider(
  indent: SettingsSwitchTile.deepNestedIndent,
);
