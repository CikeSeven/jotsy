import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 列表卡片某一个方向上的滑动动作（目前用作 `DiarySwipeActionItem.startAction`，
/// 即右滑 / 从行首往行尾滑开的那一侧）：滑开时背景上的图标与配色，以及松手
/// 生效、条目收起后的回调。
///
/// 只是不可变的描述，不持有状态：宿主每次构建都可以新建一份。组件在卡片
/// 滑出途中会记住生效时的那一份，宿主中途撤掉这个动作也能把滑出与收起
/// 走完、照常回调。
@immutable
class SwipeActionSpec {
  const SwipeActionSpec({
    required this.icon,
    required this.actionColor,
    required this.actionIconColor,
    required this.onSwiped,
  });

  /// 背景上的图标：未到阈值时随滑开距离淡入放大，越过阈值弹一下。
  final FaIconData icon;

  /// 越过阈值后的背景色（未到阈值时为弱化的 `surfaceContainerHighest`）。
  final Color actionColor;

  /// 越过阈值后的图标颜色（未到阈值时为 `onSurfaceVariant`）。
  final Color actionIconColor;

  /// 卡片滑出、条目收起后回调：宿主须在这一帧把条目移出列表（之后组件
  /// 一直保持收起，高度为 0）。
  final VoidCallback onSwiped;
}
