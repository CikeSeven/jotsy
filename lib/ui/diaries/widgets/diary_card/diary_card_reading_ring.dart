import 'package:flutter/material.dart';

import '../../../widgets/expressive_state_blend.dart';

/// 宽窗口日记页里“正在右栏阅读”的那张卡片的标记：沿卡片外形、画在原有
/// 描边外侧的一圈 2dp 主色细环。
///
/// 输入：是否为当前阅读的卡片 [active]、卡片圆角 [radius]；输出：卡片本身
/// 加一层不参与布局的前景环，没有副作用。与多选的勾选态区分开：多选改变的
/// 是卡片自己的底色与描边（并有勾选图标），这里只在外侧多一圈环，卡片内部
/// 不变。环画在外侧、只占卡片之间的间距，卡片尺寸与位置不变（不引起布局
/// 移动）。显隐经 [ExpressiveStateBlend] 补间（减少动画时直接切换）。
///
/// [revealKey]：当前阅读的卡片挂上这把 key（挂在铺满卡片的透明占位上，
/// 不包住卡片本身，换选时卡片子树不随 key 迁移），页面据此把它滚进视口。
class DiaryCardReadingRing extends StatelessWidget {
  const DiaryCardReadingRing({
    super.key,
    required this.active,
    required this.radius,
    required this.child,
    this.revealKey,
  });

  /// 环的宽度。
  static const double width = 2;

  final bool active;
  final double radius;
  final GlobalKey? revealKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Stack(
      // 原样把列表给的约束交给卡片，卡片的宽度与之前一致。
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExpressiveStateBlend(
              active: active,
              builder: (BuildContext context, double t, Widget? _) {
                if (t <= 0) {
                  return const SizedBox.shrink();
                }
                return DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius),
                      side: BorderSide(
                        color: color.withValues(alpha: color.a * t),
                        width: width,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: SizedBox(key: revealKey)),
        ),
      ],
    );
  }
}
