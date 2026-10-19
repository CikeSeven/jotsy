import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 悬浮工具栏上的「文字颜色」/「背景颜色」按钮，点按展开卡片内的颜色面板。
///
/// - 输入：正文控制器、目标（文字 / 背景）、面板是否正为它打开、点按回调；
/// - 输出：只有 [onPressed]，不直接改正文；
/// - 外观与其他工具一致（32dp 可见、40dp 触控区）；图标始终是墨色，不随所选
///   颜色染色，选区当前的颜色画在图标下方 12×3dp 的小条上（没有颜色时不画，
///   半透明的背景色按原样叠在卡片上）。面板为它打开时过渡到已选中工具的
///   primaryContainer 小圆角方形，与「更多」展开态同一做法。
///
/// 只监听正文控制器、随选区局部重建，不牵动整条工具栏。
class DiaryToolbarColorButton extends StatelessWidget {
  const DiaryToolbarColorButton({
    super.key,
    required this.controller,
    required this.target,
    required this.selected,
    required this.tooltip,
    required this.onPressed,
  });

  final quill.QuillController controller;
  final DiaryColorTarget target;
  final bool selected;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) {
          final foreground = Color.lerp(
            colors.onSurface,
            colors.onPrimaryContainer,
            t,
          )!;
          return IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: kDiaryToolbarButtonConstraints,
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.padded,
              shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
                final pressed = states.contains(WidgetState.pressed);
                return RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    pressed ? lerpDouble(12, 8, t)! : lerpDouble(16, 12, t)!,
                  ),
                );
              }),
              backgroundColor: WidgetStatePropertyAll<Color>(
                colors.primaryContainer.withValues(alpha: t),
              ),
              foregroundColor: WidgetStatePropertyAll<Color>(foreground),
              iconColor: WidgetStatePropertyAll<Color>(foreground),
            ),
            icon: SizedBox.square(
              dimension: 32,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  FaIcon(
                    target == DiaryColorTarget.text
                        ? FontAwesomeIcons.palette
                        : FontAwesomeIcons.highlighter,
                    size: 14,
                    color: foreground,
                  ),
                  // 小条落在 32dp 可见区内图标下方，图标位置与其他工具一致。
                  Positioned(
                    bottom: 4,
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (BuildContext context, Widget? child) =>
                          _ColorIndicatorBar(
                            color: DiaryColorValue.of(
                              controller.getSelectionStyle().attributes,
                              target,
                            ).color,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 图标下的颜色小条：颜色出现、消失时淡入淡出，消失过程中保留上一次的颜色，
/// 不经过黑色。
class _ColorIndicatorBar extends StatefulWidget {
  const _ColorIndicatorBar({required this.color});

  final Color? color;

  @override
  State<_ColorIndicatorBar> createState() => _ColorIndicatorBarState();
}

class _ColorIndicatorBarState extends State<_ColorIndicatorBar> {
  Color? _lastColor;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    if (color != null) _lastColor = color;
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    return AnimatedOpacity(
      opacity: color == null ? 0 : 1,
      duration: duration,
      curve: color == null ? ExpressiveMotion.exit : ExpressiveMotion.effects,
      child: AnimatedContainer(
        duration: duration,
        curve: ExpressiveMotion.effects,
        width: 12,
        height: 3,
        decoration: BoxDecoration(
          color: _lastColor ?? const Color(0x00000000),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
