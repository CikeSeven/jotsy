import 'package:flutter/material.dart';

import '../../../widgets/expressive_state_blend.dart';

/// 正在阅读的卡片此刻在哪：阅读环构建时把自己的位置记在这里，日记页据此
/// 把它滚进视口（`Scrollable.ensureVisible`）。
///
/// 不用 GlobalKey：换选、切换列表 / 瀑布流时 key 会在两棵子树之间搬家，
/// 搬进刚换掉的滚动视图里会触发语义树的断言。这里只记 context，用的时候
/// 核对日记 id 并确认它仍挂在树上。
class DiaryReadingCardLocator {
  String? _diaryId;
  BuildContext? _context;

  void _attach(String diaryId, BuildContext context) {
    _diaryId = diaryId;
    _context = context;
  }

  /// [diaryId] 那张卡片的 context；它没有构建（懒加载列表滚到了远处）或
  /// 已卸载时为 null。
  BuildContext? contextFor(String diaryId) {
    final context = _context;
    if (_diaryId != diaryId || context == null || !context.mounted) {
      return null;
    }
    return context;
  }
}

/// 宽窗口日记页里“正在右栏阅读”的那张卡片的标记：沿卡片外形、画在原有
/// 描边外侧的一圈 2dp 主色细环。
///
/// 输入：是否为当前阅读的卡片 [active]、卡片圆角 [radius]；输出：卡片本身
/// 加一层不参与布局的前景环，没有副作用（除了把位置记进 [locator]）。与多选
/// 的勾选态区分开：多选改变的是卡片自己的底色与描边（并有勾选图标），这里
/// 只在外侧多一圈环，卡片内部不变。环画在外侧、只占卡片之间的间距，卡片
/// 尺寸与位置不变（不引起布局移动）。显隐经 [ExpressiveStateBlend] 补间
/// （减少动画时直接切换）。
class DiaryCardReadingRing extends StatelessWidget {
  const DiaryCardReadingRing({
    super.key,
    required this.diaryId,
    required this.active,
    required this.radius,
    required this.child,
    this.locator,
  });

  /// 环的宽度。
  static const double width = 2;

  final String diaryId;
  final bool active;
  final double radius;
  final DiaryReadingCardLocator? locator;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (active) {
      locator?._attach(diaryId, context);
    }
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
      ],
    );
  }
}
