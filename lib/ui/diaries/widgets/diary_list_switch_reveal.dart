import 'package:flutter/widgets.dart';

import '../../widgets/glass/glass_reveal.dart';
import '../controllers/diary_list_switch_motion.dart';

/// 日记列表里的一项随 [DiaryListSwitchMotion] 退场 / 入场。
///
/// 结构恒定（静止时也包着，值为恒等），动效开始、结束都不改变子树结构，
/// 卡片不会因此重新挂载：
/// - 实色：Opacity → Transform.translate → [child]。不透明度为 1 时 Opacity
///   不建图层，静止时没有额外开销；
/// - 玻璃（[glass]）：Transform.translate → [GlassReveal] → [child]。玻璃的
///   背景模糊放进透明度层后采不到页面（见 [GlassReveal]），改由玻璃表面
///   自己按进度显现；平移不影响模糊采样。
///
/// 同一篇里的几块（章节分隔行与卡片）传同一个 [index]：错峰槽位与位移
/// 相同，一起移动；各自按是否为玻璃决定怎么淡入。
class DiaryListSwitchReveal extends StatelessWidget {
  const DiaryListSwitchReveal({
    super.key,
    required this.motion,
    required this.index,
    required this.child,
    this.glass = false,
  });

  final DiaryListSwitchMotion motion;

  /// 这一项在列表里的下标，决定错峰槽位（见 [DiaryListSwitchMotion.slotFor]）。
  final int index;

  /// [child] 的主体是否为玻璃表面。
  final bool glass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 槽位在 build 里取（不是逐帧的 builder 里）：入场那一帧按下标顺序构建，
    // 第一次取槽位定下错峰锚点。
    final slot = motion.slotFor(index);
    return AnimatedBuilder(
      animation: motion,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final opacity = motion.opacityOf(slot);
        final offset = motion.offsetOf(slot);
        if (glass) {
          return Transform.translate(
            offset: offset,
            child: GlassReveal(progress: opacity, child: child!),
          );
        }
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: offset, child: child),
        );
      },
    );
  }
}
