import 'package:flutter/animation.dart';

import '../../../app/theme/expressive_motion.dart';

/// 列表里勾选完成一条待办的时序（“勾选三拍”），行内动效、完成队列与测试
/// 都按这里的节拍走，别处不另写时长：
///
/// 1. 按下：方框压到 [pressedScale]（真弹簧，松手回弹）；
/// 2. 松手勾选：方框弹过 [bounceScale] 再回落（[bounce]），同时以强调色
///    填满、对勾沿笔画描出（方框自己的补间）；
/// 3. 删除线按行从起笔一侧划到另一侧（[strike]），标题同步变灰。
///
/// 三拍之后停一拍（[ExpressiveMotion.beat]），整段为 [check]；随后这一行收起
/// （[collapse]），收起结束才写库，下方的行补位、计数滚动。撤销时这一行原路
/// 展开回来。减少动画时各段时长为 0：方框直接画成勾选、立即写库。
abstract final class TodoCompleteMotion {
  /// 行内动效（含停的一拍）的总时长；[bounce]、[strike] 是其中的区间。
  static final Duration check =
      ExpressiveMotion.standard + ExpressiveMotion.beat;

  /// 行内动效播完后这一行收起的时长。
  static const Duration collapse = ExpressiveMotion.medium;

  /// 按下时方框的缩放。
  static const double pressedScale = 0.9;

  /// 勾选时方框弹到的最大缩放。
  static const double bounceScale = 1.15;

  /// 弹跳占前一半（停的一拍之前结束）。
  static const Interval bounce = Interval(0, 0.5);

  /// 删除线与灰字：从对勾描出一小半时开始，停的一拍之前划完。
  static const Interval strike = Interval(
    0.15,
    0.7,
    curve: ExpressiveMotion.effects,
  );

  /// 弹跳曲线：前 40% 放大到 [bounceScale]（effects），其余按 spatial 回落。
  static final Animatable<double> bounceScaleTween =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: bounceScale,
          ).chain(CurveTween(curve: ExpressiveMotion.effects)),
          weight: 40,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: bounceScale,
            end: 1,
          ).chain(CurveTween(curve: ExpressiveMotion.spatial)),
          weight: 60,
        ),
      ]).chain(CurveTween(curve: bounce));
}
