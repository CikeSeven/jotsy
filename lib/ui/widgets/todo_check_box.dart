import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'expressive_state_blend.dart';

/// 待办方框的外观：圆角方块，未勾选为描边（默认 `outline`），勾选后以强调色
/// （默认 `primary`）填充并显示对勾，状态切换经 [ExpressiveStateBlend] 补间
/// 颜色。日记正文的待办块（`DiaryTodoCheckbox`）与独立待办的列表行共用，
/// 两处看起来是同一种方框。
///
/// 给了 [tint]（独立待办有优先级时）：未勾选时方框里铺这层淡底、描边加粗到
/// 2dp（按 18dp 等比），勾选时淡底补间到强调色；不给时与原来逐像素一致。
///
/// 只负责画，不处理点按与读屏：调用方按自己的点按区域包上手势与语义。
class TodoCheckBoxVisual extends StatelessWidget {
  const TodoCheckBoxVisual({
    super.key,
    required this.checked,
    this.size = 18,
    this.accent,
    this.onAccent,
    this.tint,
  });

  final bool checked;

  /// 方块边长；圆角、描边与对勾按它等比缩放。
  final double size;

  /// 未勾选时的描边色与勾选后的填充色；null 时描边为 `outline`、填充为
  /// `primary`。独立待办用它按优先级着色。
  final Color? accent;

  /// 勾选后对勾的颜色，与 [accent] 配对（如 `error` 配 `onError`）；null 时
  /// 为 `onPrimary`。
  final Color? onAccent;

  /// 未勾选时方框里的淡底；null 时为空心。
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = accent ?? colors.primary;
    final rest = accent ?? colors.outline;
    final tint = this.tint;
    final scale = size / 18;
    return SizedBox.square(
      dimension: size,
      child: ExpressiveStateBlend(
        active: checked,
        builder: (context, t, _) => Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint == null
                ? fill.withValues(alpha: t)
                : Color.lerp(tint, fill, t),
            borderRadius: BorderRadius.circular(5 * scale),
            border: Border.all(
              color: Color.lerp(rest, fill, t)!,
              width: (tint == null ? 1.6 : 2) * scale,
            ),
          ),
          child: Opacity(
            opacity: t,
            child: FaIcon(
              FontAwesomeIcons.check,
              size: 11 * scale,
              color: onAccent ?? colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
